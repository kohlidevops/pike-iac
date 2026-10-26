
targetScope = 'resourceGroup'

// -----------------------------------------------------------------------------
// Purpose: Deploy an Azure OpenAI account.
// -----------------------------------------------------------------------------

@description('Name of the Azure OpenAI account. Must be globally unique.')
@minLength(2)
@maxLength(64)
param openAiAccountName string

@description('Azure region for the Azure OpenAI account.')
param location string = resourceGroup().location

@description('Resource tags applied to the Azure OpenAI account.')
param tags object = {
  environment: 'dev'
  managedBy: 'pike-iac'
  module: 'openai'
}

@description('Enable public network access for the Azure OpenAI account.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('SKU name for the Azure OpenAI account.')
@allowed([
  'S0'
])
param skuName string = 'S0'

// -----------------------------------------------------------------------------
// Azure OpenAI Account
// -----------------------------------------------------------------------------

resource openAiAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: openAiAccountName
  location: location
  kind: 'OpenAI'
  sku: {
    name: skuName
  }
  properties: {
    customSubDomainName: openAiAccountName
    publicNetworkAccess: publicNetworkAccess
    disableLocalAuth: false
  }
  tags: tags
}

// -----------------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------------

@description('Resource ID of the Azure OpenAI account.')
output openAiAccountId string = openAiAccount.id

@description('Name of the Azure OpenAI account.')
output openAiAccountName string = openAiAccount.name

@description('Endpoint URL of the Azure OpenAI account.')
output openAiEndpoint string = 'https://${openAiAccount.name}.openai.azure.com/'
