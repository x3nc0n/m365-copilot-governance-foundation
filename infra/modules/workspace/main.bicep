targetScope = 'resourceGroup'

@description('Azure region for the Log Analytics workspace.')
param location string = resourceGroup().location

@minLength(4)
@maxLength(63)
@description('Name of the Log Analytics workspace.')
param workspaceName string

@allowed([
  'CapacityReservation'
  'Free'
  'LACluster'
  'PerGB2018'
  'PerNode'
  'Premium'
  'Standalone'
  'Standard'
])
@description('Log Analytics workspace SKU.')
param workspaceSku string = 'PerGB2018'

@minValue(30)
@maxValue(730)
@description('Workspace retention in days.')
param workspaceRetentionInDays int = 30

@description('Resource tags applied to the workspace.')
param tags object = {}

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: workspaceSku
    }
    retentionInDays: workspaceRetentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output workspaceResourceId string = workspace.id
output workspaceName string = workspace.name
output workspaceLocation string = workspace.location
