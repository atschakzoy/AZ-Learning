# Stage 1 — Azure Basics

> **Project milestone:** The Azure Platform Foundation exists — a resource group, storage account, Key Vault, and Log Analytics workspace — created first through the Portal, then reproduced identically using the CLI.

---

## What you'll build this stage

| Resource | Name pattern | Purpose |
|----------|-------------|---------|
| Resource Group | `rg-platform-dev` | Container for everything |
| Storage Account | `stplatformdev<suffix>` | Blob storage |
| Key Vault | `kv-platform-dev-<suffix>` | Secret storage |
| Log Analytics Workspace | `law-platform-dev` | Centralized logging |

You will create these **twice**: once through the Portal (to understand every setting), then via the CLI (to see how the same result can be scripted). The CLI version becomes the starting point for Stage 2.

---

## Concepts

### Azure Resource Hierarchy

Every Azure resource lives inside a hierarchy that controls billing, governance, and permissions:

```
Tenant (Entra ID)
└── Management Groups
    └── Subscriptions
        └── Resource Groups
            └── Resources
```

- **Tenant**: your Entra ID organization — the root of everything
- **Management Group**: groups subscriptions for policy and RBAC at scale
- **Subscription**: billing boundary and administrative unit
- **Resource Group**: a logical container; deleting it deletes everything inside
- **Resource**: the actual service (storage account, Key Vault, VM, etc.)

Permissions and policies can be applied at any level and inherit downward.

### Entra ID (formerly Azure AD)

Azure's identity provider — it handles authentication for users, applications, and services.

| Identity type | What it is |
|--------------|------------|
| User | A human account that signs in |
| Group | A collection of users — assign permissions to groups, not individuals |
| Service Principal | A non-human identity for apps and automation |
| Managed Identity | A service principal whose credentials Azure manages — no secrets to rotate |

### RBAC — Role-Based Access Control

Access in Azure follows **who** can do **what** on **where**:

- **Who**: a user, group, or service principal
- **What**: a role (a named set of permissions)
- **Where**: a scope (management group → subscription → resource group → resource)

Key built-in roles:

| Role | Can do |
|------|--------|
| Owner | Everything, including manage access |
| Contributor | Create and manage resources; cannot manage access |
| Reader | View only |
| Storage Blob Data Contributor | Read/write blob data (data plane — separate from management plane) |
| Key Vault Secrets Officer | Read/write secrets in Key Vault |

**Principle of least privilege**: always assign the narrowest role at the narrowest scope that gets the job done.

**RBAC vs Entra ID roles**: RBAC controls what you can do with Azure resources. Entra ID roles control what you can do inside Entra ID itself (e.g. create users, manage groups). They are separate systems.

### Azure Portal

The web UI at `portal.azure.com`. Good for exploring what options exist on a service. Not suitable for repeatable or auditable infrastructure — that is what the CLI (now) and IaC (Stage 3) are for.

### Azure CLI

The `az` command-line tool. Anything doable in the Portal can be done with the CLI, and it can be scripted. Key patterns:

```bash
az login                                    # authenticate
az account show                             # current subscription
az group create --name rg-test --location eastus
az storage account list --output table      # table, json, tsv
az storage account list --query "[].{name:name, location:location}" --output table
```

---

## Exercises

Work through these before the project step. They build the specific skills the project step requires.

### Entra ID

1. Create a test user (`testuser@yourdomain.onmicrosoft.com`). Sign in as that user in a private browser window. Observe what they can and cannot access by default.
2. Create a security group `learn-contributors`. Add the test user to it. Assign the group `Reader` on a resource group and confirm the test user inherits the permission.
3. Register an application in Entra ID (**App Registration**). This creates a Service Principal. Note the Application (client) ID and generate a client secret — you will use this in exercise 6.

### RBAC

4. Assign `Reader` to your test user at **subscription scope**. Sign in as that user and confirm they can view resources but cannot create or delete anything.
5. Assign `Storage Blob Data Contributor` to the test user at **resource group scope only**. Verify the permission does not apply outside that group.
6. Use the Portal's **Check Access** blade (on any resource's IAM tab) to inspect effective permissions for your test user. Then confirm the same with:
   ```bash
   az role assignment list --assignee <user-object-id> --all --output table
   ```
7. Create a custom RBAC role (JSON definition) that grants only:
   - `Microsoft.Storage/storageAccounts/read`
   - `Microsoft.Resources/subscriptions/resourceGroups/read`

   Assign it and verify the user can list storage accounts but nothing else.

### Azure CLI

8. Install the Azure CLI. Run:
   ```bash
   az login
   az account show
   az account list --output table
   ```
9. Authenticate as the Service Principal from exercise 3:
   ```bash
   az login --service-principal -u <app-id> -p <secret> --tenant <tenant-id>
   az account show   # confirm SP identity
   az logout
   az login          # switch back to your user
   ```
10. Practice `--query` (JMESPath):
    ```bash
    # List all resource groups with name and location
    az group list --query "[].{name:name, location:location}" --output table

    # Get just the ID of a specific resource group
    az group show --name rg-platform-dev --query id --output tsv
    ```
11. Open **Azure Cloud Shell** in the Portal. Repeat steps 8–10 from there — notice you do not need to `az login` because Cloud Shell is pre-authenticated.

---

## Project Step — Build the Foundation

### A — Portal run (understand the options)

Create each resource in the Portal. Read every tab and setting before clicking **Review + Create**. The goal is understanding what you are configuring, not just clicking through.

1. **Resource Group**: `rg-platform-dev`, choose a region close to you.
2. **Storage Account**: `stplatformdev<your-initials>`.
   - Redundancy: `LRS`
   - Blob public access: **Disabled**
   - Enable soft delete for blobs (7-day retention)
3. **Key Vault**: `kv-platform-dev-<suffix>`.
   - Permission model: **Azure RBAC** (not Access Policies)
   - Soft delete: enabled
   - Purge protection: enabled
4. **Log Analytics Workspace**: `law-platform-dev`. Default settings are fine.

After creating each resource, open its **Activity Log** and find the creation event — note who performed it, when, and from what IP.

### B — CLI run (repeat it as code)

Delete the resource group (this removes all four resources). Then recreate everything from the CLI:

```bash
# Set variables — change SUFFIX to your initials or a short unique string
RG="rg-platform-dev"
LOCATION="eastus"
SUFFIX="abc"

# Resource group
az group create --name $RG --location $LOCATION

# Storage account
az storage account create \
  --name "stplatformdev${SUFFIX}" \
  --resource-group $RG \
  --location $LOCATION \
  --sku Standard_LRS \
  --allow-blob-public-access false

# Key Vault
az keyvault create \
  --name "kv-platform-dev-${SUFFIX}" \
  --resource-group $RG \
  --location $LOCATION \
  --enable-rbac-authorization true \
  --enable-soft-delete true \
  --enable-purge-protection true

# Log Analytics Workspace
az monitor log-analytics workspace create \
  --resource-group $RG \
  --workspace-name "law-platform-dev" \
  --location $LOCATION
```

Verify all four resources appear in the Portal.

### C — Assign yourself access to Key Vault

The Key Vault uses RBAC, so you need an explicit role to read/write secrets (being Owner of the resource group is not enough for data-plane operations):

```bash
# Get your own user object ID
USER_ID=$(az ad signed-in-user show --query id --output tsv)

# Assign Key Vault Secrets Officer
az role assignment create \
  --assignee $USER_ID \
  --role "Key Vault Secrets Officer" \
  --scope $(az keyvault show --name "kv-platform-dev-${SUFFIX}" --resource-group $RG --query id --output tsv)

# Test it — store and retrieve a secret
az keyvault secret set --vault-name "kv-platform-dev-${SUFFIX}" --name "test-secret" --value "hello"
az keyvault secret show --vault-name "kv-platform-dev-${SUFFIX}" --name "test-secret" --query value --output tsv
```

---

**Next**: Stage 2 — put these CLI commands into proper scripts, commit them to Git, and set up the Azure DevOps project and service connection that pipelines will use later.
