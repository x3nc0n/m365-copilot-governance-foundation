[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$CI,
    [ValidateRange(0, 600)]
    [int]$WaitForContentSeconds = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot 'New-ContentManifest.ps1') -RepositoryRoot $RepositoryRoot -WaitSeconds $WaitForContentSeconds
& (Join-Path $PSScriptRoot 'Compile-Artifacts.ps1') -RepositoryRoot $RepositoryRoot -RequireBicep:$CI
& (Join-Path $PSScriptRoot 'New-ReleaseManifest.ps1') -RepositoryRoot $RepositoryRoot
& (Join-Path $PSScriptRoot 'Validate-Json.ps1') -RepositoryRoot $RepositoryRoot
if ($LASTEXITCODE -notin 0, $null) {
    throw "JSON validation exited with code $LASTEXITCODE."
}

$pester = Get-Module -ListAvailable Pester | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pester) {
    throw 'Pester 5 or later is required.'
}
Import-Module $pester.Path -Force

$configuration = [PesterConfiguration]::Default
$configuration.Run.Path = Join-Path $RepositoryRoot 'tests'
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = if ($CI) { 'Detailed' } else { 'Normal' }
$configuration.TestResult.Enabled = [bool]$CI
$configuration.TestResult.OutputPath = Join-Path $RepositoryRoot 'build/test-results.xml'
$configuration.TestResult.OutputFormat = 'NUnitXml'

$result = Invoke-Pester -Configuration $configuration
if ($result.FailedCount -gt 0 -or $result.Result -ne 'Passed') {
    throw "Pester failed: result=$($result.Result), failed tests=$($result.FailedCount), failed containers=$($result.FailedContainers.Count)."
}

Write-Host "Offline build passed: $($result.PassedCount) tests."
