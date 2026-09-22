[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputPath = 'generated/release-manifest.json',
    [string]$ChecksumPath = 'generated/checksums.sha256'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Common.ps1')

$contentManifestPath = Join-Path $RepositoryRoot 'generated/content-manifest.json'
if (-not (Test-Path -LiteralPath $contentManifestPath)) {
    throw 'generated/content-manifest.json must be created before the release manifest.'
}

$releaseAssetRoot = Join-Path $RepositoryRoot 'generated/release-assets'
$releaseAssetSources = [ordered]@{
    'greenfield.json'                           = 'infra/compiled/greenfield.json'
    'greenfield.createUiDefinition.json'        = 'infra/portal/greenfield/createUiDefinition.json'
    'existing-workspace.json'                   = 'infra/compiled/existing-workspace.json'
    'existing-workspace.createUiDefinition.json' = 'infra/portal/existing-workspace/createUiDefinition.json'
}

if (Test-Path -LiteralPath $releaseAssetRoot) {
    Remove-Item -LiteralPath $releaseAssetRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $releaseAssetRoot -Force | Out-Null

$files = foreach ($asset in $releaseAssetSources.GetEnumerator()) {
    $source = Join-Path $RepositoryRoot $asset.Value
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required release source '$($asset.Value)' is missing."
    }
    $destination = Join-Path $releaseAssetRoot $asset.Key
    Copy-Item -LiteralPath $source -Destination $destination
    Get-Item -LiteralPath $destination
}

$artifacts = @(
    $files |
        Sort-Object Name |
        ForEach-Object {
            [ordered]@{
                path   = $_.Name
                sha256 = Get-Sha256 -Path $_.FullName
                bytes  = [int64]$_.Length
            }
        }
)

$manifest = [ordered]@{
    schemaVersion         = '1.0.0'
    solutionVersion       = '0.1.1'
    contentManifestSha256 = Get-Sha256 -Path $contentManifestPath
    artifacts             = $artifacts
}

$resolvedOutput = Join-Path $RepositoryRoot $OutputPath
Write-DeterministicJson -InputObject $manifest -Path $resolvedOutput

$checksumLines = @(
    $artifacts | ForEach-Object { "$($_.sha256)  $($_.path)" }
    "$(Get-Sha256 -Path $resolvedOutput)  $([System.IO.Path]::GetFileName($resolvedOutput))"
)
$resolvedChecksums = Join-Path $RepositoryRoot $ChecksumPath
[System.IO.File]::WriteAllText(
    $resolvedChecksums,
    (($checksumLines -join "`n") + "`n"),
    [System.Text.UTF8Encoding]::new($false)
)

$raw = Get-Content -LiteralPath $resolvedOutput -Raw
if (-not (Test-Json -Json $raw -SchemaFile (Join-Path $RepositoryRoot 'schemas/release-manifest.schema.json'))) {
    throw 'Generated release manifest does not satisfy its schema.'
}

Write-Host "Generated release manifest and checksums for $($artifacts.Count) artifacts."
