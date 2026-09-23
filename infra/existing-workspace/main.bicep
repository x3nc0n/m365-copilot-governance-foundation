targetScope = 'resourceGroup'

@description('Azure region used for regional content resources such as workbooks.')
param location string = resourceGroup().location

@minLength(1)
@description('Stable solution identifier.')
param solutionName string = 'm365CopilotGovernance'

@minLength(1)
@description('Solution content version.')
param solutionVersion string = '0.1.2'

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

@description('Whether deployed analytic rules should be enabled.')
param analyticsEnabled bool = false

@description('Resource tags applied where supported.')
param tags object = {}

@minLength(1)
@description('Full resource ID of an existing Log Analytics workspace. Workspace settings are not modified.')
param workspaceResourceId string

var workspaceResourceIdSegments = split(workspaceResourceId, '/')
var workspaceSubscriptionId = workspaceResourceIdSegments[2]
var workspaceResourceGroupName = workspaceResourceIdSegments[4]
var workspaceName = last(workspaceResourceIdSegments)
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

module content '../modules/content/main.bicep' = {
  name: '${resourceNamePrefix}-content'
  scope: resourceGroup(workspaceSubscriptionId, workspaceResourceGroupName)
  params: {
    location: location
    workspaceResourceId: workspace.id
    deployFunctions: deployFunctions
    deployAnalytics: deployAnalytics
    deployWorkbooks: deployWorkbooks
    analyticsEnabled: analyticsEnabled
    sentinelCustomerManagedKey: sentinelOnboardingState.properties.customerManagedKey
    tags: solutionTags
  }
}

output solutionVersion string = solutionVersion
output deploymentMode string = 'existing-workspace'
output workspaceResourceId string = workspace.id
output sentinelOnboardingStateResourceId string = sentinelOnboardingState.id
output functionResourceIds array = content.outputs.functionResourceIds
output analyticRuleResourceIds array = content.outputs.analyticRuleResourceIds
output workbookResourceIds array = content.outputs.workbookResourceIds
output deployedResourceIds array = content.outputs.deployedResourceIds
