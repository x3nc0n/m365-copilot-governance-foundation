targetScope = 'resourceGroup'

@description('Resource ID of the target Log Analytics workspace.')
param workspaceResourceId string

@description('Whether KQL functions should be deployed.')
param deployFunctions bool = true

@description('KQL function definitions from generated/content-manifest.json.')
param functions array = []

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: last(split(workspaceResourceId, '/'))
}

resource savedSearches 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = [
  for functionDefinition in functions: if (deployFunctions) {
    parent: workspace
    name: functionDefinition.resourceName
    properties: {
      category: functionDefinition.category
      displayName: functionDefinition.displayName
      query: functionDefinition.query
      functionAlias: functionDefinition.functionAlias
      functionParameters: functionDefinition.functionParameters
      version: 1
      tags: [
        {
          name: 'Solution'
          value: 'M365 Copilot Governance'
        }
        {
          name: 'ControlOwner'
          value: functionDefinition.controlOwner
        }
      ]
    }
  }
]

var deployedFunctionResourceIds = [for (functionDefinition, index) in functions: savedSearches[index].id]

output functionResourceIds array = deployFunctions ? deployedFunctionResourceIds : []
