#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID=$(az account show --query id --output tsv)
echo "Role assignment for subscription: ${SUBSCRIPTION_ID}"
echo ""
 
az role assignment list \
    --scope "/subscriptions/${SUBSCRIPTION_ID}" \
    --query "[].{principal:principalName, Role:roleDefinitionName, Scope:scope}" \
    --output table

#assign a role to a user
az role assignment create \
    --assignee naeemna@achakzoygmail.onmicrosoft.com\
    --role "Contributor" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}"
echo "role assigned successfully":

#assign a role to a service principal 
az role assignment create \
    --assignee 417ccbab-f069-496b-96dd-44dee14733ab \
    --role "Storage Blob Data Contributor" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/rg-tfstate"
echo "sp role assigned big boy"

#remove a role
az role assignment delete \
    --assignee 417ccbab-f069-496b-96dd-44dee14733ab \
    --role "Storage Blob Data Contributor"