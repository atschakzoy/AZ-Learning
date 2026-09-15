# 1.4 Azure CLI & Azure Portal

> **Goal:** Be able to interact with Azure programmatically via `az` CLI and navigate the Portal efficiently. These are your day-to-day tools before automation takes over.

---

## Table of Contents

1. [Installing & Configuring the Azure CLI](#1-installing--configuring-the-azure-cli)
2. [Authentication](#2-authentication)
3. [Core Commands](#3-core-commands)
4. [Output Formats & Querying](#4-output-formats--querying)
5. [Azure Cloud Shell](#5-azure-cloud-shell)
6. [Navigating the Azure Portal](#6-navigating-the-azure-portal)
7. [Azure PowerShell Module (Az)](#7-azure-powershell-module-az)
8. [Cheat Sheet](#8-cheat-sheet)
9. [Practice Exercises](#9-practice-exercises)

---

## 1. Installing & Configuring the Azure CLI

### What is the Azure CLI?

The Azure CLI (`az`) is a cross-platform command-line tool for managing Azure resources. It wraps the Azure REST API in human-friendly commands, making automation and scripting straightforward.

### Installation

**macOS (Homebrew — recommended):**
```bash
brew update && brew install azure-cli
```

**macOS (official script):**
```bash
curl -L https://aka.ms/InstallAzureCli | bash
```

**Linux (Debian/Ubuntu):**
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

**Windows:**
Download the MSI from [aka.ms/installazurecliwindows](https://aka.ms/installazurecliwindows), or via winget:
```powershell
winget install Microsoft.AzureCLI
```

**Verify installation:**
```bash
az version
```

### Keeping it up to date

```bash
az upgrade          # upgrade az CLI itself
brew upgrade azure-cli   # if installed via Homebrew
```

### Configuration file

The CLI saves your settings in a hidden folder on your Mac called `~/.azure/` (the `~` means your home directory). You never edit this folder directly — the `az config` commands below write to it for you. The purpose of these settings is to set **defaults** so you don't have to repeat the same flags (like `--resource-group` or `--output`) on every command.

```bash
az config set core.output=table      # show results as a readable table instead of raw JSON
az config set defaults.location=eastus        # assume eastus region on every command that needs --location
az config set defaults.group=my-rg   # assume my-rg on every command that needs --resource-group

az config get                         # show all your current defaults in one place
az config unset defaults.group        # remove a default so the CLI stops assuming it
```

---

## 2. Authentication

### Interactive login (most common)

```bash
az login
```

This opens a browser tab. After signing in, your credentials are cached in `~/.azure/`. The CLI confirms which subscriptions are available.

**Device code flow** (for headless environments):
```bash
az login --use-device-code
```

You'll get a code to enter at `https://microsoft.com/devicelogin`.

### Checking your context

```bash
az account show                              # current active subscription
az account show --query id --output tsv      # get just the subscription ID (useful in scripts)
az account list --output table               # list all subscriptions you have access to
az account list --all --output table         # include disabled subs
```

### Switching subscriptions

```bash
az account set --subscription "My Subscription Name"
az account set --subscription 00000000-0000-0000-0000-000000000000  # by ID
```

> **Tip:** Always confirm your active subscription before running destructive commands. It's easy to accidentally run `az group delete` in the wrong subscription.

### Service Principal login (automation / CI/CD)

A Service Principal (SP) is like a non-human identity used for automated authentication — pipelines, scripts, etc.

**Create a Service Principal:**
```bash
# Contributor role scoped to a subscription
az ad sp create-for-rbac \
  --name "my-sp-name" \
  --role Contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>
```

This outputs:
```json
{
  "appId": "...",       ← client ID
  "displayName": "...",
  "password": "...",    ← client secret (only shown once!)
  "tenant": "..."       ← tenant ID
}
```

**Login as a Service Principal:**
```bash
az login \
  --service-principal \
  --username <appId> \
  --password <password> \
  --tenant <tenantId>
```

**In CI/CD pipelines**, these are stored as secrets and used with environment variables:
```bash
export AZURE_CLIENT_ID="..."
export AZURE_CLIENT_SECRET="..."
export AZURE_TENANT_ID="..."
```

### Managed Identity login (inside Azure resources)

When running code inside an Azure VM, App Service, or Function App with a Managed Identity assigned:
```bash
az login --identity
az login --identity --username <client-id>   # user-assigned MI
```

No secrets needed — Azure handles the token exchange.

### Logout

```bash
az logout
az account clear   # clears cached credentials entirely
```

---

## 3. Core Commands

Azure CLI commands follow a consistent pattern:

```
az <service> <operation> [options]
az <service> <subservice> <operation> [options]
```

### Getting help

Add `--help` to any command to see all available options — you don't need to look everything up online:

```bash
az keyvault --help                  # see all keyvault sub-commands
az keyvault create --help           # see all options for keyvault create
az storage account create --help    # same for storage
```

### Resource Groups

A resource group is a logical container for related resources.

```bash
# List resource groups
az group list --output table

# Create a resource group
az group create --name my-rg --location eastus

# Show details of a resource group
az group show --name my-rg

# Delete a resource group (and everything inside it!)
az group delete --name my-rg --yes --no-wait

# Check if a resource group exists
az group exists --name my-rg
```

### Resources (generic)

```bash
# List all resources in a resource group
az resource list --resource-group my-rg --output table

# List all resources in the subscription
az resource list --output table

# Show a specific resource
az resource show \
  --resource-group my-rg \
  --name my-storage \
  --resource-type Microsoft.Storage/storageAccounts

# Delete a resource
az resource delete \
  --resource-group my-rg \
  --name my-storage \
  --resource-type Microsoft.Storage/storageAccounts
```

### Storage Accounts

```bash
# Create a storage account
az storage account create \
  --name mystorageacct123 \
  --resource-group my-rg \
  --location eastus \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-blob-public-access false    # disables anonymous internet access to blobs — always set this in real environments

# List storage accounts
az storage account list --resource-group my-rg --output table

# Show storage account details
az storage account show --name mystorageacct123 --resource-group my-rg

# Get connection string
az storage account show-connection-string \
  --name mystorageacct123 \
  --resource-group my-rg

# Delete storage account
az storage account delete --name mystorageacct123 --resource-group my-rg --yes
```

**Blob storage:**
```bash
# Create a container
az storage container create \
  --name mycontainer \
  --account-name mystorageacct123

# Upload a file
az storage blob upload \
  --account-name mystorageacct123 \
  --container-name mycontainer \
  --name myblob.txt \
  --file ./localfile.txt

# List blobs
az storage blob list \
  --account-name mystorageacct123 \
  --container-name mycontainer \
  --output table

# Download a blob
az storage blob download \
  --account-name mystorageacct123 \
  --container-name mycontainer \
  --name myblob.txt \
  --file ./downloaded.txt
```

### Virtual Machines

```bash
# List VMs
az vm list --resource-group my-rg --output table

# Create a VM (minimal example)
az vm create \
  --resource-group my-rg \
  --name my-vm \
  --image Ubuntu2204 \
  --admin-username azureuser \
  --generate-ssh-keys

# Start / Stop / Deallocate a VM
az vm start --name my-vm --resource-group my-rg
az vm stop --name my-vm --resource-group my-rg       # stops OS, still billed for compute
az vm deallocate --name my-vm --resource-group my-rg  # stops billing for compute

# Show VM status
az vm get-instance-view --name my-vm --resource-group my-rg \
  --query "instanceView.statuses[1].displayStatus"
```

### App Service (Web Apps)

```bash
# Create an App Service Plan
az appservice plan create \
  --name my-plan \
  --resource-group my-rg \
  --sku B1 \
  --is-linux

# Create a web app
az webapp create \
  --name my-webapp-unique123 \
  --resource-group my-rg \
  --plan my-plan \
  --runtime "NODE:18-lts"

# List web apps
az webapp list --resource-group my-rg --output table

# Show app settings
az webapp config appsettings list --name my-webapp-unique123 --resource-group my-rg

# Set app settings
az webapp config appsettings set \
  --name my-webapp-unique123 \
  --resource-group my-rg \
  --settings KEY=VALUE ANOTHER_KEY=VALUE2
```

### Key Vault

```bash
# Create a Key Vault (basic)
az keyvault create \
  --name my-kv-unique123 \
  --resource-group my-rg \
  --location eastus

# Create a Key Vault with production-grade settings
az keyvault create \
  --name my-kv-unique123 \
  --resource-group my-rg \
  --location eastus \
  --enable-rbac-authorization true \    # use RBAC instead of the old access policies model
  --enable-soft-delete true \           # deleted secrets/keys are recoverable for 90 days
  --enable-purge-protection true        # prevents anyone permanently deleting the vault during retention period

# Show Key Vault details
az keyvault show \
  --name my-kv-unique123 \
  --resource-group my-rg

# Get just the Key Vault's resource ID — used as --scope in role assignments
KV_ID=$(az keyvault show \
  --name my-kv-unique123 \
  --resource-group my-rg \
  --query id \
  --output tsv)

# Permanently delete a soft-deleted Key Vault (needed if you want to reuse the same name)
az keyvault purge --name my-kv-unique123

# Set a secret
az keyvault secret set \
  --vault-name my-kv-unique123 \
  --name MySecret \
  --value "super-secret-value"

# Get a secret
az keyvault secret show \
  --vault-name my-kv-unique123 \
  --name MySecret \
  --query value \
  --output tsv

# List secrets
az keyvault secret list --vault-name my-kv-unique123 --output table
```

### Log Analytics Workspace

Log Analytics is a database for logs and metrics. Azure services send their diagnostic logs here, and you query them with KQL in later stages.

```bash
# Create a Log Analytics workspace
az monitor log-analytics workspace create \
  --resource-group my-rg \
  --workspace-name law-platform-dev \
  --location eastus

# List workspaces in a resource group
az monitor log-analytics workspace list \
  --resource-group my-rg \
  --output table

# Get the workspace ID (needed when connecting other resources to it)
az monitor log-analytics workspace show \
  --resource-group my-rg \
  --workspace-name law-platform-dev \
  --query customerId \
  --output tsv
```

### RBAC

```bash
# List role assignments for a resource group
az role assignment list --resource-group my-rg --output table

# List all role assignments for a specific user/SP across all scopes (subscription-wide)
az role assignment list --assignee <object-id> --all --output table

# Assign a role at resource group scope
az role assignment create \
  --assignee user@example.com \
  --role Contributor \
  --scope /subscriptions/<sub-id>/resourceGroups/my-rg

# Assign a role at individual resource scope (narrower — principle of least privilege)
USER_ID=$(az ad signed-in-user show --query id --output tsv)   # get your own object ID
KV_ID=$(az keyvault show --name my-kv-unique123 --resource-group my-rg --query id --output tsv)

az role assignment create \
  --assignee $USER_ID \
  --role "Key Vault Secrets Officer" \    # data-plane role — allows read/write of secrets
  --scope $KV_ID                          # scoped to just this vault, not the whole resource group

# Remove a role assignment
az role assignment delete \
  --assignee user@example.com \
  --role Contributor \
  --resource-group my-rg

# List available built-in roles
az role definition list --output table
az role definition list --name "Contributor"

# Create a custom role from a JSON definition file (@ tells the CLI to read from file)
az role definition create --role-definition @custom-role.json

# Delete a custom role definition
az role definition delete --name "Storage Reader Only"
```

### Entra ID (Azure AD)

```bash
# List users
az ad user list --output table

# Show a specific user
az ad user show --id user@example.com

# Get just the object ID of a user — used when you need to assign a role to them
az ad user show --id user@example.com --query id --output tsv

# Get your own object ID (for assigning roles to yourself)
USER_ID=$(az ad signed-in-user show --query id --output tsv)

# List groups
az ad group list --output table

# List service principals
az ad sp list --output table

# Show current signed-in user
az ad signed-in-user show
```

---

## 4. Output Formats & Querying

### Output formats

By default, output is JSON. You can change it per-command or globally.

```bash
az group list --output json     # default — full structured data
az group list --output table    # human-readable table (fewer fields)
az group list --output tsv      # tab-separated — great for scripting
az group list --output yaml     # YAML format
az group list --output jsonc    # colorized JSON
az group list --output none     # suppress all output (for side-effect commands)
```

Set a default:
```bash
az config set core.output=table
```

### Querying with `--query` (JMESPath)

`--query` uses [JMESPath](https://jmespath.org/) to filter and transform JSON output. This is one of the most powerful CLI features.

**Basic field selection:**
```bash
# Get just the name of each resource group
az group list --query "[].name" --output tsv

# Get name and location
az group list --query "[].{Name:name, Location:location}" --output table
```

**Filtering (where clause):**
```bash
# List only resource groups in eastus
az group list --query "[?location=='eastus'].name" --output tsv

# Find VMs that are running
az vm list --query "[?powerState=='VM running'].name" --output tsv
```

**Single resource — pick a field:**
```bash
az storage account show \
  --name mystorageacct123 \
  --resource-group my-rg \
  --query "primaryEndpoints.blob" \
  --output tsv
```

**Nested access:**
```bash
# Get the first IP config from a NIC
az network nic show \
  --name my-nic \
  --resource-group my-rg \
  --query "ipConfigurations[0].privateIPAddress" \
  --output tsv
```

**Combining with shell variables:**
```bash
BLOB_ENDPOINT=$(az storage account show \
  --name mystorageacct123 \
  --resource-group my-rg \
  --query "primaryEndpoints.blob" \
  --output tsv)

echo "Blob endpoint: $BLOB_ENDPOINT"
```

> **Practice tip:** Start in JSON output to understand the structure, then write your `--query` expression.

---

## 5. Azure Cloud Shell

Azure Cloud Shell is a browser-based shell (Bash or PowerShell) hosted inside Azure — no local install needed.

### Accessing Cloud Shell

- **Portal:** Click the `>_` icon in the top navigation bar
- **Direct URL:** [shell.azure.com](https://shell.azure.com)
- **VS Code extension:** Azure Account extension → "Open Cloud Shell"

### What Cloud Shell gives you

- `az` CLI pre-installed and always up to date
- `kubectl`, `terraform`, `helm`, `git`, `jq`, `python`, `node` all available
- Persistent storage: a 5 GB Azure Files share is mounted at `~/clouddrive`
- Automatically authenticated — no `az login` needed

### When to use Cloud Shell

| Scenario | Cloud Shell | Local CLI |
|----------|-------------|-----------|
| Quick one-off exploration | ✅ Great | Works fine |
| No local install possible | ✅ Great | ❌ |
| Long-running scripts | ⚠️ Times out after 20 min idle | ✅ Better |
| Sensitive environments | ✅ No creds stored locally | ⚠️ Check policy |
| Automation / CI/CD | ❌ Not suitable | ✅ Required |

### Tips

```bash
# Upload files via the toolbar (or drag-and-drop)
# Access your persistent storage
ls ~/clouddrive

# Switch between Bash and PowerShell using the dropdown in the toolbar
```

---

## 6. Navigating the Azure Portal

The [Azure Portal](https://portal.azure.com) is the web UI for managing Azure. It's great for exploration, learning, and one-off tasks — but not for repeatable operations (use CLI/IaC for those).

### Key areas to know

| Area | Purpose |
|------|---------|
| **Home** | Pinned resources, recent items, quick actions |
| **All resources** | Search across every resource in your subscriptions |
| **Resource groups** | Browse by logical grouping |
| **Subscriptions** | Manage billing, IAM, and cost |
| **Azure Active Directory → Microsoft Entra ID** | Users, groups, app registrations, MIs |
| **Monitor** | Metrics, logs, alerts |
| **Cost Management + Billing** | Spending analysis, budgets |
| **Cloud Shell** (`>_` icon) | In-browser CLI |
| **Search bar** (top) | Fastest way to reach any service or resource |

### Useful portal tricks

- **Keyboard shortcut `G` then `B`** — opens All resources (blade shortcuts)
- **Pin frequently used resources** to your dashboard via the pin icon
- **JSON view:** On any resource blade, click "JSON View" to see the raw ARM representation
- **Activity log:** On every resource, see who changed what and when
- **Export template:** Many resources let you export an ARM template from the Portal → useful for learning ARM/Bicep structure
- **Access control (IAM):** Available on every resource/group/subscription — check role assignments here
- **Resource locks:** Under Settings → Locks — important to check before deleting anything

### Portal vs CLI decision guide

| Use Portal when… | Use CLI when… |
|-----------------|---------------|
| Exploring unfamiliar services | Repeating the same action |
| Reading logs and metrics visually | Scripting or automation |
| Learning what options exist | Working in CI/CD pipelines |
| One-time changes | Creating resources consistently |

---

## 7. Azure PowerShell Module (Az)

If you're in a Windows environment or working with teams that prefer PowerShell, the `Az` module is the PowerShell equivalent of the `az` CLI.

### Installation

```powershell
# Install from PowerShell Gallery
Install-Module -Name Az -Repository PSGallery -Force

# Update
Update-Module -Name Az
```

### Authentication

```powershell
# Interactive login
Connect-AzAccount

# List subscriptions
Get-AzSubscription

# Set active subscription
Set-AzContext -SubscriptionId "00000000-0000-0000-0000-000000000000"

# Service principal login
$cred = Get-Credential   # enter appId as username, secret as password
Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant <tenantId>
```

### Common commands

```powershell
# Resource groups
Get-AzResourceGroup
New-AzResourceGroup -Name "my-rg" -Location "eastus"
Remove-AzResourceGroup -Name "my-rg" -Force

# Resources
Get-AzResource -ResourceGroupName "my-rg"

# Storage
New-AzStorageAccount -ResourceGroupName "my-rg" -Name "mystorageacct" `
  -Location "eastus" -SkuName "Standard_LRS"

# VMs
Get-AzVM -ResourceGroupName "my-rg"
Start-AzVM -ResourceGroupName "my-rg" -Name "my-vm"
Stop-AzVM -ResourceGroupName "my-rg" -Name "my-vm" -Force

# Role assignments
Get-AzRoleAssignment -ResourceGroupName "my-rg"
New-AzRoleAssignment -SignInName user@example.com `
  -RoleDefinitionName "Contributor" -ResourceGroupName "my-rg"
```

### Az CLI vs Az PowerShell — when to choose

| Factor | `az` CLI | `Az` PowerShell |
|--------|----------|----------------|
| OS preference | Mac/Linux-first (works on Windows too) | Windows-first (works cross-platform) |
| Output | Text / JSON | PowerShell objects (pipe-able) |
| Scripting style | Bash scripts | PowerShell scripts |
| Team convention | Most cloud teams | Windows/enterprise teams |
| Feature parity | ~99% | ~99% |

Both tools reach the same Azure APIs — choose the one that fits your environment and team.

---

## 8. Cheat Sheet

```bash
# === AUTH ===
az login                                     # interactive browser login
az login --use-device-code                   # device code (headless)
az login --service-principal -u <appId> -p <secret> --tenant <tid>
az account show                              # current subscription
az account list --output table               # all subscriptions
az account set --subscription <name-or-id>  # switch subscription
az logout

# === CONFIG ===
az config set core.output=table
az config set defaults.group=my-rg
az config set defaults.location=eastus

# === RESOURCE GROUPS ===
az group list --output table
az group create -n my-rg -l eastus
az group show -n my-rg
az group delete -n my-rg --yes --no-wait
az group exists -n my-rg

# === RESOURCES ===
az resource list -g my-rg --output table
az resource show -g my-rg -n <name> --resource-type <type>

# === STORAGE ===
az storage account create -n <name> -g my-rg -l eastus --sku Standard_LRS --allow-blob-public-access false
az storage account list -g my-rg --output table
az storage blob upload --account-name <acct> -c <container> -n <blob> -f <local>

# === KEY VAULT ===
az keyvault create -n <name> -g my-rg -l eastus --enable-rbac-authorization true --enable-purge-protection true
az keyvault show -n <name> -g my-rg --query id -o tsv
az keyvault purge -n <name>
az keyvault secret set --vault-name <name> --name <secret> --value <value>
az keyvault secret show --vault-name <name> --name <secret> --query value -o tsv
az keyvault secret list --vault-name <name> --output table

# === LOG ANALYTICS ===
az monitor log-analytics workspace create -g my-rg --workspace-name law-dev -l eastus
az monitor log-analytics workspace show -g my-rg --workspace-name law-dev --query customerId -o tsv

# === RBAC ===
az role assignment list -g my-rg --output table
az role assignment list --assignee <object-id> --all --output table
az role assignment create --assignee <upn-or-id> --role <role> --scope <scope>
az role assignment delete --assignee <upn-or-id> --role <role> -g my-rg
az role definition create --role-definition @custom-role.json
az role definition delete --name "My Custom Role"

# === OUTPUT & QUERY ===
az group list --output json|table|tsv|yaml
az group list --query "[].name" --output tsv
az group list --query "[?location=='eastus'].{Name:name}" --output table
az storage account show -n <acct> -g my-rg --query "primaryEndpoints.blob" -o tsv
```

---

## 9. Practice Exercises

Work through these exercises in order. Each builds on the previous.

### Exercise 1 — First login and exploration

1. Run `az login` and sign in with your Azure account
2. Run `az account list --output table` — note your active subscription
3. Run `az group list --output table` — see what resource groups exist
4. Run `az resource list --output table` — see all resources

### Exercise 2 — Create and explore a resource group

1. Create a resource group: `az group create -n learning-rg -l eastus`
2. Verify it exists: `az group show -n learning-rg`
3. Check the JSON output — note the `id`, `location`, and `tags` fields
4. List resource groups and filter to just the name: `az group list --query "[].name" --output tsv`

### Exercise 3 — Create a storage account and upload a file

1. Create a storage account (name must be globally unique, 3–24 lowercase alphanumeric):
   ```bash
   az storage account create -n learningst$RANDOM -g learning-rg -l eastus --sku Standard_LRS
   ```
2. Save the account name: `ACCT=$(az storage account list -g learning-rg --query "[0].name" -o tsv)`
3. Create a container: `az storage container create -n demo --account-name $ACCT`
4. Create a test file and upload it:
   ```bash
   echo "Hello Azure" > test.txt
   az storage blob upload --account-name $ACCT -c demo -n test.txt -f test.txt
   ```
5. List the blobs: `az storage blob list --account-name $ACCT -c demo --output table`

### Exercise 4 — Practice JMESPath queries

Using `az group list` or `az storage account list`, write queries to:
1. Get just the names of all resource groups
2. Get name + location pairs as a table
3. Filter to only resource groups in `eastus`
4. Get the ID of a specific resource group by name

### Exercise 5 — Clean up

```bash
az group delete -n learning-rg --yes --no-wait
```

Watch the deletion in the Azure Portal under "Notifications" (bell icon).

### Exercise 6 — Cloud Shell

1. Open [shell.azure.com](https://shell.azure.com) or use the Portal's `>_` icon
2. Run `az account show` — confirm you're automatically authenticated
3. Run `ls ~/clouddrive` — see your persistent storage
4. Try `terraform version`, `kubectl version --client`, `helm version`

---

## Key Concepts to Remember

- **Always check your active subscription** before creating or deleting resources (`az account show`)
- **`--query` is JMESPath** — learn it once, use it everywhere
- **`--output tsv`** is your best friend for scripting (no extra formatting)
- **`--no-wait`** lets long-running operations run in the background
- **Service Principals** are for automation; **Managed Identities** are for Azure-hosted workloads
- **Cloud Shell** = zero-setup, always authenticated, great for exploration
- **Portal** = great for learning and debugging, not for repeatable work

---

## Resources

- [Azure CLI docs](https://learn.microsoft.com/en-us/cli/azure/)
- [JMESPath tutorial](https://jmespath.org/tutorial.html)
- [Azure CLI reference A–Z](https://learn.microsoft.com/en-us/cli/azure/reference-index)
- [Az PowerShell module docs](https://learn.microsoft.com/en-us/powershell/azure/)
- [Azure Portal tips](https://learn.microsoft.com/en-us/azure/azure-portal/azure-portal-overview)
- [Microsoft Learn: Control Azure services with the CLI](https://learn.microsoft.com/en-us/training/modules/control-azure-services-with-cli/)
