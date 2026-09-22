[CmdletBinding()]
param(
    [ValidateSet('All', 'Deployment', 'Audit', 'Graph', 'Identity', 'SentinelConnector', 'CustomIngestion', 'DataHealth')]
    [string]$Command = 'All',
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$Online,
    [switch]$Bootstrap,
    [ValidateSet('Json', 'Object')]
    [string]$OutputFormat = 'Json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\powershell\M365CopilotGovernance\M365CopilotGovernance.psd1') -Force

$results = @(
    if ($Command -in @('All', 'Deployment')) { Invoke-M365GovernanceValidation -RepositoryRoot $RepositoryRoot -Online:$Online }
    if ($Command -in @('All', 'Audit')) { Test-M365AuditConfiguration -Online:$Online }
    if ($Command -in @('All', 'Graph')) { Test-M365GraphAccess -Online:$Online }
    if ($Command -eq 'Identity') { Initialize-M365CollectorIdentity -Bootstrap:$Bootstrap }
    if ($Command -in @('All', 'SentinelConnector')) { Test-M365SentinelConnector -Online:$Online }
    if ($Command -in @('All', 'CustomIngestion')) { Test-M365CustomIngestion -Online:$Online }
    if ($Command -in @('All', 'DataHealth')) { Test-M365DataHealth -Online:$Online }
)

if ($OutputFormat -eq 'Json') {
    if ($results.Count -eq 1) {
        $results[0] | ConvertTo-Json -Depth 100
    }
    else {
        $results | ConvertTo-Json -Depth 100 -AsArray
    }
}
else {
    $results
}

$exitCode = @($results | ForEach-Object exitCode | Measure-Object -Maximum).Maximum
exit ([int]$exitCode)
