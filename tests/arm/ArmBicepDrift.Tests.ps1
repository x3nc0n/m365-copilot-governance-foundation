BeforeAll {
    $script:RepositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:VerifyRoot = Join-Path $script:RepositoryRoot 'build/.verify'
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
