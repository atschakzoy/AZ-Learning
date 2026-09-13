# Stage 3 — Infrastructure as Code

> **Project milestone:** The foundation infra is expressed as Bicep (learning pass), then fully rewritten as Terraform with state stored in Azure Blob. The CLI scripts from Stage 2 are retired — Terraform is the single source of truth.

---

## What you'll build this stage

The same four resources from Stage 1, now declared in code. By the end, your repo will look like:

```
project/
└── infra/
    ├── bicep/                       ← learning pass, not kept long-term
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
            ├── keyvault/
            └── loganalytics/
```

---

## Concepts

### Why IaC?

Running `az storage account create` is **imperative** — you tell Azure what to do right now. IaC is **declarative** — you tell Azure what should exist, and the tool figures out how to get there.

| Property | What it means in practice |
|----------|--------------------------|
| Idempotent | Run it 10 times, same result — no duplicates, no errors |
| Auditable | Every change is a reviewed PR, not a terminal command |
| Repeatable | Spin up dev / staging / prod from identical code |
| Drift detection | Know when reality differs from what the code says |

### Bicep

Microsoft's native IaC language for Azure. Compiles down to ARM JSON. You don't need to know ARM to write Bicep.

Key building blocks:

```bicep
param storageAccountName string        // input — changes per deployment
var location = resourceGroup().location // computed value used internally

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
}

output primaryEndpoint string = storage.properties.primaryEndpoints.blob
```

Key CLI commands:

```bash
az bicep lint main.bicep                                   # lint
az deployment group what-if --resource-group rg --template-file main.bicep  # preview
az deployment group create  --resource-group rg --template-file main.bicep  # deploy
```

### Terraform

Cross-cloud IaC tool using HCL (HashiCorp Configuration Language). The standard in most Azure platform teams.

Key building blocks:

```hcl
# providers.tf
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
  backend "azurerm" { ... }   # remote state — keep state in Azure Blob
}
provider "azurerm" { features {} }

# main.tf
resource "azurerm_storage_account" "main" {
  name                = var.storage_account_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  account_tier        = "Standard"
  account_replication_type = "LRS"
}

output "storage_primary_endpoint" {
  value = azurerm_storage_account.main.primary_blob_endpoint
}
```

Workflow:

```bash
terraform init      # download providers, configure backend
terraform plan      # show what would change
terraform apply     # make it so
terraform destroy   # tear everything down
```

### State

Terraform tracks what it created in a **state file** (`terraform.tfstate`). It uses this to calculate what needs to change on the next `plan`. Never edit the state file manually.

For team use, state must be stored remotely. The standard Azure backend is an Azure Blob container — you will set this up in the project step.

### Bicep vs Terraform

| | Bicep | Terraform |
|-|-------|-----------|
| Azure-only | Yes | No — multi-cloud |
| State file | No — Azure tracks state | Yes — must manage remote state |
| Preview changes | `what-if` | `plan` |
| Community modules | Limited | Large registry |
| When to use | Azure-only team, ARM familiarity | Multi-cloud, or when team already uses TF |

---

## Exercises

### IaC concepts

1. Run `az group create --name rg-idem-test --location eastus` twice. Confirm the second call succeeds without error. This is idempotency.
2. Create a resource manually in the Portal inside a resource group managed by your IaC. Re-run your Terraform and observe it is flagged as an unmanaged resource (drift). Understand why this matters.

### Bicep

3. Write a minimal `main.bicep` that deploys a storage account with a `param` for the name:
   ```bash
   az group create --name rg-bicep-test --location eastus
   az deployment group create --resource-group rg-bicep-test \
     --template-file main.bicep --parameters storageAccountName=stbiceptest001
   ```
4. Change the SKU from `Standard_LRS` to `Standard_GRS`. Run `what-if` before applying and review the diff output.
5. Extract the storage account into a **Bicep module** (`modules/storage.bicep`). Call it from `main.bicep`. Re-deploy — no change should occur.
6. Add an `output` that returns the primary blob endpoint. Capture it after deployment:
   ```bash
   az deployment group show \
     --name <deployment-name> --resource-group rg-bicep-test \
     --query "properties.outputs"
   ```
7. Run `az bicep lint main.bicep` on a file with a missing `description` on a parameter. Fix the warning.

### Terraform

8. Write `providers.tf` and `main.tf` with just `azurerm_resource_group`. Run `terraform init`, `plan`, `apply`. Open the `terraform.tfstate` file and understand its structure.
9. Add `azurerm_storage_account`. Run `plan` — confirm only the storage account is added. Apply. Check state again.
10. Run `terraform destroy -target=azurerm_storage_account.main`. Confirm only the storage account is removed; the resource group stays.
11. Run `terraform fmt` on a deliberately mis-indented file and observe it auto-fix. Run `terraform validate` on a file with a missing required argument and read the error.
12. Install `tflint`. Run it against your config and fix any findings.

---

## Project Step

### A — Create the remote state backend

This is the one resource you always create manually — it cannot track its own state:

```bash
az group create --name rg-tfstate --location eastus

az storage account create \
  --name "sttfstate${SUFFIX}" \
  --resource-group rg-tfstate \
  --location eastus \
  --sku Standard_LRS \
  --allow-blob-public-access false \
  --min-tls-version TLS1_2

az storage container create \
  --name tfstate \
  --account-name "sttfstate${SUFFIX}"
```

Grant yourself `Storage Blob Data Contributor` on this storage account so Terraform can read/write state:

```bash
az role assignment create \
  --assignee $(az ad signed-in-user show --query id -o tsv) \
  --role "Storage Blob Data Contributor" \
  --scope $(az storage account show --name "sttfstate${SUFFIX}" --resource-group rg-tfstate --query id -o tsv)
```

### B — Bicep pass (learning, then retire)

Write `project/infra/bicep/` with a module for each resource type. Parameters: `environment` (default `dev`) and `suffix`.

Deploy to validate:
```bash
az deployment group what-if \
  --resource-group rg-platform-dev \
  --template-file project/infra/bicep/main.bicep \
  --parameters project/infra/bicep/main.bicepparam

az deployment group create \
  --resource-group rg-platform-dev \
  --template-file project/infra/bicep/main.bicep \
  --parameters project/infra/bicep/main.bicepparam
```

Run `az bicep lint` and fix all warnings. Once Terraform is working, the Bicep folder stays in the repo as a reference but is not the active deployment path.

### C — Terraform for the foundation

`project/infra/terraform/providers.tf`:

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
    storage_account_name = "sttfstate<suffix>"   # replace with your actual name
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

`project/infra/terraform/variables.tf`:

```hcl
variable "environment" {
  type    = string
  default = "dev"
}

variable "suffix" {
  type        = string
  description = "Short unique suffix for globally unique resource names"
}

variable "location" {
  type    = string
  default = "eastus"
}
```

`project/infra/terraform/main.tf` — call modules for each resource. Each module lives in `modules/<name>/` with its own `main.tf`, `variables.tf`, and `outputs.tf`.

Run the full workflow:
```bash
cd project/infra/terraform
terraform init
terraform plan -var="suffix=abc"
terraform apply -var="suffix=abc"
```

Confirm state is written to the Azure Blob container.

### D — Variables for environments

Add a `dev.tfvars` file:
```hcl
environment = "dev"
suffix      = "abc"
location    = "eastus"
```

Run plan with the var file:
```bash
terraform plan -var-file="dev.tfvars"
```

Commit everything via a PR. Delete `project/infra/scripts/` — Terraform replaces it.

---

**Next**: Stage 4 — automate these Terraform commands inside a CI/CD pipeline so every PR shows a plan and every merge to `main` applies it automatically.
