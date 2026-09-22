BeforeAll {
    $script:RepositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:Generator = Join-Path $script:RepositoryRoot 'build/New-ContentManifest.ps1'
    $script:Manifest = Join-Path $script:RepositoryRoot 'generated/content-manifest.json'
}

Describe 'Content manifest generation' {
    It 'is byte-for-byte deterministic' {
        & $script:Generator -RepositoryRoot $script:RepositoryRoot
        $first = (Get-FileHash -LiteralPath $script:Manifest -Algorithm SHA256).Hash
        & $script:Generator -RepositoryRoot $script:RepositoryRoot
        $second = (Get-FileHash -LiteralPath $script:Manifest -Algorithm SHA256).Hash
        $second | Should -Be $first
    }

    It 'is sorted by id within each exact content array' {
        $manifest = Get-Content -LiteralPath $script:Manifest -Raw | ConvertFrom-Json -Depth 100
        foreach ($kind in 'functions', 'analytics', 'workbooks') {
            $ids = @($manifest.$kind.id)
            $ids | Should -Be @($ids | Sort-Object)
            $ids | Select-Object -Unique | Should -HaveCount $ids.Count
        }
    }

    It 'contains hashes matching every referenced source' {
        $manifest = Get-Content -LiteralPath $script:Manifest -Raw | ConvertFrom-Json -Depth 100
        foreach ($entry in @($manifest.functions) + @($manifest.analytics) + @($manifest.workbooks)) {
            $source = Join-Path $script:RepositoryRoot $entry.source
            Test-Path -LiteralPath $source | Should -BeTrue
            (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() | Should -Be $entry.sha256
        }
    }

    It 'contains the exact deployable content counts and required module properties' {
        $manifest = Get-Content -LiteralPath $script:Manifest -Raw | ConvertFrom-Json -Depth 100
        @($manifest.functions) | Should -HaveCount 4
        @($manifest.analytics) | Should -HaveCount 3
        @($manifest.workbooks) | Should -HaveCount 4

        $functionProperties = @(
            'resourceName', 'displayName', 'query', 'functionAlias',
            'functionParameters', 'version', 'category', 'controlOwner'
        )
        $analyticProperties = @(
            'resourceName', 'displayName', 'description', 'enabledByDefault', 'severity',
            'query', 'queryFrequency', 'queryPeriod', 'triggerOperator', 'triggerThreshold',
            'suppressionDuration', 'suppressionEnabled', 'eventGroupingAggregationKind',
            'incidentConfiguration', 'entityMappings', 'alertDetailsOverride', 'customDetails',
            'tactics', 'techniques'
        )
        $workbookProperties = @(
            'resourceName', 'displayName', 'description', 'serializedData', 'version', 'controlOwner'
        )

        foreach ($entry in $manifest.functions) {
            foreach ($property in $functionProperties) {
                $entry.PSObject.Properties.Name | Should -Contain $property
            }
            $entry.query | Should -Be (Get-Content -LiteralPath (Join-Path $script:RepositoryRoot $entry.source) -Raw).TrimEnd()
        }
        foreach ($entry in $manifest.analytics) {
            foreach ($property in $analyticProperties) {
                $entry.PSObject.Properties.Name | Should -Contain $property
            }
            $entry.query | Should -Be (Get-Content -LiteralPath (Join-Path $script:RepositoryRoot $entry.source) -Raw).TrimEnd()
            $entry.incidentConfiguration.groupingConfiguration.matchingMethod | Should -Be 'AllEntities'
        }
        foreach ($entry in $manifest.workbooks) {
            foreach ($property in $workbookProperties) {
                $entry.PSObject.Properties.Name | Should -Contain $property
            }
            { $entry.serializedData | ConvertFrom-Json -Depth 100 } | Should -Not -Throw
        }
    }
}
