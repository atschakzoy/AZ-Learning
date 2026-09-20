# Git & DevOps — Stage 2 Command Reference

---

## Shell basics used in exercises

### echo

`echo` prints text to the terminal. Simple but used everywhere.

```bash
# Print a plain string
echo "Hello, Git"              # output: Hello, Git

# Write text into a file
# > creates the file if it does not exist, overwrites it if it does
echo "Hello, Git" > hello.txt

# Append to a file — adds to the end without deleting what's already there
echo "second line" >> hello.txt

# Print a variable's value
NAME="Reza"
echo $NAME                     # output: Reza

# Combine text and variables in one line
echo "Hello, $NAME"            # output: Hello, Reza

# Useful for debugging scripts — see what a variable contains at runtime
echo "The resource group is: $RG"

# Print nothing (outputs a blank line — useful for spacing in scripts)
echo ""
```

**`>` vs `>>`:**
- `>` — overwrites the file from scratch every time
- `>>` — appends to the end, keeps existing content

Example:
```bash
echo "line one" > hello.txt    # creates file with "line one"
echo "line two" > hello.txt    # overwrites — now only "line two" is in the file

echo "line one" > hello.txt    # creates file with "line one"
echo "line two" >> hello.txt   # appends — file now has both lines
```

Rule: first time creating a file use `>`, adding more content to an existing file use `>>`

---

### cat

`cat` (short for concatenate) reads a file and prints its contents to the terminal. Also used to create files.

```bash
# Print the contents of a file to the terminal
cat hello.txt

# Print multiple files one after another
cat file1.txt file2.txt

# Create a file by writing directly into it
# > redirects what cat receives as input into the file
cat > hello.txt << 'EOF'
Hello, Git
This is line two
EOF
# Everything between << 'EOF' and EOF is written into hello.txt
# The quotes around 'EOF' prevent the shell from expanding $variables inside

# Combine two files into one new file
cat file1.txt file2.txt > combined.txt

# Append one file's contents to another
cat file2.txt >> file1.txt
```

**When to use which:**
- `echo` — for a single line of text
- `cat` with a here-document (`<< 'EOF'`) — for writing multiple lines at once

---

## Setup

```bash
# Install/update Git on macOS
brew install git

# Confirm version
git --version

# Set your identity — Git tags every commit with this
git config --global user.name "Your Name"
git config --global user.email "you@example.com"

# Install GitHub CLI (optional but useful)
brew install gh

# Authenticate GitHub CLI — opens browser to log in
gh auth login
```

---

## Starting a repo

```bash
# Create a new repo from scratch
mkdir git-practice
cd git-practice
git init                         # creates a hidden .git/ folder inside — this IS the repo

# Clone an existing remote repo to your machine
git clone https://github.com/<username>/<repo>.git
```

---

## The daily cycle — add → commit → push

```bash
# See what changed — always run this first before staging anything
git status

# Stage a specific file
git add hello.txt

# Stage everything in current folder (use with care — check status first)
git add .

# Commit what's staged with a message
git commit -m "Add hello.txt"

# Push commits to GitHub (origin = the GitHub remote, main = branch name)
git push origin main

# Pull latest changes from GitHub before you start working
git pull origin main
```

---

## Viewing history

```bash
# Full log (press q to quit, Space to scroll down)
git log

# One line per commit — much easier to read
git log --oneline

# Graph showing branches and merges
git log --oneline --graph

# Show what changed in a specific commit
git show a3f9d12                 # replace with the commit SHA you want to inspect

# Show what changed between working directory and last commit
git diff

# Show what's staged but not yet committed
git diff --staged
```

---

## Branches

```bash
# See all local branches (* marks the one you are currently on)
git branch

# See all branches including remote ones
git branch -a

# Create a new branch
git checkout -b feature/my-work  # create AND switch to it in one command

# Switch to an existing branch
git checkout main

# Delete a branch (safe — fails if it has unmerged commits)
git branch -d feature/my-work

# Force delete (discards the branch even if unmerged — careful)
git branch -D feature/my-work
```

> Rule: never commit directly to `main`. Create a feature branch, do the work, open a PR.

---

## Where to push, where to merge — quick reference

**Pushing:**

| You are on | You push to | Command |
|------------|-------------|---------|
| `feature/my-work` | `origin feature/my-work` | `git push origin feature/my-work` |
| `main` | `origin main` | `git push origin main` |

Always push to the **same branch you are on**. Never push your feature branch to `origin main`.

**Merging:**

| You want to | You do |
|-------------|--------|
| Bring main's latest changes into your feature branch | `git checkout feature/my-work` then `git merge main` |
| Merge your feature branch into main (locally) | `git checkout main` then `git merge feature/my-work` |
| Merge via Pull Request (the team way) | Push your branch → open PR on GitHub → merge there |

> You merge **into the branch you are currently on**. So always check which branch you are on with `git branch` before merging.

**The full solo workflow from start to finish:**

```bash
# 1. Start from an up-to-date main
git checkout main
git pull origin main

# 2. Create your feature branch
git checkout -b feature/my-work

# 3. Do your work — add, commit as many times as needed
git add .
git commit -m "My changes"

# 4. Push your branch to GitHub (not main)
git push origin feature/my-work

# 5. Open a Pull Request on GitHub → merge it there

# 6. After PR is merged, come back to main and pull the merged result
git checkout main
git pull origin main

# 7. Delete the feature branch — work is done
git branch -d feature/my-work
```

---

## Merging and rebasing

```bash
# Merge a feature branch into main
git checkout main
git merge feature/my-work        # joins the two branches with a merge commit

# Rebase (replay feature commits on top of latest main — makes history linear)
git checkout feature/rebase-test
git rebase main                  # replays your commits as if you started from the latest main

# View graph after rebase to see the linear history
git log --oneline --graph
```

**How rebase works visually:**

Someone adds a commit to `main` while you were working on your feature:
```
main:     A ── B ── E          ← new commit added while you were working
               \
feature:        C ── D         ← your commits, based off old B
```

After `git rebase main` — your commits are replayed on top of the latest main:
```
main:     A ── B ── E
                    \
feature:             C' ── D'  ← same changes, now based off latest E
```
The `'` means the commits got new IDs but contain the same changes you wrote.

**When to use which:**
- `merge` — default choice, safe, preserves full history, works fine with multiple people
- `rebase` — use only on your own private feature branch before a PR to keep history clean

**Golden rule with teams:**
> Never rebase a branch that other people are also working on.

When you rebase, Git rewrites your commits (new IDs). If a teammate already pulled your branch and based work on your old commits, their history no longer matches yours — Git sees them as completely different commits and you get a mess.

Safe pattern in a team:
- Everyone has their **own feature branch** — nobody shares a feature branch
- You rebase only your own private branch before opening a PR
- `main` is the shared branch — never rebase main
- Most teams just use `merge` for everything and skip rebase entirely

---

## Resolving merge conflicts

When Git cannot automatically combine two versions of a file, you get a conflict:

```
<<<<<<< HEAD
Hello from main branch
=======
Hello from feature branch
>>>>>>> feature/test
```

- The block between `<<<` and `===` is YOUR version (the branch you're on)
- The block between `===` and `>>>` is the INCOMING version (the branch being merged)

Fix it:
```bash
# 1. Open the file and edit it to the version you want — delete the conflict markers
# 2. Stage the resolved file
git add hello.txt

# 3. Complete the merge with a commit
git commit -m "Resolve merge conflict"
```

---

## Remotes

A remote is a URL alias pointing to a repo hosted somewhere (GitHub, Azure DevOps, etc.)

```bash
# See all remotes for this repo
git remote -v

# Add GitHub as origin (HTTPS — requires token/gh auth)
git remote add origin https://github.com/<username>/git-practice.git

# Add GitHub as origin (SSH — uses your SSH key, no password needed)
git remote add origin git@github.com:<username>/git-practice.git

# Switch an existing remote from HTTPS to SSH
git remote set-url origin git@github.com:<username>/git-practice.git

# Switch an existing remote from SSH back to HTTPS
git remote set-url origin https://github.com/<username>/git-practice.git

# Check which protocol you are currently using (look at the URL — git@ = SSH, https:// = HTTPS)
git remote -v

# Add Azure DevOps as a second remote named ado
git remote add ado https://dev.azure.com/<org>/<project>/_git/<repo>

# Push to GitHub
git push origin main

# Push the same branch to Azure DevOps (independently — they are separate)
git push ado main

# Set the default push target for a branch (so you can just git push next time)
git push -u origin main          # -u sets the upstream tracking branch
```

> SSH vs HTTPS: SSH uses your SSH key (set once, never asked again). HTTPS asks for credentials — GitHub no longer accepts passwords, so you need `gh auth login` or a Personal Access Token. SSH is simpler once set up.

---

## .gitignore

Tells Git which files to never track. Create this file at the root of your repo.

```bash
# Create a .gitignore with common patterns
# This is a "here-document" — a shell trick to write a multi-line file in one command:
#   cat          — reads input and writes it out
#   >            — redirect: writes the output into .gitignore (creates or overwrites the file)
#   << 'EOF'     — "everything until you see EOF on its own line is the input"
#                  the quotes around 'EOF' prevent the shell expanding $variables inside the block
#   EOF          — marks the end of the input block
cat > .gitignore << 'EOF'
.env                  # exact filename match — secrets like API keys and passwords
*.tfstate             # * = wildcard — matches any file ending in .tfstate (Terraform state files)
*.tfstate.backup      # Terraform backup state files
.terraform/           # trailing / means ignore this whole directory (Terraform provider plugins)
secrets/              # ignore the secrets/ folder and everything inside it
EOF

# Verify ignored files do NOT appear in git status
git status

# If a file was already tracked before you added it to .gitignore,
# .gitignore won't help — Git keeps tracking files it already knows about.
# Untrack it without deleting it from disk:
git rm --cached .env             # removes from Git tracking, file stays on your machine
git rm --cached -r .terraform/  # -r = recursive, needed for directories
```

**Pattern rules:**
- `filename` — matches that exact file name anywhere in the repo
- `*.ext` — matches any file with that extension
- `folder/` — matches a directory (trailing slash)
- `!filename` — un-ignore a file (override a previous pattern)

> If a secret is ever committed to Git, rotate it immediately — assume someone has already seen it.

---

## GitHub CLI (gh)

```bash
# Create a GitHub issue from terminal
gh issue create --title "Test issue from CLI" --body "Created using gh CLI"

# List open pull requests
gh pr list

# Check out a PR's branch locally (useful for reviewing someone else's PR)
gh pr checkout <pr-number>

# Create a pull request from the current branch
gh pr create --title "Add foundation scripts" --body "Adds create-foundation.sh and assign-access.sh"
```

---

## Pull Requests — the standard workflow

```bash
# 1. Create a feature branch
git checkout -b feature/add-foundation-scripts

# 2. Make changes and commit
git add .gitignore project/
git commit -m "Add foundation infrastructure scripts"

# 3. Push the branch (not main) to GitHub
git push -u origin feature/add-foundation-scripts

# Then open a PR on GitHub — teammates review → approve → merge
# After merging, update your local main:
git checkout main
git pull origin main
```

Closing issues automatically from a commit message or PR body:
```
git commit -m "Add team info — Closes #1"
# When the PR merges, GitHub closes Issue #1 automatically
```

---

## Azure DevOps — daily workflow

```bash
# ─────────────────────────────────────────────
# FIRST TIME ONLY — clone the repo to your machine
# ─────────────────────────────────────────────
git clone https://github.com/atschakzoy/az-learning-platform.git
cd az-learning-platform

# Add ADO as a second remote (also first time only)
git remote add ado git@ssh.dev.azure.com:v3/achakzoypa/platform-learning/platform-learning

# Confirm both remotes are there
git remote -v


# ─────────────────────────────────────────────
# EVERY DAY — before you start working
# ─────────────────────────────────────────────
git checkout main
git pull origin main          # get latest from GitHub


# ─────────────────────────────────────────────
# DO YOUR WORK — on a feature branch
# ─────────────────────────────────────────────
git checkout -b feature/my-work   # create a new branch for today's work

# ... edit files ...

git status                        # see what changed
git add .                         # stage everything (or name specific files)
git commit -m "Describe what you did"

# push your branch to GitHub
git push origin feature/my-work


# ─────────────────────────────────────────────
# PULL REQUEST — merge your branch into main
# ─────────────────────────────────────────────
# Go to GitHub → open PR from feature/my-work → main → merge it
# Then back in terminal:
git checkout main
git pull origin main              # pull the merged result down
git branch -d feature/my-work    # delete the feature branch, work is done


# ─────────────────────────────────────────────
# SEND TO ADO — mirror main to Azure DevOps
# ─────────────────────────────────────────────
git push ado main
```

---

## Azure DevOps pipeline (YAML)

The pipeline YAML below runs `az account show` using a service connection.
It triggers automatically whenever someone pushes to `main`.

```yaml
trigger:
  - main

pool:
  vmImage: ubuntu-latest

steps:
  - task: AzureCLI@2
    displayName: 'Show Azure account info'
    inputs:
      azureSubscription: azure-subscription-dev   # name of the ADO service connection
      scriptType: bash
      scriptLocation: inlineScript
      inlineScript: |
        echo "Pipeline is working!"
        az account show --output table
```

---

## Bash scripts for Stage 2 project

### create-foundation.sh

```bash
#!/usr/bin/env bash
set -euo pipefail                # stop on error, stop on undefined var, catch pipe failures

: "${SUFFIX:?ERROR: Set the SUFFIX environment variable}"   # fail fast if not set

RG="${RG:-rg-platform-dev}"     # use $RG if set, otherwise default to rg-platform-dev
LOCATION="${LOCATION:-eastus}"

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
  --enable-purge-protection true \
  --output none

az monitor log-analytics workspace create \
  --resource-group "$RG" \
  --workspace-name "law-platform-dev" \
  --location "$LOCATION" \
  --output none

# Run it like this — SUFFIX is required:
# SUFFIX=rn ./create-foundation.sh
```

### assign-access.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

: "${SUFFIX:?ERROR: Set SUFFIX}"
RG="${RG:-rg-platform-dev}"

# Capture the current user's Entra ID object ID into a variable
USER_ID=$(az ad signed-in-user show --query id --output tsv)

# Capture the full Key Vault resource ID
KV_ID=$(az keyvault show \
  --name "kv-platform-dev-${SUFFIX}" \
  --resource-group "$RG" \
  --query id \
  --output tsv)

# Assign data-plane access (Contributor does NOT grant Key Vault data access)
az role assignment create \
  --assignee "$USER_ID" \
  --role "Key Vault Secrets Officer" \
  --scope "$KV_ID" \
  --output none

# Verify access by writing and reading a secret
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
```

Make scripts executable before running:
```bash
chmod +x project/infra/scripts/*.sh
```

---

## Common mistakes

| Mistake | Fix |
|---------|-----|
| `git push origin main` rejected with "protected branch" | Branch protection is working — create a feature branch, push that, open a PR |
| File still shows in `git status` after adding to `.gitignore` | File was already tracked. Run `git rm --cached <filename>` to untrack it |
| "Repository not found" when pushing to ADO | ADO needs different auth — use your Microsoft account or a Personal Access Token |
| Script fails with "SUFFIX: unbound variable" | Run as `SUFFIX=rn ./create-foundation.sh` — you must set it before the script |
| `git branch -d` fails — "used by worktree" or "not fully merged" | Switch away from the branch first: `git checkout main`, then delete |
