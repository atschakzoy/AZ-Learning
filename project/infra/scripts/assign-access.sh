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
