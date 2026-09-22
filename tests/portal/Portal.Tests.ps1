BeforeAll {
    $script:RepositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $portalRoot = Join-Path $script:RepositoryRoot 'infra/portal'
    $script:PortalFiles = if (Test-Path -LiteralPath $portalRoot) {
        @(Get-ChildItem -LiteralPath $portalRoot -Recurse -File -Filter 'createUiDefinition.json')
    }
    else {
        @()
    }
    $script:ExistingWorkspacePortalPath = Join-Path $portalRoot 'existing-workspace/createUiDefinition.json'
    $script:ExistingWorkspaceTemplatePath = Join-Path $script:RepositoryRoot 'infra/compiled/existing-workspace.json'
}

Describe 'Azure portal definitions' {
    It 'contains valid createUiDefinition contracts when present' {
        foreach ($file in $script:PortalFiles) {
            $definition = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -Depth 100
            $definition.'$schema' | Should -Match 'CreateUIDefinition'
            $definition.handler | Should -Be 'Microsoft.Azure.CreateUIDef'
            $definition.version | Should -Not -BeNullOrEmpty
            $definition.parameters.PSObject.Properties.Name | Should -Contain 'basics'
            $definition.parameters.steps | Should -Not -BeNull
            $definition.parameters.outputs | Should -Not -BeNull
        }
    }

    It 'uses the built-in Basics scope and a Log Analytics workspace picker for the existing-workspace path' {
        $definition = Get-Content -LiteralPath $script:ExistingWorkspacePortalPath -Raw | ConvertFrom-Json -Depth 100
        $workspaceStep = @($definition.parameters.steps | Where-Object name -eq 'workspace')
        $workspaceStep | Should -HaveCount 1
        $selector = @($workspaceStep[0].elements | Where-Object type -eq 'Microsoft.Solutions.ResourceSelector')
        $selector | Should -HaveCount 1
        $selector[0].name | Should -Be 'workspaceSelector'
        $selector[0].resourceType | Should -Be 'Microsoft.OperationalInsights/workspaces'
        $selector[0].options.filter.subscription | Should -Be 'onBasics'
        $selector[0].options.filter.location | Should -Be 'all'

        $definition.parameters.config.basics.resourceGroup.allowExisting | Should -BeTrue
        $definition.parameters.config.basics.location.visible | Should -BeFalse
        @($definition.parameters.basics) | Should -HaveCount 0
    }

    It 'does not define a ResourceGroup control anywhere in the existing-workspace definition' {
        $definition = Get-Content -LiteralPath $script:ExistingWorkspacePortalPath -Raw | ConvertFrom-Json -Depth 100
        ($definition | ConvertTo-Json -Depth 100) |
            Should -Not -Match '"type"\s*:\s*"Microsoft\.Common\.ResourceGroup"'
    }

    It 'limits the existing-workspace ResourceSelector filter to supported keys' {
        $definition = Get-Content -LiteralPath $script:ExistingWorkspacePortalPath -Raw | ConvertFrom-Json -Depth 100
        $workspaceStep = @($definition.parameters.steps | Where-Object name -eq 'workspace')
        $selector = @($workspaceStep[0].elements | Where-Object type -eq 'Microsoft.Solutions.ResourceSelector')
        $filterKeys = @($selector[0].options.filter.PSObject.Properties.Name | Sort-Object)

        $filterKeys | Should -Be @('location', 'subscription')
    }

    It 'derives existing-workspace outputs and does not expose internal parameters as controls' {
        $definition = Get-Content -LiteralPath $script:ExistingWorkspacePortalPath -Raw | ConvertFrom-Json -Depth 100
        $elements = @($definition.parameters.steps | ForEach-Object { $_.elements })
        $elementNames = @($elements.name)

        @($elements | Where-Object type -eq 'Microsoft.Common.Location') | Should -HaveCount 0
        @($elements | Where-Object {
            $_.type -eq 'Microsoft.Common.TextBox' -and
            ($_.name -eq 'workspaceResourceId' -or $_.label -match '(?i)workspace resource ID')
        }) | Should -HaveCount 0

        foreach ($hiddenName in 'solutionName', 'solutionVersion', 'resourceNamePrefix', 'tags', 'workspaceResourceId', 'location') {
            $elementNames | Should -Not -Contain $hiddenName
        }

        $definition.parameters.outputs.location | Should -Be "[steps('workspace').workspaceSelector.location]"
        $definition.parameters.outputs.workspaceResourceId | Should -Be "[steps('workspace').workspaceSelector.id]"
        $definition.parameters.outputs.solutionName | Should -Be 'm365CopilotGovernance'
        $definition.parameters.outputs.solutionVersion | Should -Be '0.1.1'
        $definition.parameters.outputs.resourceNamePrefix | Should -Be 'm365gov'
        @($definition.parameters.outputs.tags.PSObject.Properties).Count | Should -Be 0
    }

    It 'keeps analytics opt-in behavior safe and explains the Sentinel selector limitation' {
        $definition = Get-Content -LiteralPath $script:ExistingWorkspacePortalPath -Raw | ConvertFrom-Json -Depth 100
        $elements = @($definition.parameters.steps | ForEach-Object { $_.elements })
        $analyticsEnabled = @($elements | Where-Object name -eq 'analyticsEnabled')
        $analyticsEnabled | Should -HaveCount 1
        $analyticsEnabled[0].defaultValue | Should -BeFalse
        $analyticsEnabled[0].visible | Should -Be "[steps('content').deployAnalytics]"

        $sentinelWarning = @($elements | Where-Object name -eq 'sentinelRequirement')
        $sentinelWarning | Should -HaveCount 1
        $sentinelWarning[0].type | Should -Be 'Microsoft.Common.InfoBox'
        $sentinelWarning[0].options.icon | Should -Be 'Warning'
        $sentinelWarning[0].options.text | Should -Match 'cannot detect Microsoft Sentinel onboarding'
    }

    It 'maps every existing-workspace template parameter exactly once' {
        $definition = Get-Content -LiteralPath $script:ExistingWorkspacePortalPath -Raw | ConvertFrom-Json -Depth 100
        $template = Get-Content -LiteralPath $script:ExistingWorkspaceTemplatePath -Raw | ConvertFrom-Json -Depth 100
        $uiOutputs = @($definition.parameters.outputs.PSObject.Properties.Name | Sort-Object)
        $templateParameters = @($template.parameters.PSObject.Properties.Name | Sort-Object)

        $uiOutputs | Should -Be $templateParameters
        @($uiOutputs | Select-Object -Unique) | Should -HaveCount $uiOutputs.Count
    }
}
