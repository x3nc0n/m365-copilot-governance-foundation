BeforeAll {
    $script:RepositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:WorkflowPath = Join-Path $script:RepositoryRoot '.github/workflows/release.yml'
    $script:Workflow = Get-Content -LiteralPath $script:WorkflowPath -Raw
    $script:ExpectedAssets = @(
        'generated/release-assets/greenfield.json'
        'generated/release-assets/existing-workspace.json'
        'generated/release-assets/greenfield.createUiDefinition.json'
        'generated/release-assets/existing-workspace.createUiDefinition.json'
        'generated/release-manifest.json'
        'generated/checksums.sha256'
    )
}

Describe 'Release workflow' {
    It 'runs only for version tag pushes with release write permission' {
        $script:Workflow | Should -Match '(?ms)^on:\s*\r?\n\s+push:\s*\r?\n\s+tags:\s*\r?\n\s+- ''v\*'''
        $script:Workflow | Should -Match '(?ms)^permissions:\s*\r?\n\s+contents:\s+write\s*$'
        $script:Workflow | Should -Not -Match '(?m)^\s*(pull_request|branches):'
    }

    It 'checks out the exact ref and installs the build validation dependencies' {
        $script:Workflow | Should -Match ([regex]::Escape('ref: ${{ github.ref }}'))
        $script:Workflow | Should -Match 'Install-Module Pester -MinimumVersion 5\.6\.1'
        $script:Workflow | Should -Match 'Install-Module PSScriptAnalyzer -MinimumVersion 1\.22\.0'
        $script:Workflow | Should -Not -Match '(?i)(azure/login|client-id|tenant-id|subscription-id|AZURE_CREDENTIALS)'
    }

    It 'runs the canonical CI build twice and rejects generated drift' {
        ([regex]::Matches($script:Workflow, '\./build/Invoke-Build\.ps1 -CI')).Count | Should -Be 2
        $script:Workflow | Should -Match 'Get-FileHash'
        $script:Workflow | Should -Match 'git diff --exit-code -- generated infra/compiled'
    }

    It 'uploads exactly the required six uniquely named release assets' {
        $assetBlocks = [regex]::Matches(
            $script:Workflow,
            '(?ms)\$assets = @\((?<assets>.*?)\)'
        )
        $uploadBlock = $assetBlocks[$assetBlocks.Count - 1].Groups['assets'].Value
        $actualAssets = @(
            [regex]::Matches($uploadBlock, "'([^']+)'") |
                ForEach-Object { $_.Groups[1].Value }
        )
        $actualAssets | Should -Be $script:ExpectedAssets
        @($actualAssets | Select-Object -Unique) | Should -HaveCount 6
    }

    It 'idempotently creates or updates the release and uploads with clobber' {
        $script:Workflow | Should -Match 'gh release view'
        $script:Workflow | Should -Match 'gh release edit'
        $script:Workflow | Should -Match 'gh release create'
        $script:Workflow | Should -Match 'gh release upload .* --clobber @assets'
    }

    It 'identifies the tag and commit and preserves the live validation caveat' {
        $script:Workflow | Should -Match 'RELEASE_TAG: \$\{\{ github\.ref_name \}\}'
        $script:Workflow | Should -Match 'RELEASE_COMMIT: \$\{\{ github\.sha \}\}'
        $script:Workflow | Should -Match 'Live Azure validation remains customer-specific'
    }
}
