# Stage 1 — Azure Basics

> **Project milestone:** The Azure Platform Foundation exists — a resource group, storage account, Key Vault, and Log Analytics workspace — created first through the Portal, then reproduced identically using the CLI.

---

## Before you start

You need these before beginning any exercise or project step:

### 1. Azure account
Sign up for a free Azure account at [azure.microsoft.com/free](https://azure.microsoft.com/free). You get $200 credit for 30 days plus a selection of always-free services. All resources in this stage cost nothing or near nothing under the free tier.

### 2. Azure CLI
The Azure CLI (`az`) lets you talk to Azure from the terminal instead of clicking through the Portal.

Install on macOS using Homebrew:
```bash
brew update && brew install azure-cli
```

Verify it installed correctly:
```bash
az --version
# You should see something like: azure-cli 2.x.x
```

### 3. Sign in to your account
```bash
az login
```
A browser window will open. Sign in with your Azure account. Once done, return to the terminal — you should see your subscription information printed as JSON.

To confirm you are signed in and see which subscription you are using:
```bash
az account show
```

You should see output like:
```json
{
  "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "name": "My Azure Subscription",
  "state": "Enabled",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

If you have multiple subscriptions, list them and set the one you want to use:
```bash
az account list --output table
az account set --subscription "My Azure Subscription"
```

---

## What you'll build this stage

| Resource | Name pattern | Purpose |
|----------|-------------|---------|
| Resource Group | `rg-platform-dev` | Container for everything |
| Storage Account | `stplatformdev<suffix>` | Blob storage |
| Key Vault | `kv-platform-dev-<suffix>` | Secret storage |
| Log Analytics Workspace | `law-platform-dev` | Centralized logging |

You will create these **twice**: once through the Portal (to understand every setting), then via the CLI (to see how the same result can be scripted). The CLI version becomes the starting point for Stage 2.

> **Why four resources?** These are the building blocks every real Azure environment starts with. Storage for data, Key Vault for secrets, Log Analytics for monitoring — you will reference all three in later stages when the project grows.

---

## Concepts

### Azure Resource Hierarchy

Think of Azure like a company structure. Everything sits inside something else:

```
Tenant (Entra ID)            ← your company's Azure organization
└── Management Groups        ← departments (e.g. Finance, Engineering)
    └── Subscriptions        ← each team's budget/billing account
        └── Resource Groups  ← projects or environments (e.g. "platform-dev")
            └── Resources    ← the actual services (storage, VMs, databases...)
```

**Why does this hierarchy matter?** Permissions, policies, and costs attach to a level in this tree and **inherit downward**. If you give someone `Reader` access at the Subscription level, they can view everything inside all resource groups in that subscription. If you give it at the Resource Group level, they can only view things in that one group.

**Real-world analogy:**
- Tenant = your company
- Subscription = a company credit card with a spending limit
- Resource Group = a project folder on that credit card
- Resource = something you bought and put in that folder

**Tenant**: Your Entra ID directory. When you sign up for Azure, a tenant is created for you automatically. It has a unique ID (a GUID) and a domain like `yourcompany.onmicrosoft.com`.

**Subscription**: The billing and administrative boundary. All Azure costs roll up to a subscription. You can have multiple subscriptions under one tenant (e.g. one for dev, one for production).

**Resource Group**: A logical container for related resources. There are no costs for the resource group itself — only for what is inside it. Deleting a resource group deletes everything inside it instantly. This makes cleanup easy.

**Resource**: The actual service — a storage account, a Key Vault, a virtual machine, etc.

---

### Entra ID (formerly Azure Active Directory)

Entra ID is Azure's **identity provider**. It is the system that answers the question "who are you?" before anything else happens.

When you log into the Azure Portal, your browser talks to Entra ID first. It checks your username, password, and (if enabled) MFA. Only after Entra ID confirms your identity does Azure let you do anything.

**The four types of identity you need to know:**

| Identity type | What it is | When you use it |
|--------------|------------|----------------|
| **User** | A person with a username and password | You, your colleagues |
| **Group** | A collection of users | Assign permissions once to the group, all members inherit |
| **Service Principal** | A non-human account for apps/scripts | A pipeline that deploys infrastructure, a script that reads secrets |
| **Managed Identity** | Like a Service Principal but Azure manages the credentials for you | An Azure service (like App Service) accessing another Azure service (like Key Vault) — no passwords, no rotation |

**Why groups matter**: Instead of assigning permissions to 10 individual users, create a group, assign permissions to the group, then add users to the group. When someone joins or leaves, you add/remove them from the group — the permissions update automatically.

**Why Managed Identity matters**: If your app needs to read a secret from Key Vault, you could give it a client secret (a password). But then you need to store that password somewhere, rotate it every 90 days, make sure it never leaks. Managed Identity eliminates all of that — Azure handles the credentials behind the scenes.

---

### RBAC — Role-Based Access Control

After Entra ID answers "who are you?", RBAC answers "what are you allowed to do?".

Every RBAC assignment has three parts:

```
WHO (identity)  +  WHAT (role)  +  WHERE (scope)
    ↓                  ↓               ↓
  A user           Contributor    A resource group
```

**Roles** are named sets of permissions. Azure has hundreds of built-in roles. The most important ones:

| Role | What it allows | Common use |
|------|---------------|-----------|
| **Owner** | Everything, including managing who has access | Subscription admins |
| **Contributor** | Create, modify, delete resources — but cannot change who has access | Developers |
| **Reader** | View everything, change nothing | Auditors, read-only access |
| **Storage Blob Data Contributor** | Read and write blob data | Apps that upload/download files |
| **Key Vault Secrets Officer** | Read and write secrets | Apps that need credentials |

> **Important distinction — management plane vs data plane:** `Contributor` lets you manage the Key Vault *resource* (change settings, delete it). But it does **not** let you read the secrets *inside* it. Data-plane access (reading/writing secrets) requires a separate role like `Key Vault Secrets Officer`. This trips up many beginners.

**Scope** controls where the role applies. You can assign at:
- **Management Group** → applies to all subscriptions under it
- **Subscription** → applies to all resource groups in the subscription
- **Resource Group** → applies to all resources in the group
- **Resource** → applies to just that one resource

**Principle of least privilege**: Always assign the *minimum* role needed, at the *narrowest* scope needed. Do not give everyone Owner on the subscription. Give people exactly what they need to do their job.

**RBAC vs Entra ID roles**: These are two separate permission systems.
- RBAC controls what you can do with Azure *resources* (create VMs, read blobs, etc.)
- Entra ID roles control what you can do *inside Entra ID itself* (create users, manage groups, etc.)

A person can be a Global Administrator in Entra ID (can create/delete users) but have zero access to any Azure resources — and vice versa.

---

### Azure Portal

The Portal is the web interface at [portal.azure.com](https://portal.azure.com). It lets you do everything through a graphical interface — no typing required.

**When to use the Portal:**
- Learning: see all the options for a resource type
- Troubleshooting: quickly check a resource's settings or logs
- One-off tasks: something you do once and never need to repeat

**When NOT to use the Portal:**
- Creating production infrastructure — clicking is not repeatable, not auditable, error-prone
- Anything you will do more than once — use the CLI or IaC instead

Navigate the Portal:
- The **left sidebar** has shortcuts to common services
- The **search bar** at the top searches across all resource types
- Every resource has a left sidebar with blades: Overview, Access control (IAM), Activity log, etc.
- The **notification bell** (top right) shows status of recent operations

---

### Azure CLI

The CLI lets you talk to Azure from your terminal. Every Portal action has an equivalent CLI command. The advantage: you can save CLI commands in a script and run them again exactly, or share them with a colleague.

**Basic structure of an `az` command:**
```
az  <service>  <action>  --option value  --option value
     ↓            ↓
  "storage"   "account create"
```

**Output formats** — add `--output` (or `-o`) to change how results are printed:
```bash
az storage account list --output table    # human-readable table
az storage account list --output json     # full JSON (default)
az storage account list --output tsv      # tab-separated, good for scripting
```

**Filtering with `--query`** — uses JMESPath syntax to extract specific fields from the JSON response:
```bash
# Get just name and location of all storage accounts
az storage account list --query "[].{name:name, location:location}" --output table

# Get just the ID of a specific resource (useful in scripts)
az group show --name rg-platform-dev --query id --output tsv
```

The `--output tsv` combined with `--query` is the go-to pattern for capturing a single value into a variable:
```bash
# Capture a value into a Bash variable
RG_ID=$(az group show --name rg-platform-dev --query id --output tsv)
echo $RG_ID
```

**Getting help:** add `--help` to any command to see all options:
```bash
az storage account create --help
az keyvault --help
az keyvault create --help
```

---

## Exercises

Work through these before the project step. They build the specific skills the project step requires.

### Entra ID

**Exercise 1 — Create a test user**

In the Portal: search for **Entra ID** → **Users** → **New user** → **Create new user**.

Fill in:
- User principal name: `testuser@yourdomain.onmicrosoft.com` (replace `yourdomain` with your actual domain shown in the dropdown)
- Display name: `Test User`
- Password: let it auto-generate, copy it

Click **Create**.

Now open a **private browser window** (Incognito in Chrome, Private in Firefox/Safari). Go to `portal.azure.com` and sign in as `testuser@...`. You will be prompted to change the password on first login.

Observe: the test user can see the Portal but has no subscriptions listed. They cannot view any resources. By default, new users in Entra ID have no Azure permissions at all.

**Exercise 2 — Create a group and assign a role**

Back in your main browser (signed in as yourself):

1. In Entra ID → **Groups** → **New group**:
   - Group type: Security
   - Group name: `learn-contributors`
   - Add your test user as a member

2. Go to **Subscriptions** → your subscription → **Resource groups** → pick one.

3. Open the resource group → **Access control (IAM)** → **Add** → **Add role assignment**.
   - Role: `Reader`
   - Assign access to: User, group, or service principal
   - Select: `learn-contributors` (the group)

4. In the private browser window (as test user), navigate to that resource group. The test user can now see it and the resources inside it.

> **What just happened:** You assigned `Reader` to the *group*, not to the user directly. The user inherits the permission by being a member of the group. This is the correct pattern — always assign to groups.

**Exercise 3 — Create a Service Principal**

A Service Principal is an identity for non-human use — scripts, pipelines, applications.

In the Portal: **Entra ID** → **App registrations** → **New registration**.
- Name: `sp-test-learn`
- Leave all other settings as defaults
- Click **Register**

After registration:
- Note the **Application (client) ID** — this is the "username" of the Service Principal
- Note the **Directory (tenant) ID** — your tenant's unique identifier

Now generate a secret (the "password"):
- **Certificates & secrets** → **Client secrets** → **New client secret**
- Description: `test`
- Expires: 90 days
- Click **Add**

**Copy the secret value immediately** — you can only see it once. Store it somewhere temporarily for exercise 9.

> **Why does this matter?** When a pipeline or script needs to authenticate to Azure, it uses a Service Principal. You will use this Service Principal in later exercises.

---

### RBAC

**Exercise 4 — Assign Reader at subscription scope and test it**

In the Portal: **Subscriptions** → your subscription → **Access control (IAM)** → **Add role assignment**.
- Role: `Reader`
- Assign to: your test user (not the group this time — assign directly to the user)

Open the private browser window as the test user. Navigate to **Subscriptions** — the test user can now see the subscription and all resource groups inside it. Try clicking **Create** on anything — it will fail with "You don't have permission to create..."

> This demonstrates scope — `Reader` at the subscription level cascades down to all resource groups and resources inside it.

**Exercise 5 — Assign a data-plane role at resource group scope**

Assign `Storage Blob Data Contributor` to the test user on *one specific resource group* (not the subscription). Navigate to that resource group as the test user and try to upload a blob to a storage account. It should work. Then try the same on a storage account in a *different* resource group — it will fail.

**Exercise 6 — Inspect permissions with Check Access**

On any resource's **Access control (IAM)** tab → **Check Access** button.
- Search for your test user
- See all role assignments and which scope they come from (inherited vs direct)

Now confirm the same via CLI:
```bash
# Get the test user's object ID first
az ad user show --id testuser@yourdomain.onmicrosoft.com --query id --output tsv

# List all their role assignments across all scopes
az role assignment list --assignee <object-id> --all --output table
```

You should see the same assignments in both the Portal and the CLI output.

**Exercise 7 — Create a custom RBAC role**

Custom roles let you define exactly which permissions to grant. Create a JSON file called `custom-role.json`:

```json
{
  "Name": "Storage Reader Only",
  "IsCustom": true,
  "Description": "Can list storage accounts and resource groups, nothing else",
  "Actions": [
    "Microsoft.Storage/storageAccounts/read",
    "Microsoft.Resources/subscriptions/resourceGroups/read"
  ],
  "NotActions": [],
  "AssignableScopes": [
    "/subscriptions/<your-subscription-id>"
  ]
}
```

Replace `<your-subscription-id>` with your actual subscription ID (`az account show --query id -o tsv`).

Create the role:
```bash
az role definition create --role-definition custom-role.json
```

Assign it to the test user on your subscription, then sign in as the test user and verify they can list storage accounts but cannot create or delete anything.

---

### Azure CLI

**Exercise 8 — Basic CLI commands**

```bash
az login
az account show          # see your current subscription
az account list --output table   # see all subscriptions you have access to
```

List all resource groups:
```bash
az group list --output table
```

Expected output (will differ for you):
```
Name               Location    Status
-----------------  ----------  ---------
rg-platform-dev    eastus      Succeeded
NetworkWatcherRG   eastus      Succeeded
```

**Exercise 9 — Authenticate as the Service Principal**

Use the client ID and secret from Exercise 3:

```bash
az login \
  --service-principal \
  --username <application-client-id> \
  --password <client-secret> \
  --tenant <tenant-id>
```

After this, `az account show` will show the Service Principal identity, not your user. Try running `az group list` — what can the SP see? (Nothing, unless you assigned it a role.)

Switch back to your user account:
```bash
az logout
az login
```

**Exercise 10 — Practice `--query`**

```bash
# All resource groups — just name and location
az group list --query "[].{Name:name, Region:location}" --output table

# All storage accounts — name, resource group, and SKU
az storage account list \
  --query "[].{Name:name, RG:resourceGroup, SKU:sku.name}" \
  --output table

# Capture a specific value into a shell variable
VAULT_ID=$(az keyvault show \
  --name "kv-platform-dev-${SUFFIX}" \
  --resource-group rg-platform-dev \
  --query id \
  --output tsv)
echo "Key Vault ID: $VAULT_ID"
```

**Exercise 11 — Azure Cloud Shell**

In the Portal, click the **Cloud Shell** icon (looks like `>_`) in the top toolbar. Choose **Bash** when prompted.

Cloud Shell is a browser-based terminal with the Azure CLI pre-installed and pre-authenticated. You do not need to `az login`. Try running the commands from Exercise 10 directly in Cloud Shell.

This is useful when you are on a machine where you cannot install software, or when you want to quickly run a command without setting up credentials.

---

## Project Step — Build the Foundation

### A — Portal run (understand every setting)

Create each resource in the Portal, reading every tab carefully before clicking Create. The goal is to understand what you are configuring.

**1. Create the Resource Group**

Search for **Resource groups** → **Create**.

- Subscription: your subscription
- Resource group name: `rg-platform-dev`
- Region: choose one geographically close to you (e.g. `East US`, `West Europe`)

Click **Review + create** → **Create**.

After creation, open the resource group. Notice it is empty — it is just a container. The sidebar on the left has options you will explore throughout this course: **Access control (IAM)**, **Activity log**, **Tags**, etc.

**2. Create the Storage Account**

Search for **Storage accounts** → **Create**.

Tab by tab:
- **Basics**: Resource group = `rg-platform-dev`, Name = `stplatformdev` + your initials (e.g. `stplatformdevnn`). Storage account names must be globally unique, 3–24 characters, lowercase and numbers only.
- **Performance**: Standard (not Premium — Premium is for high-throughput scenarios)
- **Redundancy**: `Locally-redundant storage (LRS)` — keeps 3 copies in one datacenter. Good enough for dev.

Click **Advanced** tab:
- Blob public access: **Disabled** — prevents anonymous internet access to blobs
- Blob soft delete: enable, 7 days — lets you recover accidentally deleted blobs

Click **Review + create** → **Create**.

Wait for the deployment to complete (30–60 seconds). Then open the storage account and look around — especially **Containers**, **Access control (IAM)**, and **Activity log**.

**3. Create the Key Vault**

Search for **Key vaults** → **Create**.

- Resource group: `rg-platform-dev`
- Key vault name: `kv-platform-dev-` + your initials. Must be globally unique, 3–24 characters.
- Region: same as your resource group

Click **Access configuration** tab — this is critical:
- **Permission model**: choose **Azure role-based access control (RBAC)**

  > Why RBAC and not Access Policies? Access Policies are the old model — they grant blanket access to a vault and are hard to manage at scale. RBAC lets you assign granular roles at any scope, integrates with the same system you already learned, and follows the principle of least privilege. Always choose RBAC for new Key Vaults.

Click **Recovery** tab:
- Soft delete: enabled (default, cannot be disabled for new vaults)
- Days to retain deleted vaults: 90
- Purge protection: **Enabled** — prevents anyone from permanently deleting the vault or its contents during the retention period, even admins

Click **Review + create** → **Create**.

**4. Create the Log Analytics Workspace**

Search for **Log Analytics workspaces** → **Create**.

- Resource group: `rg-platform-dev`
- Name: `law-platform-dev`
- Region: same region

Leave all other settings as defaults. Click **Review + create** → **Create**.

> **What is Log Analytics?** It is a database for logs and metrics. Azure services can be configured to send their logs here. Later stages will connect resources to this workspace so you can query and monitor everything in one place.

**Check the Activity Log**

After creating all four resources, go to the resource group → **Activity log**. You should see four `Create or Update` events. Click one to expand it — it shows who performed the action, when, the source IP, and the exact operation. This is your audit trail.

---

### B — CLI run (repeat it as code)

Now delete the resource group and recreate everything from the CLI. This demonstrates that the Portal is just a visual wrapper around the same APIs the CLI uses.

**Delete the resource group:**
In the Portal, go to `rg-platform-dev` → **Delete resource group** → type the name to confirm. This deletes all four resources simultaneously.

> Wait for deletion to complete before continuing. You can watch the **Notifications** bell at the top right.

**Create everything via CLI:**

Open your terminal. Set variables first — this makes the commands reusable:

```bash
# Change SUFFIX to your initials or any short unique string (3-5 chars, lowercase)
RG="rg-platform-dev"
LOCATION="eastus"
SUFFIX="nn"    # replace with your initials
```

Create each resource:

```bash
# 1. Resource group
az group create --name $RG --location $LOCATION
```
Expected: `"provisioningState": "Succeeded"`

```bash
# 2. Storage account
az storage account create \
  --name "stplatformdev${SUFFIX}" \
  --resource-group $RG \
  --location $LOCATION \
  --sku Standard_LRS \
  --allow-blob-public-access false
```
Expected: a large JSON blob with `"provisioningState": "Succeeded"` at the end.

```bash
# 3. Key Vault
az keyvault create \
  --name "kv-platform-dev-${SUFFIX}" \
  --resource-group $RG \
  --location $LOCATION \
  --enable-rbac-authorization true \
  --enable-soft-delete true \
  --enable-purge-protection true
```
Expected: JSON with `"provisioningState": "Succeeded"`.

```bash
# 4. Log Analytics Workspace
az monitor log-analytics workspace create \
  --resource-group $RG \
  --workspace-name "law-platform-dev" \
  --location $LOCATION
```
Expected: JSON with `"provisioningState": "Succeeded"`.

Verify all four resources exist:
```bash
az resource list --resource-group $RG --output table
```

You should see four rows — one for each resource.

> **Compare the experience:** Creating via Portal took many tabs and clicks. The CLI took four commands, which can be saved in a text file and re-run by anyone. This is why the CLI matters — repeatability.

---

### C — Assign yourself access to Key Vault

When you created the Key Vault with `--enable-rbac-authorization true`, it switched to RBAC mode. This means even though you are the subscription Owner, you cannot read secrets inside the Key Vault until you explicitly assign yourself a data-plane role.

This is intentional — it separates management-plane access (can I change Key Vault settings?) from data-plane access (can I read secrets from it?).

```bash
# Get your own user object ID
USER_ID=$(az ad signed-in-user show --query id --output tsv)

# Get the Key Vault's full resource ID
KV_ID=$(az keyvault show \
  --name "kv-platform-dev-${SUFFIX}" \
  --resource-group $RG \
  --query id \
  --output tsv)

# Assign Key Vault Secrets Officer so you can read/write secrets
az role assignment create \
  --assignee $USER_ID \
  --role "Key Vault Secrets Officer" \
  --scope $KV_ID
```

Expected: JSON confirming the role assignment was created.

Now test it — store a secret and read it back:
```bash
# Store a secret
az keyvault secret set \
  --vault-name "kv-platform-dev-${SUFFIX}" \
  --name "test-secret" \
  --value "hello-from-stage-1"

# Read it back
az keyvault secret show \
  --vault-name "kv-platform-dev-${SUFFIX}" \
  --name "test-secret" \
  --query value \
  --output tsv
```

Expected output: `hello-from-stage-1`

> **If you get a "Forbidden" error** on the secret commands, wait 1–2 minutes. Role assignments can take a minute to propagate through Azure's authorization system.

---

## Common mistakes and gotchas

- **Storage account name is already taken**: Storage account names are globally unique across all of Azure. If `stplatformdevnn` is taken, add a random number: `stplatformdevnn42`.
- **"You don't have permission" on Key Vault data plane**: Being Owner or Contributor is not enough when using RBAC mode. You need an explicit Key Vault data-plane role (e.g. `Key Vault Secrets Officer`).
- **CLI says "resource group not found"**: If you just deleted the resource group, wait 30 seconds before recreating — deletion is async.
- **`az login` opens browser but doesn't come back**: If the browser flow is stuck, try `az login --use-device-code` — it gives you a code to enter at `microsoft.com/devicelogin` manually.

---

**Next**: Stage 2 — put these CLI commands into proper scripts, commit them to a Git repository, and set up the Azure DevOps project and service connection that pipelines will use in Stage 4.
