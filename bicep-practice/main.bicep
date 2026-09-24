targetScope = 'subscription'

@description('Name for the storage account')
param storageAccountName string
@description('name for the KeyVault')
param keyVaultName string
@description('Name of the resource group to create')
param resourceGroupName string
@description('Location for all resources')
param location string

param storageSku string = 'Standard-ZRS'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

module storage './modules/storage.bicep' = {
  name: 'storageDeployment'
  scope: rg
  params: {
    storageAccountName: storageAccountName
    location : location
    storageSku: storageSku
  }
}
module kv './modules/keyvault.bicep' = {
  name: 'kvDeployment'
  scope: rg
  params: {
    keyVaultName: keyVaultName
    location: location
  }
}
module kvRoleAdmin './modules/roleassignment.bicep' = {
  name: 'kvRoleAdmin'
  scope: rg
  params: {
    name : 'kv-role'
    principalId: '754fee9b-a2af-4604-9cbd-fef7f6be106c'
    roleDefinitionId: '00482a5a-887f-4fb3-b363-3b7fe8e74483'
    assignmentDescription: 'Key Vault Administrator on resource group'
  }
}
module storageRoleDataContributer './modules/roleassignment.bicep' = {
  name: 'storageRoleDataContributer'
  scope: rg
  params: {
    name: 'storage-role'
    principalId: '754fee9b-a2af-4604-9cbd-fef7f6be106c'
    roleDefinitionId: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    assignmentDescription: 'Storage Blob Data Contributor on resource group'
  }
}
output primaryEndpoint string = storage.outputs.primaryEndpoint
output keyVaultUri string = kv.outputs.keyVaultUri
