#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="${1:-rg-tfstate}"
echo "Targeting resource group: ${RESOURCE_GROUP}"
echo ""

ACCOUNTS=$(az storage account list \
--resource-group "${RESOURCE_GROUP}" \
--query "[].name" \
--output tsv)

while read -r account; do
  KEY_ACCESS=$(az storage account show \
    --name "${account}" \
    --resource-group "${RESOURCE_GROUP}" \
    --query "allowSharedKeyAccess" \
    --output tsv)

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
done <<< "${ACCOUNTS}"

echo ""
echo "Done. All storage accounts in '${RESOURCE_GROUP}' processed."


