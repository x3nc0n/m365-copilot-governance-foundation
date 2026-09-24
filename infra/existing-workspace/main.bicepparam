using './main.bicep'

param location = 'eastus'
param solutionName = 'm365CopilotGovernance'
param solutionVersion = '0.1.3'
param resourceNamePrefix = 'm365gov'
param deployFunctions = true
param deployAnalytics = true
param deployWorkbooks = true
param analyticsEnabled = false
param tags = {
  Environment: 'example'
}
param workspaceResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-monitoring-rg/providers/Microsoft.OperationalInsights/workspaces/example-law'
