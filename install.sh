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

extract_env_value() {
  local file_path="$1"
  local key="$2"
  local line

  line="$(rg -n "^${key}=" "$file_path" | head -n 1 || true)"
  if [[ -z "$line" ]]; then
    echo ""
    return 0
  fi

  echo "${line#*=}"
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

EXISTING_ENCRYPTION_KEY=""
EXISTING_JWT_SECRET=""
EXISTING_POSTGRES_PASSWORD=""

if [[ -f "$ENV_FILE" ]]; then
  EXISTING_ENCRYPTION_KEY="$(extract_env_value "$ENV_FILE" "N8N_ENCRYPTION_KEY")"
  EXISTING_JWT_SECRET="$(extract_env_value "$ENV_FILE" "N8N_USER_MANAGEMENT_JWT_SECRET")"
  EXISTING_POSTGRES_PASSWORD="$(extract_env_value "$ENV_FILE" "POSTGRES_PASSWORD")"

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

RESET_N8N_STORAGE="no"
RESET_POSTGRES_STORAGE="no"
REUSE_EXISTING_KEYS="no"
if [[ -n "$EXISTING_ENCRYPTION_KEY" && -n "$EXISTING_JWT_SECRET" ]]; then
  if prompt_yes_no "Reuse existing n8n encryption keys from current .env?" "no"; then
    REUSE_EXISTING_KEYS="yes"
  fi
fi

if [[ "$REUSE_EXISTING_KEYS" == "yes" ]]; then
  N8N_ENCRYPTION_KEY="$EXISTING_ENCRYPTION_KEY"
  N8N_USER_MANAGEMENT_JWT_SECRET="$EXISTING_JWT_SECRET"
else
  N8N_ENCRYPTION_KEY="$(generate_secret)"
  N8N_USER_MANAGEMENT_JWT_SECRET="$(generate_secret)"
  if [[ -n "$EXISTING_ENCRYPTION_KEY" || -n "$EXISTING_JWT_SECRET" ]]; then
    echo
    echo "Warning: New encryption keys generated."
    echo "If n8n data already exists, n8n may fail until storage is reset."
    if prompt_yes_no "Reset existing n8n storage volume before startup?" "yes"; then
      RESET_N8N_STORAGE="yes"
    fi
  fi
fi

if [[ -n "$EXISTING_POSTGRES_PASSWORD" && "$EXISTING_POSTGRES_PASSWORD" != "$POSTGRES_PASSWORD" ]]; then
  echo
  echo "Postgres password changed from existing .env."
  echo "If Postgres data already exists, authentication may fail until storage is reset."
  if prompt_yes_no "Reset existing Postgres storage volume before startup?" "yes"; then
    RESET_POSTGRES_STORAGE="yes"
  fi
fi

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

if [[ "$RESET_N8N_STORAGE" == "yes" ]]; then
  project_name="$(basename "$SCRIPT_DIR")"
  n8n_volume_name="${project_name}_n8n_storage"
  echo
  echo "Stopping stack and removing n8n storage volume..."
  docker compose "${COMPOSE_ARGS[@]}" down >/dev/null 2>&1 || true
  docker volume rm "$n8n_volume_name" >/dev/null 2>&1 || true
fi

if [[ "$RESET_POSTGRES_STORAGE" == "yes" ]]; then
  project_name="$(basename "$SCRIPT_DIR")"
  postgres_volume_name="${project_name}_postgres_storage"
  echo
  echo "Stopping stack and removing Postgres storage volume..."
  docker compose "${COMPOSE_ARGS[@]}" down >/dev/null 2>&1 || true
  docker volume rm "$postgres_volume_name" >/dev/null 2>&1 || true
fi

docker_compose_cmd=(docker compose "${COMPOSE_ARGS[@]}" up -d)
if [[ "$USE_QDRANT" == "no" ]]; then
  docker_compose_cmd+=(--scale qdrant=0)
fi

compose_output_file="$(mktemp)"
set +e
"${docker_compose_cmd[@]}" 2>&1 | tee "$compose_output_file"
compose_exit_code=${PIPESTATUS[0]}
set -e

if [[ $compose_exit_code -ne 0 ]]; then
  if grep -Eq "n8n-import.+didn't complete successfully" "$compose_output_file"; then
    echo
    echo "Warning: n8n-import failed. Continuing because this can be expected."
    echo "Starting n8n directly without waiting on import completion..."
    docker compose "${COMPOSE_ARGS[@]}" up -d --no-deps n8n
  else
    rm -f "$compose_output_file"
    error "Docker Compose startup failed. Please review output above."
    exit $compose_exit_code
  fi
fi

rm -f "$compose_output_file"

echo
echo "Done. Your stack is starting now."
echo "You can check status with: docker compose ${COMPOSE_ARGS[*]} ps"
