# Terraform — Stage 3 Learning Reference

---

## What is Terraform?

Terraform is the most widely used IaC tool in the industry. Unlike Bicep, it works across multiple cloud providers (Azure, AWS, GCP, and more) using the same language and workflow.

**HCL (HashiCorp Configuration Language)** is the language Terraform uses. It is designed to be readable and easy to write.

> **Note:** Terraform is not made by Microsoft — it is made by HashiCorp. This is why it works with AWS and GCP too, not just Azure. In Azure-only companies you often see Bicep. In companies using multiple clouds, you almost always see Terraform.

> **`.tf` files** — all Terraform files use the `.tf` extension. You can split your config across multiple `.tf` files in the same folder and Terraform reads them all as one combined configuration.

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

> **`brew tap hashicorp/tap`** — `tap` adds a third-party source to Homebrew so it can find HashiCorp's packages. You only need to run this once. After that, `brew install` can find Terraform.

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

> **`~> 4.0`** — this is a version constraint. `~>` means "at least this version, but not the next major version". So `~> 4.0` allows `4.1`, `4.2`, `4.9` but NOT `5.0`. This protects you from breaking changes in major updates.

> **`features {}`** — this block is required by the `azurerm` provider even if it is empty. Without it, Terraform will refuse to run. Think of it as a placeholder that exists so you can optionally add provider-level settings inside it (like Key Vault behavior).

> **`required_version = ">= 1.9"`** — this ensures anyone running this config has at least Terraform 1.9 installed. If they have an older version, Terraform stops with a clear error instead of failing in a confusing way later.

> **`providers.tf` is just a naming convention** — you could put everything in one file or name it anything. But separating providers into their own file is the standard pattern because it keeps configuration clean.

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

> **`resource "azurerm_resource_group" "main"`** — this has two names:
> - `azurerm_resource_group` = the resource type (what kind of thing to create)
> - `main` = the local name (how you refer to it inside your Terraform code)
> The local name `main` has no effect in Azure — it only exists inside your `.tf` files.

> **`azurerm_resource_group.main.name`** — this is how you reference another resource. The format is always `resource_type.local_name.attribute`. Terraform reads this reference and automatically knows it must create the resource group before the storage account.

> **Terraform works out the order automatically.** You do not need to write resources in the correct order. If resource B references resource A, Terraform creates A first, then B.

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

> **Variables without a `default` are required** — if you do not pass a value for `suffix`, Terraform will stop and ask you for it. Variables with a `default` are optional — Terraform uses the default if you do not pass a value.

> **`${var.suffix}`** — this is string interpolation. It inserts the value of the variable into the string. If `suffix = "rn"`, the result is `"stplatformdevrn"`. The `${}` syntax only works inside strings (wrapped in `""`).

> **Why put variables in a separate `variables.tf` file?** Convention — you could put them in `main.tf` and it would still work. But separating them makes it easy to see all inputs at a glance without scrolling through resource definitions.

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

> **When do you use outputs?** When you need a value after deployment — for example, the storage account name to pass to a script, or the resource group ID to use in another Terraform config. Terraform prints outputs at the end of `apply`.

> **`azurerm_storage_account.main.name`** — this reads the `name` attribute of the storage account after it is created. Terraform gets this value from Azure after the resource exists.

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

> **`terraform init`** downloads the provider plugin (e.g. `azurerm`) into a `.terraform/` folder in your project directory. This folder can be large (~50MB) and is listed in `.gitignore` — never commit it. You must run `terraform init` once before any other command, and again whenever you change providers or add a backend.

> **`terraform plan` never touches Azure.** It only shows what would happen. Read the output carefully before running `apply`. There is no undo for apply.

> **`terraform apply` asks "Do you want to perform these actions? yes/no"** — you must type the full word `yes`. Pressing Enter or typing `y` does not work. If you want to skip the prompt (e.g. in a pipeline), add `-auto-approve` flag — but never use this manually.

> **`terraform destroy` deletes everything Terraform manages** — this includes the resource group and all resources inside it. It also asks for `yes` confirmation. Only use this in dev/test environments. Never on production.

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

> **What causes `-/+` (destroy and recreate)?** Some Azure properties cannot be changed after creation — for example, renaming a storage account, changing the location of a resource, or changing certain immutable settings. Terraform must delete the old one and create a new one. This causes downtime. Always check if a change will trigger `-/+` in the plan before applying to production.

> **Why does Terraform show `-` for something I didn't touch?** Usually because you renamed the resource in your HCL code. Terraform sees the old name gone and the new name as new — it plans to delete the old and create the new. Use `terraform state mv old_name new_name` to rename in state without destroying.

---

## The State File

Terraform keeps a record of everything it created in `terraform.tfstate`. This is a JSON file mapping your HCL resources to real Azure resources.

On every `plan`, Terraform:
1. Reads `terraform.tfstate` — what it previously created
2. Reads your `.tf` files — what you want
3. Calls the Azure API — what actually exists right now
4. Compares all three and shows you the diff

**Never edit the state file manually.** Use `terraform state` commands if something goes wrong.

> **What happens if you delete the state file?** Terraform loses all memory of what it created. The next `plan` will show all resources as new — even if they already exist in Azure. If you then apply, Terraform tries to create them again and fails with "resource already exists" errors. Always protect the state file.

> **`terraform.tfstate` contains sensitive data** — resource IDs, names, sometimes secrets. Never commit it to git. It is already listed in `.gitignore` by default in most setups.

---

## Remote State

If the state file lives on your laptop:
- If your laptop dies, you lose the state — Terraform can no longer manage those resources
- If a colleague runs Terraform, they get a blank state — chaos
- Two people running Terraform at the same time corrupt the state

**Remote state** stores the state file in Azure Blob Storage (accessible to everyone) and uses blob leasing to prevent concurrent runs.

> **Blob leasing** means when Terraform starts running, it "locks" the state file in Azure Blob. If someone else tries to run Terraform at the same time, they get an error saying the state is locked. This prevents two people from making conflicting changes at the same time.

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

> **`$(...)` — subshell syntax.** The `$()` runs the inner command and replaces itself with the output. So `--assignee $(az ad signed-in-user show --query id -o tsv)` runs the inner `az` command, gets your user ID as text, and passes it as the value of `--assignee`. You do not need to run them separately.

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

> **`key = "platform-dev.tfstate"`** — this is the filename of the state file inside the blob container. Each environment gets its own state file. For example, dev uses `platform-dev.tfstate` and prod would use `platform-prod.tfstate`. This way they do not overwrite each other.

> **`use_azuread_auth = true`** — tells Terraform to authenticate to the storage account using your Azure CLI login (Entra ID), instead of a storage access key. This is the secure modern approach — you do not need to store a storage account key anywhere.

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

> **`source = "./modules/storage"`** — points to the folder containing the module's `.tf` files. `./` means starting from the current directory. Terraform reads all `.tf` files inside that folder as the module.

> **After adding or changing a module's `source`, run `terraform init` again.** Terraform needs to register the new module before it can use it. You will see "Initializing modules..." in the output.

> **The values you pass to the module (like `name`, `resource_group_name`) must match the variable names defined in the module's `variables.tf`.** If the module expects `name` and you pass `storage_name`, Terraform will error.

> **`module.storage.primary_blob_endpoint`** — access a module's output with `module.local_name.output_name`. The module must define that output in its `outputs.tf` for this to work.

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

> **`terraform fmt`** — automatically formats your `.tf` files to the official style. It fixes indentation, aligns `=` signs, and removes extra whitespace. It is deterministic — run it 10 times, you get the same result. Run it before every commit.

> **`terraform validate`** — checks that your config is syntactically correct and internally consistent (e.g. no missing required arguments). It does NOT connect to Azure and does NOT check if resource names are unique or available.

> **`tflint`** — a separate tool that catches things `validate` misses, like deprecated arguments, invalid resource names, or missing tags. Run `tflint --init` once to download plugins, then just `tflint` on subsequent runs.

> **`terraform destroy -target=...`** — destroys only the named resource, leaves everything else. The format is `resource_type.local_name` — the same as how you reference resources in code.

> **`terraform state list`** — shows every resource Terraform is currently tracking. Useful for checking what is in state before running destructive commands.

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

> **`.tfvars` vs `variables.tf`** — these are different things:
> - `variables.tf` declares the variables (their names, types, descriptions, and optional defaults)
> - `dev.tfvars` provides the actual values for those variables
> Think of `variables.tf` as the form template and `dev.tfvars` as the filled-in form.

> **You can have multiple `.tfvars` files** — one per environment: `dev.tfvars`, `staging.tfvars`, `prod.tfvars`. Pass the right one when running plan/apply.

---

## Data Sources

A data source reads existing Azure resources that Terraform didn't create. Useful for referencing things like the current user or tenant.

```hcl
# Read the current authenticated user/service principal
data "azurerm_client_config" "current" {}

# Use it in a resource
resource "azurerm_key_vault" "main" {
  # ...
  tenant_id = data.azurerm_client_config.current.tenant_id
}
```

> **Resource vs Data Source:**
> - `resource` = Terraform creates and manages this thing
> - `data` = Terraform reads this thing (it already exists, Terraform does not create it)

> **`data "azurerm_client_config" "current" {}`** — this reads information about the currently authenticated user (the one running `terraform apply`). The empty `{}` means no filters needed — just give me the current user. You use this to get the tenant ID for Key Vault without hardcoding it.

> **`data.azurerm_client_config.current.tenant_id`** — access a data source's value with `data.type.local_name.attribute`. Same pattern as resources, just with `data.` at the front.

---

## Exercises

### Exercise 1 — Your first Terraform config

```bash
mkdir ~/tf-practice && cd ~/tf-practice
```

> **`mkdir ~/tf-practice && cd ~/tf-practice`** — creates the folder and immediately moves into it. `~/` is your home directory. `&&` means "run this only if the previous command succeeded."

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

> **`.terraform/` folder** — created by `terraform init`. It contains the downloaded provider plugin. It can be 50-100MB. Never commit this to git — it is in `.gitignore`. If you delete it, just run `terraform init` again.

Confirm the resource group exists in the Portal. Open `terraform.tfstate` — find your resource group inside the JSON.

> **`terraform.tfstate`** — open it with VS Code and look at the `resources` array. You will see your resource group listed with its Azure ID. This is how Terraform remembers what it created.

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

> **Why does the resource group show no changes?** Because the state file already tracks it and it matches what is in Azure. Terraform only shows changes for things that are new or different.

Apply, then check `terraform.tfstate` — the storage account entry is now there too.

### Exercise 3 — Target destroy

```bash
# Destroy only the storage account, leave the resource group
terraform destroy -target=azurerm_storage_account.practice
```

Confirm the storage account is gone but the resource group still exists.

> **`azurerm_storage_account.practice`** — the format is `resource_type.local_name`. The `practice` here is the local name you gave the resource in your `main.tf`, not the Azure resource name.

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

> **Why does Terraform want to remove the tag?** Because your `.tf` files do not define that tag. Terraform's job is to make Azure match your code — and your code says "no tags". So it plans to remove the manually added one.

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

> **You always run Terraform commands from the root of this folder** (i.e. inside `project/infra/terraform/`). Terraform reads all `.tf` files in the current directory. The modules are in subdirectories — Terraform only reads those when called via `module` blocks.

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

> **`purge_soft_delete_on_destroy = false`** — when Terraform destroys a Key Vault, should it also permanently purge it from soft-delete? Setting this to `false` means the Key Vault goes into the soft-delete bin (recoverable for 90 days) instead of being permanently gone immediately. Safer default.

> **`recover_soft_deleted_key_vaults = true`** — if Terraform tries to create a Key Vault that already exists in soft-delete (same name), should it automatically recover it instead of creating a new one? Setting this to `true` means Terraform handles this automatically instead of failing.

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

> **`suffix` has no default** — this means it is required. If you run `terraform plan` without passing `suffix`, Terraform will ask you to type it in the terminal. To avoid the prompt, always pass it via `-var-file="dev.tfvars"`.

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

> **`data "azurerm_client_config" "current" {}`** — reads your current Azure login details. The `tenant_id` from this is passed to the Key Vault module. Without it you would have to hardcode your tenant ID, which is bad practice.

> **`azurerm_resource_group.main.name` vs `var.environment`** — when you reference another resource (like `azurerm_resource_group.main.name`), Terraform automatically waits for that resource to be created first. This is how it knows the order of creation without you having to specify it.

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

> **`min_tls_version = "TLS1_2"`** — only allow connections using TLS 1.2 or higher. Older versions (TLS 1.0, 1.1) are less secure. Always set this.

> **`delete_retention_policy { days = 7 }`** — if you delete a blob (file in storage), it is not immediately gone. It is kept for 7 days and can be recovered. After 7 days it is permanently deleted. This protects against accidental file deletion.

### `modules/storage/variables.tf`

```hcl
variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
```

> **Module variables are the module's inputs.** The root `main.tf` passes values for these when it calls the module. The names here must match exactly what the root passes.

### `modules/storage/outputs.tf`

```hcl
output "id" { value = azurerm_storage_account.main.id }
output "name" { value = azurerm_storage_account.main.name }
output "primary_blob_endpoint" {
  value = azurerm_storage_account.main.primary_blob_endpoint
}
```

> **Module outputs are the module's return values.** After the module runs, the root `main.tf` can read these values using `module.storage.primary_blob_endpoint`. If you do not define an output here, the root cannot access that value.

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

> **`cd project/infra/terraform`** — you must be inside the terraform folder before running any `terraform` commands. Terraform looks for `.tf` files in the current directory. If you are in the wrong folder it will say "no configuration files found."

> **`terraform fmt -recursive`** — the `-recursive` flag formats `.tf` files in all subdirectories too (including your modules). Without it, only the current folder is formatted.

> **"If prompted about copying state, type `yes`"** — this happens when you switch from no backend (local state) to a remote backend. Terraform finds the local `terraform.tfstate` and asks if you want to copy it to Azure Blob. Always say yes so you do not lose state history.

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
| "No configuration files found" | You ran `terraform` in the wrong folder. `cd` into the folder that contains your `.tf` files |
| Module not found after adding it | Run `terraform init` again — Terraform must register new modules before using them |
| Required variable not set | You did not pass a value for a variable with no default. Pass it via `-var-file` or Terraform will ask you in the terminal |
