# Git & DevOps — Stage 2 Learning Reference

---

## How to read the commands in this file

Before diving in, here are the special characters you will see in every command:

| Symbol | Name | What it does |
|--------|------|-------------|
| `#` | Hash / Comment | Everything after `#` is ignored by the shell — it is a note for humans |
| `$` | Dollar sign | Means "use the value of this variable" — `$RG` gives you what's stored in `RG` |
| `\` | Backslash | Continues a long command on the next line — the shell treats it as one command |
| `/` | Forward slash | Separates folders in a path — `project/infra/scripts` means folder inside folder |
| `>` | Redirect (overwrite) | Sends output into a file, creating or overwriting it |
| `>>` | Redirect (append) | Adds output to the end of a file without deleting existing content |
| `*` | Wildcard | Matches anything — `*.sh` means every file ending in `.sh` |
| `-` | Flag prefix | Marks an option for a command — `-m` in `git commit -m "..."` means "message" |
| `--` | Long flag prefix | Same as `-` but full word — `--name`, `--location`, `--output` |
| `<<` | Here-document start | Tells the shell "read input until you see the end marker (EOF)" |
| `|` | Pipe | Sends the output of one command as input to the next |

**Example showing several at once:**
```bash
az keyvault create \        # \ continues on next line
  --name "my-kv" \          # -- is a long flag, \ continues
  --resource-group "$RG" \  # $RG = value of the RG variable
  --output none             # last line — no \ needed
```

---

# Part 1 — Shell Basics

---

## echo

`echo` prints text to the terminal. Simple but used in every script.

```bash
# Print a plain string
echo "Hello, Git"

# Write text into a file — > creates or overwrites
echo "Hello, Git" > hello.txt

# Add text to the end of a file — >> appends, keeps existing content
echo "second line" >> hello.txt

# Print a variable's value — $ means "use the value"
NAME="Reza"
echo $NAME                      # output: Reza

# Mix text and variables
echo "Hello, $NAME"             # output: Hello, Reza

# Useful in scripts to show progress
echo "Creating resource group..."

# Print a blank line (spacing in script output)
echo ""
```

**`>` vs `>>`:**
```bash
echo "line one" > hello.txt     # file contains: line one
echo "line two" > hello.txt     # file now contains only: line two  ← overwrote

echo "line one" > hello.txt     # file contains: line one
echo "line two" >> hello.txt    # file now contains: line one AND line two
```

Rule: first time creating a file use `>` — adding more to an existing file use `>>`

---

## cat

`cat` (short for concatenate) reads a file and prints it. Also the best way to write multi-line files in one command.

```bash
# Print file contents to the terminal
cat hello.txt

# Print multiple files one after another
cat file1.txt file2.txt

# Write multiple lines into a file at once (here-document)
# << 'EOF' means: everything until you see EOF on its own line is the content
# The quotes around 'EOF' stop the shell from expanding $variables inside
cat > hello.txt << 'EOF'
Hello, Git
This is line two
EOF

# Append multiple lines to an existing file
cat >> .gitignore << 'EOF'
.terraform/
*.log
secrets/
EOF

# Combine two files into one
cat file1.txt file2.txt > combined.txt
```

**When to use echo vs cat:**
- Single line → `echo "one line" > file.txt`
- Multiple lines → `cat > file.txt << 'EOF' ... EOF`

---

## mkdir and chmod

```bash
# Create a folder
mkdir scripts

# Create a folder and all parent folders at once
# -p means "create parents too, no error if already exists"
mkdir -p project/infra/scripts

# Make a script executable so you can run it
# +x means "add execute permission"
chmod +x create-foundation.sh

# Make all .sh files in a folder executable at once
chmod +x project/infra/scripts/*.sh

# Run a script
./create-foundation.sh

# Run a script and pass a variable to it
SUFFIX=rn ./create-foundation.sh
```

---

# Part 2 — Git

---

## Setup (first time only)

```bash
# Install or update Git on macOS
brew install git

# Check the version
git --version

# Set your identity — Git tags every commit with this name and email
git config --global user.name "Reza Nazari"
git config --global user.email "you@example.com"

# Check your config
git config --list
```

---

## Starting a repo

```bash
# Option A — start a brand new repo on your machine
mkdir git-practice
cd git-practice
git init                        # creates a hidden .git/ folder — this IS the repo

# Option B — download an existing repo from GitHub
git clone git@github.com:atschakzoy/az-learning-platform.git
cd az-learning-platform
```

---

## The daily cycle

```
Your files  →  git add  →  Staging area  →  git commit  →  Local repo  →  git push  →  GitHub
```

```bash
# Always start here — see what changed
git status

# Stage a specific file
git add hello.txt

# Stage all changed files at once (check status first so you know what's included)
git add .

# Commit what's staged — the message explains WHY you made the change
git commit -m "Add hello.txt"

# Push your commits to GitHub
git push origin main

# Pull the latest from GitHub before starting work
git pull origin main
```

---

## Viewing history

```bash
# Full commit log — press q to quit, Space to scroll down
git log

# One line per commit — easier to read
git log --oneline

# Visual graph showing branches and merges
git log --oneline --graph

# Show exactly what changed in a specific commit
git show a3f9d12               # replace with the 7-character commit ID

# Show what changed in your files since the last commit
git diff

# Show what is staged but not yet committed
git diff --staged
```

---

## Branches

A branch is an independent copy of the code you can work on without touching `main`.

```bash
# See all local branches — * marks the one you are currently on
git branch

# See all branches including ones on GitHub
git branch -a

# Create a new branch AND switch to it in one command
git checkout -b feature/my-work

# Switch to an existing branch
git checkout main

# Delete a branch when work is done (safe — fails if unmerged)
git branch -d feature/my-work

# Force delete — discards the branch even if it has unmerged changes (careful)
git branch -D feature/my-work
```

> Rule: never commit directly to `main`. Always create a feature branch, do the work, open a PR.

---

## Where to push and where to merge

**Pushing — always push to the same branch you are on:**

| You are on | Command |
|------------|---------|
| `feature/my-work` | `git push origin feature/my-work` |
| `main` | `git push origin main` |

**Merging — you merge INTO the branch you are currently on:**

| You want to | Steps |
|-------------|-------|
| Update your feature branch with latest main | `git checkout feature/my-work` → `git merge main` |
| Merge feature into main locally | `git checkout main` → `git merge feature/my-work` |
| Merge via Pull Request (team way) | Push branch → open PR on GitHub → merge there |

**Full solo workflow start to finish:**
```bash
# 1. Start from up-to-date main
git checkout main
git pull origin main

# 2. Create a feature branch
git checkout -b feature/my-work

# 3. Do your work — add and commit as many times as needed
git add .
git commit -m "Describe what you changed"

# 4. Push your branch to GitHub (not main)
git push origin feature/my-work

# 5. Go to GitHub → open a Pull Request → merge it

# 6. After merging, update your local main
git checkout main
git pull origin main

# 7. Delete the feature branch — work is done
git branch -d feature/my-work
```

---

## Merging and rebasing

```bash
# Merge — joins two branches with a merge commit (safe, default choice)
git checkout main
git merge feature/my-work

# Rebase — replays your commits on top of the latest main (cleaner history)
git checkout feature/my-work
git rebase main

# View the result as a graph
git log --oneline --graph
```

**How rebase works:**
```
Before:                          After git rebase main:
main:    A ── B ── E             main:    A ── B ── E
               \                                    \
feature:        C ── D           feature:             C' ── D'
```
Your commits C and D get replayed on top of E as if you started from the latest main.

**When to use which:**
- `merge` — always safe, works for teams, keeps full history
- `rebase` — only on your own private branch before a PR, never on shared branches

> Golden rule: never rebase a branch other people are also using — it rewrites commit IDs and breaks their history.

---

## Resolving merge conflicts

When two people edit the same lines in a file, Git cannot decide which version to keep:

```
<<<<<<< HEAD
Hello from main branch          ← YOUR version (branch you are on)
=======
Hello from feature branch       ← INCOMING version (branch being merged)
>>>>>>> feature/test
```

Fix:
```bash
# 1. Open the file — edit it to keep what you want, delete the conflict markers
# 2. Stage the resolved file
git add hello.txt

# 3. Finish the merge
git commit -m "Resolve merge conflict"
```

---

## .gitignore

Tells Git which files to never track — secrets, auto-generated files, large binaries.

```bash
# Create a .gitignore (here-document writes all lines at once)
cat > .gitignore << 'EOF'
.env                   # exact name — secrets like API keys
*.tfstate              # wildcard — any file ending in .tfstate
*.tfstate.backup
.terraform/            # trailing / means ignore this whole folder
secrets/
*.log
EOF

# Check it worked — ignored files should NOT appear
git status

# If a file was already tracked before you added it to .gitignore,
# Git keeps tracking it. Untrack it without deleting the file:
git rm --cached .env
git rm --cached -r .terraform/   # -r = recursive, for folders
```

**.gitignore pattern rules:**
- `filename` — matches that exact file anywhere in the repo
- `*.ext` — matches any file with that extension
- `folder/` — matches a directory and everything inside it
- `!filename` — un-ignore something (override a previous pattern)

> If a secret is ever committed to Git, rotate it immediately — assume it has been seen.

---

## Remotes

A remote is a saved name pointing to a repo URL hosted somewhere (GitHub, Azure DevOps).

```bash
# See all remotes and their URLs
git remote -v

# Add GitHub as origin using SSH (recommended — no password needed)
git remote add origin git@github.com:atschakzoy/az-learning-platform.git

# Add GitHub as origin using HTTPS
git remote add origin https://github.com/atschakzoy/az-learning-platform.git

# Switch an existing remote from HTTPS to SSH
git remote set-url origin git@github.com:atschakzoy/az-learning-platform.git

# Switch from SSH back to HTTPS
git remote set-url origin https://github.com/atschakzoy/az-learning-platform.git
```

**SSH vs HTTPS:**
- SSH uses your SSH key — set up once, never asked for a password again
- HTTPS asks for credentials — GitHub no longer accepts passwords, needs a token or `gh auth login`
- SSH is simpler once your key is added to GitHub

---

# Part 3 — GitHub

---

## GitHub CLI (gh)

```bash
# Authenticate GitHub CLI — opens browser to log in
gh auth login

# Create an issue from the terminal
gh issue create --title "Add Key Vault setup" --body "Create and assign RBAC"

# List open pull requests
gh pr list

# Create a PR from the current branch
gh pr create --title "Add foundation scripts" --body "Adds create-foundation.sh"

# Check out someone else's PR branch to review it locally
gh pr checkout 3               # 3 = PR number from gh pr list
```

---

## Pull Requests — the team workflow

A Pull Request (PR) is a formal request to merge your branch into `main`. Teammates review it before it merges — this is how teams catch mistakes.

```bash
# 1. Create a feature branch
git checkout -b feature/add-scripts

# 2. Make changes and commit
git add project/
git commit -m "Add foundation scripts"

# 3. Push the branch to GitHub (not main)
git push -u origin feature/add-scripts

# 4. Go to GitHub → Compare & pull request → add description → Create PR
# 5. Review → Approve → Merge

# 6. After merging, update local main
git checkout main
git pull origin main

# 7. Clean up the feature branch
git branch -d feature/add-scripts
```

**Auto-close issues from a PR:**
```bash
git commit -m "Add team info — Closes #1"
# When the PR merges, GitHub automatically closes Issue #1
```

---

## Branch protection (GitHub settings)

Set this up on GitHub: your repo → **Settings → Branches → Add rule**
- Branch name: `main`
- Require a pull request before merging ✓
- Require approvals (1) ✓

After this, direct pushes to `main` are rejected. All changes must go through a PR. This is how production repos work.

---

# Part 4 — Azure DevOps

---

## Daily workflow with ADO

```bash
# ─────────────────────────────────────────────
# FIRST TIME ONLY — set up remotes
# ─────────────────────────────────────────────
git clone git@github.com:atschakzoy/az-learning-platform.git
cd az-learning-platform

# Add ADO as a second remote named ado
git remote add ado git@ssh.dev.azure.com:v3/achakzoypa/platform-learning/platform-learning

# Confirm both remotes
git remote -v


# ─────────────────────────────────────────────
# EVERY DAY — before starting work
# ─────────────────────────────────────────────
git checkout main
git pull origin main            # get the latest from GitHub


# ─────────────────────────────────────────────
# DO YOUR WORK — always on a feature branch
# ─────────────────────────────────────────────
git checkout -b feature/my-work

# edit files...

git status
git add .
git commit -m "What you changed"
git push origin feature/my-work


# ─────────────────────────────────────────────
# PULL REQUEST — merge on GitHub
# ─────────────────────────────────────────────
# GitHub → open PR from feature/my-work → main → merge
git checkout main
git pull origin main
git branch -d feature/my-work


# ─────────────────────────────────────────────
# MIRROR TO ADO — send main to Azure DevOps
# ─────────────────────────────────────────────
git push ado main
```

---

## ADO pipeline (YAML)

A pipeline is an automated script that runs in the cloud when something happens (like a push to main). This one runs `az account show` using a service connection — no password needed.

```yaml
trigger:
  - main                         # runs automatically when main gets a new commit

pool:
  vmImage: ubuntu-latest         # runs on a Microsoft-hosted Linux machine

steps:
  - task: AzureCLI@2
    displayName: 'Show Azure account info'
    inputs:
      azureSubscription: azure-subscription-dev   # name of your service connection
      scriptType: bash
      scriptLocation: inlineScript
      inlineScript: |
        echo "Pipeline is working!"
        az account show --output table
```

---

## ADO authentication — Personal Access Token (PAT)

If SSH is not working with ADO, use a PAT:

1. Go to dev.azure.com → profile icon (top right) → **Personal access tokens**
2. **New Token** → name: `git-access` → Scopes: **Code → Read & write** → Create
3. Copy the token immediately — you won't see it again

```bash
# Push — when prompted for password, paste the PAT token
git push ado main
```

---

# Part 5 — Azure CLI (az)

The `az` command talks directly to Azure. You use it to create, manage, and inspect resources.

Command pattern: `az <service> <operation> [options]`

---

## Installation and updates

```bash
# Install on macOS via Homebrew
brew update && brew install azure-cli

# Verify installation
az version

# Update the CLI
az upgrade
brew upgrade azure-cli     # if installed via Homebrew
```

---

## Configuration defaults

Set defaults so you don't have to repeat `--resource-group` and `--location` on every command:

```bash
# Set output format — table is easiest to read
az config set core.output=table

# Set a default resource group — az group list will use this automatically
az config set defaults.group=rg-platform-dev

# Set a default region
az config set defaults.location=eastus

# See all your current defaults
az config get

# Remove a default
az config unset defaults.group
```

---

## Auth and account

```bash
# Log in — opens a browser tab
az login

# Log in without a browser (for remote/headless environments)
az login --use-device-code
# You'll get a code to enter at https://microsoft.com/devicelogin

# Log in as a Service Principal (used in automation and CI/CD)
az login \
  --service-principal \
  --username <appId> \
  --password <client-secret> \
  --tenant <tenantId>

# Log in using a Managed Identity (inside Azure VMs, App Service, Functions)
az login --identity                          # system-assigned
az login --identity --username <client-id>   # user-assigned

# See which subscription you are currently in
az account show

# Get just the subscription ID (useful in scripts)
az account show --query id --output tsv

# Get just the tenant ID
az account show --query tenantId --output tsv

# List all subscriptions you have access to
az account list --output table
az account list --all --output table        # include disabled subscriptions

# Switch to a different subscription
az account set --subscription "My Subscription Name"
az account set --subscription 00000000-0000-0000-0000-000000000000  # by ID

# Log out
az logout
az account clear    # clears all cached credentials completely
```

> Always check `az account show` before running destructive commands — easy to accidentally delete in the wrong subscription.

---

## Getting help

```bash
# See all sub-commands for a service
az keyvault --help
az storage --help

# See all options for a specific command
az keyvault create --help
az storage account create --help
az group create --help
```

---

## Resource Groups

```bash
# Create a resource group
az group create --name rg-platform-dev --location eastus

# List all resource groups
az group list --output table

# Show details of one resource group
az group show --name rg-platform-dev

# Check if a resource group exists (returns true/false)
az group exists --name rg-platform-dev

# Delete a resource group and everything inside it
# --yes skips the confirmation prompt
# --no-wait returns immediately, deletion runs in background
az group delete --name rg-platform-dev --yes --no-wait

# List all resources inside a group
az resource list --resource-group rg-platform-dev --output table

# List all resources across the whole subscription
az resource list --output table
```

---

## Storage Account

```bash
# Create a storage account
# Name must be globally unique — lowercase letters and numbers only, 3–24 chars
az storage account create \
  --name stplatformdevrn \
  --resource-group rg-platform-dev \
  --location eastus \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-blob-public-access false \    # never allow anonymous internet access
  --output none

# List storage accounts in a resource group
az storage account list --resource-group rg-platform-dev --output table

# Show details of a storage account
az storage account show --name stplatformdevrn --resource-group rg-platform-dev

# Get the connection string (needed for some SDK operations)
az storage account show-connection-string \
  --name stplatformdevrn \
  --resource-group rg-platform-dev

# Delete a storage account
az storage account delete --name stplatformdevrn --resource-group rg-platform-dev --yes
```

**Blob storage — working with files:**
```bash
# Create a container inside the storage account
az storage container create \
  --name mycontainer \
  --account-name stplatformdevrn

# Upload a file
az storage blob upload \
  --account-name stplatformdevrn \
  --container-name mycontainer \
  --name myblob.txt \
  --file ./localfile.txt

# List all blobs in a container
az storage blob list \
  --account-name stplatformdevrn \
  --container-name mycontainer \
  --output table

# Download a blob
az storage blob download \
  --account-name stplatformdevrn \
  --container-name mycontainer \
  --name myblob.txt \
  --file ./downloaded.txt
```

---

## Key Vault

```bash
# Create a Key Vault with production-grade settings
# Name must be globally unique — 3–24 chars
az keyvault create \
  --name kv-platform-dev-rn \
  --resource-group rg-platform-dev \
  --location eastus \
  --enable-rbac-authorization true \    # use RBAC not legacy access policies
  --enable-soft-delete true \           # deleted secrets are recoverable
  --retention-days 7 \                  # keep deleted secrets for 7 days
  --enable-purge-protection true \      # prevents permanent deletion during retention
  --output none

# Show Key Vault details
az keyvault show --name kv-platform-dev-rn --resource-group rg-platform-dev

# Get just the resource ID (used as --scope in role assignments)
KV_ID=$(az keyvault show \
  --name kv-platform-dev-rn \
  --resource-group rg-platform-dev \
  --query id \
  --output tsv)

# Permanently delete a soft-deleted vault (needed to reuse the same name)
az keyvault purge --name kv-platform-dev-rn

# Store a secret
az keyvault secret set \
  --vault-name kv-platform-dev-rn \
  --name "my-secret" \
  --value "hello"

# Read a secret value
az keyvault secret show \
  --vault-name kv-platform-dev-rn \
  --name "my-secret" \
  --query value \
  --output tsv

# List all secrets in a vault
az keyvault secret list --vault-name kv-platform-dev-rn --output table
```

---

## Log Analytics Workspace

```bash
# Create a Log Analytics Workspace
az monitor log-analytics workspace create \
  --resource-group rg-platform-dev \
  --workspace-name law-platform-dev \
  --location eastus

# List all workspaces
az monitor log-analytics workspace list \
  --resource-group rg-platform-dev \
  --output table

# Get the workspace ID (needed when connecting resources to send logs here)
az monitor log-analytics workspace show \
  --resource-group rg-platform-dev \
  --workspace-name law-platform-dev \
  --query customerId \
  --output tsv
```

---

## Entra ID (users, groups, service principals)

```bash
# List all users in the directory
az ad user list --output table

# Show a specific user by email
az ad user show --id user@example.com

# Get just the object ID of a user (needed for role assignments)
az ad user show --id user@example.com --query id --output tsv

# Get YOUR OWN object ID
USER_ID=$(az ad signed-in-user show --query id --output tsv)

# Show your full profile
az ad signed-in-user show

# List all groups
az ad group list --output table

# List all service principals
az ad sp list --output table

# Create a Service Principal with Contributor on the subscription
az ad sp create-for-rbac \
  --name "my-sp-name" \
  --role Contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>
# Output: appId (client ID), password (client secret — copy it, shown only once), tenant
```

---

## RBAC — Role assignments

```bash
# Get your own object ID
USER_ID=$(az ad signed-in-user show --query id --output tsv)

# Get the Key Vault resource ID
KV_ID=$(az keyvault show \
  --name kv-platform-dev-rn \
  --resource-group rg-platform-dev \
  --query id --output tsv)

# Assign a role at resource group scope
az role assignment create \
  --assignee user@example.com \
  --role Contributor \
  --scope /subscriptions/<sub-id>/resourceGroups/rg-platform-dev

# Assign a role at individual resource scope (more secure — least privilege)
az role assignment create \
  --assignee "$USER_ID" \
  --role "Key Vault Secrets Officer" \
  --scope "$KV_ID"

# List all role assignments for a resource group
az role assignment list --resource-group rg-platform-dev --output table

# List all role assignments for a specific user across all scopes
az role assignment list --assignee "$USER_ID" --all --output table

# Remove a role assignment
az role assignment delete \
  --assignee user@example.com \
  --role Contributor \
  --resource-group rg-platform-dev

# List all available built-in roles
az role definition list --output table

# Create a custom role from a JSON file (@ means read from file)
az role definition create --role-definition @custom-role.json

# Delete a custom role
az role definition delete --name "Storage Reader Only"
```

---

## Output formats and JMESPath queries

```bash
# --output controls the format
az group list --output json      # full JSON — see the complete structure
az group list --output table     # human-readable table
az group list --output tsv       # plain text — best for capturing into variables
az group list --output yaml      # YAML format
az group list --output none      # suppress all output (for commands with side effects)

# Set a default so you don't repeat --output every time
az config set core.output=table
```

**--query (JMESPath) — filter and extract fields:**

```bash
# Get just the names of all resource groups
az group list --query "[].name" --output tsv

# Get name and location together
az group list --query "[].{Name:name, Location:location}" --output table

# Filter — only resource groups in eastus
az group list --query "[?location=='eastus'].name" --output tsv

# Get a single field from one resource
az account show --query id --output tsv
az account show --query tenantId --output tsv

# Get a nested field
az storage account show \
  --name stplatformdevrn \
  --resource-group rg-platform-dev \
  --query "primaryEndpoints.blob" \
  --output tsv

# Capture into a variable for use in scripts
SUB_ID=$(az account show --query id --output tsv)
BLOB_URL=$(az storage account show -n stplatformdevrn -g rg-platform-dev \
  --query "primaryEndpoints.blob" --output tsv)

echo "Subscription: $SUB_ID"
echo "Blob URL: $BLOB_URL"
```

> Tip: run the command with `--output json` first to see the full structure, then write your `--query` to extract what you need.

---

# Part 6 — Bash Script Reference

---

## Shebang and safety flags

Every script should start with these two lines:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- `#!/usr/bin/env bash` — tells the OS to run this file with Bash. Must be line 1, nothing before it.
- `set -e` — stop the script immediately if any command fails
- `set -u` — stop if you use a variable that was never set
- `set -o pipefail` — catch failures inside pipes (`cmd1 | cmd2`)

Without these, a script can silently fail halfway through and continue running with broken state.

---

## Variables in scripts

```bash
# Set a variable — no $ when setting
SUFFIX="rn"
RG="rg-platform-dev"

# Use a variable — add $ when using
echo $SUFFIX
az group create --name "$RG"     # always quote variables to handle spaces safely

# Default value — use $VAR if set, otherwise use the default
RG="${RG:-rg-platform-dev}"

# Required variable — fail with a clear error if not set
: "${SUFFIX:?ERROR: Set the SUFFIX variable before running this script}"

# Capture command output into a variable
USER_ID=$(az ad signed-in-user show --query id --output tsv)
```

---

## create-foundation.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

SUFFIX="${SUFFIX:-rn}"           # default to rn if not set
RG="${RG:-rg-platform-dev}"
LOCATION="${LOCATION:-eastus}"

echo "=== Creating Azure Platform Foundation ==="

az group create --name "$RG" --location "$LOCATION" --output none

az storage account create \
  --name "stplatformdev${SUFFIX}" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --allow-blob-public-access false \
  --output none

az keyvault create \
  --name "kv-platform-dev-${SUFFIX}" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --enable-rbac-authorization true \
  --enable-soft-delete true \
  --retention-days 7 \
  --enable-purge-protection true \
  --output none

az monitor log-analytics workspace create \
  --resource-group "$RG" \
  --workspace-name "law-platform-dev" \
  --location "$LOCATION" \
  --output none

echo "=== Done ==="
az resource list --resource-group "$RG" --output table
```

---

## assign-access.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

SUFFIX="${SUFFIX:-rn}"
RG="${RG:-rg-platform-dev}"

# Get current user's Entra ID object ID
USER_ID=$(az ad signed-in-user show --query id --output tsv)

# Get Key Vault full resource ID
KV_ID=$(az keyvault show \
  --name "kv-platform-dev-${SUFFIX}" \
  --resource-group "$RG" \
  --query id \
  --output tsv)

# Assign data-plane role (Contributor alone does NOT grant Key Vault data access)
az role assignment create \
  --assignee "$USER_ID" \
  --role "Key Vault Secrets Officer" \
  --scope "$KV_ID" \
  --output none

# Verify by writing and reading a test secret
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

Make scripts executable:
```bash
chmod +x project/infra/scripts/*.sh
```

---

# Common Mistakes

| Mistake | Fix |
|---------|-----|
| `git push origin main` rejected — "protected branch" | Branch protection is on — push to your feature branch and open a PR |
| File still appears in `git status` after adding to `.gitignore` | Already tracked — run `git rm --cached <filename>` to untrack it |
| "Authentication failed" pushing to GitHub over HTTPS | GitHub doesn't accept passwords — switch remote to SSH or run `gh auth login` |
| "Authentication failed" pushing to ADO | Use a Personal Access Token as the password when prompted |
| Script fails — "SUFFIX: unbound variable" | Set it before running: `SUFFIX=rn ./create-foundation.sh` |
| `git branch -d` fails — "used by worktree" | Switch away first: `git checkout main`, then delete |
| `git merge feature/test` — "not something we can merge" | Branch doesn't exist locally — create it first with `git checkout -b feature/test` |
| Long command in terminal shows `quote>` prompt | You have an unclosed quote — press `Ctrl + C` to cancel and retype |
