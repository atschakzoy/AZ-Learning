# Stage 4 — Scripting & CI/CD for Infrastructure

> **Project milestone:** A GitHub Actions workflow runs `terraform plan` on every PR and `terraform apply` on every merge to `main`. An equivalent Azure Pipelines pipeline does the same. Infrastructure is never deployed manually again.

---

## Before you start

You need everything from Stages 1–3 in place:
- The `az-learning-platform` GitHub repo with the Terraform code from Stage 3
- The remote Terraform state backend (storage account `sttfstate<suffix>`)
- The Azure DevOps organization and service connection from Stage 2

No new tools to install — you already have the Azure CLI, Terraform, and Git.

---

## What you'll build this stage

```
project/
└── infra/
    └── terraform/           ← unchanged from Stage 3
.github/
└── workflows/
    ├── tf-plan.yml          ← runs on every PR touching infra/
    └── tf-apply.yml         ← runs on merge to main, with approval gate
.azuredevops/
└── pipelines/
    └── tf-deploy.yml        ← equivalent Azure Pipelines pipeline
```

---

## Concepts

### What is CI/CD?

**CI (Continuous Integration)**: Every time someone pushes code or opens a PR, an automated system runs checks — format validation, linting, tests, plan previews. The goal is to catch problems before they reach the main branch.

**CD (Continuous Delivery / Deployment)**: Every time code merges to main, it is automatically deployed. No manual steps, no "let me run this on my laptop" — the pipeline does it.

For infrastructure, the pipeline does exactly what you did manually in Stage 3 (`terraform init → plan → apply`), but:
- On a clean, consistent server (not your laptop with its specific setup)
- With audited credentials (not your personal login)
- With a permanent log of every deployment
- With a review step (a PR with the plan output) before anything is applied

**The workflow this stage creates:**
```
Developer pushes a branch
        ↓
PR opened → tf-plan.yml runs
        ↓
  Terraform plan output posted as PR comment
        ↓
Reviewer sees what will change in Azure, approves the PR
        ↓
PR merged to main → tf-apply.yml runs
        ↓
  Approval gate: human reviews and approves the apply
        ↓
  Terraform apply runs — infrastructure changes deployed
```

---

### Bash scripting

Bash scripts are still useful even when you have a pipeline — for local dev helpers, one-time setup tasks, and troubleshooting. Stage 2 introduced Bash basics. This stage covers patterns specific to Azure automation.

**The golden rule — always start scripts with:**
```bash
#!/usr/bin/env bash
set -euo pipefail
```

What each flag does:
- `-e`: exit immediately if any command fails (instead of continuing)
- `-u`: treat unset variables as errors (instead of silently using empty string)
- `-o pipefail`: if a pipe command fails (e.g. `cmd1 | cmd2`), fail even if `cmd2` succeeds

Without `set -euo pipefail`, this script has a silent bug:
```bash
#!/usr/bin/env bash
# Bug: if the first command fails, script continues and uses empty ACCOUNT_ID
ACCOUNT_ID=$(az account show --query notafield -o tsv)
echo "Deploying to: $ACCOUNT_ID"
az resource list --subscription "$ACCOUNT_ID"  # runs with empty string!
```

With `set -euo pipefail`, the script fails on the first command and you see a clear error immediately.

**Required vs optional variables:**
```bash
# Required — script fails immediately with a clear message if not set
: "${SUFFIX:?ERROR: Set SUFFIX environment variable before running this script}"
: "${SUBSCRIPTION_ID:?ERROR: Set SUBSCRIPTION_ID}"

# Optional — has a default value
LOCATION="${LOCATION:-eastus}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
```

**Capturing output into variables:**
```bash
# Get values from Azure commands
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
TENANT_ID=$(az account show --query tenantId --output tsv)
RG_EXISTS=$(az group exists --name rg-platform-dev)

# Use them
echo "Subscription: $SUBSCRIPTION_ID"
echo "Tenant:       $TENANT_ID"
echo "RG exists:    $RG_EXISTS"
```

**Loops over Azure resources:**
```bash
# Get all storage account names in a resource group, one per line
ACCOUNTS=$(az storage account list \
  --resource-group rg-platform-dev \
  --query "[].name" \
  --output tsv)

# Loop over them
while IFS= read -r ACCOUNT; do
  echo "Processing: $ACCOUNT"
  # do something with $ACCOUNT
done <<< "$ACCOUNTS"
```

---

### What is Workload Identity Federation (OIDC)?

When a GitHub Actions pipeline needs to run `terraform apply`, it must authenticate to Azure. The old way was to create a Service Principal with a client secret and store that secret in GitHub Secrets. Problems:
- The secret is a long-lived credential — if it leaks, an attacker can use it indefinitely
- Secrets expire and must be rotated regularly
- Storing any secret in a pipeline is a risk

**Workload Identity Federation** (also called OIDC — OpenID Connect) eliminates the secret entirely:

```
GitHub Actions starts a job
        ↓
GitHub issues a short-lived JWT token (valid for ~10 minutes)
The token says: "This is a job running in repo X on branch Y"
        ↓
The pipeline sends this token to Azure's identity service
        ↓
Azure checks: "Do I trust tokens from repo X, branch Y?"
(This trust relationship was set up in advance — the federated credential)
        ↓
If trusted: Azure issues an access token valid for ~1 hour
        ↓
The pipeline uses this access token to run Terraform
        ↓
All tokens expire — nothing to rotate, nothing to leak
```

No password is ever stored anywhere. The trust is established by configuration, not by a shared secret.

---

### GitHub Actions

GitHub Actions is automation that runs in response to Git events. It lives in `.github/workflows/` as YAML files.

**Anatomy of a workflow file:**
```yaml
name: My Workflow         # displayed in the GitHub UI

on:                       # triggers — what event causes this workflow to run
  pull_request:           # run when a PR is opened or updated
    branches: [main]      # only PRs targeting main
    paths:
      - 'project/infra/terraform/**'  # only when these files changed

permissions:              # what the workflow token can do
  id-token: write         # required for OIDC authentication
  contents: read          # read repo files
  pull-requests: write    # post comments on PRs

jobs:                     # one or more parallel jobs
  plan:                   # job name (arbitrary)
    runs-on: ubuntu-latest  # what machine to use (GitHub-hosted runner)
    steps:                  # sequential steps within this job
      - name: Checkout code
        uses: actions/checkout@v4    # use a community action

      - name: Login to Azure
        uses: azure/login@v2         # another community action
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}  # from GitHub Secrets
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Run a command
        run: echo "Hello from the pipeline"   # raw bash command
```

**Community actions** (`uses: ...`) are reusable pieces of automation published to the GitHub Marketplace. `actions/checkout@v4` checks out your code. `azure/login@v2` handles OIDC authentication to Azure. `hashicorp/setup-terraform@v3` installs Terraform.

**GitHub Secrets** are encrypted variables stored per-repo. They are injected into workflows as `${{ secrets.VARIABLE_NAME }}`. They are never visible in logs — GitHub redacts them.

**GitHub Environments** are deployment targets with optional protection rules. When a job references `environment: production`, GitHub can require a human to approve before the job runs. This is the approval gate.

---

### Azure Pipelines

Azure Pipelines is ADO's equivalent of GitHub Actions. The concepts are identical — triggers, jobs, steps — just with slightly different YAML syntax and ADO-specific tasks.

Key differences from GitHub Actions:
- Uses `task:` blocks instead of `uses:` for community actions
- Service connections (not OIDC secrets) for Azure authentication
- Environments and approval gates are configured in the ADO UI

---

## Exercises

### Bash scripting

**Exercise 1 — List storage accounts with details**

Write `scripts/list-storage-accounts.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID=$(az account show --query id --output tsv)
echo "Listing storage accounts in subscription: $SUBSCRIPTION_ID"
echo ""

az storage account list \
  --query "[].{Name:name, ResourceGroup:resourceGroup, SKU:sku.name, Tier:accessTier}" \
  --output table
```

Run it: `./scripts/list-storage-accounts.sh`

**Exercise 2 — Disable key access on all storage accounts in a resource group**

Write `scripts/disable-key-access.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

: "${RG:?ERROR: Set RG environment variable to the resource group name}"

echo "Disabling storage account key access in resource group: $RG"
echo ""

ACCOUNTS=$(az storage account list \
  --resource-group "$RG" \
  --query "[].name" \
  --output tsv)

if [ -z "$ACCOUNTS" ]; then
  echo "No storage accounts found in $RG"
  exit 0
fi

while IFS= read -r ACCOUNT; do
  echo "Processing: $ACCOUNT"
  az storage account update \
    --name "$ACCOUNT" \
    --resource-group "$RG" \
    --allow-shared-key-access false \
    --output none
  echo "  Key access disabled."
done <<< "$ACCOUNTS"

echo ""
echo "Done."
```

Run it: `RG=rg-platform-dev ./scripts/disable-key-access.sh`

**Exercise 3 — Print all users with subscription-level role assignments**

Write `scripts/list-role-assignments.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID=$(az account show --query id --output tsv)
echo "Role assignments at subscription scope:"
echo "Subscription: $SUBSCRIPTION_ID"
echo ""

ASSIGNMENTS=$(az role assignment list \
  --scope "/subscriptions/$SUBSCRIPTION_ID" \
  --query "[].{Principal:principalName, Role:roleDefinitionName, Type:principalType}" \
  --output table)

if [ -z "$ASSIGNMENTS" ]; then
  echo "No role assignments found at subscription scope."
else
  echo "$ASSIGNMENTS"
fi
```

**Exercise 4 — Experience `set -euo pipefail` in action**

Create `scripts/error-demo.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Step 1: starting"

# This command will fail (group does not exist)
az group show --name rg-does-not-exist-xyz

echo "Step 2: this should not print"
```

Run it and observe it exits after the failing command. Remove `set -euo pipefail` and run again — "Step 2" now prints, demonstrating the silent error problem.

---

### GitHub Actions

**Exercise 5 — First workflow**

Create `.github/workflows/hello.yml`:
```yaml
name: Hello World

on:
  push:
    branches: ['**']    # any branch

jobs:
  hello:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "Hello from GitHub Actions! Branch is $GITHUB_REF_NAME"
      - run: az --version
        # Note: az is pre-installed on ubuntu-latest runners
```

Push this to a branch and watch it run in the GitHub **Actions** tab.

**Exercise 6 — Format check on PRs**

Create `.github/workflows/tf-lint.yml`:
```yaml
name: Terraform Lint

on:
  pull_request:
    paths:
      - 'project/infra/terraform/**'

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~1.9"

      - name: Terraform Format Check
        working-directory: project/infra/terraform
        run: terraform fmt -check -recursive
        # This fails if any .tf file is not correctly formatted.
        # Run "terraform fmt -recursive" locally to fix it.

      - name: Terraform Validate
        working-directory: project/infra/terraform
        run: |
          terraform init -backend=false   # skip backend for validation only
          terraform validate
```

Open a PR with a deliberately mis-formatted `.tf` file and watch the check fail. Fix the formatting (`terraform fmt`) and watch it pass.

**Exercise 7 — GitHub Environment with approval gate**

On GitHub: **Settings** → **Environments** → **New environment** → name it `production`.

Under **Protection rules**: check **Required reviewers** and add yourself.

Create a workflow that uses this environment:
```yaml
name: Protected Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production    # this gates the job behind the approval
    steps:
      - run: echo "This only runs after someone approves in the GitHub UI"
```

Push to main and navigate to **Actions** — you should see the workflow waiting for approval. Click the pending job, review it, and approve. It then runs.

---

### Azure Pipelines

**Exercise 8 — First AzureCLI task**

In ADO: **Pipelines** → **New pipeline** → your ADO repo → **Starter pipeline**.

Replace the YAML:
```yaml
trigger:
  - main

pool:
  vmImage: ubuntu-latest

steps:
  - task: AzureCLI@2
    displayName: 'List resource groups via Azure CLI'
    inputs:
      azureSubscription: azure-subscription-dev   # your service connection name
      scriptType: bash
      scriptLocation: inlineScript
      inlineScript: |
        echo "Authenticated as:"
        az account show --output table
        echo ""
        echo "Resource groups:"
        az group list --output table
```

**Exercise 9 — Variable Groups**

In ADO: **Pipelines** → **Library** → **Variable groups** → **New variable group**.
- Name: `platform-dev-vars`
- Add variables: `SUFFIX` = your initials, `LOCATION` = `eastus`

Reference in a pipeline:
```yaml
variables:
  - group: platform-dev-vars

steps:
  - script: echo "Suffix is $(SUFFIX), Location is $(LOCATION)"
```

**Exercise 10 — ADO Approval Gate**

In ADO: **Pipelines** → **Environments** → **New environment** → name: `production`.

Open the environment → **...** menu → **Approvals and checks** → **Add** → **Approvals**.
Add yourself as an approver.

In a pipeline, use `deployment` job type with the environment:
```yaml
jobs:
  - deployment: TerraformApply
    environment: production   # triggers approval gate
    strategy:
      runOnce:
        deploy:
          steps:
            - script: echo "Approved! Running apply..."
```

---

## Project Step

### A — Set up Workload Identity Federation for GitHub Actions

This is done in two parts: create the App Registration + grant permissions, then add the federated credentials (the trust relationship).

**Step 1 — Create the App Registration and grant permissions:**
```bash
# Create the app
APP_ID=$(az ad app create \
  --display-name "sp-github-platform-learner" \
  --query appId \
  --output tsv)
echo "App (client) ID: $APP_ID"

# Create the service principal
az ad sp create --id $APP_ID --output none

# Grant Contributor on your subscription
SUB_ID=$(az account show --query id --output tsv)
az role assignment create \
  --assignee $APP_ID \
  --role Contributor \
  --scope /subscriptions/$SUB_ID \
  --output none
echo "Granted Contributor on subscription."

# Grant Storage Blob Data Contributor for Terraform remote state
STATE_SA_ID=$(az storage account show \
  --name "sttfstate${SUFFIX}" \
  --resource-group rg-tfstate \
  --query id \
  --output tsv)
az role assignment create \
  --assignee $APP_ID \
  --role "Storage Blob Data Contributor" \
  --scope $STATE_SA_ID \
  --output none
echo "Granted state storage access."

# Print the values you need for GitHub Secrets
TENANT_ID=$(az account show --query tenantId --output tsv)
echo ""
echo "=== Add these to GitHub Secrets ==="
echo "AZURE_CLIENT_ID:       $APP_ID"
echo "AZURE_TENANT_ID:       $TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID: $SUB_ID"
```

**Step 2 — Add federated credentials in the Portal:**

Go to **Entra ID** → **App registrations** → `sp-github-platform-learner` → **Certificates & secrets** → **Federated credentials** → **Add credential**.

Add two credentials:

First (for apply on push to main):
- Federated credential scenario: **GitHub Actions deploying Azure resources**
- Organization: your GitHub username
- Repository: `az-learning-platform`
- Entity type: **Branch**
- Branch name: `main`
- Name: `github-main-branch`

Second (for plan on PRs):
- Same settings but Entity type: **Pull request**
- Name: `github-pull-requests`

**Step 3 — Add GitHub Secrets:**

On GitHub: repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.

Add three secrets:
- `AZURE_CLIENT_ID` — the App ID from Step 1
- `AZURE_TENANT_ID` — the Tenant ID from Step 1
- `AZURE_SUBSCRIPTION_ID` — the Subscription ID from Step 1

**Step 4 — Create the production environment:**

On GitHub: **Settings** → **Environments** → **New environment** → `production`.

Add yourself as a **Required reviewer**.

---

### B — PR plan workflow

Create `.github/workflows/tf-plan.yml`:

```yaml
name: Terraform Plan

on:
  pull_request:
    branches: [main]
    paths:
      - 'project/infra/terraform/**'

permissions:
  id-token: write         # required for OIDC
  contents: read          # read the repo
  pull-requests: write    # post plan output as PR comment

jobs:
  plan:
    name: Terraform Plan
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Login to Azure (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Install Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~1.9"

      - name: Terraform Format Check
        working-directory: project/infra/terraform
        run: terraform fmt -check -recursive

      - name: Terraform Init
        working-directory: project/infra/terraform
        run: terraform init

      - name: Terraform Validate
        working-directory: project/infra/terraform
        run: terraform validate

      - name: Terraform Plan
        id: plan
        working-directory: project/infra/terraform
        run: terraform plan -var-file="dev.tfvars" -no-color
        continue-on-error: true  # capture exit code, don't fail yet

      - name: Post plan as PR comment
        uses: actions/github-script@v7
        with:
          script: |
            const output = `#### Terraform Plan 📋
            \`\`\`
            ${{ steps.plan.outputs.stdout }}
            \`\`\`
            Plan result: ${{ steps.plan.outcome }}`;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            })

      - name: Fail if plan failed
        if: steps.plan.outcome == 'failure'
        run: exit 1
```

> **How to test this:** Open a PR that changes something in `project/infra/terraform/` — for example, add a tag to the resource group. The workflow fires, posts the plan as a comment on the PR, and you can review what will change before approving.

---

### C — Apply on merge workflow

Create `.github/workflows/tf-apply.yml`:

```yaml
name: Terraform Apply

on:
  push:
    branches: [main]
    paths:
      - 'project/infra/terraform/**'

permissions:
  id-token: write
  contents: read

jobs:
  apply:
    name: Terraform Apply
    runs-on: ubuntu-latest
    environment: production    # requires approval before running

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Login to Azure (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Install Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~1.9"

      - name: Terraform Init
        working-directory: project/infra/terraform
        run: terraform init

      - name: Terraform Apply
        working-directory: project/infra/terraform
        run: terraform apply -var-file="dev.tfvars" -auto-approve
```

---

### D — Azure Pipelines equivalent

Create `.azuredevops/pipelines/tf-deploy.yml`:

```yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - project/infra/terraform/**

pr:
  branches:
    include:
      - main
  paths:
    include:
      - project/infra/terraform/**

pool:
  vmImage: ubuntu-latest

variables:
  - group: platform-dev-vars    # variable group from Exercise 9

stages:
  - stage: Plan
    displayName: Terraform Plan
    jobs:
      - job: TerraformPlan
        displayName: Plan
        steps:
          - checkout: self

          - task: AzureCLI@2
            displayName: Terraform Init and Plan
            inputs:
              azureSubscription: azure-subscription-dev
              scriptType: bash
              addSpnToEnvironment: true
              workingDirectory: project/infra/terraform
              scriptLocation: inlineScript
              inlineScript: |
                # Export credentials for Terraform to use
                export ARM_CLIENT_ID="$servicePrincipalId"
                export ARM_OIDC_TOKEN="$idToken"
                export ARM_TENANT_ID="$tenantId"
                export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
                export ARM_USE_OIDC=true

                terraform init
                terraform fmt -check -recursive
                terraform validate
                terraform plan \
                  -var="suffix=$(SUFFIX)" \
                  -var="location=$(LOCATION)"

  - stage: Apply
    displayName: Terraform Apply
    dependsOn: Plan
    condition: |
      and(
        succeeded(),
        eq(variables['Build.SourceBranch'], 'refs/heads/main')
      )
    jobs:
      - deployment: TerraformApply
        displayName: Apply
        environment: production    # approval gate configured in ADO Environments
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self

                - task: AzureCLI@2
                  displayName: Terraform Apply
                  inputs:
                    azureSubscription: azure-subscription-dev
                    scriptType: bash
                    addSpnToEnvironment: true
                    workingDirectory: project/infra/terraform
                    scriptLocation: inlineScript
                    inlineScript: |
                      export ARM_CLIENT_ID="$servicePrincipalId"
                      export ARM_OIDC_TOKEN="$idToken"
                      export ARM_TENANT_ID="$tenantId"
                      export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
                      export ARM_USE_OIDC=true

                      terraform init
                      terraform apply \
                        -var="suffix=$(SUFFIX)" \
                        -var="location=$(LOCATION)" \
                        -auto-approve
```

In ADO: **Pipelines** → **New pipeline** → **Azure Repos Git** → your repo → **Existing Azure Pipelines YAML file** → select `.azuredevops/pipelines/tf-deploy.yml`.

Set up the `production` environment in ADO with an approval gate (Pipelines → Environments → production → Approvals and checks → Approvals).

---

### E — Test the full flow

1. Make a small change to the Terraform code (e.g. add a tag to the resource group):
   ```hcl
   resource "azurerm_resource_group" "main" {
     name     = "rg-platform-${var.environment}"
     location = var.location
     tags = {
       managed-by = "terraform"
       stage      = "4"
     }
   }
   ```

2. Create a branch, commit, push, open a PR.

3. Watch the `tf-plan.yml` workflow fire in the **Actions** tab. After ~1 minute, a comment appears on the PR showing the plan output.

4. Review the plan (the tag will be added). Approve and merge the PR.

5. Watch `tf-apply.yml` fire. It will pause at the **production** environment and wait for your approval. Go to the **Actions** tab, click **Review deployments**, and approve.

6. After approval, `terraform apply` runs and adds the tags.

7. Confirm in the Portal that the resource group now has the tags.

---

## Common mistakes and gotchas

- **"Error: No subscription ID found"**: The `ARM_SUBSCRIPTION_ID` environment variable is missing. The `addSpnToEnvironment: true` setting in the AzureCLI task exposes OIDC token variables — make sure it is set.

- **GitHub Actions OIDC "400 Bad Request" error**: The federated credential was set up incorrectly. Double-check: Organization matches your GitHub username exactly, Repository name matches exactly, Branch name is `main` (not `main/*`).

- **Plan shows no changes when you expect changes**: The PR might not include the files in the `paths` filter. Check that you changed files under `project/infra/terraform/`.

- **`terraform apply -auto-approve` applies without showing a plan**: This is by design — the plan was already reviewed in the PR step. In production, you can save the plan file with `-out=tfplan` and apply exactly that plan to prevent any drift between plan and apply.

- **ADO pipeline fails: "The directory does not exist"**: Check `workingDirectory` — it must match your actual folder structure exactly, case-sensitive.

- **Approval gate never appears**: The `environment: production` in the workflow must match the exact environment name created in GitHub Settings. Case-sensitive.

---

**Next**: Stage 5 — the infrastructure is automated and solid. A simple Azure OpenAI application is introduced as the workload the infrastructure will host.
