targetScope = 'resourceGroup'

@description('Azure region for regional content resources.')
param location string = resourceGroup().location

@description('Resource ID of the target Log Analytics workspace.')
param workspaceResourceId string

@description('Whether KQL functions should be deployed.')
param deployFunctions bool = true

@description('Whether analytic rule resources should be deployed.')
param deployAnalytics bool = true

@description('Whether workbook resources should be deployed.')
param deployWorkbooks bool = true

@description('Whether deployed analytic rules should be enabled.')
param analyticsEnabled bool = false

@description('Sentinel onboarding-state value resolved before content deployment. This read fails when Sentinel is absent or unreadable.')
param sentinelCustomerManagedKey bool

@description('Resource tags applied where supported.')
param tags object = {}

var contentManifest = loadJsonContent('../../../generated/content-manifest.json')

module functions '../functions/main.bicep' = {
  name: 'm365-copilot-governance-functions'
  params: {
    workspaceResourceId: workspaceResourceId
    deployFunctions: deployFunctions
    functions: contentManifest.functions
  }
}

module analytics '../analytics/main.bicep' = {
  name: 'm365-copilot-governance-analytics'
  params: {
    workspaceResourceId: workspaceResourceId
    deployAnalytics: deployAnalytics
    analyticsEnabled: analyticsEnabled
    analytics: contentManifest.analytics
  }
}

module workbooks '../workbooks/main.bicep' = {
  name: 'm365-copilot-governance-workbooks'
  params: {
    location: location
    workspaceResourceId: workspaceResourceId
    deployWorkbooks: deployWorkbooks
    workbooks: contentManifest.workbooks
    tags: tags
  }
}

output contentManifestVersion string = contentManifest.solutionVersion
output sentinelCustomerManagedKey bool = sentinelCustomerManagedKey
output functionResourceIds array = functions.outputs.functionResourceIds
output analyticRuleResourceIds array = analytics.outputs.analyticRuleResourceIds
output workbookResourceIds array = workbooks.outputs.workbookResourceIds
output deployedResourceIds array = concat(
  functions.outputs.functionResourceIds,
  analytics.outputs.analyticRuleResourceIds,
  workbooks.outputs.workbookResourceIds
)
