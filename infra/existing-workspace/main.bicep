targetScope = 'resourceGroup'

@description('Azure region used for regional content resources such as workbooks.')
param location string = resourceGroup().location

@minLength(1)
@description('Stable solution identifier.')
param solutionName string = 'm365CopilotGovernance'

@minLength(1)
@description('Solution content version.')
param solutionVersion string = '0.2.0'

@minLength(1)
@maxLength(32)
@description('Prefix used for deployment names and metadata.')
param resourceNamePrefix string = 'm365gov'

@description('Whether KQL functions should be deployed.')
param deployFunctions bool = true

@description('Whether analytic rule resources should be deployed.')
param deployAnalytics bool = true

@description('Whether workbook resources should be deployed.')
param deployWorkbooks bool = true

@description('Resource tags applied where supported.')
param tags object = {}

@allowed([
  'Enabled'
  'Disabled'
])
@description('Required decision: Enabled deploys the collector that exports Microsoft 365 Copilot prompt and response content into the workspace for 90 days. Disabled deploys no collector.')
param interactionContentCollection string

@allowed([
  'AllLicensedUsers'
  'IncludeGroup'
  'ExcludeGroup'
])
@description('Users whose interactions are collected: every Copilot-licensed user, only members of a group, or every licensed user except members of a group.')
param interactionCollectionScope string = 'AllLicensedUsers'

@description('Microsoft Entra group object ID. Required when interactionCollectionScope is IncludeGroup or ExcludeGroup.')
param interactionCollectionGroupId string = ''

@description('HTTPS URL of the collector released-package.zip. Empty deploys collector infrastructure without code.')
param interactionCollectorPackageUri string = 'https://github.com/x3nc0n/m365-copilot-governance-foundation/releases/download/v${solutionVersion}/released-package.zip'

@minLength(1)
@description('Full resource ID of an existing Log Analytics workspace. Workspace settings are not modified.')
param workspaceResourceId string

var workspaceResourceIdSegments = split(workspaceResourceId, '/')
var workspaceSubscriptionId = workspaceResourceIdSegments[2]
var workspaceResourceGroupName = workspaceResourceIdSegments[4]
var workspaceName = last(workspaceResourceIdSegments)
var interactionContentEnabled = interactionContentCollection == 'Enabled'
var solutionTags = union(tags, {
  Solution: solutionName
  SolutionVersion: solutionVersion
  ResourceNamePrefix: resourceNamePrefix
  DeploymentMode: 'existing-workspace'
})

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  scope: resourceGroup(workspaceSubscriptionId, workspaceResourceGroupName)
  name: workspaceName
}

resource sentinelOnboardingState 'Microsoft.SecurityInsights/onboardingStates@2024-03-01' existing = {
  scope: workspace
  name: 'default'
}

module interactionCollector '../modules/interaction-collector/main.bicep' = if (interactionContentEnabled) {
  name: '${resourceNamePrefix}-interaction-collector'
  scope: resourceGroup(workspaceSubscriptionId, workspaceResourceGroupName)
  params: {
    location: location
    workspaceLocation: workspace.location
    workspaceResourceId: workspace.id
    resourceNamePrefix: resourceNamePrefix
    collectionScope: interactionCollectionScope
    collectionGroupId: interactionCollectionGroupId
    packageUri: interactionCollectorPackageUri
    solutionVersion: solutionVersion
    tags: solutionTags
  }
}

module content '../modules/content/main.bicep' = {
  name: '${resourceNamePrefix}-content'
  scope: resourceGroup(workspaceSubscriptionId, workspaceResourceGroupName)
  params: {
    location: location
    workspaceResourceId: workspace.id
    deployFunctions: deployFunctions
    deployAnalytics: deployAnalytics
    deployWorkbooks: deployWorkbooks
    interactionContentEnabled: interactionContentEnabled
    sentinelOnboardingStateProperties: sentinelOnboardingState.properties
    tags: solutionTags
  }
  dependsOn: [
    interactionCollector
  ]
}

output solutionVersion string = solutionVersion
output deploymentMode string = 'existing-workspace'
output workspaceResourceId string = workspace.id
output sentinelOnboardingStateResourceId string = sentinelOnboardingState.id
output functionResourceIds array = content.outputs.functionResourceIds
output analyticRuleResourceIds array = content.outputs.analyticRuleResourceIds
output workbookResourceIds array = content.outputs.workbookResourceIds
output interactionContentCollection string = interactionContentCollection
output interactionCollectorPrincipalId string = interactionContentEnabled ? interactionCollector!.outputs.managedIdentityPrincipalId : ''
output interactionCollectorResourceIds array = interactionContentEnabled ? interactionCollector!.outputs.deployedResourceIds : []
output deployedResourceIds array = concat(
  content.outputs.deployedResourceIds,
  interactionContentEnabled ? interactionCollector!.outputs.deployedResourceIds : []
)
