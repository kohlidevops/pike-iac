targetScope = 'resourceGroup'

@description('Azure region for Container Apps resources.')
param location string = resourceGroup().location

@description('Azure Container App name.')
param containerAppName string

@description('Azure Container Apps managed environment name.')
param managedEnvironmentName string

@description('Log Analytics workspace name used by the Container Apps environment.')
param logAnalyticsWorkspaceName string

@description('Container image to deploy.')
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Resource tags.')
param tags object = {}


// ---------------------------------------------------------
// Log Analytics Workspace
// ---------------------------------------------------------

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location

  properties: {
    retentionInDays: 30

    sku: {
      name: 'PerGB2018'
    }

    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }

  tags: tags
}


// ---------------------------------------------------------
// Container Apps Managed Environment
// ---------------------------------------------------------

resource managedEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: managedEnvironmentName
  location: location

  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'

      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }

  tags: tags
}


// ---------------------------------------------------------
// Azure Container App
// ---------------------------------------------------------

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location

  properties: {
    managedEnvironmentId: managedEnvironment.id

    configuration: {
      activeRevisionsMode: 'Single'

      ingress: {
        external: true
        targetPort: 80
        allowInsecure: false
        transport: 'auto'
      }
    }

    template: {
      containers: [
        {
          name: 'sample-app'

          image: containerImage

          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]

      scale: {
        minReplicas: 0
        maxReplicas: 2
      }
    }
  }

  tags: tags
}


// ---------------------------------------------------------
// Outputs
// ---------------------------------------------------------

output containerAppName string = containerApp.name

output containerAppId string = containerApp.id

output managedEnvironmentName string = managedEnvironment.name

output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name

output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
