# Stage 3 — Infrastructure as Code

> **Project milestone:** The foundation infra is expressed as Bicep (learning pass), then fully rewritten as Terraform with state stored in Azure Blob. The CLI scripts from Stage 2 are retired — Terraform is the single source of truth.

---

## Before you start

### 1. Install Bicep
The Bicep CLI comes with the Azure CLI. Make sure it is up to date:
```bash
az bicep install
az bicep upgrade
az bicep version
# Expected: Bicep CLI version 0.x.x
```

### 2. Install Terraform
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Verify:
terraform --version
# Expected: Terraform v1.x.x
```

### 3. Install tflint (Terraform linter)
```bash
brew install tflint
tflint --version
```

### 4. VS Code extensions (recommended)
Install these extensions for a much better editing experience:
- **Bicep** (by Microsoft) — syntax highlighting, autocomplete, error detection for `.bicep` files
- **HashiCorp Terraform** — syntax highlighting and autocomplete for `.tf` files

---

## What you'll build this stage

The same four resources from Stage 1, now declared in code. By the end, your repo will look like:

```
project/
└── infra/
    ├── bicep/                       ← learning pass (kept as reference)
    │   ├── main.bicep
    │   ├── main.bicepparam
    │   └── modules/
    │       ├── storage.bicep
    │       ├── keyvault.bicep
    │       └── loganalytics.bicep
    └── terraform/                   ← the version you keep and automate
        ├── providers.tf
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── modules/
            ├── storage/
            │   ├── main.tf
            │   ├── variables.tf
            │   └── outputs.tf
            ├── keyvault/
            └── loganalytics/
```

---

## Concepts

### Why Infrastructure as Code?

In Stage 1 you created infrastructure by running CLI commands. In Stage 2 you wrapped those in a script. This is better than clicking in the Portal, but it is still **imperative** — you are telling Azure what to *do* step by step.

**IaC is declarative** — you describe what the end state should *look like*, and the tool figures out how to get there.

The difference in practice:

| Imperative (CLI script) | Declarative (IaC) |
|------------------------|-------------------|
| `az storage account create ...` | `resource "azurerm_storage_account" "main" { ... }` |
| If it already exists, the command fails | If it already exists, nothing happens |
| To add a resource, add a command at the end | To add a resource, add a block — the tool decides what to do |
| No memory of what it created | State file tracks everything |
| Hard to know what "current state" is | `terraform plan` always shows the diff between code and reality |

**Four properties of IaC:**

- **Idempotent**: Run it 10 times, you get the same result. No duplicates, no errors on the second run. The script from Stage 2 would fail if you ran it twice (the storage account already exists). Terraform and Bicep handle this automatically.

- **Auditable**: Every infrastructure change is a code change in a PR. You can see who changed what, when, and why (the PR description). With a CLI script, you just see "someone ran this script at some point."

- **Repeatable**: Spin up an identical dev and prod environment from the same code. Just change the variable values.

- **Drift detection**: "Drift" is when what actually exists in Azure differs from what your code says should exist. Someone added a resource manually in the Portal. Someone changed a setting via CLI. Terraform will tell you about this on the next `plan` run.

---

### Bicep

Bicep is Microsoft's language for describing Azure resources. It compiles to ARM (Azure Resource Manager) JSON — the format Azure's API actually understands. You write readable Bicep, the CLI converts it to ARM JSON, and sends it to Azure.

**Why learn Bicep if we will end up using Terraform?**
- It is Microsoft's native IaC for Azure and widely used in Azure-centric teams
- Understanding it gives you a deeper appreciation of how Azure's resource model works
- Some Azure features appear in Bicep/ARM before they appear in the Terraform provider

**Bicep file structure:**

```bicep
// Parameters: inputs that can change per deployment
param storageAccountName string
param location string = resourceGroup().location   // default value
param environment string = 'dev'

// Variables: computed values used internally
var sku = environment == 'prod' ? 'Standard_GRS' : 'Standard_LRS'

// Resources: the actual Azure resources to create
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: sku
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
  }
}

// Outputs: values that are returned after deployment
// (useful for passing to other templates or scripts)
output primaryEndpoint string = storage.properties.primaryEndpoints.blob
output storageAccountId string = storage.id
```

**Resource type format:** `'Microsoft.Storage/storageAccounts@2023-01-01'`
- `Microsoft.Storage` = the resource provider (who manages this resource type)
- `storageAccounts` = the resource type
- `2023-01-01` = the API version (always use the latest stable version)

You can find all resource types and their current API versions in the [Azure resource documentation](https://learn.microsoft.com/en-us/azure/templates/).

**Deploying Bicep:**
```bash
# Preview changes without applying them
az deployment group what-if \
  --resource-group rg-platform-dev \
  --template-file main.bicep \
  --parameters storageAccountName=stplatformdevnn

# Apply
az deployment group create \
  --resource-group rg-platform-dev \
  --template-file main.bicep \
  --parameters storageAccountName=stplatformdevnn
```

**Bicep modules:** A module is just a separate `.bicep` file. The parent file calls the module and passes parameters. This lets you split a large template into smaller, reusable pieces.

```bicep
// main.bicep calling a module
module storage './modules/storage.bicep' = {
  name: 'storageDeployment'
  params: {
    storageAccountName: 'stplatformdevnn'
    location: location
  }
}
```

---

### Terraform

Terraform is the most widely used IaC tool in the industry. Unlike Bicep, it works across multiple cloud providers (Azure, AWS, GCP, etc.) using the same language and workflow.

**HCL (HashiCorp Configuration Language)** is the language Terraform uses. It is designed to be easy to read and write.

**Key building blocks:**

```hcl
# A "provider" is a plugin that knows how to talk to a specific cloud API
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"    # ~> means "4.anything but not 5.0"
    }
  }
}

provider "azurerm" {
  features {}    # required block, even if empty
}
```

```hcl
# A "resource" is something Terraform will create and manage
resource "azurerm_resource_group" "main" {
  name     = "rg-platform-dev"
  location = "East US"
}

# Reference another resource: azurerm_resource_group.main.name
# Terraform automatically figures out the dependency order
resource "azurerm_storage_account" "main" {
  name                = "stplatformdevnn"
  resource_group_name = azurerm_resource_group.main.name    # reference
  location            = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

```hcl
# Variables: inputs to your configuration
variable "suffix" {
  type        = string
  description = "Short unique suffix for globally unique names"
}

# Use a variable with var.suffix
resource "azurerm_storage_account" "main" {
  name = "stplatformdev${var.suffix}"
  # ...
}
```

```hcl
# Outputs: values Terraform exports after running
output "storage_account_name" {
  value = azurerm_storage_account.main.name
}
```

**The Terraform workflow — these four commands are everything:**

```bash
# 1. Initialize — download providers, set up backend
terraform init

# 2. Plan — show what would change (does NOT make any changes)
terraform plan

# 3. Apply — actually make the changes (asks for confirmation)
terraform apply

# 4. Destroy — delete everything Terraform manages
terraform destroy
```

`terraform plan` output explained:
```
  # azurerm_storage_account.main will be created
  + resource "azurerm_storage_account" "main" {
      + name     = "stplatformdevnn"     # green = will be added
      + location = "eastus"
    }

  # azurerm_key_vault.main will be updated in-place
  ~ resource "azurerm_key_vault" "main" {
      ~ sku_name = "standard" -> "premium"   # ~ = will be changed
    }

  # azurerm_storage_account.old will be destroyed
  - resource "azurerm_storage_account" "old" {   # red = will be deleted
    }
```

- `+` green = will be created
- `~` yellow = will be updated in-place (no downtime)
- `-` red = will be deleted (**review these carefully**)
- `-/+` = will be destroyed and recreated (some changes require replacement)

---

### The State File

Terraform keeps a record of everything it created in a **state file** (`terraform.tfstate`). This is a JSON file that maps your HCL resources to real Azure resources.

On the next `plan`, Terraform:
1. Reads the state file to know what it previously created
2. Reads your `.tf` files to know what you want
3. Calls the Azure API to check what actually exists
4. Compares all three and shows you the diff

**Why remote state?** If the state file lives on your laptop:
- If your laptop dies, you lose the state — Terraform can no longer manage those resources
- If a colleague runs Terraform, they get a blank state — chaos
- Two people running Terraform at the same time corrupt the state

Remote state solves this by storing the state file in Azure Blob storage (accessible to everyone) and using blob leasing to prevent concurrent runs.

**Never edit the state file manually.** If something goes wrong, use `terraform state` commands.

---

### Terraform Modules

A module is a folder of `.tf` files that can be called from another configuration. Like functions in programming — write once, call many times with different inputs.

```
modules/
└── storage/
    ├── main.tf        ← the resource definitions
    ├── variables.tf   ← inputs to the module
    └── outputs.tf     ← values the module exports

main.tf                ← root module — calls child modules
```

Calling a module:
```hcl
# main.tf
module "storage" {
  source = "./modules/storage"

  name                = "stplatformdev${var.suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

# Use a module's output
output "storage_endpoint" {
  value = module.storage.primary_endpoint
}
```

---

### Bicep vs Terraform — when to use which

| | Bicep | Terraform |
|-|-------|-----------|
| Works with | Azure only | Azure, AWS, GCP, and 1000+ providers |
| State management | Azure tracks state | You manage state (remote backend) |
| Preview changes | `what-if` | `plan` |
| Learning curve | Lower for Azure-focused learners | Higher initially |
| Community modules | Limited | Large public registry |
| New Azure features | Available immediately (it compiles to ARM) | Depends on AzureRM provider updates |
| When to use | Azure-only org, teams preferring Microsoft tooling | Multi-cloud, or when team already uses Terraform |

---

## Exercises

### IaC concepts

**Exercise 1 — Demonstrate idempotency**

The CLI script from Stage 2 fails if you run it twice:
```bash
SUFFIX=nn ./project/infra/scripts/create-foundation.sh
# Second run: "Storage account name stplatformdevnn is already taken"
```

Run the Bicep deployment twice (after you write it in the project step) — the second run succeeds with no changes. This is idempotency.

**Exercise 2 — Experience drift detection**

After completing the project step and deploying Terraform:
1. Go to the Portal and manually add a tag to your storage account
2. Run `terraform plan`
3. Terraform shows the tag as drift and plans to remove it

This is drift. In a real environment, someone changing resources manually outside of IaC is a problem — Terraform will revert their change on the next apply.

---

### Bicep exercises

**Exercise 3 — Your first Bicep file**

Create a scratch folder for practice:
```bash
mkdir ~/bicep-practice && cd ~/bicep-practice
```

Create `main.bicep`:
```bicep
@description('Name for the storage account')
param storageAccountName string

@description('Azure region')
param location string = resourceGroup().location

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
  }
}

output primaryEndpoint string = storage.properties.primaryEndpoints.blob
```

Create a test resource group and deploy:
```bash
az group create --name rg-bicep-test --location eastus

az deployment group create \
  --resource-group rg-bicep-test \
  --template-file main.bicep \
  --parameters storageAccountName=stbiceptest001
```

Expected: deployment completes, you can see the storage account in the Portal.

**Exercise 4 — Preview changes with what-if**

Change the SKU in your `main.bicep` from `Standard_LRS` to `Standard_GRS`. Before applying, run what-if:

```bash
az deployment group what-if \
  --resource-group rg-bicep-test \
  --template-file main.bicep \
  --parameters storageAccountName=stbiceptest001
```

Read the output carefully. You should see a change planned for the SKU. This is the Bicep equivalent of `terraform plan` — always run this before deploying changes to production.

Apply the change:
```bash
az deployment group create \
  --resource-group rg-bicep-test \
  --template-file main.bicep \
  --parameters storageAccountName=stbiceptest001
```

**Exercise 5 — Extract to a module**

Create `modules/storage.bicep`:
```bicep
@description('Name for the storage account')
param storageAccountName string

param location string = resourceGroup().location

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
  }
}

output primaryEndpoint string = storage.properties.primaryEndpoints.blob
```

Update `main.bicep` to call the module:
```bicep
param storageAccountName string
param location string = resourceGroup().location

module storage './modules/storage.bicep' = {
  name: 'storageDeployment'
  params: {
    storageAccountName: storageAccountName
    location: location
  }
}

output endpoint string = storage.outputs.primaryEndpoint
```

Re-deploy — no change should occur (same resources, just refactored code).

**Exercise 6 — Capture outputs**

Find the deployment name from the previous run:
```bash
az deployment group list --resource-group rg-bicep-test --output table
```

Then query its outputs:
```bash
az deployment group show \
  --name <deployment-name> \
  --resource-group rg-bicep-test \
  --query "properties.outputs"
```

**Exercise 7 — Lint**

Add a parameter without a `@description` decorator:
```bicep
param undescribedParam string  // missing @description
```

Run the linter:
```bash
az bicep lint main.bicep
```

Expected: warning about missing description. Add the decorator and re-run — warning disappears.

---

### Terraform exercises

**Exercise 8 — Your first Terraform config**

Create a scratch folder:
```bash
mkdir ~/tf-practice && cd ~/tf-practice
```

Create `providers.tf`:
```hcl
terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

Create `main.tf`:
```hcl
resource "azurerm_resource_group" "practice" {
  name     = "rg-tf-practice"
  location = "East US"
}
```

Initialize and deploy:
```bash
terraform init
# Expected: "Terraform has been successfully initialized!"
# This downloads the azurerm provider (~50MB) to .terraform/

terraform plan
# Expected: "Plan: 1 to add, 0 to change, 0 to destroy."

terraform apply
# Terraform will ask: "Do you want to perform these actions? yes/no"
# Type: yes
```

Confirm the resource group exists in the Portal. Now look at `terraform.tfstate` — it is a JSON file. Find your resource group inside it.

**Exercise 9 — Add a storage account**

Append to `main.tf`:
```hcl
resource "azurerm_storage_account" "practice" {
  name                     = "sttfpractice001"
  resource_group_name      = azurerm_resource_group.practice.name
  location                 = azurerm_resource_group.practice.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

Run plan — only the storage account should appear as new. The resource group should show no changes.

Apply, then look at `terraform.tfstate` again — the storage account entry is now there too.

**Exercise 10 — Target destroy**

```bash
# Destroy only the storage account, leave the resource group
terraform destroy -target=azurerm_storage_account.practice
```

Confirm the storage account is gone but the resource group still exists in the Portal.

**Exercise 11 — Format and validate**

Deliberately mis-indent your `main.tf` (add extra spaces, misalign the `=` signs). Run:
```bash
terraform fmt
```

Open `main.tf` — it is now perfectly formatted. `terraform fmt` is deterministic — it always produces the same output for the same input. Run it before every commit.

Now remove a required argument (e.g. delete `location` from the resource group). Run:
```bash
terraform validate
```

Expected: clear error message pointing to the missing argument.

**Exercise 12 — tflint**

```bash
tflint --init   # downloads tflint plugins
tflint
```

tflint checks for common Terraform mistakes that `terraform validate` misses — things like deprecated arguments, missing required tags, or naming convention violations.

---

## Project Step

### A — Create the remote state backend (manual, one-time)

The remote state storage must be created manually because Terraform cannot track its own state creation.

```bash
# Variables
RG_TFSTATE="rg-tfstate"
LOCATION="eastus"
SA_NAME="sttfstate${SUFFIX}"   # replace SUFFIX with your initials

# Create a dedicated resource group for the state storage
az group create --name $RG_TFSTATE --location $LOCATION

# Create the storage account (no public access, enforced TLS)
az storage account create \
  --name $SA_NAME \
  --resource-group $RG_TFSTATE \
  --location $LOCATION \
  --sku Standard_LRS \
  --allow-blob-public-access false \
  --min-tls-version TLS1_2

# Create the container
az storage container create \
  --name tfstate \
  --account-name $SA_NAME

# Grant yourself access to read/write the state file
az role assignment create \
  --assignee $(az ad signed-in-user show --query id -o tsv) \
  --role "Storage Blob Data Contributor" \
  --scope $(az storage account show --name $SA_NAME --resource-group $RG_TFSTATE --query id -o tsv)
```

> **Why a separate resource group?** The state storage outlives individual environments. If you delete `rg-platform-dev`, you want the state to survive. Keeping state storage in its own resource group prevents accidental deletion.

---

### B — Bicep (learning pass)

Write `project/infra/bicep/` with a module for each of the four resources.

**`project/infra/bicep/modules/storage.bicep`:**
```bicep
@description('Storage account name (globally unique)')
param name string

@description('Azure region')
param location string

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: name
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}

output id string = storage.id
output primaryEndpoint string = storage.properties.primaryEndpoints.blob
```

**`project/infra/bicep/modules/keyvault.bicep`:**
```bicep
@description('Key Vault name (globally unique, 3-24 chars)')
param name string

param location string

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
  }
}

output id string = kv.id
output uri string = kv.properties.vaultUri
```

**`project/infra/bicep/modules/loganalytics.bicep`:**
```bicep
@description('Log Analytics Workspace name')
param name string

param location string

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

output id string = law.id
output customerId string = law.properties.customerId
```

**`project/infra/bicep/main.bicep`:**
```bicep
@description('Short unique suffix for globally unique names')
param suffix string

@description('Environment name (dev, prod, etc.)')
param environment string = 'dev'

@description('Azure region')
param location string = resourceGroup().location

module storage './modules/storage.bicep' = {
  name: 'storageDeployment'
  params: {
    name: 'stplatformdev${suffix}'
    location: location
  }
}

module kv './modules/keyvault.bicep' = {
  name: 'kvDeployment'
  params: {
    name: 'kv-platform-${environment}-${suffix}'
    location: location
  }
}

module law './modules/loganalytics.bicep' = {
  name: 'lawDeployment'
  params: {
    name: 'law-platform-${environment}'
    location: location
  }
}
```

**`project/infra/bicep/main.bicepparam`:**
```bicep
using 'main.bicep'

param suffix = 'nn'   // replace with your initials
param environment = 'dev'
```

Lint and deploy:
```bash
az bicep lint project/infra/bicep/main.bicep

az deployment group what-if \
  --resource-group rg-platform-dev \
  --template-file project/infra/bicep/main.bicep \
  --parameters project/infra/bicep/main.bicepparam

az deployment group create \
  --resource-group rg-platform-dev \
  --template-file project/infra/bicep/main.bicep \
  --parameters project/infra/bicep/main.bicepparam
```

---

### C — Terraform for the foundation

**`project/infra/terraform/providers.tf`:**
```hcl
terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstatenn"   # replace nn with your SUFFIX
    container_name       = "tfstate"
    key                  = "platform-dev.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}
```

**`project/infra/terraform/variables.tf`:**
```hcl
variable "environment" {
  type        = string
  default     = "dev"
  description = "Environment name (dev, prod, etc.)"
}

variable "suffix" {
  type        = string
  description = "Short unique suffix for globally unique resource names (e.g. your initials)"
}

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region for all resources"
}
```

**`project/infra/terraform/main.tf`:**
```hcl
resource "azurerm_resource_group" "main" {
  name     = "rg-platform-${var.environment}"
  location = var.location
}

module "storage" {
  source = "./modules/storage"

  name                = "stplatformdev${var.suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

module "keyvault" {
  source = "./modules/keyvault"

  name                = "kv-platform-${var.environment}-${var.suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
}

module "loganalytics" {
  source = "./modules/loganalytics"

  name                = "law-platform-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

data "azurerm_client_config" "current" {}
```

**`project/infra/terraform/modules/storage/main.tf`:**
```hcl
resource "azurerm_storage_account" "main" {
  name                     = var.name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }
}
```

**`project/infra/terraform/modules/storage/variables.tf`:**
```hcl
variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
```

**`project/infra/terraform/modules/storage/outputs.tf`:**
```hcl
output "id" { value = azurerm_storage_account.main.id }
output "name" { value = azurerm_storage_account.main.name }
output "primary_blob_endpoint" {
  value = azurerm_storage_account.main.primary_blob_endpoint
}
```

Create similar modules for Key Vault and Log Analytics following the same pattern.

**`project/infra/terraform/dev.tfvars`:**
```hcl
environment = "dev"
suffix      = "nn"       # replace with your initials
location    = "eastus"
```

**Run the full workflow:**
```bash
cd project/infra/terraform

terraform init
# Expected: "Terraform has been successfully initialized!"
# If prompted about copying state, type "yes"

terraform fmt -recursive
# Formats all .tf files in subdirectories too

terraform validate
# Expected: "Success! The configuration is valid."

terraform plan -var-file="dev.tfvars"
# Read the output carefully — confirm the four resources will be created

terraform apply -var-file="dev.tfvars"
# Type "yes" when prompted

# Confirm state is stored in Azure Blob
az storage blob list \
  --account-name "sttfstate${SUFFIX}" \
  --container-name tfstate \
  --output table
# Expected: platform-dev.tfstate listed
```

### D — Clean up and commit

Delete `project/infra/scripts/` — Terraform replaces the scripts as the source of truth.

Add `dev.tfvars` to `.gitignore` if it contains sensitive values. For this project it is safe to commit since it only contains non-sensitive configuration.

Commit everything via a PR:
```bash
git checkout -b feature/add-iac
git add project/infra/
git commit -m "Add Bicep and Terraform for foundation infra

- bicep/: learning pass with modules for all four resources
- terraform/: active deployment with remote state in Azure Blob
- dev.tfvars: dev environment variable values"
git push origin feature/add-iac
```

Open a PR, merge it.

---

## Common mistakes and gotchas

- **`terraform init` fails with "Error acquiring the state lock"**: Another Terraform process is running (or crashed) and left a lock. Find the lease in the Portal (storage account → container → `platform-dev.tfstate.lock`) and break it, or wait a few minutes.
- **"Existing state found for backend"**: When switching from local to remote backend, Terraform asks if you want to copy the local state. Type `yes`.
- **Terraform destroys and recreates a resource instead of updating**: Some changes require replacement (e.g. renaming a resource). Read the plan output carefully for `-/+` entries — these are destructive changes.
- **`terraform apply` succeeds but Key Vault already had purge protection and soft delete**: If you previously created a Key Vault with the same name and deleted it, it enters soft-delete. Run `az keyvault list-deleted` and `az keyvault purge --name ...` to permanently remove it first.
- **Bicep deployment fails with "Invalid template"**: Run `az bicep lint` to find syntax errors. The linter catches most issues before deployment.
- **`terraform fmt` does not change anything**: Your file is already correctly formatted. This is fine — `fmt` is idempotent.

---

**Next**: Stage 4 — automate these Terraform commands inside a CI/CD pipeline. Every PR shows a Terraform plan as a comment. Every merge to `main` applies the changes automatically.
