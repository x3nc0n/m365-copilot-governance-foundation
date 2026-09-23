BeforeAll {
    $script:RepositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:Generator = Join-Path $script:RepositoryRoot 'build/New-ReleaseManifest.ps1'
    $script:ManifestPath = Join-Path $script:RepositoryRoot 'generated/release-manifest.json'
    $script:ChecksumPath = Join-Path $script:RepositoryRoot 'generated/checksums.sha256'
    $script:AssetRoot = Join-Path $script:RepositoryRoot 'generated/release-assets'
    $script:VerifyRoot = Join-Path $script:RepositoryRoot 'build/.verify/release-line-endings'
    $script:ExpectedAssets = @(
        'existing-workspace.createUiDefinition.json'
        'existing-workspace.json'
        'greenfield.createUiDefinition.json'
        'greenfield.json'
    )
    . (Join-Path $script:RepositoryRoot 'build/Common.ps1')
}

AfterAll {
    if (Test-Path -LiteralPath $script:VerifyRoot) {
        Remove-Item -LiteralPath $script:VerifyRoot -Recurse -Force
    }
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

    It 'copies compiled ARM bytes exactly without normalizing compiler output' {
        $sourceMap = @{
            'greenfield.json' = 'infra/compiled/greenfield.json'
            'existing-workspace.json' = 'infra/compiled/existing-workspace.json'
        }
        foreach ($asset in $sourceMap.Keys) {
            $packagedHash = (Get-FileHash -LiteralPath (Join-Path $script:AssetRoot $asset) -Algorithm SHA256).Hash
            $sourceHash = (Get-FileHash -LiteralPath (Join-Path $script:RepositoryRoot $sourceMap[$asset]) -Algorithm SHA256).Hash
            $packagedHash | Should -Be $sourceHash
        }
    }

    It 'packages portal JSON as UTF-8 LF with byte-exact manifest and checksum metadata' {
        $sourceMap = @{
            'greenfield.createUiDefinition.json' = 'infra/portal/greenfield/createUiDefinition.json'
            'existing-workspace.createUiDefinition.json' = 'infra/portal/existing-workspace/createUiDefinition.json'
        }
        $manifest = Get-Content -LiteralPath $script:ManifestPath -Raw | ConvertFrom-Json -Depth 100
        $checksumLines = @(Get-Content -LiteralPath $script:ChecksumPath)

        foreach ($asset in $sourceMap.Keys) {
            $assetPath = Join-Path $script:AssetRoot $asset
            $expectedText = Get-NormalizedTextContent -Path (Join-Path $script:RepositoryRoot $sourceMap[$asset])
            $expectedBytes = [System.Text.UTF8Encoding]::new($false).GetBytes($expectedText)
            $actualBytes = [System.IO.File]::ReadAllBytes($assetPath)
            $artifact = @($manifest.artifacts | Where-Object path -eq $asset)
            $actualHash = (Get-FileHash -LiteralPath $assetPath -Algorithm SHA256).Hash.ToLowerInvariant()

            [Convert]::ToBase64String($actualBytes) | Should -Be ([Convert]::ToBase64String($expectedBytes))
            [System.Text.Encoding]::UTF8.GetString($actualBytes) | Should -Not -Match "`r"
            $artifact | Should -HaveCount 1
            $artifact[0].sha256 | Should -Be $actualHash
            $artifact[0].bytes | Should -Be $actualBytes.Length
            @($checksumLines | Where-Object { $_ -eq "$actualHash  $asset" }) | Should -HaveCount 1
        }
    }

    It 'produces identical portal packages, manifests, and checksums from LF and CRLF sources' {
        $lfRoot = Join-Path $script:VerifyRoot 'lf'
        $crlfRoot = Join-Path $script:VerifyRoot 'crlf'
        foreach ($fixtureRoot in $lfRoot, $crlfRoot) {
            New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'generated') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'infra/compiled') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'infra/portal') -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $script:RepositoryRoot 'schemas') -Destination $fixtureRoot -Recurse
            Copy-Item -LiteralPath (Join-Path $script:RepositoryRoot 'generated/content-manifest.json') -Destination (Join-Path $fixtureRoot 'generated/content-manifest.json')
            Copy-Item -LiteralPath (Join-Path $script:RepositoryRoot 'infra/compiled/greenfield.json') -Destination (Join-Path $fixtureRoot 'infra/compiled/greenfield.json')
            Copy-Item -LiteralPath (Join-Path $script:RepositoryRoot 'infra/compiled/existing-workspace.json') -Destination (Join-Path $fixtureRoot 'infra/compiled/existing-workspace.json')
            Copy-Item -LiteralPath (Join-Path $script:RepositoryRoot 'infra/portal/greenfield') -Destination (Join-Path $fixtureRoot 'infra/portal') -Recurse
            Copy-Item -LiteralPath (Join-Path $script:RepositoryRoot 'infra/portal/existing-workspace') -Destination (Join-Path $fixtureRoot 'infra/portal') -Recurse
        }

        foreach ($relativePath in 'infra/portal/greenfield/createUiDefinition.json', 'infra/portal/existing-workspace/createUiDefinition.json') {
            $sourceText = Get-NormalizedTextContent -Path (Join-Path $script:RepositoryRoot $relativePath)
            [System.IO.File]::WriteAllText(
                (Join-Path $lfRoot $relativePath),
                $sourceText,
                [System.Text.UTF8Encoding]::new($false)
            )
            [System.IO.File]::WriteAllText(
                (Join-Path $crlfRoot $relativePath),
                $sourceText.Replace("`n", "`r`n"),
                [System.Text.UTF8Encoding]::new($false)
            )
        }

        & $script:Generator -RepositoryRoot $lfRoot
        & $script:Generator -RepositoryRoot $crlfRoot

        foreach ($relativePath in @(
            'generated/release-assets/greenfield.createUiDefinition.json'
            'generated/release-assets/existing-workspace.createUiDefinition.json'
            'generated/release-manifest.json'
            'generated/checksums.sha256'
        )) {
            $lfPath = Join-Path $lfRoot $relativePath
            $crlfPath = Join-Path $crlfRoot $relativePath
            (Get-FileHash -LiteralPath $crlfPath -Algorithm SHA256).Hash |
                Should -Be (Get-FileHash -LiteralPath $lfPath -Algorithm SHA256).Hash
        }
    }
}
