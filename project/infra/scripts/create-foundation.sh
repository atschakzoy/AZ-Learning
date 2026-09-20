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
