targetScope = 'resourceGroup'

@description('Resource ID of the target Log Analytics workspace.')
param workspaceResourceId string

@description('Whether analytic rule resources should be deployed.')
param deployAnalytics bool = true

@description('Whether deployed analytic rules should be enabled.')
param analyticsEnabled bool = false

@description('Analytic rule definitions from generated/content-manifest.json.')
param analytics array = []

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: last(split(workspaceResourceId, '/'))
}

resource analyticRules 'Microsoft.SecurityInsights/alertRules@2024-03-01' = [
  for analytic in analytics: if (deployAnalytics) {
    scope: workspace
    name: guid(workspaceResourceId, analytic.resourceName)
    kind: 'Scheduled'
    properties: {
      alertDetailsOverride: analytic.alertDetailsOverride
      customDetails: analytic.customDetails
      description: analytic.description
      displayName: analytic.displayName
      enabled: analyticsEnabled && analytic.enabledByDefault
      entityMappings: analytic.entityMappings
      eventGroupingSettings: {
        aggregationKind: analytic.eventGroupingAggregationKind
      }
      incidentConfiguration: analytic.incidentConfiguration
      query: analytic.query
      queryFrequency: analytic.queryFrequency
      queryPeriod: analytic.queryPeriod
      severity: analytic.severity
      suppressionDuration: analytic.suppressionDuration
      suppressionEnabled: analytic.suppressionEnabled
      tactics: analytic.tactics
      techniques: analytic.techniques
      triggerOperator: analytic.triggerOperator
      triggerThreshold: analytic.triggerThreshold
    }
  }
]

var deployedAnalyticRuleResourceIds = [for (analytic, index) in analytics: analyticRules[index].id]

output analyticRuleResourceIds array = deployAnalytics ? deployedAnalyticRuleResourceIds : []
