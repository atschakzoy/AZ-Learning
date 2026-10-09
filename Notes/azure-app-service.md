# App Service Notes — Stage 6

---

## What is App Service?

Azure App Service is a managed platform for running web apps directly from code — no Docker, no image builds. You give it your code, tell it what language to use, and Azure handles the rest: OS, runtime, scaling, HTTPS, domain.

Compare to Container Apps:
- **App Service** — give it code, it runs it. Simpler, less control.
- **Container Apps** — give it a Docker image, it runs it. More control, more setup.

---

## App Service Plan

The App Service Plan is the underlying compute. Your App Service runs on it.

```
App Service Plan (the machine)
    └── App Service (your app running on that machine)
    └── App Service 2 (another app, same machine)
```

You pay for the plan, not per app. One plan can host multiple apps.

**Tiers:**

| SKU | Cost | Notes |
|-----|------|-------|
| F1 | Free | 60 CPU min/day, no always-on, no custom SSL |
| B1 | ~$13/month | Basic — always-on, custom domains |
| S1+ | More | Auto-scaling, slots |

F1 quota is subscription-level. Some subscriptions have 0 quota in certain regions — check Azure Portal → Quotas before deploying.

---

## Terraform Resources

```hcl
resource "azurerm_service_plan" "main" {
  name                = var.app_service_plan_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "F1"
}

resource "azurerm_linux_web_app" "main" {
  name                = var.app_service_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = false   # required for F1 — provider defaults to true which breaks F1
    application_stack {
      python_version = "3.12"
    }
    app_command_line = "gunicorn --bind=0.0.0.0 --timeout 600 main:app"
  }

  app_settings = {
    AZURE_OPENAI_ENDPOINT          = azurerm_cognitive_account.main.endpoint
    AZURE_OPENAI_DEPLOYMENT        = var.openai_deployment_name
    KEY_VAULT_URL                  = azurerm_key_vault.main.vault_uri
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
  }
}

resource "azurerm_role_assignment" "app_kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "app_openai_user" {
  scope                = azurerm_cognitive_account.main.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}
```

**Key points:**

| Setting | Why |
|---------|-----|
| `identity { type = "SystemAssigned" }` | Azure auto-creates a managed identity for this App Service — no manual setup |
| `always_on = false` | F1 doesn't support always-on — must explicitly set false or apply fails |
| `app_command_line` | Tells App Service to start the app with gunicorn instead of Flask dev server |
| `SCM_DO_BUILD_DURING_DEPLOYMENT` | Runs `pip install` automatically when you deploy the zip |
| `app_settings` | Environment variables injected at runtime — replaces the local `.env` file |
| `Key Vault Secrets User` | Lets the App Service read secrets from Key Vault |
| `Cognitive Services OpenAI User` | Lets the App Service call Azure OpenAI |

---

## Deployment — Zip Deploy

App Service takes a zip file of your code and runs it. No Docker, no image build.

```bash
# 1. Zip only the app files
cd App/
zip app.zip main.py requirements.txt

# 2. Deploy
az webapp deploy \
  --resource-group rg-tfexample-dev-rn \
  --name app-ai-dev-rn001 \
  --src-path app.zip \
  --type zip
```

Because `SCM_DO_BUILD_DURING_DEPLOYMENT=true`, App Service runs `pip install -r requirements.txt` automatically inside the container after receiving the zip.

**Don't include:** `.env`, `Dockerfile`, `.git` — just the files the app needs to run.

---

## Gunicorn vs Flask Dev Server

Flask's built-in server (`app.run()`) is for development only. App Service uses gunicorn — a production-grade Python web server.

```
Flask dev server          Gunicorn
─────────────────         ────────────────────────────
Single threaded           Multi-worker
No concurrent requests    Handles concurrent requests
Crashes in production     Designed for production load
```

Add `gunicorn` to `requirements.txt`. App Service startup command:
```
gunicorn --bind=0.0.0.0 --timeout 600 main:app
```

- `--bind=0.0.0.0` — listens on all interfaces (same as `host="0.0.0.0"` in Flask)
- `--timeout 600` — 10 minute timeout (Azure OpenAI calls can be slow)
- `main:app` — file `main.py`, Flask instance named `app`

---

## How `DefaultAzureCredential` Works on App Service

Same as Container Apps — no code changes needed. The managed identity is injected automatically by Azure.

```
App Service starts
    ↓
DefaultAzureCredential() checks for managed identity endpoint
    ↓
Finds system-assigned identity (injected by Azure automatically)
    ↓
Gets token for Key Vault
    ↓
SecretClient.get_secret("openai-key") → returns API key
    ↓
AzureOpenAI client initialized
```

Locally: uses `az login`.
On App Service: uses system-assigned managed identity automatically.
Same code, zero changes.

---

## Soft Delete — Key Vault and OpenAI

Both Key Vault and Cognitive Services (OpenAI) use **soft delete** — when deleted, the resource enters a recoverable state for 90 days. The name stays reserved globally.

**Problem:** destroy → recreate with same name → 409 Conflict.

**Fix in `provider.tf`:**
```hcl
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy = true
    }
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
  }
}
```

**Manual purge (if deleted outside Terraform):**
```bash
# List all soft-deleted vaults
az keyvault list-deleted --query "[].{Name:name, Location:properties.location}" -o table

# Purge Key Vault
az keyvault purge --name kv-tfexample001 --location <location-from-above>

# Purge OpenAI
az cognitiveservices account purge \
  --name oai-dev-rn001 \
  --resource-group rg-tfexample-dev-rn \
  --location swedencentral
```

---

## Test

```bash
curl -X POST https://app-ai-dev-rn001.azurewebsites.net/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "what is azure in one sentence"}'
```

App Service URL format: `https://<app-name>.azurewebsites.net`

---

## Deployment Slots

A deployment slot is a second version of your App Service running in parallel on the same App Service Plan. Used for zero-downtime deployments.

### Requirements
- App Service Plan must be **S1 or higher** — F1 (Free) does not support slots
- Both slots (production + staging) run on the same plan — same compute, same region, same cost tier

### How it works
```
production slot → live traffic (100%)
staging slot    → new version, no traffic (0%)

after swap:
production slot → was staging (new version, now gets 100% traffic)
staging slot    → was production (old version, gets 0% traffic)
```

Swap is instant — Azure just reroutes traffic. No downtime, no new server.

### Terraform resource for a staging slot
```hcl
resource "azurerm_linux_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.main.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = false
    application_stack {
      python_version = "3.12"
    }
    app_command_line = "gunicorn --bind=0.0.0.0 --timeout 600 main:app"
  }

  app_settings = {
    AZURE_OPENAI_ENDPOINT          = azurerm_cognitive_account.main.endpoint
    AZURE_OPENAI_DEPLOYMENT        = var.openai_deployment_name
    KEY_VAULT_URL                  = azurerm_key_vault.main.vault_uri
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
  }
}
```

> The staging slot has its own **separate managed identity** — you must assign Key Vault and OpenAI roles to it separately, the same as the production slot.

### Role assignments for staging slot (must add to Terraform)
```hcl
resource "azurerm_role_assignment" "staging_kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app_slot.staging.identity[0].principal_id
}

resource "azurerm_role_assignment" "staging_openai_user" {
  scope                = azurerm_cognitive_account.main.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_linux_web_app_slot.staging.identity[0].principal_id
}
```

### Deploy to staging slot
```bash
az webapp deploy \
  --resource-group <rg-name> \
  --name <app-name> \
  --slot staging \
  --src-path app.zip \
  --type zip
```

No `--slot` flag = deploys to production slot.

### Test staging before swap
Staging URL format: `https://<app-name>-staging.azurewebsites.net`

```bash
curl -X POST https://<app-name>-staging.azurewebsites.net/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "say hello"}'
```

### Swap staging → production
```bash
az webapp deployment slot swap \
  --resource-group <rg-name> \
  --name <app-name> \
  --slot staging \
  --target-slot production
```

After swap: production has the new version, staging has the old version.

### Check slot status in portal
**App Services** → click your app → left sidebar → **Deployment slots**
Shows both slots, their status, and traffic percentage.

### Real-world pattern
- Dev environment: deploy directly to production slot (no staging needed — dev is not customer-facing)
- Prod environment: deploy to staging slot → approval → swap to production

---

## State Drift — Manual Deletion Outside Terraform

If you delete resources via `az group delete` or Azure Portal, the Terraform state file still lists them as existing. On the next apply, Terraform tries to read/update them and gets 404.

**Fix — sync state before applying:**
```bash
terraform apply -refresh-only -var-file="dev.tfvars" -auto-approve
terraform apply -var-file="dev.tfvars" -auto-approve
```

`-refresh-only` queries Azure, updates the state to match reality, makes no infrastructure changes. Then the regular apply creates everything from scratch.
