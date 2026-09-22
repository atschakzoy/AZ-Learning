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

> **Note:** You never write ARM JSON by hand. You write Bicep, and the CLI converts it automatically when you deploy. Think of Bicep as a human-friendly version of Azure's own format.

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

> **Note:** You do not install Bicep separately. It is part of the Azure CLI. If `az bicep version` shows an old version, run `az bicep upgrade` to get the latest.

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

> **`resourceGroup().location`** — this is a built-in Bicep function. It reads the location of the resource group you are deploying into and uses it as the default. This way you do not have to hardcode `eastus` — it just uses wherever the resource group is.

> **`environment == 'prod' ? 'Standard_GRS' : 'Standard_LRS'`** — this is a ternary (if/else in one line). It means: if environment is prod, use GRS (geo-redundant storage); otherwise use LRS (locally redundant). Same as writing an if/else but shorter.

> **`kind: 'StorageV2'`** — StorageV2 is the current generation of Azure storage accounts. Always use StorageV2 unless you have a specific reason not to.

> **`allowBlobPublicAccess: false`** — by default Azure storage can be made public. Setting this to false means nobody can access your blobs without authentication. Always set this to false for security.

> **Parameters vs Variables:**
> - `param` = input from outside (you pass a value when deploying)
> - `var` = calculated internally (no input needed, Bicep works it out itself)

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

> **Why does the API version matter?** Azure adds new features and properties over time. If you use an old API version, those new features do not exist in Bicep — even if they exist in Azure. Always use the latest stable date. Find them in the [Azure resource documentation](https://learn.microsoft.com/en-us/azure/templates/).

---

## What Every Resource Requires

The **skeleton is always the same** across all resource types:

| Field | What it is | Example |
|-------|------------|---------|
| Symbolic name | name you use to reference the resource inside Bicep (not the Azure name) | `resource storage` |
| Resource type + API version | what kind of Azure resource to create | `'Microsoft.Storage/storageAccounts@2023-01-01'` |
| `name` | the actual name of the resource in Azure | `storageAccountName` |
| `location` | Azure region to deploy into | `location` |

**What differs is the `properties` block** — each resource type has its own required fields inside it:

| Resource | Required inside `properties` |
|----------|------------------------------|
| Storage Account | `sku` and `kind` live at resource level (not inside `properties`) |
| Key Vault | `tenantId`, `sku`, and either `accessPolicies` or `enableRbacAuthorization` |
| Log Analytics Workspace | `sku`, `retentionInDays` |
| Virtual Network | `addressSpace` |
| App Service | `serverFarmId` |

> **Rule of thumb:** `name` + `location` are always at the top level of every resource. `sku` is required for most resources. What goes inside `properties` is resource-specific — the VS Code Bicep extension will underline missing required fields in red, which is the fastest way to know what is mandatory.

> **How to find what is required:** In VS Code with the Bicep extension, type `resource myName '` and IntelliSense shows all resource types. Once you pick one, it will flag any missing required fields. You can also check the [Azure resource reference](https://learn.microsoft.com/en-us/azure/templates/) and look up the specific resource type.

---

## Important Notes

> **Resource group scope vs subscription scope**
> `az deployment group` deploys INTO an existing resource group — the resource group must already exist before you run this command. That is why you run `az group create` first.
> If you want Bicep to create the resource group itself, you must use `az deployment sub` (subscription scope) and add `targetScope = 'subscription'` at the top of your `main.bicep`.

> **`deployment group` = RG must exist already**
> **`deployment sub` = RG can be defined inside Bicep**

> **Why is there a `--location` in `deployment sub` but not in `deployment group`?**
> When deploying at subscription level, Azure needs to know where to store the deployment metadata (logs, history). This is what `--location` sets — it is NOT the location of your resources. Your resource locations are set inside your Bicep files.

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

> **`--template-file`** points to your `.bicep` file. The terminal must be in the same folder as the file, or you must give the full path (e.g. `project/infra/bicep/main.bicep`). If you get "file not found", run `ls` to check you are in the right folder.

> **`--parameters storageAccountName=stplatformdevnn`** — this passes a value for one parameter inline. If you have multiple parameters it gets messy. Use a `.bicepparam` file instead (see next section).

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

> **`using 'main.bicep'`** — this line at the top of the params file tells Bicep which `.bicep` file these parameters belong to. Without it the file does not work. It must match the name of your Bicep file exactly.

> **The params file must be in the same folder as your `main.bicep`**, or you pass the full path. If VS Code shows a warning on the `using` line, it usually means the path is wrong.

---

## Decorators

Decorators add metadata to parameters:

```bicep
@description('Name for the storage account')
param storageAccountName string

@description('Azure region')
param location string = resourceGroup().location
```

> **Decorators are optional but recommended.** They start with `@` and go on the line directly above the `param`. The `@description` text appears in the Portal when someone deploys manually, and the linter will warn you if it is missing.

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

> **Why use modules?** If everything is in one file, `main.bicep` becomes very long and hard to read. Modules let you put each resource type in its own file and call it from `main.bicep`. Same concept as splitting code into functions or files in programming.

> **`name: 'storageDeployment'`** — this is the deployment name that appears in the Azure Portal under your resource group → Deployments. It is NOT the name of the Azure resource. Give it a clear name so you can find it in the Portal later.

> **`./modules/storage.bicep`** — the `./` means "starting from the current folder". So `./modules/storage.bicep` means "go into the `modules` folder and open `storage.bicep`".

> **`storage.outputs.primaryEndpoint`** — after a module runs, you access its outputs with `moduleName.outputs.outputName`. The module must have defined that output for this to work.

---

## Lint

The linter checks your Bicep for errors and warnings before deploying:

```bash
az bicep lint -f main.bicep
```

> **`-f`** is short for `--file`. Both work the same way — `-f` is just faster to type.

Common warnings:
- Missing `@description` decorator on a parameter
- Unused variables or parameters
- Deprecated resource API versions

> **Lint does not connect to Azure.** It only reads your files. It is fast and safe — run it every time before deploying.

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

> **`<deployment-name>`** — replace this with the actual deployment name from the list command above. In Bicep, the deployment name is what you set in the `name:` field of the module, or it defaults to the template file name.

> **`--query "properties.outputs"`** — this filters the JSON response to only show the outputs section. Without `--query` you get the full deployment details which is very long.

---

## Exercises

### Exercise 1 — Idempotency demo

The CLI script from Stage 2 fails if you run it twice (storage account already exists). Run the Bicep deployment twice — the second run succeeds with no changes. This is idempotency.

### Exercise 2 — Your first Bicep file

```bash
mkdir ~/bicep-practice && cd ~/bicep-practice
```

> **`~/`** means your home folder (e.g. `/Users/rezanazari`). `mkdir` creates the folder, `&&` means "if that succeeded, then run the next command", `cd` moves into it.

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

> **Storage account names must be globally unique across all of Azure** — no two storage accounts in the world can have the same name. If `stbiceptest001` is taken, try adding your initials: `stbiceptest001rn`.

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

> **SKU** means the pricing/replication tier. `Standard_LRS` = locally redundant (3 copies in one datacenter). `Standard_GRS` = geo-redundant (copies in a second region). GRS costs more but survives a datacenter failure.

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

> **Why does re-deploying show no changes?** Because Bicep is declarative — it compares what your code says with what exists in Azure. The resources are identical, so nothing needs to change.

### Exercise 5 — Lint

Add a parameter without a `@description` decorator:
```bicep
param undescribedParam string  // missing @description
```

Run:
```bash
az bicep lint -f main.bicep
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

> **You only ever run commands against `main.bicep`.** The modules are called automatically from inside `main.bicep`. You never deploy a module file directly.

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

> **`minimumTlsVersion: 'TLS1_2'`** — TLS is the encryption protocol used when connecting to Azure storage. Setting this to TLS1_2 means older, less secure versions (1.0, 1.1) are rejected. Always set this in production.

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

> **`tenantId: subscription().tenantId`** — `subscription()` is a built-in Bicep function that reads your current Azure subscription's details. `.tenantId` gets the Entra ID tenant ID from it. Key Vault needs this to know which directory to check for permissions.

> **`enableSoftDelete: true` and `softDeleteRetentionInDays: 90`** — soft delete means if you delete the Key Vault, it is not immediately gone. It goes into a "deleted but recoverable" state for 90 days. After 90 days it is permanently deleted. This protects against accidental deletion.

> **`enablePurgeProtection: true`** — once enabled, you cannot permanently delete the Key Vault during the retention period even if you want to. This is the strongest protection. Important: if you enable this and try to redeploy with the same name, you must wait for the retention period or `az keyvault purge` it manually.

> **`enableRbacAuthorization: true`** — access to secrets is controlled by Azure RBAC (role assignments) rather than Key Vault access policies. RBAC is the modern approach and the one we use.

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

> **`PerGB2018`** — this is the pricing model name for Log Analytics. It means you pay per gigabyte of data ingested. It is the standard modern pricing tier — always use this.

> **`retentionInDays: 30`** — how long Azure keeps your logs before deleting them. 30 days is the minimum and cheapest. Production environments often use 90 days.

> **`customerId`** — this is the Workspace ID used when connecting other services (like VMs or apps) to send their logs to this workspace. You often need this output when wiring things together.

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

> **`'stplatformdev${suffix}'`** — the `${}` is string interpolation. It inserts the value of `suffix` into the string. If `suffix = 'rn'`, the result is `stplatformdevrn`. This is how you make resource names unique per person or environment.

### `main.bicepparam`

```bicep
using 'main.bicep'

param suffix = 'nn'        // replace with your initials
param environment = 'dev'
```

### Deploy the project Bicep

```bash
# Lint first
az bicep lint -f project/infra/bicep/main.bicep

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

> **`targetScope = 'subscription'`** — by default Bicep deploys at resource group level. Adding this line at the very top changes it to subscription level. This is required when your Bicep file creates the resource group itself.

> **`scope: rg`** — when deploying at subscription level, modules do not automatically know which resource group to go into. You must tell each module explicitly with `scope: rg`. The `rg` here refers to the resource group resource defined above in the same file.

> **Why `location` is hardcoded as `'eastus'` here instead of `resourceGroup().location`** — because at subscription level, the resource group does not exist yet when the file is first read. So `resourceGroup().location` would fail — there is no RG to read from. You must pass the location as a parameter instead.

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
#   sub = subscription-level deployment (not group)
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
| Deployment fails with "Invalid template" | Run `az bicep lint -f main.bicep` to find syntax errors |
| Key Vault already exists in soft-delete | `az keyvault list-deleted` then `az keyvault purge --name ...` |
| Missing `@description` on parameters | Add decorator — the linter will warn about it |
| Wrong API version in resource type | Check [Azure resource docs](https://learn.microsoft.com/en-us/azure/templates/) for latest stable version |
| Running `what-if` after deploying — shows no changes | Your code matches what exists — that is correct, not an error |
| "File not found" when running deploy command | Your terminal is in the wrong folder — run `ls` to check, then navigate to the right folder |
| Storage account name already taken | Names must be globally unique — add your initials to the end |
| `using` line in `.bicepparam` shows an error | The path in `using` does not match the actual Bicep filename — check spelling |

---

## All az Commands for Running Bicep in a Real Project

### Setup

```bash
# Install / update Bicep CLI
az bicep install
az bicep upgrade
az bicep version
```

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
  --location eastus \    # where to store deployment metadata (not where your resources go)
  --template-file project/infra/bicep/main.bicep \    # your Bicep file
  --parameters project/infra/bicep/main.bicepparam    # your parameter values file

# Apply — creates the resource group AND all resources inside it
az deployment sub create \    # sub = subscription level
  --location eastus \    # where to store deployment metadata
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
# --yes = skip the "are you sure?" prompt
# --no-wait = do not wait for it to finish, return immediately
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
