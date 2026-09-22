[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [switch]$Bootstrap,
    [ValidateSet('Json', 'Object')][string]$OutputFormat = 'Json'
)

Import-Module (Join-Path $PSScriptRoot '..\powershell\M365CopilotGovernance\M365CopilotGovernance.psd1') -Force
$parameters = @{ Bootstrap = $Bootstrap }
if ($WhatIfPreference) { $parameters.WhatIf = $true }
if ($PSBoundParameters.ContainsKey('Confirm')) { $parameters.Confirm = $PSBoundParameters.Confirm }
$result = Initialize-M365CollectorIdentity @parameters
if ($OutputFormat -eq 'Json') { $result | ConvertTo-Json -Depth 100 } else { $result }
exit $result.exitCode
