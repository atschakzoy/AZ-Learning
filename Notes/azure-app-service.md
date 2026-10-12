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

## Networking — Stage 8

---

### Why Networking?

By default every Azure resource (Key Vault, OpenAI, App Service) is accessible from the public internet. Anyone with valid credentials can reach them from anywhere. Stage 8 locks this down:

- Key Vault and Azure OpenAI are moved off the public internet — only accessible via private IPs inside a VNet
- The App Service routes its outbound traffic through the VNet so it can reach those private IPs
- Public access to Key Vault and OpenAI is explicitly disabled

---

### The Full Picture

```
User (internet)
      │
      ▼ (inbound — stays public, app is user-facing)
┌─────────────────────────────────────────────────────────────┐
│  App Service                                                │
│  virtual_network_subnet_id = snet-app-service-integration  │
└─────────────────────────────────────────────────────────────┘
      │
      │ outbound traffic routes through VNet
      ▼
┌─────────────────────────────────────────────────────────────┐
│  VNet  10.0.0.0/16                                         │
│                                                             │
│  snet-app-service-integration  10.0.2.0/24                 │
│  (delegated to Microsoft.Web/serverFarms)                   │
│       │                                                     │
│       │ private routing                                     │
│       ▼                                                     │
│  snet-private-endpoints  10.0.1.0/24                       │
│       ├── Key Vault NIC  (private IP: 10.0.1.x)            │
│       └── Azure OpenAI NIC  (private IP: 10.0.1.y)         │
│                                                             │
│  Private DNS Zone: privatelink.vaultcore.azure.net          │
│  Private DNS Zone: privatelink.openai.azure.com             │
│  (override public DNS — return private IPs instead)         │
└─────────────────────────────────────────────────────────────┘

Public internet → Key Vault   ✗ BLOCKED
Public internet → OpenAI      ✗ BLOCKED
App Service     → Key Vault   ✓ via private endpoint
App Service     → OpenAI      ✓ via private endpoint
```

---

### Concepts

#### VNet (Virtual Network)
Your private network inside Azure. Resources inside it get private IPs and talk to each other without going through the public internet. Think of it as renting a private floor in Azure's building — you control who gets in.

#### Subnet
A segment inside the VNet with its own IP range. Subnets let you:
- Separate concerns (endpoints vs app service traffic)
- Apply different firewall rules (NSGs) to different parts
- Reserve space for a specific service (delegation)

CIDR ranges used:
- VNet: `10.0.0.0/16` — 65,536 IPs total
- `snet-private-endpoints`: `10.0.1.0/24` — 256 IPs, for Key Vault and OpenAI NICs
- `snet-app-service-integration`: `10.0.2.0/24` — 256 IPs, for App Service outbound traffic

Azure reserves the first 5 IPs in every subnet for itself.

#### Subnet Delegation
Reserves a subnet for a specific Azure service. The App Service integration subnet needs `Microsoft.Web/serverFarms` delegation — no other resource type can use it.

#### NSG (Network Security Group)
A firewall attached to a subnet. A list of allow/deny rules for inbound and outbound traffic. Even with no custom rules, Azure has sensible defaults (deny all inbound from internet, allow VNet-to-VNet, etc.).

#### Private Endpoint
Gives a PaaS service (Key Vault, OpenAI) a private IP address inside your subnet. Azure creates a NIC (Network Interface Card) in `snet-private-endpoints` and connects it to the service. Traffic to that service now goes through that NIC — never leaves the VNet.

#### Private DNS Zone
When your app calls `myvault.vault.azure.net`, DNS normally resolves this to a **public IP**. A Private DNS Zone overrides this — it's a DNS server only your VNet can see. It returns the **private IP** of the NIC instead.

Without the DNS zone: private endpoint exists but DNS still points to the public IP — traffic goes to the wrong place.

DNS zone names are fixed by Microsoft (not customizable):
- Key Vault → `privatelink.vaultcore.azure.net`
- Azure OpenAI → `privatelink.openai.azure.com`

#### VNet Integration (App Service)
PaaS services like App Service don't natively live inside a subnet. VNet Integration is a feature that tells App Service to route its **outbound** traffic through a dedicated delegated subnet. This lets the app reach private endpoint IPs inside the VNet.

- Inbound (users → App Service) stays public — the app is user-facing
- Outbound (App Service → Key Vault / OpenAI) routes through the VNet

Controlled in Terraform by `virtual_network_subnet_id` on `azurerm_linux_web_app`.

---

### Terraform Resources

#### Step 1 — VNet + Subnets + NSGs
```hcl
resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_network_security_group" "private_endpoints" {
  name                = "nsg-private-endpoints"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_network_security_group" "app_service_integration" {
  name                = "nsg-app-service-integration"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}

resource "azurerm_subnet" "app_service_integration" {
  name                 = "snet-app-service-integration"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "app_service_integration" {
  subnet_id                 = azurerm_subnet.app_service_integration.id
  network_security_group_id = azurerm_network_security_group.app_service_integration.id
}
```

#### Step 2 — Private DNS Zones + Private Endpoints
```hcl
resource "azurerm_private_dns_zone" "key_vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone" "openai" {
  name                = "privatelink.openai.azure.com"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  name                  = "link-kv"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "openai" {
  name                  = "link-openai"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.openai.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-keyvault"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-keyvault"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-kv"
    private_dns_zone_ids = [azurerm_private_dns_zone.key_vault.id]
  }
}

resource "azurerm_private_endpoint" "openai" {
  name                = "pe-openai"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-openai"
    private_connection_resource_id = azurerm_cognitive_account.main.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-openai"
    private_dns_zone_ids = [azurerm_private_dns_zone.openai.id]
  }
}
```

`subresource_names` is a Microsoft-fixed value per service — `"vault"` for Key Vault, `"account"` for OpenAI. These never change.

`private_dns_zone_group` inside the private endpoint auto-registers an A record in the DNS zone pointing to the private IP when the endpoint is created.

#### Step 3 — Disable Public Access
Add to `azurerm_key_vault.main` and `azurerm_cognitive_account.main`:
```hcl
public_network_access_enabled = false
```

#### Step 4 — VNet Integration on App Service
Add to `azurerm_linux_web_app.main`:
```hcl
virtual_network_subnet_id = azurerm_subnet.app_service_integration.id
```

In AzureRM provider v4.x, setting `virtual_network_subnet_id` automatically routes all outbound traffic through the VNet. Do NOT also set `WEBSITE_VNET_ROUTE_ALL` in `app_settings` — the provider manages that internally and will error if you set it manually.

---

### Gotchas Encountered

| Problem | Cause | Fix |
|---|---|---|
| `cannot set a value for WEBSITE_VNET_ROUTE_ALL in app_settings` | AzureRM v4.x manages this setting internally when `virtual_network_subnet_id` is set | Remove `WEBSITE_VNET_ROUTE_ALL` from `app_settings` |
| `AccountCustomSubDomainNameNotSet` on private endpoint for OpenAI | Azure requires a custom subdomain on the Cognitive Services account before a private endpoint can be attached | Add `custom_subdomain_name = var.openai_name` to `azurerm_cognitive_account` — this forces recreation of the resource |
| `Provider produced inconsistent final plan` on App Service | OpenAI account was recreated with a new endpoint URL mid-apply — App Service planned with the old URL | Re-run apply — second run uses the updated state with the correct endpoint |
| State lock collision (`state blob is already locked`) | Multiple pipeline runs competing for the same state file simultaneously | Add `concurrency: group: terraform` to both `tf-plan.yml` and `tf-apply.yml`; break stuck leases with `az storage blob lease break` |

---

### Breaking a Stuck State Lock

When Terraform exits without releasing the lock (crashed runner, cancelled job):

```bash
# Find the storage account and container in provider.tf backend config
az storage blob lease break \
  --account-name <storage_account_name> \
  --container-name <container_name> \
  --blob-name <env>/terraform.tfstate \
  --account-key $(az storage account keys list --account-name <storage_account_name> --query '[0].value' -o tsv)
```

Result `0` = lease broken successfully. Error `LeaseNotPresentWithLeaseOperation` = already unlocked.

---

### Pipeline Concurrency Fix

Without concurrency controls, a plan and apply can run simultaneously and both try to lock the same state file.

Add to both `tf-plan.yml` and `tf-apply.yml`:
```yaml
concurrency:
  group: terraform
  cancel-in-progress: false
```

`cancel-in-progress: false` means new runs queue up rather than cancelling the current one — important for Terraform since you never want to kill an apply mid-run.

---

### Cost of Stage 8 Resources

| Resource | Cost |
|---|---|
| VNet, Subnets, NSGs | Free |
| Private Endpoint x2 | ~$0.01/hr each (~$7/month each if always on) |
| Private DNS Zone x2 | ~$0.50/month each |
| VNet Integration | Free (no extra charge on S1+) |

Destroy when done learning to avoid ongoing charges.

---

### Verify Public Access is Blocked (Step 6)

After apply, try to reach Key Vault from your laptop:

```bash
# Should return 403 Forbidden — public access disabled
curl https://<keyvault-name>.vault.azure.net/secrets?api-version=7.4
```

If you get `{"error":{"code":"Forbidden",...}}` — public access is successfully blocked. Only the App Service (inside the VNet) can now reach Key Vault and OpenAI.

---

## State Drift — Manual Deletion Outside Terraform

If you delete resources via `az group delete` or Azure Portal, the Terraform state file still lists them as existing. On the next apply, Terraform tries to read/update them and gets 404.

**Fix — sync state before applying:**
```bash
terraform apply -refresh-only -var-file="dev.tfvars" -auto-approve
terraform apply -var-file="dev.tfvars" -auto-approve
```

`-refresh-only` queries Azure, updates the state to match reality, makes no infrastructure changes. Then the regular apply creates everything from scratch.
