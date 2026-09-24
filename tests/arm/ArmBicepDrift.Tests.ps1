BeforeAll {
    $script:RepositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:VerifyRoot = Join-Path $script:RepositoryRoot 'build/.verify'

    function Get-NestedArmResource {
        param(
            [Parameter(Mandatory)]
            [object]$Template
        )

        foreach ($resource in @($Template.resources)) {
            $resource
            if (
                $resource.PSObject.Properties.Name -contains 'properties' -and
                $resource.properties.PSObject.Properties.Name -contains 'template'
            ) {
                Get-NestedArmResource -Template $resource.properties.template
            }
        }
    }
}

AfterAll {
    if (Test-Path -LiteralPath $script:VerifyRoot) {
        Remove-Item -LiteralPath $script:VerifyRoot -Recurse -Force
    }
}

Describe 'ARM and Bicep drift' {
    It 'matches compiled artifacts when Azure CLI and source entry points exist' {
        $az = Get-Command az -ErrorAction SilentlyContinue
        if (-not $az) {
            Set-ItResult -Skipped -Because 'Azure CLI is not installed.'
            return
        }
        $entries = @{
            'infra/greenfield/main.bicep' = 'infra/compiled/greenfield.json'
            'infra/existing-workspace/main.bicep' = 'infra/compiled/existing-workspace.json'
        }
        foreach ($entry in $entries.GetEnumerator()) {
            $source = Join-Path $script:RepositoryRoot $entry.Key
            if (-not (Test-Path -LiteralPath $source)) {
                continue
            }
            $expected = Join-Path $script:RepositoryRoot $entry.Value
            Test-Path -LiteralPath $expected | Should -BeTrue
            New-Item -ItemType Directory -Path $script:VerifyRoot -Force | Out-Null
            $actual = Join-Path $script:VerifyRoot ([System.IO.Path]::GetFileName($expected))
            & $az.Source bicep build --file $source --outfile $actual
            $LASTEXITCODE | Should -Be 0
            (Get-FileHash -LiteralPath $actual -Algorithm SHA256).Hash | Should -Be (Get-FileHash -LiteralPath $expected -Algorithm SHA256).Hash
        }
    }

    It 'builds both sample Bicep parameter files' {
        $az = Get-Command az -ErrorAction SilentlyContinue
        if (-not $az) {
            Set-ItResult -Skipped -Because 'Azure CLI is not installed.'
            return
        }
        $parameterFiles = @(
            'infra/greenfield/main.bicepparam'
            'infra/existing-workspace/main.bicepparam'
        )
        New-Item -ItemType Directory -Path $script:VerifyRoot -Force | Out-Null
        foreach ($relativePath in $parameterFiles) {
            $source = Join-Path $script:RepositoryRoot $relativePath
            $output = Join-Path $script:VerifyRoot "$([System.IO.Path]::GetFileName((Split-Path -Parent $source)))-parameters.json"
            & $az.Source bicep build-params --file $source --outfile $output
            $LASTEXITCODE | Should -Be 0
            Test-Path -LiteralPath $output -PathType Leaf | Should -BeTrue
            { Get-Content -LiteralPath $output -Raw | ConvertFrom-Json -Depth 100 } | Should -Not -Throw
        }
    }

    It 'requires a readable Sentinel onboarding state before existing-workspace content deployment' {
        $source = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot 'infra/existing-workspace/main.bicep') -Raw
        $source | Should -Match 'sentinelOnboardingStateProperties:\s*sentinelOnboardingState\.properties'
        $source | Should -Not -Match 'sentinelOnboardingState\.properties\.customerManagedKey'

        $templatePath = Join-Path $script:RepositoryRoot 'infra/compiled/existing-workspace.json'
        $templateRaw = Get-Content -LiteralPath $templatePath -Raw
        $templateRaw | Should -Match '"sentinelOnboardingStateProperties"'
        $templateRaw | Should -Match 'Microsoft\.SecurityInsights/onboardingStates'
        $templateRaw | Should -Not -Match '\.customerManagedKey'

        $template = $templateRaw | ConvertFrom-Json -Depth 100
        $contentDeployment = $template.resources |
            Where-Object { $_.type -eq 'Microsoft.Resources/deployments' -and $_.name -match 'content' } |
            Select-Object -First 1
        $contentDeployment.properties.parameters.sentinelOnboardingStateProperties.value |
            Should -Match '^(\[reference\().*Microsoft\.SecurityInsights/onboardingStates'
        $contentDeployment.properties.template.parameters.sentinelOnboardingStateProperties.type |
            Should -Be 'object'
    }

    It 'uses resource-valid saved-search versions and omits empty analytic entity mappings' {
        foreach ($relativePath in @(
            'infra/compiled/greenfield.json'
            'infra/compiled/existing-workspace.json'
        )) {
            $templateRaw = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot $relativePath) -Raw
            $template = $templateRaw | ConvertFrom-Json -Depth 100
            $resources = @(Get-NestedArmResource -Template $template)

            $savedSearchResources = @(
                $resources |
                    Where-Object type -eq 'Microsoft.OperationalInsights/workspaces/savedSearches'
            )
            $savedSearchResources | Should -Not -BeNullOrEmpty -Because $relativePath
            foreach ($resource in $savedSearchResources) {
                $resource.properties.version | Should -BeOfType ([long])
                $resource.properties.version | Should -Be 1
            }

            $analyticResources = @(
                $resources |
                    Where-Object type -eq 'Microsoft.SecurityInsights/alertRules'
            )
            $analyticResources | Should -Not -BeNullOrEmpty -Because $relativePath
            foreach ($resource in $analyticResources) {
                $resource.properties | Should -Match "if\(empty\(.*\.entityMappings\), createObject\(\), createObject\('entityMappings', .*\.entityMappings\)\)"
            }

            $contentDeployment = $template.resources |
                Where-Object { $_.type -eq 'Microsoft.Resources/deployments' -and $_.name -match 'content' } |
                Select-Object -First 1
            $contentManifest = $contentDeployment.properties.template.variables.PSObject.Properties.Value |
                Where-Object {
                    $_ -isnot [string] -and
                    $_.PSObject.Properties.Name -contains 'analytics'
                } |
                Select-Object -First 1
            @($contentManifest.analytics | Where-Object { @($_.entityMappings).Count -eq 0 }) |
                Should -HaveCount 1
            @($contentManifest.analytics | Where-Object { @($_.entityMappings).Count -gt 0 }) |
                Should -HaveCount 2
        }
    }

    It 'embeds four functions, three analytics, and four workbooks with deployable properties' {
        $compiledTemplates = @(
            'infra/compiled/greenfield.json'
            'infra/compiled/existing-workspace.json'
        )
        $requiredProperties = @{
            functions = @('resourceName', 'displayName', 'query', 'functionAlias', 'functionParameters', 'version', 'category', 'controlOwner')
            analytics = @(
                'resourceName', 'displayName', 'description', 'enabledByDefault', 'severity', 'query',
                'queryFrequency', 'queryPeriod', 'triggerOperator', 'triggerThreshold',
                'suppressionDuration', 'suppressionEnabled', 'eventGroupingAggregationKind',
                'incidentConfiguration', 'entityMappings', 'alertDetailsOverride', 'customDetails',
                'tactics', 'techniques'
            )
            workbooks = @('resourceName', 'displayName', 'description', 'serializedData', 'version', 'controlOwner')
        }
        $expectedCounts = @{
            functions = 4
            analytics = 3
            workbooks = 4
        }

        foreach ($relativePath in $compiledTemplates) {
            $template = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot $relativePath) -Raw | ConvertFrom-Json -Depth 100
            $manifest = @(
                $template.resources |
                    Where-Object { $_.type -eq 'Microsoft.Resources/deployments' -and $_.name -match 'content' } |
                    ForEach-Object { $_.properties.template.variables.PSObject.Properties.Value } |
                    Where-Object {
                        $_ -isnot [string] -and
                        $_.PSObject.Properties.Name -contains 'functions' -and
                        $_.PSObject.Properties.Name -contains 'analytics' -and
                        $_.PSObject.Properties.Name -contains 'workbooks'
                    }
            ) | Select-Object -First 1

            $manifest | Should -Not -BeNullOrEmpty -Because $relativePath
            foreach ($kind in 'functions', 'analytics', 'workbooks') {
                @($manifest.$kind) | Should -HaveCount $expectedCounts[$kind] -Because "$relativePath must deploy every $kind entry"
                foreach ($entry in $manifest.$kind) {
                    foreach ($property in $requiredProperties[$kind]) {
                        $entry.PSObject.Properties.Name | Should -Contain $property -Because "$relativePath $kind entries must satisfy the module contract"
                    }
                }
            }
        }
    }
}
