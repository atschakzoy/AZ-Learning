param keyVaultName string
param location string = resourceGroup().location

resource keyvault 'Microsoft.KeyVault/vaults@2025-05-01'= {
  name: keyVaultName 
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true 
    enableSoftDelete: true
  }
}

output keyVaultUri string = keyvault.properties.vaultUri
output id string = keyvault.id 
