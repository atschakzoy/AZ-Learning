# Bicep — Stage 3 Learning Reference

---

## Why Infrastructure as Code (IaC)?

In Stage 1 you ran CLI commands. In Stage 2 you wrapped them in scripts. Both are **imperative** — you tell Azure *what to do* step by step.

**IaC is declarative** — you describe the end state, the tool figures out how to get there.

| Imperative (CLI script) | Declarative (Bicep/Terraform) |
|------------------------|-------------------------------|
| `az storage account create ...` | declare resource in code |
| Fails if resource already exists | Skips if already exists |
| No memory of what it created | Tracks everything |
| Hard to know current state | Always shows diff before applying |

**Four properties of IaC:**

- **Idempotent** — run 10 times, same result. The Stage 2 script would fail on the second run. Bicep handles this automatically.
- **Auditable** — every infra change is a code change in a PR. You see who changed what and why.
- **Repeatable** — spin up identical dev and prod environments from the same code, different variable values.
- **Drift detection** — Terraform (not Bicep) tells you when what exists in Azure differs from your code.

---

## What is Bicep?

Bicep is Microsoft's language for describing Azure resources. It compiles to ARM (Azure Resource Manager) JSON — the format Azure's API actually understands.

You write readable Bicep → CLI converts it to ARM JSON → ARM JSON sent to Azure.

**Why learn Bicep if we end up using Terraform?**
- Microsoft's native IaC for Azure, widely used in Azure-centric teams
- Gives you a deeper appreciation of how Azure's resource model works
- New Azure features appear in Bicep/ARM before they appear in the Terraform provider

---

## Install and Setup

```bash
# Bicep comes with the Azure CLI — keep it updated
az bicep install
az bicep upgrade
az bicep version
# Expected: Bicep CLI version 0.x.x
```

VS Code extension: install **Bicep** (by Microsoft) — gives syntax highlighting, autocomplete, and error detection for `.bicep` files.

---

## Bicep File Structure

A `.bicep` file has four building blocks: parameters, variables, resources, outputs.

```bicep
// Parameters: inputs that can change per deployment
param storageAccountName string
param location string = resourceGroup().location   // default value
param environment string = 'dev'

// Variables: computed values used internally (not inputs)
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

// Outputs: values returned after deployment
// (useful for passing to other templates or scripts)
output primaryEndpoint string = storage.properties.primaryEndpoints.blob
output storageAccountId string = storage.id
```

---

## Resource Type Format

Every Bicep resource type looks like this:

```
'Microsoft.Storage/storageAccounts@2023-01-01'
  ^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^  ^^^^^^^^^^
  resource provider  resource type  API version
```

- **Resource provider** — who manages this resource type (e.g. `Microsoft.Storage`, `Microsoft.KeyVault`)
- **Resource type** — the specific type (e.g. `storageAccounts`, `vaults`)
- **API version** — always use the latest stable version

Find all resource types and API versions in the [Azure resource documentation](https://learn.microsoft.com/en-us/azure/templates/).

---

## Deploying Bicep

Always run `what-if` before applying — it shows exactly what will change without touching anything.

```bash
# Preview changes (safe — does not make any changes)
az deployment group what-if \
  --resource-group rg-platform-dev \
  --template-file main.bicep \
  --parameters storageAccountName=stplatformdevnn

# Apply the deployment
az deployment group create \
  --resource-group rg-platform-dev \
  --template-file main.bicep \
  --parameters storageAccountName=stplatformdevnn

# Apply using a .bicepparam file (cleaner for many parameters)
az deployment group create \
  --resource-group rg-platform-dev \
  --template-file main.bicep \
  --parameters main.bicepparam
```

---

## Parameters File (.bicepparam)

Instead of passing `--parameters name=value` one by one, put them in a params file:

```bicep
// main.bicepparam
using 'main.bicep'

param suffix = 'nn'        // replace with your initials
param environment = 'dev'
```

Then deploy with:
```bash
az deployment group create \
  --resource-group rg-platform-dev \
  --template-file main.bicep \
  --parameters main.bicepparam
```

---

## Decorators

Decorators add metadata to parameters:

```bicep
@description('Name for the storage account')
param storageAccountName string

@description('Azure region')
param location string = resourceGroup().location
```

`@description` is also checked by the linter — missing descriptions will show as warnings.

---

## Bicep Modules

A module is a separate `.bicep` file. The parent file calls the module and passes parameters. This lets you split a large template into smaller reusable pieces.

```bicep
// main.bicep calling a module
module storage './modules/storage.bicep' = {
  name: 'storageDeployment'
  params: {
    storageAccountName: 'stplatformdevnn'
    location: location
  }
}

// Using a module's output
output endpoint string = storage.outputs.primaryEndpoint
```

The `name` field (`'storageDeployment'`) is the deployment name in Azure — it appears in the Portal under Deployments.

---

## Lint

The linter checks your Bicep for errors and warnings before deploying:

```bash
az bicep lint main.bicep
```

Common warnings:
- Missing `@description` decorator on a parameter
- Unused variables or parameters
- Deprecated resource API versions

Always lint before deploying to production.

---

## View Deployment Outputs

After deploying, you can read the outputs your template defined:

```bash
# List deployments in a resource group
az deployment group list --resource-group rg-bicep-test --output table

# Show a specific deployment's outputs
az deployment group show \
  --name <deployment-name> \
  --resource-group rg-bicep-test \
  --query "properties.outputs"
```

---

## Exercises

### Exercise 1 — Idempotency demo

The CLI script from Stage 2 fails if you run it twice (storage account already exists). Run the Bicep deployment twice — the second run succeeds with no changes. This is idempotency.

### Exercise 2 — Your first Bicep file

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

Deploy:
```bash
az group create --name rg-bicep-test --location eastus

az deployment group create \
  --resource-group rg-bicep-test \
  --template-file main.bicep \
  --parameters storageAccountName=stbiceptest001
```

Expected: deployment completes, storage account visible in Portal.

### Exercise 3 — Preview changes with what-if

Change the SKU in `main.bicep` from `Standard_LRS` to `Standard_GRS`. Before applying, run:

```bash
az deployment group what-if \
  --resource-group rg-bicep-test \
  --template-file main.bicep \
  --parameters storageAccountName=stbiceptest001
```

Read the output — you should see the SKU change planned. This is the Bicep equivalent of `terraform plan`. Apply:
```bash
az deployment group create \
  --resource-group rg-bicep-test \
  --template-file main.bicep \
  --parameters storageAccountName=stbiceptest001
```

### Exercise 4 — Extract to a module

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

### Exercise 5 — Lint

Add a parameter without a `@description` decorator:
```bicep
param undescribedParam string  // missing @description
```

Run:
```bash
az bicep lint main.bicep
```

Expected: warning about missing description. Add the decorator and re-run — warning disappears.

---

## Project: Bicep Modules for Foundation Infra

These are the actual files for your `project/infra/bicep/` folder. The structure:

```
project/infra/bicep/
├── main.bicep
├── main.bicepparam
└── modules/
    ├── storage.bicep
    ├── keyvault.bicep
    └── loganalytics.bicep
```

### `modules/storage.bicep`

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

### `modules/keyvault.bicep`

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

### `modules/loganalytics.bicep`

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

### `main.bicep`

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

### `main.bicepparam`

```bicep
using 'main.bicep'

param suffix = 'nn'        // replace with your initials
param environment = 'dev'
```

### Deploy the project Bicep

```bash
# Lint first
az bicep lint project/infra/bicep/main.bicep

# Preview
az deployment group what-if \
  --resource-group rg-platform-dev \
  --template-file project/infra/bicep/main.bicep \
  --parameters project/infra/bicep/main.bicepparam

# Apply
az deployment group create \
  --resource-group rg-platform-dev \
  --template-file project/infra/bicep/main.bicep \
  --parameters project/infra/bicep/main.bicepparam
```

---

## Real-World Full Deployment — Everything in Bicep

In a real project the resource group is also defined in Bicep, not created manually in the terminal. This means the deployment happens at **subscription level**, not resource group level.

### File structure

```
project/infra/bicep/
├── main.bicep           ← subscription-level entry point, defines RG + calls modules
├── main.bicepparam      ← parameter values
└── modules/
    ├── storage.bicep
    ├── keyvault.bicep
    └── loganalytics.bicep
```

### `main.bicep` (subscription-level)

```bicep
targetScope = 'subscription'   // tells Bicep this deploys at subscription level, not RG level

@description('Short unique suffix for globally unique names')
param suffix string

@description('Environment name')
param environment string = 'dev'

@description('Azure region')
param location string = 'eastus'

// Resource group defined in Bicep — not created manually in terminal
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-platform-${environment}'
  location: location
}

// Modules are scoped to the resource group above
module storage './modules/storage.bicep' = {
  name: 'storageDeployment'
  scope: rg                    // deploy this module into the RG defined above
  params: {
    name: 'stplatformdev${suffix}'
    location: location
  }
}

module kv './modules/keyvault.bicep' = {
  name: 'kvDeployment'
  scope: rg
  params: {
    name: 'kv-platform-${environment}-${suffix}'
    location: location
  }
}

module law './modules/loganalytics.bicep' = {
  name: 'lawDeployment'
  scope: rg
  params: {
    name: 'law-platform-${environment}'
    location: location
  }
}
```

### `main.bicepparam`

```bicep
using 'main.bicep'

param suffix      = 'nn'    // replace with your initials
param environment = 'dev'
param location    = 'eastus'
```

### Full deployment commands (real-world order)

```bash
# Step 1 — lint: check your files for errors before touching Azure
az bicep lint -f project/infra/bicep/main.bicep

# Step 2 — what-if: preview what would be created/changed/deleted
#   sub create = subscription-level deployment (not group)
az deployment sub what-if \
  --location eastus \
  --template-file project/infra/bicep/main.bicep \
  --parameters project/infra/bicep/main.bicepparam

# Step 3 — apply: actually deploy everything including the resource group
az deployment sub create \
  --location eastus \
  --template-file project/infra/bicep/main.bicep \
  --parameters project/infra/bicep/main.bicepparam
```

### Key differences from the simpler approach

| | Simple (RG created manually) | Real-world (RG in Bicep) |
|--|------------------------------|--------------------------|
| RG creation | `az group create` in terminal | defined as a resource in `main.bicep` |
| Deployment command | `az deployment group create` | `az deployment sub create` |
| `targetScope` in Bicep | not needed (default is resourceGroup) | `targetScope = 'subscription'` required |
| Modules | no `scope:` needed | `scope: rg` required on each module |

---

## Bicep vs Terraform — Quick Comparison

| | Bicep | Terraform |
|-|-------|-----------|
| Works with | Azure only | Azure, AWS, GCP, 1000+ providers |
| State management | Azure tracks state (no state file) | You manage state (remote backend) |
| Preview changes | `what-if` | `plan` |
| Learning curve | Lower for Azure-focused learners | Higher initially |
| New Azure features | Available immediately (compiles to ARM) | Depends on provider updates |
| When to use | Azure-only org, Microsoft-tooling teams | Multi-cloud, or team already uses Terraform |

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Deployment fails with "Invalid template" | Run `az bicep lint` to find syntax errors |
| Key Vault already exists in soft-delete | `az keyvault list-deleted` then `az keyvault purge --name ...` |
| Missing `@description` on parameters | Add decorator — the linter will warn about it |
| Wrong API version in resource type | Check [Azure resource docs](https://learn.microsoft.com/en-us/azure/templates/) for latest stable version |
| Running `what-if` after deploying — shows no changes | Your code matches what exists — that is correct, not an error |

---

## All az Commands for Running Bicep in a Real Project


### Lint (always first)

```bash
# Check a single file for errors and warnings
az bicep lint -f project/infra/bicep/main.bicep
```

### Simple approach — RG created manually, deploy at resource group level

```bash
# Create the resource group once (manually, before any Bicep deployment)
az group create \
  --name rg-platform-dev \    # name of the resource group to create
  --location eastus            # Azure region where it will live

# Preview changes — shows what would be created/changed/deleted, touches nothing
az deployment group what-if \    # what-if = dry run, no real changes
  --resource-group rg-platform-dev \    # deploy INTO this resource group
  --template-file project/infra/bicep/main.bicep \    # your Bicep file
  --parameters project/infra/bicep/main.bicepparam    # your parameter values file

# Apply — actually creates or updates the resources in Azure
az deployment group create \    # create = real deployment, changes will happen
  --resource-group rg-platform-dev \    # deploy INTO this resource group
  --template-file project/infra/bicep/main.bicep \    # your Bicep file
  --parameters project/infra/bicep/main.bicepparam    # your parameter values file
```

### Real-world approach — RG in Bicep, deploy at subscription level

```bash
# Preview changes — subscription level because main.bicep has targetScope = 'subscription'
az deployment sub what-if \    # sub = subscription level (not resource group level)
  --location eastus \    # region where the deployment metadata is stored
  --template-file project/infra/bicep/main.bicep \    # your Bicep file
  --parameters project/infra/bicep/main.bicepparam    # your parameter values file

# Apply — creates the resource group AND all resources inside it
az deployment sub create \    # sub = subscription level
  --location eastus \    # region for the deployment metadata
  --template-file project/infra/bicep/main.bicep \    # your Bicep file
  --parameters project/infra/bicep/main.bicepparam    # your parameter values file
```

### View deployments and outputs

```bash
# List all deployments in a resource group
az deployment group list \
  --resource-group rg-platform-dev \
  --output table

# Show a specific deployment and its outputs
az deployment group show \
  --name <deployment-name> \
  --resource-group rg-platform-dev \
  --query "properties.outputs"

# List subscription-level deployments
az deployment sub list --output table
```

### Manage soft-deleted Key Vaults (common issue)

```bash
# List soft-deleted Key Vaults
az keyvault list-deleted --output table

# Permanently delete a soft-deleted Key Vault so you can redeploy with same name
az keyvault purge --name kv-platform-dev-nn
```

### Cleanup

```bash
# Delete a resource group and everything inside it
az group delete --name rg-platform-dev --yes --no-wait
```

---

### Quick run — single main.bicep + main.bicepparam (no modules)

Use this when everything is written in one file, no modules folder.

```bash
az bicep lint -f main.bicep

az deployment group what-if \
  --resource-group rg-platform-dev \
  --template-file main.bicep \
  --parameters main.bicepparam

az deployment group create \
  --resource-group rg-platform-dev \
  --template-file main.bicep \
  --parameters main.bicepparam
```

---

### Quick run — modularised Bicep (main.bicep calls modules, RG defined in Bicep)

Use this when main.bicep has `targetScope = 'subscription'` and calls modules from a `modules/` folder.
The az command still only points to `main.bicep` — Azure follows the module references automatically.

```bash
az bicep lint -f project/infra/bicep/main.bicep

az deployment sub what-if \
  --location eastus \
  --template-file project/infra/bicep/main.bicep \
  --parameters project/infra/bicep/main.bicepparam

az deployment sub create \
  --location eastus \
  --template-file project/infra/bicep/main.bicep \
  --parameters project/infra/bicep/main.bicepparam
```
