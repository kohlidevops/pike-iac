@description('Azure OpenAI account name.')
param accountName string

@description('Azure region.')
param location string

@description('Azure OpenAI SKU name.')
param skuName string

@description('Custom subdomain name for the Azure OpenAI endpoint.')
param customSubDomainName string

@description('Public network access setting.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string

@description('Resource tags.')
param tags object

resource openAiService 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: accountName
  location: location
  kind: 'OpenAI'
  sku: {
    name: skuName
  }
  properties: {
    customSubDomainName: customSubDomainName
    publicNetworkAccess: publicNetworkAccess
  }
  tags: tags
}

output accountId string = openAiService.id
output accountName string = openAiService.name
output location string = openAiService.location
