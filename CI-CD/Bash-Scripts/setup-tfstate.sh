#!/usr/bin/env bash
set -euo pipefail
SUFFIX="rn001"
LOCATION="eastus"
RESOURCE_GROUP="rg-tfstate"
STORAGE_ACCOUNT="sttfstate${SUFFIX}"
CCNTAINER="tfstate110"

SUBSCRIPTION_ID=$(az account show --query id --output tsv)
echo "Ising subscription: ${SUBSCRIPTION_ID}"

echo "creating a resource group: ${RESOURCE_GROUP}"
az group create \
--name "${RESOURCE_GROUP}" \
--location "${LOCATION}" \
--output none 

echo "creating a storage account: ${STORAGE_ACCOUNT}"
az storage account create\
--name "${STORAGE_ACCOUNT}" \
--resource-group "${RESOURCE_GROUP}" \
--location "${LOCATION}" \
--sku Standard_LRS \
min-tls-version TLS1_2 \
--output none

echo "creating a blob container: ${CONTAINER}"
az storage container create \
--name "${CONTAINER}" \
--account-name "${STORAGE_ACCOUNT}" \
--auth-mode login \
--output none

echo""
echo "Done. Terraform backend is ready."
echo "resource group: ${RESOURCE_GROUP}"
echo "storage account: ${STORAGE_ACCOUNT}"
echo "container: ${CONTAINER}"
echo "Subscription: ${SUBSCRIPTION-ID}"
