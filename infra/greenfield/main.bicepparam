using './main.bicep'

param location = 'eastus'
param solutionName = 'm365CopilotGovernance'
param solutionVersion = '0.1.1'
param resourceNamePrefix = 'm365gov'
param deployFunctions = true
param deployAnalytics = true
param deployWorkbooks = true
param analyticsEnabled = false
param tags = {
  Environment: 'example'
}
param workspaceName = 'm365gov-example-law'
param workspaceSku = 'PerGB2018'
param workspaceRetentionInDays = 30
