# Terraform — Stage 3 Learning Reference

---

## What is Terraform?

Terraform is the most widely used IaC tool in the industry. Unlike Bicep, it works across multiple cloud providers (Azure, AWS, GCP, and more) using the same language and workflow.

**HCL (HashiCorp Configuration Language)** is the language Terraform uses. It is designed to be readable and easy to write.

---

## Install and Setup

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Verify
terraform --version
# Expected: Terraform v1.x.x

# Install tflint (linter — catches mistakes terraform validate misses)
brew install tflint
tflint --version
```

VS Code extension: install **HashiCorp Terraform** — syntax highlighting and autocomplete for `.tf` files.

---

## The Four Core Concepts

### 1 — Provider

A provider is a plugin that knows how to talk to a specific cloud API. The `azurerm` provider talks to Azure.

```hcl
# providers.tf
terraform {
  required_version = ">= 1.9"
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

### 2 — Resource

A resource is something Terraform will create and manage in Azure.

```hcl
# main.tf
resource "azurerm_resource_group" "main" {
  name     = "rg-platform-dev"
  location = "East US"
}

# Reference another resource: azurerm_resource_group.main.name
# Terraform automatically figures out the dependency order
resource "azurerm_storage_account" "main" {
  name                = "stplatformdevnn"
  resource_group_name = azurerm_resource_group.main.name     # reference
  location            = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

Format: `resource "<provider_type>" "<local_name>"` — the local name is what you use to reference it elsewhere.

### 3 — Variable

Variables are inputs to your configuration. They keep values out of your code and let you reuse the same config for different environments.

```hcl
# variables.tf
variable "suffix" {
  type        = string
  description = "Short unique suffix for globally unique names"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "location" {
  type    = string
  default = "eastus"
}
```

Use a variable with `var.name`:
```hcl
resource "azurerm_storage_account" "main" {
  name = "stplatformdev${var.suffix}"
  # ...
}
```

### 4 — Output

Outputs are values Terraform exports after running. Useful for reading resource IDs or names after deployment.

```hcl
# outputs.tf
output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "resource_group_id" {
  value = azurerm_resource_group.main.id
}
```

---

## The Terraform Workflow

These four commands are everything:

```bash
# 1. Initialize — download providers, set up backend
#    Run this once per new project, and after changing providers
terraform init

# 2. Plan — show what would change (does NOT make any changes)
#    Always read this output before applying
terraform plan

# 3. Apply — actually make the changes (asks for confirmation)
terraform apply

# 4. Destroy — delete everything Terraform manages
#    Dangerous — always read what it will delete before confirming
terraform destroy
```

With a variables file:
```bash
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

---

## Reading the Plan Output

```
  # azurerm_storage_account.main will be created
  + resource "azurerm_storage_account" "main" {
      + name     = "stplatformdevnn"     ← green, will be added
      + location = "eastus"
    }

  # azurerm_key_vault.main will be updated in-place
  ~ resource "azurerm_key_vault" "main" {
      ~ sku_name = "standard" -> "premium"   ← yellow, will be changed
    }

  # azurerm_storage_account.old will be destroyed
  - resource "azurerm_storage_account" "old" {   ← red, will be deleted
    }
```

| Symbol | Meaning | Safe? |
|--------|---------|-------|
| `+` green | will be created | yes |
| `~` yellow | will be updated in-place (no downtime) | usually yes |
| `-` red | will be deleted | review carefully |
| `-/+` | will be destroyed and recreated | caution — causes downtime |

**Always review `-` and `-/+` lines before typing `yes`.**

---

## The State File

Terraform keeps a record of everything it created in `terraform.tfstate`. This is a JSON file mapping your HCL resources to real Azure resources.

On every `plan`, Terraform:
1. Reads `terraform.tfstate` — what it previously created
2. Reads your `.tf` files — what you want
3. Calls the Azure API — what actually exists right now
4. Compares all three and shows you the diff

**Never edit the state file manually.** Use `terraform state` commands if something goes wrong.

---

## Remote State

If the state file lives on your laptop:
- If your laptop dies, you lose the state — Terraform can no longer manage those resources
- If a colleague runs Terraform, they get a blank state — chaos
- Two people running Terraform at the same time corrupt the state

**Remote state** stores the state file in Azure Blob Storage (accessible to everyone) and uses blob leasing to prevent concurrent runs.

### Setting up remote state backend (do this once, manually)

```bash
# Variables — set these before running
RG_TFSTATE="rg-tfstate"
LOCATION="eastus"
SA_NAME="sttfstate${SUFFIX}"   # replace SUFFIX with your initials

# Create dedicated resource group for state storage
az group create --name $RG_TFSTATE --location $LOCATION

# Create the storage account
az storage account create \
  --name $SA_NAME \
  --resource-group $RG_TFSTATE \
  --location $LOCATION \
  --sku Standard_LRS \
  --allow-blob-public-access false \
  --min-tls-version TLS1_2

# Create the container that will hold the state file
az storage container create \
  --name tfstate \
  --account-name $SA_NAME

# Grant yourself access to read/write the state file
az role assignment create \
  --assignee $(az ad signed-in-user show --query id -o tsv) \
  --role "Storage Blob Data Contributor" \
  --scope $(az storage account show --name $SA_NAME --resource-group $RG_TFSTATE --query id -o tsv)
```

> **Why a separate resource group?** The state storage outlives individual environments. If you delete `rg-platform-dev`, you want the state to survive. Keeping state in its own resource group prevents accidental deletion.

### Backend block in providers.tf

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
```

After adding the backend block, run `terraform init` again — it will ask to copy local state to the remote. Type `yes`.

---

## Modules

A module is a folder of `.tf` files that can be called from another configuration — like a function you write once and call many times with different inputs.

```
modules/
└── storage/
    ├── main.tf        ← resource definitions
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
  value = module.storage.primary_blob_endpoint
}
```

---

## Useful Commands

```bash
# Format all .tf files (always run before committing)
terraform fmt

# Format all files in subdirectories too
terraform fmt -recursive

# Check syntax and config validity
terraform validate

# Run the linter (checks things validate misses)
tflint --init   # downloads tflint plugins first time
tflint

# Destroy only one specific resource, leave the rest
terraform destroy -target=azurerm_storage_account.practice

# List all resources in state
terraform state list

# Show a specific resource in state
terraform state show azurerm_storage_account.main

# Verify state is stored in Azure Blob
az storage blob list \
  --account-name "sttfstate${SUFFIX}" \
  --container-name tfstate \
  --output table
```

---

## Variables File (.tfvars)

Instead of passing `--var suffix=nn` every time, put variable values in a `.tfvars` file:

```hcl
# dev.tfvars
environment = "dev"
suffix      = "nn"       # replace with your initials
location    = "eastus"
```

Then:
```bash
terraform plan  -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

---

## Data Sources

A data source reads existing Azure resources that Terraform didn't create. Useful for referencing things like the current user or tenant.

```hcl
# Read the current authenticated user/service principal
data "azurerm_client_config" "current" {}

# Use it in a resource
resource "azurerm_key_vault" "main" {
  # ...
  properties: {
    tenant_id = data.azurerm_client_config.current.tenant_id
  }
}
```

---

## Exercises

### Exercise 1 — Your first Terraform config

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

Run:
```bash
terraform init
# Expected: "Terraform has been successfully initialized!"
# Downloads the azurerm provider (~50MB) into .terraform/

terraform plan
# Expected: "Plan: 1 to add, 0 to change, 0 to destroy."

terraform apply
# Type: yes
```

Confirm the resource group exists in the Portal. Open `terraform.tfstate` — find your resource group inside the JSON.

### Exercise 2 — Add a storage account

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

Run `terraform plan` — only the storage account should appear as new. The resource group shows no changes.

Apply, then check `terraform.tfstate` — the storage account entry is now there too.

### Exercise 3 — Target destroy

```bash
# Destroy only the storage account, leave the resource group
terraform destroy -target=azurerm_storage_account.practice
```

Confirm the storage account is gone but the resource group still exists.

### Exercise 4 — Format and validate

Deliberately mis-indent your `main.tf`. Run:
```bash
terraform fmt
```

Open `main.tf` — it is perfectly formatted. `fmt` is deterministic — always produces the same output. Run it before every commit.

Remove a required argument (e.g. delete `location` from the resource group). Run:
```bash
terraform validate
```

Expected: clear error message pointing to the missing argument.

### Exercise 5 — tflint

```bash
tflint --init   # downloads tflint plugins
tflint
```

tflint checks for common mistakes that `terraform validate` misses — deprecated arguments, missing required tags, naming convention violations.

### Exercise 6 — Drift detection

After deploying Terraform in the project step:
1. Go to the Portal and manually add a tag to your storage account
2. Run `terraform plan`
3. Terraform shows the tag as drift and plans to remove it

This is drift. In a real environment, someone changing resources manually is a problem — Terraform reverts their change on the next apply. This is why IaC is the single source of truth.

---

## Project: Terraform for Foundation Infra

Full file structure:

```
project/infra/terraform/
├── providers.tf
├── main.tf
├── variables.tf
├── outputs.tf
├── dev.tfvars
└── modules/
    ├── storage/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── keyvault/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── loganalytics/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### `providers.tf`

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

### `variables.tf`

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

### `main.tf`

```hcl
data "azurerm_client_config" "current" {}

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
```

### `dev.tfvars`

```hcl
environment = "dev"
suffix      = "nn"       # replace with your initials
location    = "eastus"
```

### `modules/storage/main.tf`

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

### `modules/storage/variables.tf`

```hcl
variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
```

### `modules/storage/outputs.tf`

```hcl
output "id" { value = azurerm_storage_account.main.id }
output "name" { value = azurerm_storage_account.main.name }
output "primary_blob_endpoint" {
  value = azurerm_storage_account.main.primary_blob_endpoint
}
```

Create similar `main.tf`, `variables.tf`, and `outputs.tf` for `modules/keyvault/` and `modules/loganalytics/` following the same pattern.

### Run the full workflow

```bash
cd project/infra/terraform

terraform init
# Expected: "Terraform has been successfully initialized!"
# If prompted about copying state, type "yes"

terraform fmt -recursive
# Formats all .tf files including subdirectories

terraform validate
# Expected: "Success! The configuration is valid."

terraform plan -var-file="dev.tfvars"
# Read carefully — confirm the four resources will be created

terraform apply -var-file="dev.tfvars"
# Type "yes" when prompted

# Confirm state is stored in Azure Blob
az storage blob list \
  --account-name "sttfstate${SUFFIX}" \
  --container-name tfstate \
  --output table
# Expected: platform-dev.tfstate listed
```

---

## Commit via PR

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

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `terraform init` fails — "Error acquiring the state lock" | Another Terraform process crashed and left a lock. Find the lease in Portal (storage account → container → `platform-dev.tfstate.lock`) and break it, or wait a few minutes |
| "Existing state found for backend" | When switching from local to remote backend, Terraform asks to copy state. Type `yes` |
| Terraform destroys and recreates a resource instead of updating | Some changes require replacement. Read the plan for `-/+` entries — these are destructive |
| Key Vault already has purge protection and soft delete | Run `az keyvault list-deleted` and `az keyvault purge --name ...` to remove the soft-deleted vault first |
| `terraform fmt` doesn't change anything | File is already correctly formatted — this is fine, `fmt` is idempotent |
| `terraform apply` says "No changes" | Your code already matches what exists in Azure — correct behavior |
| Plan shows `-` for resource you didn't touch | You renamed the resource in HCL — Terraform sees it as delete+create. Use `terraform state mv` to rename in state without destroying |
