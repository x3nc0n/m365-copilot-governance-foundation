targetScope = 'resourceGroup'

@description('Azure region for the collector Function App, storage, and identity.')
param location string = resourceGroup().location

@description('Azure region of the destination workspace. The data collection rule must be in the same region.')
param workspaceLocation string

@description('Resource ID of the destination Log Analytics workspace. The workspace must be in this resource group.')
param workspaceResourceId string

@minLength(1)
@maxLength(32)
@description('Prefix used for collector resource names.')
param resourceNamePrefix string

@allowed([
  'AllLicensedUsers'
  'IncludeGroup'
  'ExcludeGroup'
])
@description('Which users the collector exports interactions for.')
param collectionScope string

@description('Microsoft Entra group object ID used by IncludeGroup or ExcludeGroup scopes.')
param collectionGroupId string = ''

@description('HTTPS URL of the collector released-package.zip. Leave empty to deploy infrastructure without code.')
param packageUri string = ''

@description('Solution version recorded in collector telemetry.')
param solutionVersion string

@description('Resource tags applied where supported.')
param tags object = {}

var tableName = 'M365GovCopilotInteractionContent_CL'
var streamName = 'Custom-M365GovCopilotInteractionContent'
var retentionInDays = 90
var uniqueSuffix = uniqueString(resourceGroup().id, workspaceResourceId, resourceNamePrefix)
var storageAccountName = take('stm365gov${uniqueSuffix}', 24)
var functionAppName = '${resourceNamePrefix}-copilot-collector-${take(uniqueSuffix, 8)}'
var deploymentContainerName = 'app-package'
var stateContainerName = 'collector-state'

var storageBlobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var monitoringMetricsPublisherRoleId = '3913510d-42f4-4e42-8a64-420c390055eb'

var interactionColumns = [
  { name: 'TimeGenerated', type: 'datetime' }
  { name: 'InteractionId', type: 'string' }
  { name: 'SessionId', type: 'string' }
  { name: 'RequestId', type: 'string' }
  { name: 'InteractionType', type: 'string' }
  { name: 'AppClass', type: 'string' }
  { name: 'ConversationType', type: 'string' }
  { name: 'Locale', type: 'string' }
  { name: 'Etag', type: 'string' }
  { name: 'UserId', type: 'string' }
  { name: 'UserPrincipalName', type: 'string' }
  { name: 'FromUserId', type: 'string' }
  { name: 'FromApplicationId', type: 'string' }
  { name: 'FromApplicationName', type: 'string' }
  { name: 'BodyContentType', type: 'string' }
  { name: 'BodyContent', type: 'string' }
  { name: 'BodyTruncated', type: 'boolean' }
  { name: 'Attachments', type: 'string' }
  { name: 'AttachmentsTruncated', type: 'boolean' }
  { name: 'Contexts', type: 'dynamic' }
  { name: 'Links', type: 'dynamic' }
  { name: 'Mentions', type: 'dynamic' }
  { name: 'CollectionScope', type: 'string' }
  { name: 'CollectorRunId', type: 'string' }
  { name: 'CollectorVersion', type: 'string' }
]

var tableColumnTypes = {
  datetime: 'dateTime'
  string: 'string'
  boolean: 'boolean'
  dynamic: 'dynamic'
}

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: last(split(workspaceResourceId, '/'))
}

resource interactionTable 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = {
  parent: workspace
  name: tableName
  properties: {
    plan: 'Analytics'
    retentionInDays: retentionInDays
    totalRetentionInDays: retentionInDays
    schema: {
      name: tableName
      description: 'Microsoft 365 Copilot prompt and response content exported from the Microsoft Graph interaction export API.'
      columns: [for column in interactionColumns: {
        name: column.name
        type: tableColumnTypes[column.type]
      }]
    }
  }
}

resource collectorIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${resourceNamePrefix}-copilot-collector-id'
  location: location
  tags: tags
}

resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: '${resourceNamePrefix}-copilot-interaction-dcr'
  location: workspaceLocation
  kind: 'Direct'
  tags: tags
  properties: {
    description: 'Logs Ingestion API rule for Microsoft 365 Copilot interaction content.'
    streamDeclarations: {
      '${streamName}': {
        columns: interactionColumns
      }
    }
    destinations: {
      logAnalytics: [
        {
          name: 'governanceWorkspace'
          workspaceResourceId: workspaceResourceId
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          streamName
        ]
        destinations: [
          'governanceWorkspace'
        ]
        transformKql: 'source'
        outputStream: 'Custom-${tableName}'
      }
    ]
  }
  dependsOn: [
    interactionTable
  ]
}

resource dcrPublisher 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(dataCollectionRule.id, collectorIdentity.id, monitoringMetricsPublisherRoleId)
  scope: dataCollectionRule
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringMetricsPublisherRoleId)
    principalId: collectorIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    dnsEndpointType: 'Standard'
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Enabled'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }

  resource blobServices 'blobServices' = {
    name: 'default'

    resource deploymentContainer 'containers' = {
      name: deploymentContainerName
      properties: {
        publicAccess: 'None'
      }
    }

    resource stateContainer 'containers' = {
      name: stateContainerName
      properties: {
        publicAccess: 'None'
      }
    }
  }
}

resource storageBlobOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, collectorIdentity.id, storageBlobDataOwnerRoleId)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
    principalId: collectorIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${resourceNamePrefix}-copilot-collector-ai'
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspaceResourceId
    DisableLocalAuth: true
  }
}

resource appInsightsPublisher 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(applicationInsights.id, collectorIdentity.id, monitoringMetricsPublisherRoleId)
  scope: applicationInsights
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringMetricsPublisherRoleId)
    principalId: collectorIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: '${resourceNamePrefix}-copilot-collector-plan'
  location: location
  tags: tags
  kind: 'functionapp'
  sku: {
    tier: 'FlexConsumption'
    name: 'FC1'
  }
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${collectorIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storage.properties.primaryEndpoints.blob}${deploymentContainerName}'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: collectorIdentity.id
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 40
        instanceMemoryMB: 2048
      }
      runtime: {
        name: 'dotnet-isolated'
        version: '8.0'
      }
    }
  }

  resource appSettings 'config' = {
    name: 'appsettings'
    properties: {
      AzureWebJobsStorage__accountName: storage.name
      AzureWebJobsStorage__credential: 'managedidentity'
      AzureWebJobsStorage__clientId: collectorIdentity.properties.clientId
      APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString
      APPLICATIONINSIGHTS_AUTHENTICATION_STRING: 'ClientId=${collectorIdentity.properties.clientId};Authorization=AAD'
      Collector__ManagedIdentityClientId: collectorIdentity.properties.clientId
      Collector__Scope: collectionScope
      Collector__GroupId: collectionGroupId
      Collector__LogsIngestionEndpoint: dataCollectionRule.properties.endpoints.logsIngestion
      Collector__DataCollectionRuleImmutableId: dataCollectionRule.properties.immutableId
      Collector__StreamName: streamName
      Collector__StateBlobUri: '${storage.properties.primaryEndpoints.blob}${stateContainerName}/checkpoint.json'
      Collector__Version: solutionVersion
    }
  }
}

resource packageDeployment 'Microsoft.Web/sites/extensions@2024-04-01' = if (!empty(packageUri)) {
  parent: functionApp
  name: 'onedeploy'
  #disable-next-line BCP187
  properties: {
    packageUri: packageUri
    remoteBuild: false
  }
  dependsOn: [
    functionApp::appSettings
    storageBlobOwner
  ]
}

output tableName string = tableName
output dataCollectionRuleId string = dataCollectionRule.id
output functionAppId string = functionApp.id
output functionAppName string = functionApp.name
output managedIdentityResourceId string = collectorIdentity.id
output managedIdentityPrincipalId string = collectorIdentity.properties.principalId
output managedIdentityClientId string = collectorIdentity.properties.clientId
output deployedResourceIds array = [
  interactionTable.id
  collectorIdentity.id
  dataCollectionRule.id
  storage.id
  applicationInsights.id
  plan.id
  functionApp.id
]
