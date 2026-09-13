# Stage 4 — Scripting & CI/CD for Infrastructure

> **Project milestone:** A GitHub Actions workflow runs `terraform plan` on every PR and `terraform apply` on every merge to `main`. An equivalent Azure Pipelines pipeline does the same. Infrastructure is never deployed manually again.

---

## What you'll build this stage

```
project/
└── infra/
    └── terraform/               ← unchanged from Stage 3
.github/
└── workflows/
    ├── tf-plan.yml              ← runs on every PR touching infra/
    └── tf-apply.yml             ← runs on merge to main, with approval gate
.azuredevops/
└── pipelines/
    └── tf-deploy.yml            ← equivalent Azure Pipelines pipeline
```

---

## Concepts

### Bash scripting for Azure

Bash scripts wrap CLI commands for tasks that do not belong in a pipeline — local dev helpers, one-time operations, troubleshooting. Key practices:

```bash
#!/usr/bin/env bash
set -euo pipefail          # exit on error, undefined var, or pipe failure

SUFFIX="${SUFFIX:?Must set SUFFIX}"   # fail fast if required var is missing
RG="${RG:-rg-platform-dev}"           # default value if not set

# Command substitution
ACCOUNT_ID=$(az account show --query id --output tsv)
```

`set -euo pipefail` is non-negotiable — without it, a failed command mid-script is silently ignored and the script continues into a broken state.

### CI/CD for infrastructure

The pipeline does exactly what you do locally — `terraform plan` and `terraform apply` — with controlled credentials, a review step, and a permanent audit trail.

Key patterns:

| Pattern | What it does |
|---------|-------------|
| Plan on PR | Runs `terraform plan` and posts the output as a PR comment |
| Apply on merge | Runs `terraform apply` only after a PR is approved and merged to `main` |
| Environment with approval | Gates `apply` on a human approval before it runs |
| Path filter | Only triggers the workflow when files in `project/infra/terraform/` change |

### Workload Identity Federation (OIDC)

The pipeline authenticates to Azure **without a stored client secret**. Instead:
1. The pipeline requests a short-lived OIDC token from GitHub/ADO
2. Azure has been pre-configured to trust tokens from your specific repo/pipeline
3. No secrets to rotate, no secrets in pipeline variables

This is the modern standard. Avoid the old pattern of storing a `CLIENT_SECRET` in GitHub Secrets.

### GitHub Actions

YAML-based automation in `.github/workflows/`. Triggered by Git events.

```yaml
on:
  pull_request:
    paths:
      - 'project/infra/terraform/**'   # only trigger when infra changes

permissions:
  id-token: write      # required for OIDC
  contents: read
  pull-requests: write  # required to post plan as PR comment
```

### Azure Pipelines

ADO's CI/CD engine. Similar to GitHub Actions. Relevant for teams using ADO as the primary platform.

---

## Exercises

### Bash scripting

1. Write a script that lists all storage accounts in your subscription and prints their name, resource group, and access tier:
   ```bash
   az storage account list \
     --query "[].{name:name, rg:resourceGroup, tier:accessTier}" \
     --output table
   ```

2. Write a script that disables the storage account access key for every storage account in a given resource group:
   ```bash
   for ACCOUNT in $(az storage account list --resource-group "$RG" --query "[].name" --output tsv); do
     echo "Disabling key access on $ACCOUNT"
     az storage account update --name "$ACCOUNT" --resource-group "$RG" --allow-shared-key-access false
   done
   ```

3. Write a script that prints all users with role assignments at subscription scope. Handle the case where there are no assignments.

4. Add `set -euo pipefail` to your script. Introduce a deliberately failing command (e.g. `az group show --name doesnotexist`). Confirm the script exits immediately rather than continuing.

### GitHub Actions

5. Create a workflow that triggers on every push and runs `az --version` using the `azure/login` action with OIDC credentials.
6. Add a job that runs `terraform fmt --check` and `terraform validate` on PRs.
7. Create a GitHub **Environment** called `production` with a required reviewer. Add a deployment job that only runs after approval.
8. Post the Terraform plan output as a PR comment using `marocchino/sticky-pull-request-comment` or similar.

### Azure Pipelines

9. Create a YAML pipeline that uses your service connection (from Stage 2) to run `az group list --output table`.
10. Create an ADO **Variable Group** with environment-specific values (`SUFFIX`, `LOCATION`). Reference them in the pipeline with `$(variable-name)`.
11. Add an **Approval gate** in ADO (Environments → Approvals and checks) before the apply stage.

---

## Project Step

### A — Set up Workload Identity Federation for GitHub Actions

```bash
# Create an app registration for GitHub Actions
APP_ID=$(az ad app create --display-name "sp-github-platform" --query appId --output tsv)
SP_ID=$(az ad sp create --id $APP_ID --query id --output tsv)

# Grant Contributor on your subscription
# (use a narrower scope in production)
SUB_ID=$(az account show --query id --output tsv)
az role assignment create \
  --assignee $APP_ID \
  --role Contributor \
  --scope /subscriptions/$SUB_ID

# Grant Storage Blob Data Contributor for Terraform remote state
STATE_SA_ID=$(az storage account show --name "sttfstate${SUFFIX}" \
  --resource-group rg-tfstate --query id --output tsv)
az role assignment create \
  --assignee $APP_ID \
  --role "Storage Blob Data Contributor" \
  --scope $STATE_SA_ID
```

Add federated credentials in the Portal: **App Registration → Certificates & secrets → Federated credentials → Add**.
- Scenario: GitHub Actions
- Organization: your GitHub org/username
- Repository: your repo name
- Entity: Branch → `main` (for apply)
- Add a second for: Pull request (for plan)

Store these as **GitHub Secrets** (not environment variables):
- `AZURE_CLIENT_ID` = the app's client ID
- `AZURE_TENANT_ID` = your tenant ID
- `AZURE_SUBSCRIPTION_ID` = your subscription ID

### B — PR plan workflow

`.github/workflows/tf-plan.yml`:

```yaml
name: Terraform Plan

on:
  pull_request:
    paths:
      - 'project/infra/terraform/**'

permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  plan:
    name: Terraform Plan
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~1.9"

      - name: Terraform Init
        working-directory: project/infra/terraform
        run: terraform init

      - name: Terraform Validate
        working-directory: project/infra/terraform
        run: terraform validate

      - name: Terraform Plan
        working-directory: project/infra/terraform
        run: terraform plan -var-file="dev.tfvars" -out=tfplan
```

### C — Apply on merge workflow

`.github/workflows/tf-apply.yml`:

```yaml
name: Terraform Apply

on:
  push:
    branches:
      - main
    paths:
      - 'project/infra/terraform/**'

permissions:
  id-token: write
  contents: read

jobs:
  apply:
    name: Terraform Apply
    runs-on: ubuntu-latest
    environment: production    # requires manual approval

    steps:
      - uses: actions/checkout@v4

      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~1.9"

      - name: Terraform Init
        working-directory: project/infra/terraform
        run: terraform init

      - name: Terraform Apply
        working-directory: project/infra/terraform
        run: terraform apply -var-file="dev.tfvars" -auto-approve
```

### D — Azure Pipelines equivalent

`.azuredevops/pipelines/tf-deploy.yml`:

```yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - project/infra/terraform/**

pr:
  paths:
    include:
      - project/infra/terraform/**

pool:
  vmImage: ubuntu-latest

variables:
  - group: platform-dev-vars    # ADO variable group with SUFFIX, LOCATION

stages:
  - stage: Plan
    jobs:
      - job: TerraformPlan
        steps:
          - task: AzureCLI@2
            displayName: Terraform Init & Plan
            inputs:
              azureSubscription: your-service-connection-name
              scriptType: bash
              workingDirectory: project/infra/terraform
              scriptLocation: inlineScript
              inlineScript: |
                terraform init
                terraform plan -var="suffix=$(SUFFIX)" -var="location=$(LOCATION)"

  - stage: Apply
    dependsOn: Plan
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: TerraformApply
        environment: production    # approval gate configured here in ADO
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureCLI@2
                  displayName: Terraform Apply
                  inputs:
                    azureSubscription: your-service-connection-name
                    scriptType: bash
                    workingDirectory: project/infra/terraform
                    scriptLocation: inlineScript
                    inlineScript: |
                      terraform init
                      terraform apply -var="suffix=$(SUFFIX)" -var="location=$(LOCATION)" -auto-approve
```

Commit everything via a PR. Test that the plan workflow fires on the PR, and the apply workflow fires after merge with the approval gate holding it.

---

**Next**: Stage 5 — the infrastructure automation is solid. A simple Azure OpenAI application is introduced as the workload the infrastructure will host.
