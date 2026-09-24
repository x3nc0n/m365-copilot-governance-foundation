BeforeAll {
    $script:RepositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:DocumentationPaths = @(
        'README.md'
        'docs/deployment.md'
        'docs/release.md'
        'docs/troubleshooting.md'
    )
    $script:PortalGuidancePaths = @(
        'README.md'
        'docs/deployment.md'
    )
    $script:Repository = 'x3nc0n/m365-copilot-governance-foundation'
    $script:Tag = 'v0.1.3'
    $script:RawBaseUri = "https://raw.githubusercontent.com/$($script:Repository)/$($script:Tag)/generated/release-assets"
    $script:ExpectedAssets = @{
        'greenfield' = @{
            Template = "$($script:RawBaseUri)/greenfield.json"
            UiDefinition = "$($script:RawBaseUri)/greenfield.createUiDefinition.json"
        }
        'existing-workspace' = @{
            Template = "$($script:RawBaseUri)/existing-workspace.json"
            UiDefinition = "$($script:RawBaseUri)/existing-workspace.createUiDefinition.json"
        }
    }
    $script:Documents = @{}
    foreach ($relativePath in $script:DocumentationPaths) {
        $fullPath = Join-Path $script:RepositoryRoot $relativePath
        $script:Documents[$relativePath] = Get-Content -LiteralPath $fullPath -Raw
    }
    $script:PortalUrls = @(
        foreach ($entry in $script:Documents.GetEnumerator()) {
            foreach ($match in [regex]::Matches($entry.Value, '(?i)https://portal\.azure\.com/#create/Microsoft\.Template/[^\s)>]+')) {
                [pscustomobject]@{
                    Document = $entry.Key
                    Url = $match.Value
                }
            }
        }
    )
}

Describe 'Azure portal deployment documentation URLs' {
    It 'does not present release downloads as portal template or UI assets' {
        $portalAssetNames = @(
            'greenfield.json'
            'existing-workspace.json'
            'greenfield.createUiDefinition.json'
            'existing-workspace.createUiDefinition.json'
        ) | ForEach-Object { [regex]::Escape($_) }
        $portalAssetPattern = $portalAssetNames -join '|'
        $repositoryPattern = [regex]::Escape($script:Repository)
        $releaseAssetPattern = "(?i)https://github\.com/$repositoryPattern/releases/download/[^/\s]+/(?:$portalAssetPattern)"

        foreach ($relativePath in $script:PortalGuidancePaths) {
            $script:Documents[$relativePath] | Should -Not -Match $releaseAssetPattern
        }
    }

    It 'does not send release-download assets to the Azure portal' {
        $script:PortalUrls | Should -Not -BeNullOrEmpty

        foreach ($portalUrl in $script:PortalUrls) {
            $portalUrl.Url | Should -Not -Match '(?i)(?:releases(?:/|%2f)download)'
        }
    }

    It 'uses only immutable raw v0.1.3 release assets in portal URL payloads' {
        $actualTemplates = [System.Collections.Generic.List[string]]::new()
        $actualUiDefinitions = [System.Collections.Generic.List[string]]::new()

        foreach ($portalUrl in $script:PortalUrls) {
            $routeMatch = [regex]::Match(
                $portalUrl.Url,
                '(?i)/uri/(?<template>[^/]+)(?:/createUIDefinitionUri/(?<uiDefinition>[^/]+))?$'
            )
            $routeMatch.Success | Should -BeTrue -Because "$($portalUrl.Document) must use the Azure portal template route"

            $templateSegment = $routeMatch.Groups['template'].Value
            $templateUri = [uri]::UnescapeDataString($templateSegment)
            $expectedScenario = @(
                $script:ExpectedAssets.Keys |
                    Where-Object { $script:ExpectedAssets[$_].Template -eq $templateUri }
            )
            $expectedScenario | Should -HaveCount 1 -Because "$($portalUrl.Document) must pin a known raw template asset"
            $templateSegment | Should -Be ([uri]::EscapeDataString($templateUri)) -Because 'the complete template URL must be URL encoded'
            $actualTemplates.Add($templateUri)

            if ($routeMatch.Groups['uiDefinition'].Success) {
                $uiDefinitionSegment = $routeMatch.Groups['uiDefinition'].Value
                $uiDefinitionUri = [uri]::UnescapeDataString($uiDefinitionSegment)
                $uiDefinitionUri | Should -Be $script:ExpectedAssets[$expectedScenario[0]].UiDefinition -Because 'the portal UI must match its template scenario'
                $uiDefinitionSegment | Should -Be ([uri]::EscapeDataString($uiDefinitionUri)) -Because 'the complete createUiDefinition URL must be URL encoded'
                $actualUiDefinitions.Add($uiDefinitionUri)
            }
        }

        $actualTemplates | Sort-Object -Unique | Should -Be @(
            $script:ExpectedAssets['existing-workspace'].Template
            $script:ExpectedAssets['greenfield'].Template
        )
        $actualUiDefinitions | Sort-Object -Unique | Should -Be @(
            $script:ExpectedAssets['existing-workspace'].UiDefinition
            $script:ExpectedAssets['greenfield'].UiDefinition
        )
    }

    It 'opens the existing-workspace picker from every documented portal link' {
        $existingTemplate = $script:ExpectedAssets['existing-workspace'].Template
        $existingUiDefinition = $script:ExpectedAssets['existing-workspace'].UiDefinition
        $existingPortalUrls = @(
            $script:PortalUrls |
                Where-Object {
                    $decoded = [uri]::UnescapeDataString($_.Url)
                    $decoded -match [regex]::Escape($existingTemplate)
                }
        )

        $existingPortalUrls | Should -Not -BeNullOrEmpty
        foreach ($portalUrl in $existingPortalUrls) {
            [uri]::UnescapeDataString($portalUrl.Url) | Should -Match ([regex]::Escape("/createUIDefinitionUri/$existingUiDefinition"))
        }
    }

    It 'keeps direct release downloads valid outside Azure portal links' {
        $releaseDocumentation = $script:Documents['docs/release.md']
        $releaseDocumentation | Should -Match ([regex]::Escape("https://github.com/$($script:Repository)/releases/download/$($script:Tag)/<asset>"))
        $releaseDocumentation | Should -Match 'checksums\.sha256'
    }
}
