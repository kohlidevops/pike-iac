
using './main.bicep'

// -----------------------------------------------------------------------------
// Purpose: Supply representative parameters for validation.
// -----------------------------------------------------------------------------

param openAiAccountName = 'pike-openai-test-001'
param location = 'centralus'

param tags = {
  environment: 'test'
  managedBy: 'pike-iac'
  module: 'openai'
}

param publicNetworkAccess = 'Enabled'
param skuName = 'S0'
