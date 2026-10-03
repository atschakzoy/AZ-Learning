#!/usr/bin//env bash
set -euo pipefail

SUBSCRIPTION_ID=$(az account show --query id --output tsv)
echo "Listing storage account in subscription: ${SUBSCRIPTION_ID}"
echo ""

ACCOUNTS=$(az storage account list \
  --query "[].{Name:name, ResourceGroup:resourceGroup, Location:location}" \
  --output tsv)

while read -r name rg location; do
  echo "${name} | ${rg} | ${location}"
done <<< "${ACCOUNTS}"

COUNT=$(echo "${ACCOUNTS}" | wc -l)
echo ""
echo "Total storage accounts: ${COUNT}"