@description('Name for the storage account')
param storageAccountName string
@description('name for the KeyVault')
param keyVaultName string
@description('Azure region')
param location string = resourceGroup().location

module storage './modules/storage.bicep' = {
  name: 'storageDeployment'
  params: {
    storageAccountName: storageAccountName
    location: location
  }
}
module kv './modules/keyvault.bicep' = {
  name: 'kvDeployment'
  params: {
    keyVaultName: keyVaultName
    location: location
  }
  
}
output primaryEndpoint string = storage.outputs.primaryEndpoint
output keyVaultUri string = kv.outputs.keyVaultUri
