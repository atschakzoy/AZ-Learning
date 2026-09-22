@description('Name for the storage account')
param storageAccountName string

@description('Azure region')
param location string = resourceGroup().location

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_GRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
  }
}

output primaryEndpoint string = storage.properties.primaryEndpoints.blob
