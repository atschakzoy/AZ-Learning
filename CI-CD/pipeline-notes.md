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
