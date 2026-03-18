```text
 █████╗ ██╗      ███████╗████████╗ █████╗  ██████╗██╗  ██╗
██╔══██╗██║      ██╔════╝╚══██╔══╝██╔══██╗██╔════╝██║ ██╔╝
███████║██║█████╗███████╗   ██║   ███████║██║     █████╔╝ 
██╔══██║██║╚════╝╚════██║   ██║   ██╔══██║██║     ██╔═██╗ 
██║  ██║██║      ███████║   ██║   ██║  ██║╚██████╗██║  ██╗
╚═╝  ╚═╝╚═╝      ╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
```
**AI Stack** is an open-source Docker Compose template designed to swiftly initialize a comprehensive local AI and low-code development environment.

## Quick start: choose your setup

### Local (no HTTPS, direct ports)

1) Create `.env` (minimum)

```bash
cp .env.example .env
# Required
POSTGRES_USER=<your-user>
POSTGRES_PASSWORD=<your-strong-password>
POSTGRES_DB=<your-db>

# Recommended
N8N_RUNNERS_ENABLED=true
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true

# Local n8n behind no proxy
N8N_HOST=localhost
N8N_PROTOCOL=http
N8N_PORT=5678
N8N_PATH=/
N8N_PROXY_HOPS=0
WEBHOOK_URL=http://localhost:5678/

# If using Ollama outside Docker (recommended)
# OLLAMA_HOST=localhost:11434
```

2) Start local stack

```bash
docker compose -f docker-compose.local.yml up -d
```

3) Open: `http://localhost:5678`

Reset local data (optional): `docker compose -f docker-compose.local.yml down -v`

### Production (Traefik + HTTPS)

1) Prereqs: DNS A record to your server, ports 80/443 open (cloud firewalls like DigitalOcean Firewalls must allow 80/443; UFW on the server is fine), Docker + Compose installed

2) Create `.env` (minimum)

```bash
cp .env.example .env
# Required
POSTGRES_USER=<your-user>
POSTGRES_PASSWORD=<your-strong-password>
POSTGRES_DB=<your-db>
LETSENCRYPT_EMAIL=<you@example.com>
N8N_ENCRYPTION_KEY=<random-48+ chars>
N8N_USER_MANAGEMENT_JWT_SECRET=<random-48+ chars>

# n8n behind Traefik
N8N_HOST=<your-domain>
N8N_PROTOCOL=https
N8N_PORT=5678
N8N_PATH=/
N8N_PROXY_HOPS=1
WEBHOOK_URL=https://<your-domain>/

# If using Ollama outside Docker (recommended)
# OLLAMA_HOST=<public-ip>:11434
```

Tip (generate secrets):

```bash
openssl rand -base64 48
```

3) Start production stack

```bash
docker compose up -d
```

4) Open: `https://<your-domain>`

Update (both modes):

```bash
docker compose pull && docker compose up -d --no-deps --remove-orphans
```

![n8n.io - Screenshot](assets/n8n-demo.gif)

Curated by <https://github.com/fromtheroot>, and built on [n8n](https://n8n.io/), it combines the self-hosted n8n
platform with a curated set of compatible AI products and components to quickly get started with
building self-hosted AI workflows.

> [!TIP]
> [Read the announcement](https://blog.n8n.io/self-hosted-ai/)

### What’s included

✅ [**Self-hosted n8n**](https://n8n.io/) - Low-code platform with over 400
integrations and advanced AI components

✅ [**Ollama**](https://ollama.com/) - Recommended to install outside Docker for best performance

✅ [**Qdrant**](https://qdrant.tech/) - Open-source, high performance vector
store with an comprehensive API

✅ [**PostgreSQL**](https://www.postgresql.org/) -  Workhorse of the Data
Engineering world, handles large amounts of data safely.

### What you can build

⭐️ **AI Agents** for scheduling appointments

⭐️ **Summarize Company PDFs** securely without data leaks

⭐️ **Smarter Slack Bots** for enhanced company communications and IT operations

⭐️ **Private Financial Document Analysis** at minimal cost

## Installation

### Cloning the Repository

```bash
git clone https://github.com/fromtheroot/ai-stack.git
cd ai-stack
cp .env.example .env # you should update secrets and passwords inside
```

### Running n8n using Docker Compose

#### For Mac / Apple Silicon users

If you’re using a Mac with an M1 or newer processor, you can't expose your GPU
to the Docker instance, unfortunately. There are two options in this case:

1. Run the starter kit fully on CPU, like in the section "For everyone else"
   below
2. Run Ollama on your Mac for faster inference, and connect to that from the
   n8n instance

If you want to run Ollama on your Mac, install it directly on the host (outside Docker) for better performance. See the [Ollama homepage](https://ollama.com/) for installation instructions, then run the starter kit as follows:

```bash
git clone https://github.com/fromtheroot/ai-stack.git
cd ai-stack
cp .env.example .env # you should update secrets and passwords inside
docker compose up
```

##### For Mac users running OLLAMA locally

If you're running OLLAMA locally on your Mac (not in Docker), you need to modify the OLLAMA_HOST environment variable

1. Set OLLAMA_HOST to `localhost:11434` (or your host IP: `http://<IP>:11434`) in your .env file. 
2. Additionally, after you see "Editor is now accessible via: <http://localhost:5678/>":

    1. Head to <http://localhost:5678/home/credentials>
    2. Click on "Local Ollama service"
    3. Change the base URL to "http://localhost:11434/" (or your host IP)

#### For everyone else

```bash
git clone https://github.com/fromtheroot/ai-stack.git
cd ai-stack
cp .env.example .env # you should update secrets and passwords inside
docker compose up -d
```

## ⚡️ Quick start and usage

The core of AI Stack is a Docker Compose setup, pre-configured with network and storage settings, minimizing the need for additional installations.
After completing the installation steps above, simply follow the steps below to get started.

1. Open <http://localhost:5678/> in your browser to set up n8n. You’ll only
   have to do this once.
2. Open the included workflow:
   <http://localhost:5678/workflow/srOnR8PAY3u4RSwb>
3. Click the **Chat** button at the bottom of the canvas, to start running the workflow.
4. If this is the first time you’re running the workflow, you may need to wait
   until Ollama finishes downloading Llama3.2. You can inspect the docker
   console logs to check on the progress.

To open n8n at any time, visit <http://localhost:5678/> in your browser.

With your n8n instance, you’ll have access to over 400 integrations and a
suite of basic and advanced AI nodes such as
[AI Agent](https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.agent/),
[Text classifier](https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.text-classifier/),
and [Information Extractor](https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.information-extractor/)
nodes. To keep everything local, just remember to use the Ollama node for your
language model and Qdrant as your vector store.

> [!NOTE]
> This starter kit is designed to help you get started with self-hosted AI
> workflows. While it’s not fully optimized for production environments, it
> combines robust components that work well together for proof-of-concept
> projects. You can customize it to meet your specific needs

## 🧪 Local deployment (docker-compose.local.yml)

1) Copy environment and set recommended flags

```bash
cp .env.example .env
# Recommended:
# N8N_RUNNERS_ENABLED=true
# N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
# If using Ollama outside Docker (recommended):
# OLLAMA_HOST=localhost:11434
```

2) Start the stack with the local compose file

```bash
docker compose -f docker-compose.local.yml up -d
```

4) Open the app

- n8n: `http://localhost:5678`
- Qdrant (optional): `http://localhost:6333`
- Ollama (optional): `http://localhost:11434`

Reset local data (optional)

```bash
docker compose -f docker-compose.local.yml down -v
```

Note: If you change `POSTGRES_PASSWORD` after the first run, also clear volumes or revert to the original password to avoid auth failures.

## Upgrading

```bash
docker compose pull
docker compose up -d --no-deps --remove-orphans
```

## 👓 Recommended reading

n8n is full of useful content for getting started quickly with its AI concepts
and nodes. If you run into an issue, go to [support](#support).

- [AI agents for developers: from theory to practice with n8n](https://blog.n8n.io/ai-agents/)
- [Tutorial: Build an AI workflow in n8n](https://docs.n8n.io/advanced-ai/intro-tutorial/)
- [Langchain Concepts in n8n](https://docs.n8n.io/advanced-ai/langchain/langchain-n8n/)
- [Demonstration of key differences between agents and chains](https://docs.n8n.io/advanced-ai/examples/agent-chain-comparison/)
- [What are vector databases?](https://docs.n8n.io/advanced-ai/examples/understand-vector-databases/)

## 🎥 Video walkthrough

- [Installing and using Local AI for n8n](https://www.youtube.com/watch?v=xz_X2N-hPg0)

## 🛍️ More AI templates

For more AI workflow ideas, visit the [**official n8n AI template
gallery**](https://n8n.io/workflows/categories/ai/). From each workflow,
select the **Use workflow** button to automatically import the workflow into
your local n8n instance.

### Learn AI key concepts

- [AI Agent Chat](https://n8n.io/workflows/1954-ai-agent-chat/)
- [AI chat with any data source (using the n8n workflow too)](https://n8n.io/workflows/2026-ai-chat-with-any-data-source-using-the-n8n-workflow-tool/)
- [Chat with OpenAI Assistant (by adding a memory)](https://n8n.io/workflows/2098-chat-with-openai-assistant-by-adding-a-memory/)
- [Use an open-source LLM (via Hugging Face)](https://n8n.io/workflows/1980-use-an-open-source-llm-via-huggingface/)
- [Chat with PDF docs using AI (quoting sources)](https://n8n.io/workflows/2165-chat-with-pdf-docs-using-ai-quoting-sources/)
- [AI agent that can scrape webpages](https://n8n.io/workflows/2006-ai-agent-that-can-scrape-webpages/)

### Local AI templates

- [Tax Code Assistant](https://n8n.io/workflows/2341-build-a-tax-code-assistant-with-qdrant-mistralai-and-openai/)
- [Breakdown Documents into Study Notes with MistralAI and Qdrant](https://n8n.io/workflows/2339-breakdown-documents-into-study-notes-using-templating-mistralai-and-qdrant/)
- [Financial Documents Assistant using Qdrant and](https://n8n.io/workflows/2335-build-a-financial-documents-assistant-using-qdrant-and-mistralai/) [Mistral.ai](http://mistral.ai/)
- [Recipe Recommendations with Qdrant and Mistral](https://n8n.io/workflows/2333-recipe-recommendations-with-qdrant-and-mistral/)

## Tips & tricks

### Accessing local files

AI Stack will create a shared folder (by default,
located in the same directory) which is mounted to the n8n container and
allows n8n to access files on disk. This folder within the n8n container is
located at `/data/shared` -- this is the path you’ll need to use in nodes that
interact with the local filesystem.

**Nodes that interact with the local filesystem**

- [Read/Write Files from Disk](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.filesreadwrite/)
- [Local File Trigger](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.localfiletrigger/)
- [Execute Command](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.executecommand/)

## 🚀 Production deployment with Traefik and custom domain

These compose files are ready to run behind a reverse proxy with automatic HTTPS using Traefik.

### Step-by-step guide (DigitalOcean / Ubuntu)

1. Create droplet
   - Ubuntu LTS, at least 2 CPU / 4 GB RAM recommended
   - Add your SSH key

2. Point DNS
   - Create an A record: `<your-domain> -> <your-droplet-ip>`

3. Install Docker and Compose plugin
   ```bash
   sudo apt-get update -y && sudo apt-get install -y ca-certificates curl gnupg
   sudo install -m 0755 -d /etc/apt/keyrings
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
   echo \
     "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
     $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
     sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   sudo apt-get update -y
   sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   sudo usermod -aG docker $USER && newgrp docker
   ```

4. Clone the repo and configure environment
   ```bash
   git clone https://github.com/fromtheroot/ai-stack.git
   cd ai-stack
   cp .env.example .env
   # Edit .env and set strong secrets and your real domain/email
   ```

5. Start the stack
   ```bash
   docker compose up -d
   ```

6. Verify
   ```bash
   docker compose logs -f traefik n8n | cat
   ```
   - Wait for Traefik to obtain certificates
   - Open `https://<your-domain>` in your browser

7. Updates
   ```bash
   docker compose pull
   docker compose up -d --no-deps --remove-orphans
   ```


### Prerequisites

- Ubuntu server (e.g., DigitalOcean droplet) with Docker and Docker Compose plugin installed
- DNS A record for your domain pointing to the server (e.g., `<your-domain>`)
- Firewall allows inbound ports 80 and 443

### 1) Configure environment

```bash
cp .env.example .env
# Edit .env and set at minimum:
# - POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB
# - N8N_HOST=<your-domain>
# - WEBHOOK_URL=https://<your-domain>/
# - LETSENCRYPT_EMAIL=<you@example.com>
```

### 2) Start the stack

```bash
docker compose up -d
```

### 3) Check logs

```bash
docker compose logs -f traefik n8n
```

### 4) Access your instance

Open https://<your-domain> in your browser. Traefik will automatically request and store a Let's Encrypt TLS certificate inside its `letsencrypt` Docker volume.

Notes:

- Only `n8n` is publicly exposed via Traefik. `Postgres`, `Qdrant`, and `Ollama` are private on the Docker network.
- To add future apps, attach them to the `traefik_proxy` network and add Traefik labels.

## 📜 License

This project is licensed under the Apache License 2.0 - see the
[LICENSE](LICENSE) file for details.

## 💬 Support

Join the conversation in the [n8n Forum](https://community.n8n.io/), where you
can:

- **Share Your Work**: Show off what you’ve built with n8n and inspire others
  in the community.
- **Ask Questions**: Whether you’re just getting started or you’re a seasoned
  pro, the community and our team are ready to support with any challenges.
- **Propose Ideas**: Have an idea for a feature or improvement? Let us know!
  We’re always eager to hear what you’d like to see next.
