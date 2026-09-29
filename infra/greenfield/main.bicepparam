using './main.bicep'

param location = 'eastus'
param solutionName = 'm365CopilotGovernance'
param solutionVersion = '0.2.0'
param resourceNamePrefix = 'm365gov'
param deployFunctions = true
param deployAnalytics = true
param deployWorkbooks = true
// Required decision: 'Enabled' collects Copilot prompt and response content for 90 days; 'Disabled' deploys no collector.
param interactionContentCollection = 'Disabled'
param interactionCollectionScope = 'AllLicensedUsers'
param interactionCollectionGroupId = ''
param tags = {
  Environment: 'example'
}
param workspaceName = 'm365gov-example-law'
param workspaceSku = 'PerGB2018'
param workspaceRetentionInDays = 30
