targetScope = 'resourceGroup'

@description('Resource ID of the Log Analytics workspace to onboard.')
param workspaceResourceId string

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: last(split(workspaceResourceId, '/'))
}

resource onboardingState 'Microsoft.SecurityInsights/onboardingStates@2024-03-01' = {
  scope: workspace
  name: 'default'
  properties: {
    customerManagedKey: false
  }
}

output sentinelOnboardingStateResourceId string = onboardingState.id
output sentinelOnboardingStateProperties object = onboardingState.properties
