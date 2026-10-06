# Bash Scripting Notes

---

## Bash Loop Conventions

### for loop — fixed list or single-value output
```bash
for item in one two three; do
  echo "${item}"
done
```
- Use when you have a known list or each line has one value.
- `item` gets each value one by one.
- `do` starts the block, `done` ends it.

### for loop — over command output
```bash
for name in $(az storage account list --query "[].name" --output tsv); do
  echo "${name}"
done
```
- `$(...)` runs the command and gives the output to `for`.
- Splits on spaces and tabs — breaks if a value has spaces in it.

### while read — multi-column output
```bash
while read -r name rg location; do
  echo "${name} | ${rg} | ${location}"
done <<< "${VARIABLE}"
```
- `while` — keep looping as long as `read` can grab a line.
- `read -r name rg location` — grabs one line and splits it into variables. Each variable catches one column left to right.
- `name`, `rg`, `location` — you name these yourself. They are set fresh on every iteration.
- `do` — starts the loop body.
- `done` — ends the loop body.
- `<<< "${VARIABLE}"` — feeds the variable into the loop one line at a time.
- Use when each line has multiple columns (from `--output tsv`).
- The variable order must match the column order from `--query`.

### if statement inside a loop
```bash
if [[ "${VALUE}" == "true" ]]; then
  echo "condition is true"
else
  echo "condition is false"
fi
```
- `if` — checks a condition.
- `[[ ]]` — where you write the condition. Always use double brackets in bash.
- `==` — string comparison. Checks if two strings are equal.
- `then` — starts the block that runs when the condition is true.
- `else` — starts the block that runs when the condition is false. Optional — you can have `if` without `else`.
- `fi` — closes the if block. (`fi` = `if` backwards, bash convention.)
- Variables set before the `if` (like `account` from `read`) are available inside the `if` block.

---

## Script 4 — list-role-assignments.sh (Output Formatting)

This script lists all role assignments at subscription scope.
Teaches: `--output table` for automatic formatting, `--scope` flag.

---

### Step 1 — Header + Subscription

```bash
#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID=$(az account show --query id --output tsv)
echo "Role assignments for subscription: ${SUBSCRIPTION_ID}"
echo ""
```

- Same header pattern as all previous scripts.

---

### Step 2 — Fetch and Print Role Assignments

```bash
az role assignment list \
  --scope "/subscriptions/${SUBSCRIPTION_ID}" \
  --query "[].{Principal:principalName, Role:roleDefinitionName, Scope:scope}" \
  --output table
```

- `az role assignment list` — lists who has what access at what scope.
- `--scope "/subscriptions/${SUBSCRIPTION_ID}"` — limits to subscription level only. Without this you'd get every role assignment across every resource.
- `--output table` — Azure CLI auto-formats the output as a table with column headers. No loop or printf needed.
- No variable needed — you're just displaying, not processing the data.

---

## Script 1 — setup-tfstate.sh (One-Time Setup)

This script creates the Azure infrastructure needed to store Terraform state remotely:
a resource group, a storage account, and a blob container.

---

### Step 1 — Script Header

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- `#!/usr/bin/env bash` — shebang line. Tells the OS to run this file with bash.
- `set -euo pipefail` — three safety flags combined:
  - `-e` → exit immediately if any command returns a non-zero exit code
  - `-u` → treat unset variables as an error (catches typos)
  - `-o pipefail` → if any command in a pipe fails, the whole pipe fails
- Always put this at the top of every bash script you write.

---

### Step 2 — Declare Variables

```bash
SUFFIX="rn001"
LOCATION="eastus"
RESOURCE_GROUP="rg-tfstate"
STORAGE_ACCOUNT="sttfstate${SUFFIX}"
CONTAINER="tfstate"
```

- No spaces around `=`. `SUFFIX = "rn001"` would fail — bash treats it as a command.
- `${SUFFIX}` inside a string embeds the variable value. Curly braces make the variable boundary clear.
- ALL_CAPS is the bash convention for script-level constants.
- These values match the backend config in `provider.tf` exactly.

---

### Step 3 — Capture Azure CLI Output into a Variable

```bash
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
echo "Using subscription: ${SUBSCRIPTION_ID}"
```

- `$(...)` — command substitution. Runs the command inside and stores its output in the variable.
- `az account show` — returns info about the currently active Azure subscription.
- `--query id` — JMESPath query. Extracts only the `id` field from the JSON response. Azure CLI always returns JSON — `--query` lets you pick only the fields you need.
- **How `--query` naming works:** `[].{ColumnName:realFieldName}` — `[]` loops over an array, `{}` picks fields. The left side of `:` is the name YOU choose (shown as column header), the right side is the real field name from the Azure JSON. Example: `{Role:roleDefinitionName}` — Azure calls it `roleDefinitionName`, you display it as `Role`. To find real field names, run the command with `--output json` first and look at the raw response.
- `--output tsv` — plain text output, no quotes. Always use `tsv` when storing CLI output in a variable.
- `echo` — prints to terminal so you can confirm which subscription the script is targeting.

---

### Step 4 — Create the Resource Group

```bash
echo "Creating resource group: ${RESOURCE_GROUP}"
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --output none
```

- `az group create` — creates an Azure resource group. Every Azure resource lives inside one.
- `\` — line continuation. Splits one long command across multiple lines for readability.
- `--output none` — suppresses the default JSON response. Use this when you're running an action, not capturing a value.
- `az group create` is idempotent — if the group already exists it won't fail or duplicate it. Safe to re-run.

---

### Step 5 — Create the Storage Account

```bash
echo "Creating storage account: ${STORAGE_ACCOUNT}"
az storage account create \
  --name "${STORAGE_ACCOUNT}" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --sku Standard_LRS \
  --min-tls-version TLS1_2 \
  --output none
```

- `az storage account create` — creates the storage account where Terraform stores its state file.
- `--sku Standard_LRS` — Locally Redundant Storage. Cheapest option, 3 copies within one datacenter. Free tier eligible.
- `--min-tls-version TLS1_2` — security baseline, matches the Terraform `main.tf` config.
- Pattern: always `echo` before the `az` command to log what the script is doing.

---

### Step 6 — Create the Blob Container

```bash
echo "Creating blob container: ${CONTAINER}"
az storage container create \
  --name "${CONTAINER}" \
  --account-name "${STORAGE_ACCOUNT}" \
  --auth-mode login \
  --output none
```

- `az storage container create` — creates the blob container inside the storage account where the `terraform.tfstate` file will live.
- `--auth-mode login` — authenticates using your Azure AD login instead of storage account keys. More secure.
- Container name `tfstate` matches `container_name` in `provider.tf` backend config.
- Order matters: resource group → storage account → container. Each depends on the one before it.

---

### Step 7 — Print a Success Summary

```bash
echo ""
echo "Done. Terraform backend is ready."
echo "  Resource group:   ${RESOURCE_GROUP}"
echo "  Storage account:  ${STORAGE_ACCOUNT}"
echo "  Container:        ${CONTAINER}"
echo "  Subscription:     ${SUBSCRIPTION_ID}"
```

- `echo ""` — prints a blank line for terminal readability.
- Printing a summary at the end confirms what was created and in which subscription.
- Because of `set -e`, if any earlier command had failed the script would have already exited. Reaching this echo means everything above succeeded.

---

### Running the Script

**Make it executable (one time only):**
```bash
chmod +x CI-CD/setup-tfstate.sh
```

**Run it:**
```bash
bash CI-CD/setup-tfstate.sh
```

- `chmod +x` — sets the executable permission on the file. Without it, the OS won't run it as a program. Only needed once per file.
- `bash <file>` — runs the script directly using bash.
- You must be logged in to Azure CLI (`az login`) before running this script, since it calls `az` commands.

---

## Script 2 — list-storage-accounts.sh (Query + Loop)

This script lists all storage accounts in the current subscription.
Teaches: fetching JSON from Azure CLI, looping over results, formatted output.

---

### Step 1 — Script Header + Subscription

```bash
#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID=$(az account show --query id --output tsv)
echo "Listing storage accounts in subscription: ${SUBSCRIPTION_ID}"
echo ""
```

- Same header as Script 1.
- `echo ""` before the list prints a blank line so output is readable.

---

### Step 2 — Fetch the List of Storage Accounts

```bash
ACCOUNTS=$(az storage account list \
  --query "[].{Name:name, ResourceGroup:resourceGroup, Location:location}" \
  --output tsv)
```

- `az storage account list` — returns all storage accounts in the subscription as JSON.
- `--query "[].{Name:name, ResourceGroup:resourceGroup, Location:location}"` — JMESPath query. `[]` loops over the array, `{...}` picks and renames three fields per item.
- `--output tsv` — tab-separated output. Each account becomes one line with three columns. Easy to loop over.
- Result is stored in `ACCOUNTS` via `$()` command substitution.

---

### Step 3 — Loop Over Results

**Three levels of bash loops:**

Level 1 — simplest, fixed list:
```bash
for item in one two three; do
  echo "${item}"
done
```

Level 2 — loop over command output (one value per line):
```bash
for name in $(az storage account list --query "[].name" --output tsv); do
  echo "${name}"
done
```

Level 3 — loop over multi-column lines (what this script uses):
```bash
while read -r name rg location; do
  echo "${name} | ${rg} | ${location}"
done <<< "${ACCOUNTS}"
```

- Use `for` when each line has one value. Use `while read` when each line has multiple columns.
- `<<<` is a "here-string" — feeds a variable into the loop as if it were a file.
- `read -r` — `-r` prevents backslashes from being treated as escape characters.
- `IFS=$'\t'` tells bash to split on tabs only. Without it, bash splits on any whitespace. Safe to omit for learning; keep it in production.

**Beginner version (no IFS, no printf):**
```bash
while read -r name rg location; do
  echo "${name} | ${rg} | ${location}"
done <<< "${ACCOUNTS}"
```

- The variable names in `read -r name rg location` match the column order in `--query`.
- Column 1 → first variable, column 2 → second variable, column 3 → third variable.
- If you change the field order in `--query`, update the variable order in `read` to match.

---

### Step 4 — Print the Count

```bash
COUNT=$(echo "${ACCOUNTS}" | wc -l)
echo ""
echo "Total storage accounts: ${COUNT}"
```

- `wc -l` — counts the number of lines in its input. Each storage account = one line.
- `|` — pipe. Takes output from the left command and feeds it as input to the right command.
- `echo "${ACCOUNTS}" | wc -l` — prints the accounts text and pipes it into `wc -l` to count lines.

---

## Script 3 — disable-key-access.sh (Conditional Logic)

This script disables shared key access on all storage accounts in a resource group.
Teaches: command-line arguments, if statements inside loops.

---

### Step 1 — Header + Variable

```bash
#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="${1:-rg-tfstate}"
echo "Targeting resource group: ${RESOURCE_GROUP}"
echo ""
```

- `$1` — the first argument passed to the script when you run it. Example: `bash disable-key-access.sh rg-prod`
- `:-rg-tfstate` — default value. If no argument is given, use `rg-tfstate`.
- Combined: `${1:-rg-tfstate}` means "use what the user typed, or fall back to `rg-tfstate`".

---

### Step 2 — Fetch Storage Accounts in the Resource Group

```bash
ACCOUNTS=$(az storage account list \
  --resource-group "${RESOURCE_GROUP}" \
  --query "[].name" \
  --output tsv)
```

- `--resource-group` — filters results to only accounts inside that resource group.
- `--query "[].name"` — only fetch names this time (no need for location/rg since we already know them).
- Each line of `ACCOUNTS` is one storage account name.

---

### Step 3 — Loop + Check if Key Access is Already Disabled

```bash
while read -r account; do
  KEY_ACCESS=$(az storage account show \
    --name "${account}" \
    --resource-group "${RESOURCE_GROUP}" \
    --query "allowSharedKeyAccess" \
    --output tsv)

  if [[ "${KEY_ACCESS}" == "true" ]]; then
    echo "${account}: key access is enabled — disabling..."
  else
    echo "${account}: key access already disabled, skipping"
  fi
done <<< "${ACCOUNTS}"
```

- `if [[ condition ]]; then` — runs the block if the condition is true. `[[ ]]` is the bash way to test conditions.
- `== "true"` — string comparison inside `[[ ]]`.
- `else` — what to run when the condition is false.
- `fi` — closes the if block (`fi` = `if` backwards).
- `az storage account show --query "allowSharedKeyAccess"` — returns `true` or `false` for that property.

---

### Step 4 — Disable Key Access Inside the Loop

```bash
  if [[ "${KEY_ACCESS}" == "true" ]]; then
    echo "${account}: disabling shared key access..."
    az storage account update \
      --name "${account}" \
      --resource-group "${RESOURCE_GROUP}" \
      --allow-shared-key-access false \
      --output none
    echo "${account}: done"
  else
    echo "${account}: already disabled, skipping"
  fi
```

- `az storage account update` — modifies an existing storage account.
- `--allow-shared-key-access false` — disables key-based auth, forces Azure AD auth instead.
- The update only runs inside the `if` block — accounts already disabled are skipped.
- Safe to run multiple times without breaking anything.

---

## Script 4 — list-role-assignments.sh (Output Formatting)

```bash
#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID=$(az account show --query id --output tsv)
echo "Role assignments for subscription: ${SUBSCRIPTION_ID}"
echo ""

az role assignment list \
  --scope "/subscriptions/${SUBSCRIPTION_ID}" \
  --query "[].{Principal:principalName, Role:roleDefinitionName, Scope:scope}" \
  --output table
```

- `az role assignment list` — lists who has what access at what scope.
- `--scope "/subscriptions/${SUBSCRIPTION_ID}"` — limits to subscription level only.
- `--output table` — Azure CLI auto-formats as a table. No loop or printf needed. Use when displaying, not processing.

---

## Exercise 4 — error-demo.sh (set -euo pipefail in action)

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Step 1: starting"

az group show --name rg-does-not-exist-xyz

echo "Step 2: this should not print"
```

- With `set -euo pipefail`: script stops after the failing `az group show`. Step 2 never prints.
- Without it: script continues past the failure and prints Step 2 — a silent error that could cause damage downstream.
- This is exactly why every script starts with `set -euo pipefail`.
















