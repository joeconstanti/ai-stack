#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

print_banner() {
  cat <<'EOF'
 █████╗ ██╗      ███████╗████████╗ █████╗  ██████╗██╗  ██╗
██╔══██╗██║      ██╔════╝╚══██╔══╝██╔══██╗██╔════╝██║ ██╔╝
███████║██║█████╗███████╗   ██║   ███████║██║     █████╔╝
██╔══██║██║╚════╝╚════██║   ██║   ██╔══██║██║     ██╔═██╗
██║  ██║██║      ███████║   ██║   ██║  ██║╚██████╗██║  ██╗
╚═╝  ╚═╝╚═╝      ╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
EOF
}

error() {
  echo "Error: $*" >&2
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Required command '$1' is not installed or not on PATH."
    exit 1
  fi
}

require_docker_compose() {
  if ! docker compose version >/dev/null 2>&1; then
    error "Docker Compose plugin is missing. Install Docker Compose and retry."
    exit 1
  fi
}

prompt_with_default() {
  local prompt="$1"
  local default_value="${2:-}"
  local value=""

  if [[ -n "$default_value" ]]; then
    read -r -p "${prompt} (Default: ${default_value}): " value
    if [[ -z "$value" ]]; then
      value="$default_value"
    fi
  else
    read -r -p "${prompt}: " value
  fi

  echo "$value"
}

prompt_yes_no() {
  local prompt="$1"
  local default_choice="$2"
  local answer=""
  local suffix=""

  if [[ "$default_choice" == "yes" ]]; then
    suffix="[Y/n]"
  else
    suffix="[y/N]"
  fi

  while true; do
    read -r -p "${prompt} ${suffix}: " answer
    answer="$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')"

    if [[ -z "$answer" ]]; then
      answer="$default_choice"
    fi

    case "$answer" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) echo "Please answer yes or no." ;;
    esac
  done
}

generate_secret() {
  openssl rand -base64 48 | tr -d '\n'
}

print_banner
echo
echo "This installer will generate a new .env file and start the stack."
echo

require_command docker
require_command openssl
require_docker_compose

if [[ -f "$ENV_FILE" ]]; then
  if ! prompt_yes_no ".env already exists. Overwrite it?" "no"; then
    echo "Installation aborted."
    exit 0
  fi
fi

echo
echo "Deployment mode:"
echo "1) Local (HTTP, direct port access)"
echo "2) Traefik (HTTPS, Let's Encrypt)"
deploy_choice="$(prompt_with_default "Choose deployment mode [1/2]" "1")"

case "$deploy_choice" in
  1|local|LOCAL)
    DEPLOY_MODE="local"
    N8N_PROTOCOL="http"
    N8N_PROXY_HOPS="0"
    COMPOSE_ARGS=(-f docker-compose.local.yml)
    ;;
  2|traefik|TRAEFIK)
    DEPLOY_MODE="traefik"
    N8N_PROTOCOL="https"
    N8N_PROXY_HOPS="1"
    COMPOSE_ARGS=()
    ;;
  *)
    error "Invalid deployment mode: ${deploy_choice}"
    exit 1
    ;;
esac

POSTGRES_USER="$(prompt_with_default "What do you want your postgres username to be?" "n8n-user")"
read -r -s -p "What do you want your postgres password to be? (leave blank to auto-generate): " POSTGRES_PASSWORD
echo
if [[ -z "$POSTGRES_PASSWORD" ]]; then
  POSTGRES_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
  echo "Generated postgres password: ${POSTGRES_PASSWORD}"
fi
POSTGRES_DB="$(prompt_with_default "What do you want your postgres database name to be?" "n8n-db")"

N8N_PORT="$(prompt_with_default "What port do you want n8n to run on?" "5678")"
N8N_PATH="/"

LETSENCRYPT_EMAIL=""

if [[ "$DEPLOY_MODE" == "traefik" ]]; then
  N8N_HOST="$(prompt_with_default "What is your n8n host? (domain/subdomain)" "")"
  while [[ -z "$N8N_HOST" ]]; do
    echo "A domain is required for Traefik deployment."
    N8N_HOST="$(prompt_with_default "What is your n8n host? (domain/subdomain)" "")"
  done

  LETSENCRYPT_EMAIL="$(prompt_with_default "What is your email address (for letsencrypt)?" "")"
  while [[ -z "$LETSENCRYPT_EMAIL" ]]; do
    echo "An email is required for Let's Encrypt."
    LETSENCRYPT_EMAIL="$(prompt_with_default "What is your email address (for letsencrypt)?" "")"
  done

  WEBHOOK_URL="https://${N8N_HOST}/"
else
  N8N_HOST="$(prompt_with_default "What is your n8n host?" "localhost")"
  if prompt_yes_no "Do you want to add a custom domain/subdomain for webhook URL?" "no"; then
    custom_domain="$(prompt_with_default "Enter custom domain/subdomain (without protocol)" "")"
    while [[ -z "$custom_domain" ]]; do
      echo "Please provide a domain."
      custom_domain="$(prompt_with_default "Enter custom domain/subdomain (without protocol)" "")"
    done
    WEBHOOK_URL="http://${custom_domain}/"
  else
    WEBHOOK_URL="http://${N8N_HOST}:${N8N_PORT}/"
  fi
fi

USE_QDRANT="yes"
if ! prompt_yes_no "Will you be using qdrant?" "yes"; then
  USE_QDRANT="no"
fi

USE_OLLAMA="no"
OLLAMA_HOST=""
if prompt_yes_no "Will you be using ollama?" "no"; then
  USE_OLLAMA="yes"
  if [[ "$DEPLOY_MODE" == "traefik" ]]; then
    OLLAMA_HOST="$(prompt_with_default "What is your Ollama host?" "<public-ip>:11434")"
  else
    OLLAMA_HOST="$(prompt_with_default "What is your Ollama host?" "localhost:11434")"
  fi
fi

N8N_ENCRYPTION_KEY="$(generate_secret)"
N8N_USER_MANAGEMENT_JWT_SECRET="$(generate_secret)"

cat > "$ENV_FILE" <<EOF
# Generated by install.sh
# Required
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}
N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
N8N_USER_MANAGEMENT_JWT_SECRET=${N8N_USER_MANAGEMENT_JWT_SECRET}

# n8n
N8N_HOST=${N8N_HOST}
N8N_PROTOCOL=${N8N_PROTOCOL}
N8N_PORT=${N8N_PORT}
N8N_PATH=${N8N_PATH}
N8N_PROXY_HOPS=${N8N_PROXY_HOPS}
WEBHOOK_URL=${WEBHOOK_URL}

# Recommended
N8N_RUNNERS_ENABLED=true
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
EOF

if [[ "$DEPLOY_MODE" == "traefik" ]]; then
  cat >> "$ENV_FILE" <<EOF
LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}
EOF
fi

if [[ "$USE_OLLAMA" == "yes" ]]; then
  cat >> "$ENV_FILE" <<EOF
OLLAMA_HOST=${OLLAMA_HOST}
EOF
fi

echo
echo "Configuration complete. Wrote: ${ENV_FILE}"
echo "Deployment mode: ${DEPLOY_MODE}"
echo "n8n URL: ${N8N_PROTOCOL}://${N8N_HOST}"
if [[ "$DEPLOY_MODE" == "local" ]]; then
  echo "n8n URL with port: ${N8N_PROTOCOL}://${N8N_HOST}:${N8N_PORT}"
fi
if [[ "$USE_QDRANT" == "no" ]]; then
  echo "Qdrant: disabled"
fi
if [[ "$USE_OLLAMA" == "yes" ]]; then
  echo "Ollama host: ${OLLAMA_HOST}"
fi
echo

if ! prompt_yes_no "Proceed with Docker Compose startup now?" "yes"; then
  echo "Skipped docker compose startup. Run it manually when ready."
  exit 0
fi

docker_compose_cmd=(docker compose "${COMPOSE_ARGS[@]}" up -d)
if [[ "$USE_QDRANT" == "no" ]]; then
  docker_compose_cmd+=(--scale qdrant=0)
fi

"${docker_compose_cmd[@]}"

echo
echo "Done. Your stack is starting now."
echo "You can check status with: docker compose ${COMPOSE_ARGS[*]} ps"
