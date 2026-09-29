[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [switch]$Bootstrap,
    [string]$ManagedIdentityPrincipalId,
    [ValidateSet('AllLicensedUsers', 'IncludeGroup', 'ExcludeGroup')]
    [string]$CollectionScope = 'AllLicensedUsers',
    [string]$GroupId,
    [ValidateSet('Json', 'Object')][string]$OutputFormat = 'Json'
)

Import-Module (Join-Path $PSScriptRoot '..\powershell\M365CopilotGovernance\M365CopilotGovernance.psd1') -Force
$parameters = @{
    Bootstrap                  = $Bootstrap
    ManagedIdentityPrincipalId = $ManagedIdentityPrincipalId
    CollectionScope            = $CollectionScope
    GroupId                    = $GroupId
}
if ($WhatIfPreference) { $parameters.WhatIf = $true }
if ($PSBoundParameters.ContainsKey('Confirm')) { $parameters.Confirm = $PSBoundParameters.Confirm }
$result = Initialize-M365CollectorIdentity @parameters
if ($OutputFormat -eq 'Json') { $result | ConvertTo-Json -Depth 100 } else { $result }
exit $result.exitCode
