targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@minLength(1)
@description('Stable solution identifier.')
param solutionName string = 'm365CopilotGovernance'

@minLength(1)
@description('Solution content version.')
param solutionVersion string = '0.1.1'

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

@description('Whether deployed analytic rules should be enabled.')
param analyticsEnabled bool = false

@description('Resource tags applied where supported.')
param tags object = {}

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

module content '../modules/content/main.bicep' = {
  name: '${resourceNamePrefix}-content'
  params: {
    location: location
    workspaceResourceId: workspace.outputs.workspaceResourceId
    deployFunctions: deployFunctions
    deployAnalytics: deployAnalytics
    deployWorkbooks: deployWorkbooks
    analyticsEnabled: analyticsEnabled
    sentinelCustomerManagedKey: sentinel.outputs.sentinelCustomerManagedKey
    tags: solutionTags
  }
}

output solutionVersion string = solutionVersion
output deploymentMode string = 'greenfield'
output workspaceResourceId string = workspace.outputs.workspaceResourceId
output sentinelOnboardingStateResourceId string = sentinel.outputs.sentinelOnboardingStateResourceId
output functionResourceIds array = content.outputs.functionResourceIds
output analyticRuleResourceIds array = content.outputs.analyticRuleResourceIds
output workbookResourceIds array = content.outputs.workbookResourceIds
output deployedResourceIds array = concat(
  [
    workspace.outputs.workspaceResourceId
    sentinel.outputs.sentinelOnboardingStateResourceId
  ],
  content.outputs.deployedResourceIds
)
