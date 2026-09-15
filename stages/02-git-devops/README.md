# Stage 2 — Git & Source Control + Azure DevOps

> **Project milestone:** The CLI scripts from Stage 1 live in a Git repository on GitHub, mirrored to Azure Repos. An Azure DevOps project is set up with a service connection to your Azure subscription — ready for pipelines in Stage 4.

---

## Before you start

### 1. Install Git
```bash
# macOS — comes pre-installed, but update it via Homebrew:
brew install git

# Verify:
git --version
# Expected: git version 2.x.x
```

Set your identity (Git tags every commit with this):
```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

### 2. GitHub account
Create a free account at [github.com](https://github.com) if you do not have one. Use the same email as your git config above.

### 3. GitHub CLI (optional but recommended)
```bash
brew install gh
gh auth login    # follow the prompts to authenticate
```

### 4. Azure DevOps account
Go to [dev.azure.com](https://dev.azure.com) and sign in with your Microsoft account (the same one used for Azure). Click **Create new organization** if prompted.

---

## What you'll build this stage

The infrastructure from Stage 1 exists, but the CLI commands that built it live only in your terminal history. If your laptop dies, those commands are gone. If a colleague needs to recreate the environment, they have nothing to refer to.

This stage puts everything under source control. By the end, your repo will contain:

```
project/
└── infra/
    └── scripts/
        ├── create-foundation.sh   ← the CLI commands from Stage 1
        └── assign-access.sh       ← role assignment commands
```

---

## Concepts

### What is Git and why does it matter?

Think of Git as a **save system for code**. Every time you run `git commit`, Git takes a snapshot of your files at that moment. You can look back at any previous snapshot, compare differences between snapshots, and recover anything you accidentally deleted.

Without Git:
- You save files as `script_v2.sh`, `script_v2_final.sh`, `script_final_REAL.sh`
- You email files to colleagues
- If something breaks, you cannot easily go back to what worked

With Git:
- One file, `script.sh` — Git tracks every version
- Everyone works from the same repository
- Every change has an author, a timestamp, and a message explaining why

**The core Git workflow:**

```
Working directory   →   Staging area   →   Local repo   →   Remote repo (GitHub)
   (your files)       (git add .)       (git commit)        (git push)
```

1. You edit a file
2. `git add` — tell Git "I want to include this change in the next snapshot"
3. `git commit` — take the snapshot with a message
4. `git push` — send the snapshot to GitHub so others can see it

---

### Key Git concepts

**Repository (repo)**: A folder that Git is tracking. Contains your files plus a hidden `.git/` folder where Git stores all the history.

**Commit**: A saved snapshot. Each commit has:
- A unique ID (a 40-character SHA hash, usually shown as the first 7 characters, e.g. `a3f9d12`)
- Author and timestamp
- A message describing what changed and why

**Branch**: An independent line of development. Think of the `main` branch as the official version. You create a feature branch to work on something new without touching `main`. When the work is done and reviewed, you merge it back.

```
main:    A ── B ── C ──────────── F
                    \            /
feature/my-work:    D ── E ─────
```

**Pull Request (PR)**: A formal request to merge a branch into `main`. Before merging, teammates review the changes, leave comments, and approve. Only then does it merge. This is how teams catch mistakes before they reach production.

**.gitignore**: A file that tells Git which files to never track. Crucial for:
- Secrets (`.env` files with passwords, API keys)
- Terraform state files (`*.tfstate` — contain sensitive infrastructure details)
- Auto-generated files that don't belong in source control

If a secret ever gets committed to Git, treat it as compromised — someone may have already seen it. Rotate it immediately.

---

### Merge vs Rebase

Both bring changes from one branch into another. They differ in *how* they do it.

**Merge**: Creates a new "merge commit" that joins the two branches. History shows both lines of development.
```
main:    A ── B ──────── M   (M = merge commit)
              \          /
feature:       C ── D ──
```

**Rebase**: Replays the feature branch commits on top of the latest `main`. History looks linear, as if the feature was developed after `main` was updated.
```
Before rebase:          After rebase:
main:    A ── B          main:    A ── B
              \                        \
feature:       C ── D    feature:       C' ── D'  (replayed on top of B)
```

For beginners: **use merge by default**. It is safer (does not rewrite history). Rebase is useful for keeping a clean history but requires more care.

---

### GitHub

GitHub hosts Git repositories in the cloud. Beyond storage, it adds:

**Branch protection rules**: Prevent anyone from pushing directly to `main`. All changes must go through a Pull Request, and the PR needs at least one approval. This is how teams prevent accidental breaking changes.

**Issues**: A built-in task tracker. Create an issue for each piece of work ("Add Key Vault setup", "Fix RBAC assignment"). Reference issues in commit messages (`Closes #5` in a commit message automatically closes Issue #5 when merged).

**GitHub Actions**: Automation that runs when Git events happen (someone pushes, opens a PR, creates a tag). You will use this heavily in Stage 4 to run Terraform automatically.

---

### Azure DevOps (ADO)

Azure DevOps is Microsoft's all-in-one platform for software delivery. Think of it as GitHub's Microsoft equivalent, with deeper Azure integrations.

| Component | What it does |
|-----------|-------------|
| **Azure Repos** | Hosts Git repositories (works exactly like GitHub) |
| **Azure Boards** | Kanban boards, sprints, backlogs for tracking work |
| **Azure Pipelines** | CI/CD automation — like GitHub Actions but from Microsoft |
| **Service Connections** | Saved, secure link from ADO to your Azure subscription |

**Why learn both GitHub and ADO?** Many companies use one or the other (or both). GitHub is more common for open-source and modern teams. ADO is common in enterprises already using Microsoft tooling. Knowing both makes you more versatile.

---

### Service Connections and how pipelines authenticate to Azure

When a pipeline runs `az group create` or `terraform apply`, it needs to authenticate to Azure. But the pipeline runs on a Microsoft-hosted server in the cloud — it cannot do `az login` interactively.

The old way: create a Service Principal, store its client secret as a pipeline variable. Problem: you now have a long-lived password stored in a variable, which is a security risk.

The modern way: **Workload Identity Federation (OIDC)**. Instead of a password:
1. ADO (or GitHub Actions) generates a short-lived cryptographic token for the pipeline run
2. Azure is pre-configured to trust tokens from your specific ADO organization / GitHub repo
3. The pipeline exchanges the token for an Azure access token — no password ever stored

You will set this up in full in Stage 4. In this stage, you just need to create the service connection — ADO will set up the trust relationship automatically.

---

## Exercises

### Git basics

**Exercise 1 — Your first repo**

```bash
mkdir git-practice
cd git-practice
git init
```

Expected: `Initialized empty Git repository in .../git-practice/.git/`

Create a file:
```bash
echo "Hello, Git" > hello.txt
```

Check what Git sees:
```bash
git status
```
Expected: `hello.txt` listed under "Untracked files" — Git knows the file exists but is not tracking it yet.

Stage the file:
```bash
git add hello.txt
git status
```
Expected: `hello.txt` now listed under "Changes to be committed".

Commit it:
```bash
git commit -m "Add hello.txt"
```
Expected: `[main (root-commit) a3f9d12] Add hello.txt`

View the history:
```bash
git log --oneline
```

**Exercise 2 — Push to GitHub**

On GitHub.com: **New repository** → name it `git-practice` → **Create repository** (do not initialize with README).

GitHub shows you instructions. Follow the "push an existing repository" section:
```bash
git remote add origin https://github.com/<your-username>/git-practice.git
git branch -M main
git push -u origin main
```

Refresh GitHub — your `hello.txt` should be there.

**Exercise 3 — Resolve a merge conflict**

Create a feature branch:
```bash
git checkout -b feature/test
```

Edit `hello.txt` on this branch:
```bash
echo "Hello from feature branch" > hello.txt
git add hello.txt
git commit -m "Update from feature branch"
```

Switch back to main and make a conflicting change:
```bash
git checkout main
echo "Hello from main branch" > hello.txt
git add hello.txt
git commit -m "Update from main"
```

Now try to merge the feature branch:
```bash
git merge feature/test
```

Expected: conflict error. Open `hello.txt` — it will look like:
```
<<<<<<< HEAD
Hello from main branch
=======
Hello from feature branch
>>>>>>> feature/test
```

The section between `<<<` and `===` is what is in `main`. Between `===` and `>>>` is what is in the feature branch. Edit the file to the version you want to keep (delete the conflict markers), then:
```bash
git add hello.txt
git commit -m "Resolve merge conflict"
```

**Exercise 4 — Create a .gitignore**

```bash
cat > .gitignore << 'EOF'
.env
*.tfstate
*.tfstate.backup
.terraform/
secrets/
EOF
```

Test it:
```bash
echo "SECRET_KEY=abc123" > .env
echo "test" > my-file.tfstate
mkdir secrets && echo "password" > secrets/db.txt

git status
```

Expected: none of these files appear in `git status` — Git ignores them entirely.

**Exercise 5 — Practice rebasing**

```bash
git checkout -b feature/rebase-test
echo "line from feature" >> hello.txt
git add hello.txt && git commit -m "Feature commit 1"
echo "another line from feature" >> hello.txt
git add hello.txt && git commit -m "Feature commit 2"
```

Add a commit to main:
```bash
git checkout main
echo "line from main after feature branched" >> hello.txt
git add hello.txt && git commit -m "Main commit after branch"
```

Rebase the feature branch on top of the updated main:
```bash
git checkout feature/rebase-test
git rebase main
```

Run `git log --oneline --graph` — the feature commits are now replayed on top of the latest main commit, as if they were written after.

---

### GitHub

**Exercise 6 — Enable branch protection**

On GitHub: your repo → **Settings** → **Branches** → **Add branch protection rule**.
- Branch name pattern: `main`
- Check: **Require a pull request before merging**
- Check: **Require approvals** (set to 1)
- Check: **Require branches to be up to date before merging**

Try pushing directly to main:
```bash
git checkout main
echo "test" >> hello.txt
git add hello.txt && git commit -m "Test direct push"
git push origin main
```

Expected: push rejected with "protected branch" error. Good — this is the guard rail you want in production.

**Exercise 7 — PR with auto-closing issue**

On GitHub, create a new Issue: "Add team info to hello.txt". Note the issue number (e.g. `#1`).

Create a branch, make a change, push, and open a PR:
```bash
git checkout -b feature/add-team-info
echo "Team: Platform Engineering" >> hello.txt
git add hello.txt && git commit -m "Add team info — Closes #1"
git push origin feature/add-team-info
```

On GitHub, open a PR from this branch to `main`. In the PR description write `Closes #1`. When you merge the PR, GitHub automatically closes Issue #1.

**Exercise 8 — GitHub CLI**

```bash
# Create an issue from terminal
gh issue create --title "Test issue from CLI" --body "Created using gh CLI"

# List open PRs
gh pr list

# Check out a PR branch (get PR number from the list)
gh pr checkout <pr-number>
```

---

### Azure DevOps

**Exercise 9 — Create ADO organization and project**

Go to [dev.azure.com](https://dev.azure.com) → **New organization** (or use an existing one).

Inside the organization: **New project**
- Name: `platform-learning`
- Visibility: Private
- Version control: Git

**Exercise 10 — Add Azure Repos as a second remote**

In ADO: **Repos** → **Clone** → copy the HTTPS URL.

In your terminal:
```bash
git remote add ado <paste-ado-url-here>
git push ado main
```

You now have two remotes:
```bash
git remote -v
# origin  https://github.com/... (fetch)
# origin  https://github.com/... (push)
# ado     https://dev.azure.com/... (fetch)
# ado     https://dev.azure.com/... (push)
```

Pushing to `ado` does not affect GitHub and vice versa — they are independent remotes. You explicitly choose which one to push to.

**Exercise 11 — Create a service connection**

In ADO: **Project Settings** (bottom left) → **Service connections** → **New service connection**.
- Type: **Azure Resource Manager**
- Authentication method: **Workload Identity Federation (automatic)** — if this option exists, choose it. If not, choose **Service Principal (automatic)**.
- Subscription: select your Azure subscription from the dropdown
- Resource group: leave blank (grants access to the whole subscription)
- Service connection name: `azure-subscription-dev`
- Check: **Grant access permission to all pipelines**

Click **Save**. ADO creates a Service Principal in your Entra ID and sets up the trust relationship automatically. You can find it in **Entra ID → App registrations** — it will be named something like `platform-learning-azure-subscription-dev-<guid>`.

**Exercise 12 — Create a simple pipeline**

In ADO: **Pipelines** → **New pipeline** → **Azure Repos Git** → select your repo → **Starter pipeline**.

Replace the starter YAML with:
```yaml
trigger:
  - main

pool:
  vmImage: ubuntu-latest

steps:
  - task: AzureCLI@2
    displayName: 'Show Azure account info'
    inputs:
      azureSubscription: azure-subscription-dev
      scriptType: bash
      scriptLocation: inlineScript
      inlineScript: |
        echo "Pipeline is working!"
        az account show --output table
```

Click **Save and run**. Watch the pipeline run — click the running job to see the log. After a minute, you should see `Pipeline is working!` and your subscription details in the output.

---

## Project Step

### A — Create the GitHub repo for the project

On GitHub: **New repository** → name: `az-learning-platform` → Private → **Create repository**.

In your local project folder (where you have the scripts from Stage 1):
```bash
git init
git remote add origin https://github.com/<your-username>/az-learning-platform.git
```

### B — Create the .gitignore

Create `.gitignore` at the repo root:
```
.env
*.tfstate
*.tfstate.backup
.terraform/
.terraform.lock.hcl
secrets/
*.log
```

> **Why `.terraform.lock.hcl`?** Terraform generates this lock file locally. It is sometimes committed (to pin exact provider versions for teams) and sometimes ignored. For this learning project, keep it in the gitignore for simplicity — add it back later when you understand what it does.

### C — Write the scripts

Create the folder structure:
```bash
mkdir -p project/infra/scripts
```

Create `project/infra/scripts/create-foundation.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Usage: SUFFIX=nn ./create-foundation.sh
# Required env vars
: "${SUFFIX:?ERROR: Set the SUFFIX environment variable (e.g. your initials)}"

RG="${RG:-rg-platform-dev}"
LOCATION="${LOCATION:-eastus}"

echo "=== Creating Azure Platform Foundation ==="
echo "Resource group: $RG"
echo "Location:       $LOCATION"
echo "Suffix:         $SUFFIX"
echo ""

echo "--- Creating resource group..."
az group create --name "$RG" --location "$LOCATION" --output none
echo "Done."

echo "--- Creating storage account..."
az storage account create \
  --name "stplatformdev${SUFFIX}" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --allow-blob-public-access false \
  --output none
echo "Done."

echo "--- Creating Key Vault..."
az keyvault create \
  --name "kv-platform-dev-${SUFFIX}" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --enable-rbac-authorization true \
  --enable-soft-delete true \
  --enable-purge-protection true \
  --output none
echo "Done."

echo "--- Creating Log Analytics Workspace..."
az monitor log-analytics workspace create \
  --resource-group "$RG" \
  --workspace-name "law-platform-dev" \
  --location "$LOCATION" \
  --output none
echo "Done."

echo ""
echo "=== Foundation created successfully ==="
az resource list --resource-group "$RG" --output table
```

Create `project/infra/scripts/assign-access.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

: "${SUFFIX:?ERROR: Set SUFFIX}"
RG="${RG:-rg-platform-dev}"

echo "=== Assigning Key Vault access to current user ==="

USER_ID=$(az ad signed-in-user show --query id --output tsv)
echo "User object ID: $USER_ID"

KV_ID=$(az keyvault show \
  --name "kv-platform-dev-${SUFFIX}" \
  --resource-group "$RG" \
  --query id \
  --output tsv)
echo "Key Vault ID: $KV_ID"

echo "--- Assigning Key Vault Secrets Officer..."
az role assignment create \
  --assignee "$USER_ID" \
  --role "Key Vault Secrets Officer" \
  --scope "$KV_ID" \
  --output none
echo "Done."

echo ""
echo "=== Verifying: storing and reading a test secret ==="
az keyvault secret set \
  --vault-name "kv-platform-dev-${SUFFIX}" \
  --name "test-access-check" \
  --value "ok" \
  --output none

VALUE=$(az keyvault secret show \
  --vault-name "kv-platform-dev-${SUFFIX}" \
  --name "test-access-check" \
  --query value \
  --output tsv)

echo "Secret value: $VALUE"
echo "=== Access confirmed ==="
```

Make both scripts executable:
```bash
chmod +x project/infra/scripts/*.sh
```

Run the creation script to verify it works:
```bash
SUFFIX=nn ./project/infra/scripts/create-foundation.sh
```

### D — Commit via a PR (practice the workflow)

```bash
# Create a feature branch — never commit directly to main
git checkout -b feature/add-foundation-scripts

# Stage the files
git add .gitignore project/

# See what will be committed
git status

# Commit
git commit -m "Add foundation infrastructure scripts

- create-foundation.sh: creates RG, storage, Key Vault, Log Analytics
- assign-access.sh: assigns Key Vault Secrets Officer to current user"

# Push the branch
git push -u origin feature/add-foundation-scripts
```

Open a PR on GitHub: **Compare & pull request** → add a description → **Create pull request**.

Since you are working alone, you can merge your own PR. In a real team, a colleague would review it first.

After merging: update your local main:
```bash
git checkout main
git pull origin main
```

### E — Mirror to Azure DevOps

```bash
git remote add ado <your-ado-repo-url>
git push ado main
```

Confirm the repo and scripts appear in ADO **Repos** → **Files**.

---

## Common mistakes and gotchas

- **`git push origin main` rejected after branch protection**: This is correct behaviour. Create a branch, push that, open a PR.
- **Files still appear in `git status` after adding to `.gitignore`**: If the file was already tracked by Git, `.gitignore` does not remove it. Run `git rm --cached <filename>` to untrack it without deleting it.
- **"Repository not found" when pushing to ADO**: ADO uses different authentication from GitHub. When prompted, use your Microsoft account credentials or a Personal Access Token (ADO → User settings → Personal access tokens).
- **Script fails with "SUFFIX: unbound variable"**: You must set the `SUFFIX` variable before running: `SUFFIX=nn ./create-foundation.sh`. The `set -u` flag causes the script to fail fast on undefined variables — this is intentional.
- **`set -euo pipefail` is not at the top**: If you add it after the first command, errors in the commands before it are silently ignored. Always put it on line 2 of every Bash script, right after the shebang.

---

**Next**: Stage 3 — replace these scripts with Bicep templates, then Terraform with remote state. The scripts become the reference but are no longer the source of truth.
