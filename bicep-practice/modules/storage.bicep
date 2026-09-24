param storageAccountName string
param location string = resourceGroup().location
param storageSku string

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false 
  }
}
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: storage
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-04-01' = {
  name: 'mycontainer'
  parent :blobService
  properties: {
    publicAccess: 'None'
  }
}
output primaryEndpoint string = storage.properties.primaryEndpoints.blob
