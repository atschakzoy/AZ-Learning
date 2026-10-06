# Terraform GitHub Actions Pipeline — Notes

## How a Workflow Runs (Big Picture)

```
Developer opens a PR
        ↓
GitHub sees files changed in terraform-practice/terraform-1/
        ↓
GitHub spins up a fresh Ubuntu machine (the runner)
        ↓
The runner runs your job steps in order:
  1. Download your repo files (checkout)
  2. Log in to Azure (OIDC — no password stored)
  3. Install Terraform
  4. terraform fmt -check
  5. terraform init
  6. terraform validate
  7. terraform plan → output posted as PR comment
        ↓
Reviewer sees exactly what will change in Azure
        ↓
PR approved and merged → a second workflow runs terraform apply
```

---

## Workflow File Structure (Russian Dolls)

```
workflow          ← the whole .yml file
  └── jobs        ← groups of work (can run in parallel)
        └── plan  ← one job (you name it — "plan", "build", anything)
              └── steps   ← the actual commands that run, in order
                    ├── step 1: checkout
                    ├── step 2: azure login
                    ├── step 3: install terraform
                    └── step 4: terraform plan
```

- You **cannot skip** `jobs:` or the job name — GitHub requires them even with one step
- Each job runs on its own fresh machine (`runs-on: ubuntu-latest`)
- Steps inside a job run in order, top to bottom
- When all steps finish, the machine is deleted

**Minimum valid workflow:**
```yaml
name: My Workflow

on:
  push:
    branches: [main]

jobs:
  my-job:
    runs-on: ubuntu-latest
    steps:
      - run: echo "hello"
```

---

## How `id-token: write` Works (OIDC Authentication)

```
Workflow runs on GitHub
        ↓
GitHub generates a short-lived JWT token (valid ~10 min)
The token says: "I am a job in repo YOUR-REPO, on branch main"
        ↓
The azure/login step sends this token to Azure
        ↓
Azure checks: "Do I trust tokens from this repo?"
        ↓
If yes → Azure issues an access token for Terraform to use
        ↓
Token expires automatically — nothing to rotate, nothing to leak
```

**What you need to set up once on the Azure side:**
1. Create an App Registration (service principal)
2. Add a Federated Credential — tells Azure to trust tokens from your GitHub repo
3. Add 3 GitHub Secrets in your repo settings:
   - `AZURE_CLIENT_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`

---


## Step 1 — The Trigger (`on:`)

```yaml
on:
  pull_request:
    branches: [main]
    paths:
      - 'terraform-practice/terraform-1/**'
```

**What it means:**
- `on: pull_request` → this workflow runs when someone opens or updates a PR
- `branches: [main]` → only when the PR targets the `main` branch
- `paths:` → only when files inside `terraform-practice/terraform-1/` changed (no point running Terraform if someone only edited a README)
- `/**` at the end → matches any file inside that folder

**Is it required?** Yes — without `on:`, GitHub doesn't know when to run the workflow.

**Common bugs:**
- `path:` must be `paths:` (plural)
- The folder path must be relative to the repo root, not an absolute path

---

## Step 2 — Permissions (`permissions:`)

```yaml
permissions:
  contents: read
  pull-requests: write
  id-token: write
```

**What it means:**
- `contents: read` → the workflow can read your repo files
- `pull-requests: write` → it can post comments on the PR (used to post the Terraform plan output)
- `id-token: write` → required for OIDC — this is how GitHub authenticates to Azure without storing a password

**Is it required?** Yes — without this, the workflow can't post comments or authenticate to Azure.

**Common bugs:**
- `permission:` must be `permissions:` (plural)
- `content:` must be `contents:` (plural)
- `pull_requests:` must use a hyphen: `pull-requests:`
- Missing `id-token: write` breaks Azure OIDC authentication

---

## Step 3 — Checkout Code

```yaml
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
```

**What it means:**
- `steps:` → the list of things the job runs in order, one by one
- `- name:` → just a label you see in the GitHub Actions UI, you can call it anything
- `uses:` → instead of writing a bash command, you're using a pre-built action from the GitHub Marketplace
- `actions/checkout@v4` → GitHub's official action that downloads your repo code onto the runner machine

**Why it's needed:**
The runner (Ubuntu machine) starts completely empty. Without this step there are no files — Terraform can't find your `.tf` files, nothing works.

**Is it required?** Yes — always the first step in any workflow that works with your code.

---

## Step 4 — Azure Login

```yaml
      - name: Login to Azure
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

**What it means:**
- `uses: azure/login@v2` → pre-built action by Microsoft that handles Azure authentication
- `with:` → inputs you pass to the action (like arguments to a function)
- `${{ secrets.AZURE_CLIENT_ID }}` → reads the secret stored in GitHub repo settings — never visible in logs, GitHub redacts it automatically

**Why no password?**
Because of `id-token: write` in permissions — this uses OIDC. No client secret needed, just the three IDs.

**Is it required?** Yes — without logging in, Terraform has no permission to create or read anything in Azure.

**GitHub Secrets needed (add in repo Settings → Secrets → Actions):**
- `AZURE_CLIENT_ID` — App Registration ID from Azure Entra ID
- `AZURE_TENANT_ID` — found in Azure Entra ID → Overview
- `AZURE_SUBSCRIPTION_ID` — found in Azure → Subscriptions

---

## Step 5 — Install Terraform

```yaml
      - name: Install Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~1.9"
```

**What it means:**
- `uses: hashicorp/setup-terraform@v3` → official action by HashiCorp that installs Terraform on the runner
- `terraform_version: "~1.9"` → install any version of Terraform 1.9.x (the `~` means "this version or newer patch releases")

**Why not an exact version like `1.9.0`?**
Using `~1.9` means you automatically get bug fix updates (1.9.1, 1.9.2 etc.) without changing your workflow file.

**Is it required?** Yes — the Ubuntu runner has no Terraform installed by default. Without this step every `terraform` command fails with "command not found".

---

## Step 6 — Terraform Format Check

```yaml
      - name: Terraform Format Check
        working-directory: terraform-practice/terraform-1
        run: terraform fmt -check -recursive
```

**What it means:**
- `working-directory:` → tells the step to run inside this folder, not the repo root
- `run:` → runs a direct bash command instead of a pre-built action
- `terraform fmt -check` → checks if `.tf` files are correctly formatted but does NOT change them
- `-recursive` → checks all subfolders too
- If any file is not formatted → the step fails and the PR is blocked

**Is it required?** No — but strongly recommended. Enforces consistent formatting on every PR.

**Fix formatting locally before pushing:**
```bash
terraform fmt -recursive
```

---

## Step 7 — Terraform Init

```yaml
      - name: Terraform Init
        working-directory: terraform-practice/terraform-1
        run: terraform init
```

**What it means:**
- `terraform init` prepares Terraform to work — it does three things:
  1. Downloads the Azure provider plugin (`hashicorp/azurerm`)
  2. Connects to your remote state backend (the storage account)
  3. Sets up the `.terraform` folder on the runner

**Why it must run before everything else:**
Without `init`, commands like `validate` and `plan` fail immediately because the provider isn't downloaded yet.

**Is it required?** Yes — always. Every Terraform workflow must start with `init`.

**Note:** If you have a remote backend in your `provider.tf`, the runner connects to your Azure storage account to read the state file — that's why Azure login must come before this step.

---

## Step 8 — Terraform Validate

```yaml
      - name: Terraform Validate
        working-directory: terraform-practice/terraform-1
        run: terraform validate
```

**What it means:**
- Checks your `.tf` files for syntax errors and configuration mistakes
- Does NOT connect to Azure — only checks the code itself
- Catches: missing required variables, wrong resource argument names, invalid types

**Difference from Format Check:**
- `fmt -check` → checks style (spacing, brackets)
- `validate` → checks logic (is the code actually valid Terraform?)

**Is it required?** No — but strongly recommended. Catches mistakes before `plan` runs.

---

## Step 9 — Terraform Plan

```yaml
      - name: Terraform Plan
        id: plan
        working-directory: terraform-practice/terraform-1
        run: terraform plan -var-file="dev.tfvars" -no-color
        continue-on-error: true
```

**What it means:**
- `terraform plan` → connects to Azure and calculates exactly what will change — nothing is created or deleted yet, only a preview
- `-var-file="dev.tfvars"` → uses your variable values from the dev.tfvars file
- `-no-color` → removes color codes so output displays cleanly as a PR comment
- `id: plan` → gives this step a name so the next step can reference its output
- `continue-on-error: true` → if plan fails, the workflow continues to the next step so we can post the error as a PR comment before failing

**Is it required?** Yes — this is the whole point of the PR workflow. The reviewer sees exactly what Terraform will do before approving.

---

---

# Azure DevOps (ADO) Pipeline — Notes

## How ADO Pipelines Differ from GitHub Actions

```
GitHub Actions                    Azure DevOps Pipelines
──────────────────────────────    ──────────────────────────────
on:                               trigger: / pr:
jobs: → job-name: → steps:       pool: → steps: (flat, no job nesting required)
runs-on: ubuntu-latest            vmImage: ubuntu-latest
uses: some-action@v1              task: SomeTask@1
${{ secrets.MY_SECRET }}          $(MY_VARIABLE)
permissions: id-token: write      Service Connection (set in ADO UI)
```

---

## Setting Up a Service Connection (Do This Before Writing the Pipeline)

A Service Connection is how Azure DevOps authenticates to your Azure subscription. It replaces everything you did for GitHub (App Registration + Federated Credentials + GitHub Secrets) — all handled automatically by ADO.

**Steps:**
1. Azure DevOps → your project → **Project Settings** (bottom left)
2. **Pipelines** → **Service connections**
3. **New service connection** → **Azure Resource Manager**
4. Select **Workload Identity Federation (automatic)** — free OIDC, no passwords
5. Choose your subscription, leave resource group empty
6. Name it (e.g. `azure-service-connection`)
7. Check **Grant access permission to all pipelines** → Save

You reference this name in every task that needs Azure access.

---

## Step 1 — The Trigger (`trigger:` / `pr:`)

```yaml
trigger: none

pr:
  branches:
    include:
      - main
  paths:
    include:
      - terraform-practice/terraform-1/**
```

**What it means:**
- `trigger: none` → do not run on direct pushes (equivalent to not having `on: push` in GitHub Actions)
- `pr:` → run when a Pull Request is opened or updated (equivalent to `on: pull_request`)
- `branches: include: [main]` → only when the PR targets the `main` branch
- `paths: include:` → only when files inside `terraform-practice/terraform-1/` changed — no point running Terraform if only a README changed

**Difference from GitHub Actions:**
- GitHub Actions uses one `on:` block for everything
- ADO splits it: `trigger:` controls push events, `pr:` controls pull request events

**Is it required?** Yes — without it ADO doesn't know when to run the pipeline.

---

## Step 2 — The Pool (`pool:`)

```yaml
trigger: none

pr:
  branches:
    include:
      - main
  paths:
    include:
      - terraform-practice/terraform-1/**

pool:
  vmImage: ubuntu-latest
```

**What it means:**
- `pool:` → tells ADO what machine to run the pipeline on
- `vmImage: ubuntu-latest` → use a fresh Ubuntu Linux VM — same machine as GitHub Actions `runs-on: ubuntu-latest`
- The machine starts completely empty and is deleted when the pipeline finishes

**Difference from GitHub Actions:**
- GitHub Actions: `runs-on:` lives inside the job block (nested under `jobs: → plan:`)
- ADO: `pool:` is at the top level — when you have a single job, no `jobs:` nesting is needed

**Is it required?** Yes — without it ADO doesn't know what machine to use.

---

## Step 3 — Checkout Code (`checkout: self`)

```yaml
pool:
  vmImage: ubuntu-latest

steps:
  - checkout: self
```

**What it means:**
- `steps:` → the list of tasks the pipeline runs in order, one by one
- `- checkout: self` → downloads your repo code onto the runner machine
- `self` means "this repo" — the one the pipeline lives in

**Difference from GitHub Actions:**
- GitHub Actions: `uses: actions/checkout@v4` — a third-party action you reference by name
- ADO: `checkout: self` is a built-in keyword, no external action needed

**Is it required?** Yes — always the first step. The runner starts completely empty, without this there are no `.tf` files to work with.

---

## Step 4 — Install Terraform (`TerraformInstaller@1`)

```yaml
steps:
  - checkout: self

  - task: TerraformInstaller@1
    displayName: Install Terraform
    inputs:
      terraformVersion: "~1.9"
```

**What it means:**
- `task:` → uses a pre-built ADO task (equivalent to `uses:` in GitHub Actions)
- `TerraformInstaller@1` → official HashiCorp task that installs Terraform on the runner (`@1` is the version of the task itself)
- `displayName:` → the label you see in the ADO UI (equivalent to `name:` in GitHub Actions)
- `inputs:` → arguments passed to the task (equivalent to `with:` in GitHub Actions)
- `terraformVersion: "~1.9"` → install Terraform 1.9.x, same as the GitHub Actions workflow

**Difference from GitHub Actions:**
- GitHub Actions: `uses: hashicorp/setup-terraform@v3` with `with:`
- ADO: `task: TerraformInstaller@1` with `inputs:`

**Is it required?** Yes — the Ubuntu runner has no Terraform installed. Without this every `terraform` command fails.

---

## Step 5 — Terraform Init (`TerraformTaskV4@4`)

```yaml
  - task: TerraformTaskV4@4
    displayName: Terraform Init
    inputs:
      provider: azurerm
      command: init
      workingDirectory: $(System.DefaultWorkingDirectory)/terraform-practice/terraform-1
      backendServiceArm: azure-service-connection
      backendAzureRmResourceGroupName: rg-tfstate
      backendAzureRmStorageAccountName: sttfstatern001
      backendAzureRmContainerName: tfstate
      backendAzureRmKey: terraform.tfstate
```

**What it means:**
- `task: TerraformTaskV4@4` → official HashiCorp Terraform task for running Terraform commands (`@4` is the task version)
- `command: init` → runs `terraform init`
- `workingDirectory:` → folder containing your `.tf` files. `$(System.DefaultWorkingDirectory)` is a built-in ADO variable pointing to the repo root (equivalent to `working-directory:` in GitHub Actions)
- `backendServiceArm:` → uses your service connection to authenticate to the Azure storage account where Terraform state is stored
- `backendAzureRm*` fields → match exactly what is in your `provider.tf` backend block — resource group, storage account, container, and key

**Difference from GitHub Actions:**
- GitHub Actions: runs `terraform init` as a plain bash command, relies on `ARM_USE_OIDC` env vars for auth
- ADO: the task handles backend authentication automatically using the service connection — no env vars needed

**Is it required?** Yes — downloads the Azure provider plugin and connects to the remote state backend. Must run before validate and plan.

---

## Step 6 — Terraform Validate

```yaml
  - task: TerraformTaskV4@4
    displayName: Terraform Validate
    inputs:
      provider: azurerm
      command: validate
      workingDirectory: $(System.DefaultWorkingDirectory)/terraform-practice/terraform-1
```

**What it means:**
- Same `TerraformTaskV4@4` task as init, but `command: validate` this time
- Checks your `.tf` files for syntax errors and invalid configuration — does NOT connect to Azure
- No backend inputs needed — validate only reads the code, not the state file
- Catches: missing required variables, wrong resource argument names, invalid types

**Difference from GitHub Actions:**
- GitHub Actions: `run: terraform validate` as a plain bash command
- ADO: same task as init, just a different `command:` value — the pattern is consistent across all Terraform commands

**Is it required?** No — but strongly recommended. Catches code mistakes before the more expensive `plan` step runs.

---

## Step 7 — Terraform Plan

```yaml
  - task: TerraformTaskV4@4
    displayName: Terraform Plan
    inputs:
      provider: azurerm
      command: plan
      workingDirectory: $(System.DefaultWorkingDirectory)/terraform-practice/terraform-1
      environmentServiceNameAzureRM: azure-service-connection
      commandOptions: -var-file="dev.tfvars" -no-color
```

**What it means:**
- `command: plan` → runs `terraform plan` — connects to Azure and calculates what will change, nothing is created or deleted yet
- `environmentServiceNameAzureRM:` → uses the service connection to authenticate to Azure for the plan
- `commandOptions:` → extra flags passed directly to the terraform command
  - `-var-file="dev.tfvars"` → use your variable values from dev.tfvars
  - `-no-color` → clean output without color codes

**Important — two different input names for the service connection:**
| Step | Input key |
|---|---|
| Init | `backendServiceArm` |
| Plan | `environmentServiceNameAzureRM` |

Both point to the same `azure-service-connection` — they just serve different purposes (storage access vs Azure resource access).

**Difference from GitHub Actions:**
- GitHub Actions: uses `continue-on-error: true` + a separate script step to post plan output as a PR comment
- ADO: the task output is shown directly in the pipeline UI — no extra script needed

**Is it required?** Yes — this is the whole point of the PR pipeline. Shows exactly what will change before anyone approves the merge.

---

## GitHub Actions — tf-apply.yml (CD Pipeline)

This workflow runs after a PR is merged to main and applies the Terraform changes.

**How it differs from tf-plan.yml:**
| | tf-plan.yml | tf-apply.yml |
|---|---|---|
| Trigger | `pull_request` | `push` to `main` |
| Runs | On every PR | After PR is merged |
| Command | `terraform plan` | `terraform apply` |
| Approval gate | None (read-only) | `environment: production` |
| PR comment | Yes | No |

---

### Step 1 — Trigger and Permissions

```yaml
name: Terraform Apply

on:
  push:
    branches: [main]
    paths:
      - 'terraform-practice/terraform-1/**'

permissions:
  id-token: write
  contents: read
```

- Trigger is `push` to `main` — fires after a PR is merged, not when it is opened.
- No `pull-requests: write` — this workflow doesn't post PR comments.

---

### Step 2 — Job with Environment Gate

```yaml
jobs:
  apply:
    runs-on: ubuntu-latest
    environment: production
    env:
      ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
      ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
      ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      ARM_USE_OIDC: "true"
```

- `environment: production` — pauses the job and waits for a required reviewer to approve in the GitHub UI before continuing.
- The `production` environment must be created in GitHub Settings → Environments with a required reviewer added.
- Same `env:` OIDC variables as tf-plan.yml.

---

### Step 3 — Steps

```yaml
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Login to Azure
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
        working-directory: terraform-practice/terraform-1
        run: terraform init

      - name: Terraform Apply
        working-directory: terraform-practice/terraform-1
        run: terraform apply -var-file="dev.tfvars" -auto-approve
```

- No `fmt -check` or `validate` — those already ran in the plan phase on the PR.
- No `terraform plan` step — goes straight to apply after approval.
- `-auto-approve` — skips Terraform's interactive yes/no prompt. The human approval already happened via the GitHub environment gate.

---

# Azure DevOps (ADO) — Variable Groups

## What is a Variable Group?

A Variable Group is a set of shared variables stored in ADO Library. You define it once and any pipeline can reference it — no copying the same values into every YAML file.

**Where it lives:** ADO → Pipelines → Library → Variable groups

---

## Exercise 9 — terraform-shared Variable Group

Created a variable group named `terraform-shared` with these variables:

| Name | Value |
|---|---|
| `TF_RESOURCE_GROUP` | `rg-tfstate` |
| `TF_STORAGE_ACCOUNT` | `sttfstatern001` |
| `TF_CONTAINER` | `tfstate` |

---

## How to Reference a Variable Group in a Pipeline

```yaml
variables:
  - group: terraform-shared
```

Add this at the top level of the pipeline YAML (same level as `trigger:`, `pool:`).

Then use the variables with `$(VARIABLE_NAME)` — same syntax as built-in ADO variables:

```yaml
commandOptions: -var-file="dev.tfvars"
backendAzureRmResourceGroupName: $(TF_RESOURCE_GROUP)
backendAzureRmStorageAccountName: $(TF_STORAGE_ACCOUNT)
backendAzureRmContainerName: $(TF_CONTAINER)
```

**Why use variable groups instead of hardcoding:**
- Change a value in one place → all pipelines pick it up automatically
- In real projects: link the group to Azure Key Vault so secrets are never copied into ADO at all

---

# ADO Apply Pipeline — tf-ado-prod.yml (Full File Walkthrough)

```yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - terraform-practice/terraform-1/**

pool:
  vmImage: ubuntu-24.04

jobs:
  - deployment: apply
    displayName: Apply to Production
    environment: production
    strategy:
      runOnce:
        deploy:
          steps:
            - checkout: self

            - task: TerraformInstaller@1
              displayName: Install Terraform
              inputs:
                terraformVersion: "1.9.8"

            - task: TerraformTaskV4@4
              displayName: Terraform Init
              inputs:
                provider: azurerm
                command: init
                workingDirectory: $(System.DefaultWorkingDirectory)/terraform-practice/terraform-1
                backendServiceArm: azure-service-connection
                backendAzureRmResourceGroupName: rg-tfstate
                backendAzureRmStorageAccountName: sttfstatern001
                backendAzureRmContainerName: tfstate
                backendAzureRmKey: terraform.tfstate

            - task: TerraformTaskV4@4
              displayName: Terraform Apply
              inputs:
                provider: azurerm
                command: apply
                workingDirectory: $(System.DefaultWorkingDirectory)/terraform-practice/terraform-1
                environmentServiceNameAzureRM: azure-service-connection
                commandOptions: -var-file="dev.tfvars" -auto-approve
```

---

## trigger: (push to main)

```yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - terraform-practice/terraform-1/**
```

- `trigger:` — fires when code is pushed (or merged via PR) to `main`
- Different from the plan pipeline which used `trigger: none` + `pr:`
- Plan runs on PRs. Apply runs after merge to main.
- `paths:` — only when terraform files changed. A README change does not trigger apply.

---

## pool:

```yaml
pool:
  vmImage: ubuntu-24.04
```

- Same machine as the plan pipeline. Fresh Ubuntu VM, deleted after the pipeline finishes.

---

## jobs: → deployment: (the approval gate job)

```yaml
jobs:
  - deployment: apply
    displayName: Apply to Production
    environment: production
    strategy:
      runOnce:
        deploy:
          steps:
```

- `jobs:` — needed because a deployment job has more structure than a flat `steps:` list
- `- deployment: apply` — declares a deployment job named `apply`. A deployment job is the only type that can reference an ADO environment.
- `environment: production` — links to the ADO environment you created with the approval gate. When the pipeline reaches this job, ADO pauses and waits for the required reviewer to approve before continuing.
- `strategy: runOnce: deploy:` — required boilerplate for deployment jobs. Means "run each step once, in deploy mode". Always written exactly like this.
- `steps:` — the actual commands start here, indented under `deploy:`

**Why `deployment:` and not `job:`?**
A regular `job:` cannot use ADO environments with approval gates. Only `deployment:` jobs can. This is the ADO equivalent of `environment: production` in GitHub Actions.

---

## checkout: self

```yaml
- checkout: self
```

- Downloads the repo onto the runner. Required in deployment jobs — without it there are no `.tf` files.
- `self` = this repo (the one the pipeline lives in).

---

## Terraform Init (in apply pipeline)

```yaml
- task: TerraformTaskV4@4
  displayName: Terraform Init
  inputs:
    provider: azurerm
    command: init
    workingDirectory: $(System.DefaultWorkingDirectory)/terraform-practice/terraform-1
    backendServiceArm: azure-service-connection
    backendAzureRmResourceGroupName: rg-tfstate
    backendAzureRmStorageAccountName: sttfstatern001
    backendAzureRmContainerName: tfstate
    backendAzureRmKey: terraform.tfstate
```

- Identical to the plan pipeline init step. Must run before apply to connect to the remote state backend.
- No validate step here — validation already happened on the PR before merge.

---

## Terraform Apply

```yaml
- task: TerraformTaskV4@4
  displayName: Terraform Apply
  inputs:
    provider: azurerm
    command: apply
    workingDirectory: $(System.DefaultWorkingDirectory)/terraform-practice/terraform-1
    environmentServiceNameAzureRM: azure-service-connection
    commandOptions: -var-file="dev.tfvars" -auto-approve
```

- `command: apply` — runs `terraform apply`
- `environmentServiceNameAzureRM:` — service connection for Azure access. Same key as the plan step (different from init's `backendServiceArm:` which is for storage access)
- `-auto-approve` — skips Terraform's interactive yes/no prompt. Safe here because the human already approved via the ADO environment gate above

**Two different service connection keys — why:**

| Step | Input key | Purpose |
|---|---|---|
| Init | `backendServiceArm` | Access the storage account holding state |
| Plan / Apply | `environmentServiceNameAzureRM` | Access Azure to read/create resources |

Both point to the same `azure-service-connection` — they just serve different purposes.

---

# Pipeline Conventions — GitHub Actions vs ADO Side by Side

| Concept | GitHub Actions | ADO |
|---|---|---|
| Push trigger | `on: push: branches: [main]` | `trigger: branches: include: [main]` |
| PR trigger | `on: pull_request:` | `pr: branches: include:` |
| No push trigger | *(omit push block)* | `trigger: none` |
| Machine | `runs-on: ubuntu-latest` | `pool: vmImage: ubuntu-24.04` |
| Job structure | `jobs: → job-name: → steps:` | `jobs: → job:/deployment: → steps:` or flat `steps:` |
| Pre-built action | `uses: some-action@v2` | `task: SomeTask@1` |
| Action inputs | `with:` | `inputs:` |
| Step label | `name:` | `displayName:` |
| Bash command | `run: echo hello` | `script: echo hello` |
| Secret | `${{ secrets.MY_SECRET }}` | `$(MY_SECRET)` (from variable group or pipeline variables) |
| Built-in variable | `${{ github.sha }}` | `$(Build.SourceVersion)` |
| Working directory | `working-directory: path/` | `workingDirectory: $(System.DefaultWorkingDirectory)/path/` |
| Approval gate | `environment: production` on a job | `deployment:` job + `environment: production` |
| Auth to Azure | `permissions: id-token: write` + `azure/login@v2` | Service Connection (set in ADO UI, no YAML needed) |
| Repo path variable | `${{ github.workspace }}` | `$(System.DefaultWorkingDirectory)` |

---

## Key ADO Concepts to Remember

**`trigger:` vs `pr:`**
ADO splits push and PR triggers into two separate top-level keys. GitHub Actions puts everything under one `on:` block.

**Flat steps vs jobs:**
- Plan pipeline: flat `steps:` at top level — simple, one job implied
- Apply pipeline: `jobs: → deployment:` — required because you need an environment for approval

**`task:` vs `script:`**
- `task:` — runs a pre-built ADO task (like a marketplace action). Has `inputs:`
- `script:` — runs raw bash commands directly. Like `run:` in GitHub Actions

**`$(System.DefaultWorkingDirectory)`**
The ADO built-in variable that points to the root of your checked-out repo. Always use this as the base for `workingDirectory:`.

**Service Connection replaces everything in GitHub OIDC setup:**
In GitHub you had to: create App Registration → add federated credential → add 3 secrets → add `permissions: id-token: write`. In ADO, a Service Connection handles all of this automatically — you just reference its name.

**Pipeline registration:**
GitHub Actions auto-discovers any `.yml` file in `.github/workflows/`. ADO does not — you manually register each pipeline file in the ADO UI pointing to its path in the repo.

---

