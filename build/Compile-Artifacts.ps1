[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$RequireBicep
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Common.ps1')

$entryPoints = [ordered]@{
    'infra/greenfield/main.bicep'       = 'infra/compiled/greenfield.json'
    'infra/existing-workspace/main.bicep' = 'infra/compiled/existing-workspace.json'
}
$parameterFiles = @(
    'infra/greenfield/main.bicepparam'
    'infra/existing-workspace/main.bicepparam'
)

$az = Get-Command az -ErrorAction SilentlyContinue
if (-not $az -and $RequireBicep) {
    throw 'Azure CLI is required to compile Bicep entry points and parameter files.'
}

foreach ($entry in $entryPoints.GetEnumerator()) {
    $source = Join-Path $RepositoryRoot $entry.Key
    $output = Join-Path $RepositoryRoot $entry.Value

    if (-not (Test-Path -LiteralPath $source)) {
        if ($RequireBicep) {
            throw "Required Bicep entry point '$($entry.Key)' is missing."
        }
        Write-Warning "Skipping missing Bicep entry point '$($entry.Key)'."
        continue
    }
    if (-not $az) {
        if ($RequireBicep) {
            throw "Azure CLI is required to compile '$($entry.Key)'."
        }
        Write-Warning "Azure CLI is unavailable; existing compiled artifact will be validated if present."
        if (-not (Test-Path -LiteralPath $output)) {
            throw "No compiler or compiled artifact is available for '$($entry.Key)'."
        }
        continue
    }

    New-Item -ItemType Directory -Path (Split-Path -Parent $output) -Force | Out-Null
    & $az.Source bicep build --file $source --outfile $output
    if ($LASTEXITCODE -ne 0) {
        throw "Bicep compilation failed for '$($entry.Key)'."
    }
}

$parameterOutputRoot = Join-Path $RepositoryRoot 'build/.verify/bicepparam'
try {
    foreach ($relativeParameterFile in $parameterFiles) {
        $parameterFile = Join-Path $RepositoryRoot $relativeParameterFile
        if (-not (Test-Path -LiteralPath $parameterFile -PathType Leaf)) {
            throw "Required Bicep parameter file '$relativeParameterFile' is missing."
        }
        if (-not $az) {
            Write-Warning "Azure CLI is unavailable; skipping '$relativeParameterFile'."
            continue
        }

        New-Item -ItemType Directory -Path $parameterOutputRoot -Force | Out-Null
        $parameterDirectoryName = Split-Path -Leaf (Split-Path -Parent $parameterFile)
        $parameterOutput = Join-Path $parameterOutputRoot "$parameterDirectoryName-parameters.json"
        & $az.Source bicep build-params --file $parameterFile --outfile $parameterOutput
        if ($LASTEXITCODE -ne 0) {
            throw "Bicep parameter compilation failed for '$relativeParameterFile'."
        }
        $null = Get-Content -LiteralPath $parameterOutput -Raw | ConvertFrom-Json -Depth 100
    }
}
finally {
    if (Test-Path -LiteralPath $parameterOutputRoot) {
        Remove-Item -LiteralPath $parameterOutputRoot -Recurse -Force
    }
}

$generatedJson = @(
    Join-Path $RepositoryRoot 'infra/compiled'
    Join-Path $RepositoryRoot 'infra/portal'
    Join-Path $RepositoryRoot 'src/workbooks'
) | Where-Object { Test-Path -LiteralPath $_ } |
    ForEach-Object { Get-ChildItem -LiteralPath $_ -Recurse -File -Filter '*.json' } |
    Sort-Object FullName

foreach ($file in $generatedJson) {
    try {
        $null = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -Depth 100
    }
    catch {
        throw "Generated artifact '$($file.FullName)' is not valid JSON: $($_.Exception.Message)"
    }
}

Write-Host "Compiled and verified $($generatedJson.Count) generated JSON artifacts."
