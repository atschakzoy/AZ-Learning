# Docker, ACR, and Azure Container Apps

How to package your app, store it, and run it on Azure.

---

## What is Docker?

Docker lets you package your app and everything it needs to run into one unit called a **container**.

"Everything it needs" means:
- Python (or whatever language you use)
- All your libraries (`pip install`)
- Your code
- Configuration

You build that container once and run it anywhere — your Mac, someone else's Windows PC, Azure — and it behaves identically every time. No "it works on my machine" problems.

---

## Container vs Virtual Machine

Both isolate your app. The difference is how deep they go:

```
Virtual Machine                    Container
┌─────────────────┐               ┌─────────────────┐
│   Your App      │               │   Your App      │
│   Libraries     │               │   Libraries     │
│   Python        │               │   Python        │
│   Full OS       │  ← heavy      │                 │
│   Hypervisor    │               │  Docker Engine  │  ← light
│   Host OS       │               │   Host OS       │
└─────────────────┘               └─────────────────┘
  GBs, minutes to start             MBs, seconds to start
```

A VM includes a full operating system inside it — slow and heavy.
A container shares the OS of the machine it runs on — fast and small.

---

## Image vs Container

Two words you'll hear constantly:

| | Image | Container |
|--|-------|-----------|
| What it is | The blueprint (read-only) | A running instance of an image |
| Analogy | A recipe | The actual food made from the recipe |
| Built by | `docker build` | `docker run` |

One image → you can run many containers from it at the same time.

---

## The Dockerfile

A Dockerfile is a plain text file with instructions for building an image. It's a recipe — Docker reads it top to bottom and builds your image step by step.

```dockerfile
# Start from an official Python base image
FROM python:3.11-slim

# Set the working directory inside the container
WORKDIR /app

# Copy requirements file first
COPY requirements.txt .

# Install dependencies
RUN pip install -r requirements.txt

# Copy the rest of your code
COPY . .

# Tell Docker what port the app listens on
EXPOSE 8000

# The command to run when the container starts
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Line by line:**

| Line | What it does |
|------|-------------|
| `FROM python:3.11-slim` | Start from a pre-built Python image — you don't install Python yourself |
| `WORKDIR /app` | All commands from here run inside `/app` inside the container |
| `COPY requirements.txt .` | Copy your requirements file into the container |
| `RUN pip install -r requirements.txt` | Install your libraries inside the container |
| `COPY . .` | Copy all your code into the container |
| `EXPOSE 8000` | Document that this container uses port 8000 |
| `CMD [...]` | What runs when the container starts |

---

## Core Docker Commands

```bash
# Build an image from the Dockerfile in your current folder
docker build -t my-app .

# Run a container from that image
docker run -p 8000:8000 my-app

# Run with environment variables (your secrets)
docker run -p 8000:8000 \
  -e AZURE_OPENAI_ENDPOINT=https://... \
  -e AZURE_OPENAI_KEY=abc123 \
  my-app

# See all running containers
docker ps

# Stop a running container
docker stop <container-id>

# See all images on your machine
docker images

# Delete an image
docker rmi my-app
```

---

## Port Mapping — the `-p` flag

Your container is isolated from your machine. Nothing can reach it unless you open a door.

```bash
docker run -p 8000:8000 my-app
#           ↑     ↑
#     your Mac  container's port
```

`-p 8000:8000` means: connect your Mac's port 8000 to the container's port 8000.

You can map different numbers:
```bash
docker run -p 3000:8000 my-app
# your Mac port 3000 → container port 8000
# open localhost:3000 in your browser to reach the app
```

---

## ACR — Azure Container Registry

ACR is a private storage place for your Docker images inside Azure.

Think of it as a warehouse. It holds your images so Azure services can pull them when needed.

**Why not just use Docker Hub?**
- Docker Hub is public by default — your code is visible to everyone
- ACR is private, inside your Azure subscription
- Azure services trust ACR natively — no extra auth setup

**The workflow:**

```bash
# 1. Login to your ACR
az acr login --name myregistry

# 2. Tag your image with the ACR address
docker build -t myregistry.azurecr.io/my-app:latest .

# 3. Push the image to ACR
docker push myregistry.azurecr.io/my-app:latest
```

Now your image is stored in Azure. Any Azure service can pull it.

**Image tags:**
The `:latest` part is a tag — a label for the version. You can tag by version number too:
```bash
myregistry.azurecr.io/my-app:v1.0
myregistry.azurecr.io/my-app:v1.1
myregistry.azurecr.io/my-app:latest
```

---

## ACA — Azure Container Apps

ACA is the Azure service that actually **runs** your containers. You point it at an image in ACR and it starts running your app.

ACA handles everything you'd otherwise have to manage yourself:
- Scaling
- Networking
- Domain and HTTPS
- Health checks

---

## Scaling — Handling More Traffic Automatically

Scaling means: when more people use your app, run more containers. When it's quiet, run fewer (or zero).

**Without scaling:**
```
100 users hit your app at the same time
→ 1 container tries to handle all 100
→ it gets slow or crashes
```

**With ACA scaling:**
```
100 users hit your app
→ ACA detects the load
→ ACA starts 5 containers automatically
→ traffic is split between them
→ each container handles 20 users comfortably
```

When traffic drops back down, ACA shuts the extra containers off.

**Scale to zero:**
ACA can scale your app down to zero containers when nobody is using it. Zero containers = zero cost. When a request comes in, ACA starts a container in a few seconds to handle it. This is great for dev/test environments or apps with low traffic — you only pay when the app is actually being used.

**What triggers scaling:**
- Number of incoming HTTP requests
- CPU usage
- Memory usage
- Custom rules you define

---

## Networking — How Traffic Reaches Your Container

Your container runs inside Azure's network. By default nothing outside can reach it. You control access with **ingress**.

**Ingress** = the door that lets traffic in.

Two types:

| Type | Who can reach it |
|------|-----------------|
| `external` | Anyone on the internet |
| `internal` | Only other services inside Azure (private) |

When you set ingress to `external`, ACA creates a public endpoint — a URL anyone can call.

```bash
az containerapp create \
  --name my-app \
  --ingress external \       # open to the internet
  --target-port 8000         # forward traffic to port 8000 in your container
```

ACA then gives you a URL like:
```
https://my-app.happybeach-abc123.westeurope.azurecontainerapps.io
```

---

## Domains and HTTPS

**Default domain:**
When ACA creates your app it gives you a long auto-generated URL:
```
https://my-app.happybeach-abc123.westeurope.azurecontainerapps.io
```

It's ugly but it works and it's already HTTPS.

**Custom domain:**
You can attach your own domain name (`myapp.com`) to ACA:
1. You own the domain (bought from a registrar like Namecheap, GoDaddy)
2. You point the domain's DNS to ACA's IP address
3. ACA verifies you own it
4. Done — `myapp.com` now hits your container

**HTTPS — why it matters:**
HTTPS encrypts the connection between the user and your server. Without it, anyone in between (the user's ISP, a coffee shop router) can read the traffic — including API keys and user data.

**ACA handles HTTPS automatically:**
- It provisions a TLS certificate (the thing that makes HTTPS work)
- It renews the certificate before it expires
- You do nothing — HTTPS is on by default

For your custom domain, ACA also handles the certificate automatically using a service called Let's Encrypt (a free certificate authority).

```
User's browser
    ↓  HTTPS (encrypted)
ACA (handles encryption/decryption here)
    ↓  HTTP (inside Azure's private network)
Your container
```

Your container itself doesn't need to handle encryption — ACA does it at the door before passing the request in.

---

## Health Checks — Is Your App Still Alive?

A health check is ACA regularly asking your app "are you okay?" and acting on the answer.

**Why this matters:**
Imagine your container is running but your app crashed inside it. The container is technically alive but serving nothing. Without health checks, ACA doesn't know — it keeps sending traffic to a broken container.

With health checks, ACA detects the problem and restarts the container automatically.

**Two types of health checks:**

**Liveness probe** — "Is the app alive at all?"
ACA calls a URL on your app every few seconds. If it doesn't get a response, it kills and restarts the container.

**Readiness probe** — "Is the app ready to take traffic?"
ACA checks this before sending traffic to a new container. A container might be starting up and not ready yet — the readiness probe prevents requests from hitting it too early.

**How to add a health check endpoint in FastAPI:**

```python
@app.get("/health")
def health():
    return {"status": "ok"}
```

ACA calls `/health` every 10 seconds. If it gets `200 OK` back — healthy. If it gets nothing or an error — ACA restarts the container.

**What ACA does on failure:**

```
ACA calls /health
→ no response (app crashed)
→ ACA waits, tries again
→ still nothing
→ ACA kills the container
→ ACA starts a new container from the same image
→ app is back up
→ you get notified in Azure Monitor logs
```

This all happens automatically, without you doing anything.

---

## The Full Picture

```
You write Python code (FastAPI app)
    ↓
You write a Dockerfile
    ↓
docker build → creates an image on your Mac
    ↓
docker push → sends image to ACR (Azure's warehouse)
    ↓
ACA pulls the image from ACR
    ↓
ACA runs your container and gives it a public HTTPS URL
    ↓
ACA handles scaling, networking, HTTPS, health checks automatically
    ↓
Your app is live
```

ACR = the warehouse (stores images)
ACA = the factory (runs containers, manages everything)

---

## ACR vs ACA — Summary

| | ACR | ACA |
|--|-----|-----|
| What it is | Image storage | Container runtime |
| What it does | Holds your Docker images | Runs your containers |
| Analogy | Warehouse | Factory |
| You create it | Yes | Yes |
| Automatic features | None — just storage | Scaling, HTTPS, health checks, networking |
| Cost | Pay per GB stored | Pay per CPU/memory used (zero when scaled to zero) |

---

## Stage 6 — Deploying the AI App

### Step 1: `App/requirements.txt`

Lists all Python packages the container needs to install. No Anaconda in the container — packages must be explicitly listed.

```
flask
openai
python-dotenv
azure-identity
azure-keyvault-secrets
```

During `docker build`, this file is copied into the image and `pip install -r requirements.txt` runs inside the container.

### Step 2: `App/Dockerfile`

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY main.py .
EXPOSE 5000
CMD ["python", "main.py"]
```

| Line | What it does |
|------|-------------|
| `FROM python:3.12-slim` | Start from an official Python image — slim variant = smaller size |
| `WORKDIR /app` | All following commands run inside `/app` inside the container |
| `COPY requirements.txt .` | Copy requirements into the container first (before code) |
| `RUN pip install -r requirements.txt` | Install packages at build time — baked into the image |
| `COPY main.py .` | Copy the app code |
| `EXPOSE 5000` | Document that the app listens on port 5000 |
| `CMD ["python", "main.py"]` | Command that runs when the container starts |

> **Why copy requirements.txt before the code?** Docker caches each layer. If you copy everything at once, any code change invalidates the pip install cache — slow builds every time. Copying requirements first means pip only re-runs when requirements.txt actually changes.

> **No `.env` in the container** — the deployed app reads secrets from Key Vault via Managed Identity. Never copy `.env` into a container image.

### Step 3: ACR in Terraform

Added to `variables.tf`:
```hcl
variable "acr_name" {
  type        = string
  description = "name of the Azure Container Registry"
}
```

Added to `dev.tfvars`:
```hcl
acr_name = "acrdevRN001"
```

> ACR names must be alphanumeric only, 5-50 characters, globally unique across Azure.

Added to `main.tf`:
```hcl
resource "azurerm_container_registry" "main" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
}
```

- `sku = "Basic"` — cheapest tier, enough for learning
- `admin_enabled = true` — enables username/password login to push images

Added to `outputs.tf`:
```hcl
output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}
```

Output after apply: `acrdevrn001.azurecr.io`

### Step 4: Build and Push the Image

```bash
# Login to ACR
az acr login --name acrdevrn001

# Build the image — tag it with the ACR address
docker build -t acrdevrn001.azurecr.io/ai-app:latest .

# Push to ACR
docker push acrdevrn001.azurecr.io/ai-app:latest
```

- The tag `acrdevrn001.azurecr.io/ai-app:latest` tells Docker where to push — the ACR address is baked into the name
- `latest` is the version tag — you can use `v1.0`, `v1.1` etc. in real projects
- If Docker CLI is not found: `export PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin"`
- If Docker Desktop is not running: open the app first, wait for the whale icon to stop animating

### Step 5: Container Apps in Terraform

Added to `variables.tf`:
```hcl
variable "managed_identity_name" {
  type        = string
  description = "name of the user assigned managed identity"
}

variable "container_app_env_name" {
  type        = string
  description = "name of the container app environment"
}

variable "container_app_name" {
  type        = string
  description = "name of the container app"
}
```

Added to `dev.tfvars`:
```hcl
managed_identity_name  = "id-ai-app-dev"
container_app_env_name = "cae-dev-rn001"
container_app_name     = "ca-ai-app-dev"
```

Added to `main.tf` — three resources:

**1. Managed Identity**
```hcl
resource "azurerm_user_assigned_identity" "main" {
  name                = var.managed_identity_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}
```
The identity the container runs as in Azure. When the app calls Key Vault, Azure uses this identity to decide if access is allowed.

**2. Role Assignment — Key Vault Secrets User**
```hcl
resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}
```
Grants the Managed Identity permission to read secrets from Key Vault. Without this, the deployed app would get a 403.

**3. Container Apps Environment**
```hcl
resource "azurerm_container_app_environment" "main" {
  name                       = var.container_app_env_name
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}
```
The network and runtime environment that hosts Container Apps. Connected to Log Analytics so logs go there automatically.

**4. Container App**
```hcl
resource "azurerm_container_app" "main" {
  name                         = var.container_app_name
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.main.id]
  }

  template {
    container {
      name   = "ai-app"
      image  = "${azurerm_container_registry.main.login_server}/ai-app:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "AZURE_OPENAI_ENDPOINT"
        value = azurerm_cognitive_account.main.endpoint
      }
      env {
        name  = "AZURE_OPENAI_DEPLOYMENT"
        value = var.openai_deployment_name
      }
      env {
        name  = "KEY_VAULT_URL"
        value = azurerm_key_vault.main.vault_uri
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 5000
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.main.admin_password
  }
}
```

**What each section does:**

| Section | Purpose |
|---------|---------|
| `identity` | Attaches the Managed Identity — the app runs as this identity in Azure |
| `template > container` | Defines what runs: image from ACR, CPU/memory, env vars injected at runtime |
| `env` blocks | Same variables the app read from `.env` locally — now injected by Azure |
| `ingress` | Makes the app reachable from the internet on port 5000, ACA provides HTTPS URL |
| `registry` | Tells Container Apps where to pull the image and how to authenticate to ACR |
| `secret` | ACR admin password stored as a Container Apps secret, referenced by name |

Added to `outputs.tf`:
```hcl
output "container_app_url" {
  value = azurerm_container_app.main.latest_revision_fqdn
}
```

Output after apply:
```
container_app_url = "ca-ai-app-dev--chjod83.proudpebble-1d0b8dfe.germanywestcentral.azurecontainerapps.io"
```

### Fix 1: Flask Must Listen on 0.0.0.0

By default, `app.run(debug=True)` binds Flask to `127.0.0.1` — the loopback address inside the container. Container Apps tries to reach port 5000 from outside the container network namespace and cannot reach the loopback. Health checks fail, the revision never becomes ready, and the app is unreachable.

Fix in `App/main.py`:
```python
# WRONG — only reachable from inside the container
app.run(debug=True)

# CORRECT — listens on all interfaces, Container Apps can reach it
app.run(host="0.0.0.0", debug=True)
```

`0.0.0.0` means "accept connections on all network interfaces" — it's the standard setting for any containerized server.

After this change: rebuild the image, push it to ACR, re-run `terraform apply`. Terraform creates a new revision of the Container App with the updated image.

### Fix 2: AZURE_CLIENT_ID for Managed Identity

`DefaultAzureCredential()` in Azure uses the container's managed identity to authenticate to Key Vault. If there is more than one user-assigned identity on the container, the SDK doesn't know which one to use.

Best practice: always set `AZURE_CLIENT_ID` to the client ID of the managed identity you want the app to use. This makes the SDK's identity selection explicit and predictable.

Add to the `container` block in `main.tf`:
```hcl
env {
  name  = "AZURE_CLIENT_ID"
  value = azurerm_user_assigned_identity.main.client_id
}
```

`azurerm_user_assigned_identity.main.client_id` is the UUID that identifies the managed identity — different from its resource ID.

After this change: run `terraform apply` (no rebuild needed — this is just an env var change, Terraform creates a new revision automatically).

### Step 6: Test the Deployed App

Get the stable app URL first:
```bash
az containerapp show \
  --name ca-ai-app-dev \
  --resource-group rg-tfexample-dev-rn \
  --query properties.configuration.ingress.fqdn \
  -o tsv
```

Output: `ca-ai-app-dev.proudpebble-1d0b8dfe.germanywestcentral.azurecontainerapps.io`

Then test:
```bash
curl -X POST https://ca-ai-app-dev.proudpebble-1d0b8dfe.germanywestcentral.azurecontainerapps.io/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "what is azure in one sentence"}'
```

Response:
```json
{
  "response": "Azure is Microsoft's cloud computing platform that provides a wide range of services including computing, analytics, storage, and networking to build, deploy, and manage applications through Microsoft-managed data centers."
}
```

**`latest_revision_fqdn` vs `ingress[0].fqdn`**

The Terraform output was originally:
```hcl
output "container_app_url" {
  value = azurerm_container_app.main.latest_revision_fqdn
}
```

`latest_revision_fqdn` returns a URL tied to a specific revision (e.g. `ca-ai-app-dev--chjod83...`). Every time Terraform creates a new revision, this URL becomes stale and returns Azure's 404 page.

Use the stable ingress URL instead:
```hcl
output "container_app_url" {
  value = azurerm_container_app.main.ingress[0].fqdn
}
```

`ingress[0].fqdn` always points to whichever revision is currently active — it never goes stale.

**Troubleshooting:**

| Error | Cause | Fix |
|-------|-------|-----|
| Azure 404 "Container App stopped or does not exist" | Using stale `latest_revision_fqdn` URL | Get stable URL: `az containerapp show ... --query properties.configuration.ingress.fqdn` |
| Connection timeout / 503 | Flask bound to 127.0.0.1 | Add `host="0.0.0.0"` to app.run(), rebuild and push |
| `CredentialUnavailableError` | Managed identity not found | Add `AZURE_CLIENT_ID` env var to main.tf, re-apply |
| `ForbiddenByRbac` on Key Vault | Role assignment not propagated yet | Wait 2-3 minutes and retry |
| `RevisionProvisioningState: Failed` | Image pull failed or app crashed at startup | Check logs: `az containerapp logs show --name ca-ai-app-dev --resource-group rg-tfexample-dev-rn` |
