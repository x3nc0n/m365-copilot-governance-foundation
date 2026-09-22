[CmdletBinding()]
param(
    [switch]$Online,
    [ValidateSet('Json', 'Object')][string]$OutputFormat = 'Json'
)

Import-Module (Join-Path $PSScriptRoot '..\powershell\M365CopilotGovernance\M365CopilotGovernance.psd1') -Force
$result = Test-M365SentinelConnector -Online:$Online
if ($OutputFormat -eq 'Json') { $result | ConvertTo-Json -Depth 100 } else { $result }
exit $result.exitCode
