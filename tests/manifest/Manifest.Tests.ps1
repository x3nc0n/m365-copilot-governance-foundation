BeforeAll {
    $script:RepositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:Generator = Join-Path $script:RepositoryRoot 'build/New-ContentManifest.ps1'
    $script:Manifest = Join-Path $script:RepositoryRoot 'generated/content-manifest.json'
    $script:VerifyRoot = Join-Path $script:RepositoryRoot 'build/.verify/manifest-line-endings'
    . (Join-Path $script:RepositoryRoot 'build/Common.ps1')
}

AfterAll {
    if (Test-Path -LiteralPath $script:VerifyRoot) {
        Remove-Item -LiteralPath $script:VerifyRoot -Recurse -Force
    }
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
            Get-NormalizedTextSha256 -Path $source | Should -Be $entry.sha256
        }
    }

    It 'produces identical manifests from LF and CRLF text sources' {
        $lfRoot = Join-Path $script:VerifyRoot 'lf'
        $crlfRoot = Join-Path $script:VerifyRoot 'crlf'
        foreach ($fixtureRoot in $lfRoot, $crlfRoot) {
            New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $script:RepositoryRoot 'schemas') -Destination $fixtureRoot -Recurse
            Copy-Item -LiteralPath (Join-Path $script:RepositoryRoot 'src') -Destination $fixtureRoot -Recurse
        }

        $sourcePatterns = @('*.kql', '*.workbook.json')
        foreach ($pattern in $sourcePatterns) {
            foreach ($file in Get-ChildItem -LiteralPath (Join-Path $lfRoot 'src') -Recurse -File -Filter $pattern) {
                $normalized = ConvertTo-LfText -Text ([System.IO.File]::ReadAllText($file.FullName))
                [System.IO.File]::WriteAllText($file.FullName, $normalized, [System.Text.UTF8Encoding]::new($false))
            }
            foreach ($file in Get-ChildItem -LiteralPath (Join-Path $crlfRoot 'src') -Recurse -File -Filter $pattern) {
                $normalized = ConvertTo-LfText -Text ([System.IO.File]::ReadAllText($file.FullName))
                [System.IO.File]::WriteAllText($file.FullName, $normalized.Replace("`n", "`r`n"), [System.Text.UTF8Encoding]::new($false))
            }
        }

        & $script:Generator -RepositoryRoot $lfRoot
        & $script:Generator -RepositoryRoot $crlfRoot

        $lfManifestPath = Join-Path $lfRoot 'generated/content-manifest.json'
        $crlfManifestPath = Join-Path $crlfRoot 'generated/content-manifest.json'
        (Get-FileHash -LiteralPath $lfManifestPath -Algorithm SHA256).Hash |
            Should -Be (Get-FileHash -LiteralPath $crlfManifestPath -Algorithm SHA256).Hash

        $manifest = Get-Content -LiteralPath $crlfManifestPath -Raw | ConvertFrom-Json -Depth 100
        foreach ($entry in @($manifest.functions) + @($manifest.analytics)) {
            $entry.query | Should -Not -Match "`r"
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
            $entry.query | Should -Be (Get-NormalizedTextContent -Path (Join-Path $script:RepositoryRoot $entry.source)).TrimEnd()
            $entry.functionParameters | Should -Not -Match '\b(?:ago|now)\s*\('
        }
        foreach ($entry in $manifest.analytics) {
            foreach ($property in $analyticProperties) {
                $entry.PSObject.Properties.Name | Should -Contain $property
            }
            $entry.query | Should -Be (Get-NormalizedTextContent -Path (Join-Path $script:RepositoryRoot $entry.source)).TrimEnd()
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
