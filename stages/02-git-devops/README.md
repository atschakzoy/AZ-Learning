# Stage 2 — Git & DevOps

> **Project milestone:** The CLI scripts from Stage 1 live in a Git repo on GitHub, mirrored to Azure Repos. An Azure DevOps project is set up with a service connection to your Azure subscription — ready for pipelines in Stage 4.

---

## What you'll build this stage

The infrastructure from Stage 1 exists, but the CLI commands that built it live only in your terminal history. This stage puts everything under source control so it is auditable, shareable, and a solid base for IaC in Stage 3.

By the end of this stage your repo will contain:

```
project/
└── infra/
    └── scripts/
        ├── create-foundation.sh   ← CLI commands from Stage 1
        └── assign-access.sh       ← role assignment commands
```

---

## Concepts

### Git

Git records every change as a **commit** — a snapshot with an author, timestamp, and message. Key ideas:

| Concept | What it is |
|---------|-----------|
| Branch | An independent line of development |
| Pull Request (PR) | A proposal to merge a branch, with a review step |
| Merge | Combines branches, preserves both histories |
| Rebase | Replays commits on top of another branch — cleaner history, rewrites SHAs |
| `.gitignore` | Files Git should never track (secrets, state files, build artifacts) |

For infrastructure work, always `.gitignore`:
```
.env
*.tfstate
*.tfstate.backup
.terraform/
secrets/
```

### GitHub

The hosted Git platform used in this project. Key features:

- **Branch protection**: prevent direct pushes to `main`, require PRs and approvals
- **Issues**: track tasks, bugs, and improvements
- **GitHub Actions**: automation triggered by Git events (used heavily in Stage 4)

### Azure DevOps (ADO)

Microsoft's end-to-end DevOps platform. The components you will use:

| Component | Purpose |
|-----------|---------|
| Azure Repos | Hosts a copy of your Git repo |
| Azure Boards | Sprint and backlog tracking |
| Azure Pipelines | CI/CD automation (Stage 4) |
| Service Connection | A trusted link from ADO to your Azure subscription |

### Service Connections and Workload Identity Federation

A **service connection** lets Azure Pipelines authenticate to Azure without a developer's personal credentials. The modern way to set this up is **Workload Identity Federation** (OIDC): instead of storing a client secret, Azure trusts a short-lived token issued by ADO. No secrets to rotate, no secrets in pipeline variables.

GitHub Actions has the same capability — you will set that up in Stage 4.

---

## Exercises

### Git

1. In a scratch folder, run `git init`. Create a file, stage it (`git add`), commit it, then push to a new empty GitHub repo.
2. Create a feature branch (`git checkout -b feature/test`). Edit the same line of a file on both `main` and the feature branch, then merge and resolve the conflict manually.
3. Practice rebasing: create a feature branch with two commits. Add a commit to `main`. Run `git rebase main` on the feature branch and observe how the commit history changes compared to a merge.
4. Create a `.gitignore` that ignores `.env`, `*.tfstate`, `*.tfstate.backup`, `.terraform/`, and `secrets/`. Verify git does not track matching files (`git status` should not show them).

### GitHub

5. Enable branch protection on `main`: require a PR with at least one approval, require the branch to be up to date before merging. Confirm that a direct `git push origin main` is rejected.
6. Create an Issue. Open a PR from a feature branch whose commit message contains `Closes #1`. Merge the PR and confirm the issue auto-closes.
7. Install the GitHub CLI (`gh`). Create an issue, list open PRs, and check out a PR branch — all from the terminal without opening the browser.

### Azure DevOps

8. Create a free Azure DevOps organization at `dev.azure.com`. Create a new project. Push your repo to Azure Repos as a second remote:
   ```bash
   git remote add ado <your-ado-repo-url>
   git push ado main
   ```
9. Create a **service connection** in ADO (Project Settings → Service Connections → Azure Resource Manager). Choose **Workload Identity Federation** if available; otherwise use Service Principal (automatic).
10. Create a minimal YAML pipeline that prints "Pipeline is working" using a `script` step. Trigger it by pushing a commit and watch it run in the ADO UI.

---

## Project Step

### A — Initialize the repo

From your project folder:

```bash
git init
git remote add origin <your-github-url>
```

Create `.gitignore` at the repo root:

```
.env
*.tfstate
*.tfstate.backup
.terraform/
secrets/
```

### B — Move the CLI commands into scripts

Create `project/infra/scripts/create-foundation.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Required env vars — set these before running
: "${SUFFIX:?Set SUFFIX (e.g. your initials)}"
RG="${RG:-rg-platform-dev}"
LOCATION="${LOCATION:-eastus}"

echo "Creating resource group: $RG"
az group create --name "$RG" --location "$LOCATION"

echo "Creating storage account"
az storage account create \
  --name "stplatformdev${SUFFIX}" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --allow-blob-public-access false

echo "Creating Key Vault"
az keyvault create \
  --name "kv-platform-dev-${SUFFIX}" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --enable-rbac-authorization true \
  --enable-soft-delete true \
  --enable-purge-protection true

echo "Creating Log Analytics Workspace"
az monitor log-analytics workspace create \
  --resource-group "$RG" \
  --workspace-name "law-platform-dev" \
  --location "$LOCATION"

echo "Done."
```

Create `project/infra/scripts/assign-access.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

: "${SUFFIX:?Set SUFFIX}"
RG="${RG:-rg-platform-dev}"

USER_ID=$(az ad signed-in-user show --query id --output tsv)
KV_ID=$(az keyvault show --name "kv-platform-dev-${SUFFIX}" --resource-group "$RG" --query id --output tsv)

echo "Assigning Key Vault Secrets Officer to current user"
az role assignment create \
  --assignee "$USER_ID" \
  --role "Key Vault Secrets Officer" \
  --scope "$KV_ID"

echo "Done."
```

Make both scripts executable:
```bash
chmod +x project/infra/scripts/*.sh
```

### C — Commit via a PR

Create a feature branch, commit the scripts, push, and open a PR:

```bash
git checkout -b feature/add-foundation-scripts
git add project/ .gitignore
git commit -m "Add foundation CLI scripts and gitignore"
git push origin feature/add-foundation-scripts
gh pr create --title "Add foundation CLI scripts" --body "Captures the Stage 1 CLI commands as reusable scripts."
```

Review and merge the PR on GitHub.

### D — Mirror to Azure DevOps

```bash
git remote add ado <your-ado-repo-url>
git push ado main
```

Confirm the repo and scripts appear in ADO Repos.

---

**Next**: Stage 3 — replace these scripts with Bicep templates, then Terraform with remote state. The scripts become the reference but are no longer the source of truth.
