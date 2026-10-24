using './main.bicep'

param workloadName = 'sampleapp'
param environment = 'dev'
param regionCode = 'centralus'
param instance = '001'

param logAnalyticsWorkspaceId = ''
param enableDiagnosticSettings = false

param skuName = 'GP_S_Gen5_2'
param skuTier = 'GeneralPurpose'

param entraAdminObjectId = '3e7e4269-f773-4b01-9a41-2261bf9c558b'
param entraAdminLogin = 'sathish.vit099_gmail.com#EXT#@sathishvit099gmail.onmicrosoft.com'
param entraTenantId = 'ff360367-7322-4db4-97a7-ade6839352de'

param costCenter = 'CC-1001'
param owner = 'platform-team'
param applicationName = 'sampleapp'
