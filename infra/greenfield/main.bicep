targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@minLength(1)
@description('Stable solution identifier.')
param solutionName string = 'm365CopilotGovernance'

@minLength(1)
@description('Solution content version.')
param solutionVersion string = '0.2.0'

@minLength(1)
@maxLength(32)
@description('Prefix used for deployable resource names.')
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

@minLength(4)
@maxLength(63)
@description('Name of the Log Analytics workspace to create.')
param workspaceName string

@description('Log Analytics workspace SKU.')
param workspaceSku string = 'PerGB2018'

@minValue(30)
@maxValue(730)
@description('Workspace retention in days.')
param workspaceRetentionInDays int = 30

var interactionContentEnabled = interactionContentCollection == 'Enabled'
var solutionTags = union(tags, {
  Solution: solutionName
  SolutionVersion: solutionVersion
  ResourceNamePrefix: resourceNamePrefix
  DeploymentMode: 'greenfield'
})

module workspace '../modules/workspace/main.bicep' = {
  name: '${resourceNamePrefix}-workspace'
  params: {
    location: location
    workspaceName: workspaceName
    workspaceSku: workspaceSku
    workspaceRetentionInDays: workspaceRetentionInDays
    tags: solutionTags
  }
}

module sentinel '../modules/sentinel/main.bicep' = {
  name: '${resourceNamePrefix}-sentinel'
  params: {
    workspaceResourceId: workspace.outputs.workspaceResourceId
  }
}

module interactionCollector '../modules/interaction-collector/main.bicep' = if (interactionContentEnabled) {
  name: '${resourceNamePrefix}-interaction-collector'
  params: {
    location: location
    workspaceLocation: workspace.outputs.workspaceLocation
    workspaceResourceId: workspace.outputs.workspaceResourceId
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
  params: {
    location: location
    workspaceResourceId: workspace.outputs.workspaceResourceId
    deployFunctions: deployFunctions
    deployAnalytics: deployAnalytics
    deployWorkbooks: deployWorkbooks
    interactionContentEnabled: interactionContentEnabled
    sentinelOnboardingStateProperties: sentinel.outputs.sentinelOnboardingStateProperties
    tags: solutionTags
  }
  dependsOn: [
    interactionCollector
  ]
}

output solutionVersion string = solutionVersion
output deploymentMode string = 'greenfield'
output workspaceResourceId string = workspace.outputs.workspaceResourceId
output sentinelOnboardingStateResourceId string = sentinel.outputs.sentinelOnboardingStateResourceId
output functionResourceIds array = content.outputs.functionResourceIds
output analyticRuleResourceIds array = content.outputs.analyticRuleResourceIds
output workbookResourceIds array = content.outputs.workbookResourceIds
output interactionContentCollection string = interactionContentCollection
output interactionCollectorPrincipalId string = interactionContentEnabled ? interactionCollector!.outputs.managedIdentityPrincipalId : ''
output interactionCollectorResourceIds array = interactionContentEnabled ? interactionCollector!.outputs.deployedResourceIds : []
output deployedResourceIds array = concat(
  [
    workspace.outputs.workspaceResourceId
    sentinel.outputs.sentinelOnboardingStateResourceId
  ],
  content.outputs.deployedResourceIds,
  interactionContentEnabled ? interactionCollector!.outputs.deployedResourceIds : []
)
