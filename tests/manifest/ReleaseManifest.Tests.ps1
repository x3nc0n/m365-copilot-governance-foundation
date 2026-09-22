BeforeAll {
    $script:RepositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:Generator = Join-Path $script:RepositoryRoot 'build/New-ReleaseManifest.ps1'
    $script:ManifestPath = Join-Path $script:RepositoryRoot 'generated/release-manifest.json'
    $script:ChecksumPath = Join-Path $script:RepositoryRoot 'generated/checksums.sha256'
    $script:AssetRoot = Join-Path $script:RepositoryRoot 'generated/release-assets'
    $script:ExpectedAssets = @(
        'existing-workspace.createUiDefinition.json'
        'existing-workspace.json'
        'greenfield.createUiDefinition.json'
        'greenfield.json'
    )
}

Describe 'Release packaging' {
    It 'produces deterministic flattened assets with unique portal names' {
        & $script:Generator -RepositoryRoot $script:RepositoryRoot
        $firstManifestHash = (Get-FileHash -LiteralPath $script:ManifestPath -Algorithm SHA256).Hash
        $firstChecksumHash = (Get-FileHash -LiteralPath $script:ChecksumPath -Algorithm SHA256).Hash
        & $script:Generator -RepositoryRoot $script:RepositoryRoot

        (Get-FileHash -LiteralPath $script:ManifestPath -Algorithm SHA256).Hash | Should -Be $firstManifestHash
        (Get-FileHash -LiteralPath $script:ChecksumPath -Algorithm SHA256).Hash | Should -Be $firstChecksumHash

        $actualAssets = @(Get-ChildItem -LiteralPath $script:AssetRoot -File | Sort-Object Name | Select-Object -ExpandProperty Name)
        $actualAssets | Should -Be $script:ExpectedAssets
        @($actualAssets | Where-Object { $_ -like '*.createUiDefinition.json' }) | Should -HaveCount 2
        @($actualAssets | Select-Object -Unique) | Should -HaveCount 4
    }

    It 'lists every flattened asset in the manifest and checksum file' {
        $manifest = Get-Content -LiteralPath $script:ManifestPath -Raw | ConvertFrom-Json -Depth 100
        @($manifest.artifacts.path) | Should -Be $script:ExpectedAssets

        foreach ($artifact in $manifest.artifacts) {
            $assetPath = Join-Path $script:AssetRoot $artifact.path
            Test-Path -LiteralPath $assetPath -PathType Leaf | Should -BeTrue
            (Get-FileHash -LiteralPath $assetPath -Algorithm SHA256).Hash.ToLowerInvariant() | Should -Be $artifact.sha256
            (Get-Item -LiteralPath $assetPath).Length | Should -Be $artifact.bytes
        }

        $checksumLines = @(Get-Content -LiteralPath $script:ChecksumPath)
        $checksumLines | Should -HaveCount 5
        foreach ($asset in $script:ExpectedAssets) {
            @($checksumLines | Where-Object { $_ -match "  $([regex]::Escape($asset))$" }) | Should -HaveCount 1
        }
        @($checksumLines | Where-Object { $_ -match '  release-manifest\.json$' }) | Should -HaveCount 1
        @($checksumLines | Where-Object { $_ -match '[\\/]' }) | Should -HaveCount 0
    }

    It 'copies bytes from the canonical template and portal sources' {
        $sourceMap = @{
            'greenfield.json' = 'infra/compiled/greenfield.json'
            'existing-workspace.json' = 'infra/compiled/existing-workspace.json'
            'greenfield.createUiDefinition.json' = 'infra/portal/greenfield/createUiDefinition.json'
            'existing-workspace.createUiDefinition.json' = 'infra/portal/existing-workspace/createUiDefinition.json'
        }
        foreach ($asset in $sourceMap.Keys) {
            $packagedHash = (Get-FileHash -LiteralPath (Join-Path $script:AssetRoot $asset) -Algorithm SHA256).Hash
            $sourceHash = (Get-FileHash -LiteralPath (Join-Path $script:RepositoryRoot $sourceMap[$asset]) -Algorithm SHA256).Hash
            $packagedHash | Should -Be $sourceHash
        }
    }
}
