targetScope = 'resourceGroup'

@description('Azure region for workbook resources.')
param location string = resourceGroup().location

@description('Resource ID of the target Log Analytics workspace.')
param workspaceResourceId string

@description('Whether workbook resources should be deployed.')
param deployWorkbooks bool = true

@description('Workbook definitions from generated/content-manifest.json.')
param workbooks array = []

@description('Resource tags applied to workbook resources.')
param tags object = {}

resource workbookResources 'Microsoft.Insights/workbooks@2023-06-01' = [
  for workbook in workbooks: if (deployWorkbooks) {
    name: guid(workspaceResourceId, workbook.resourceName)
    location: location
    kind: 'shared'
    tags: union(tags, {
      Solution: 'M365 Copilot Governance'
      SolutionResourceName: workbook.resourceName
      ControlOwner: workbook.controlOwner
    })
    properties: {
      category: 'sentinel'
      description: workbook.description
      displayName: workbook.displayName
      serializedData: workbook.serializedData
      sourceId: workspaceResourceId
      version: workbook.version
    }
  }
]

var deployedWorkbookResourceIds = [for (workbook, index) in workbooks: workbookResources[index].id]

output workbookResourceIds array = deployWorkbooks ? deployedWorkbookResourceIds : []
