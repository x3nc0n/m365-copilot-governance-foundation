Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Format-M365Check {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('pass', 'warning', 'fail', 'skipped')][string]$Status,
        [string]$Evidence = '',
        [string]$Remediation = ''
    )

    [pscustomobject][ordered]@{
        name        = $Name
        status      = $Status
        evidence    = $Evidence
        remediation = $Remediation
    }
}

function ConvertTo-M365RedactedObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [object]$InputObject
    )

    begin {
        $script:redactionCount = 0

        function Protect-Value {
            param(
                [AllowNull()][object]$Value,
                [string]$KeyName = ''
            )

            if ($null -eq $Value) {
                return $null
            }

            $credentialOrContentKey = $KeyName -match '(?i)(token|secret|password|credential|authorization|cookie|certificate|connection.?string|prompt|response)'
            $identifierKey = $KeyName -match '(?i)^(tenant(id|guid|name|domain)?|subscription(id|guid)?|object(id|guid)?|user(id|guid|name|principal|principalname)?|upn|email(address)?|ip(address)?|clientip|sourceip|destinationip|domain(name)?|dnsname|fqdn|device(id|name)?|host(name)?|computer(name)?|machine(name)?|account(name)?|actor(name)?|employee(name)?|initiatedby|requestedby|createdby|modifiedby)$'
            $sensitiveKey = $credentialOrContentKey -or $identifierKey
            if ($sensitiveKey) {
                $script:redactionCount++
                return '[REDACTED]'
            }

            if ($Value -is [System.Collections.IDictionary]) {
                $result = [ordered]@{}
                foreach ($key in $Value.Keys) {
                    $result[[string]$key] = Protect-Value -Value $Value[$key] -KeyName ([string]$key)
                }
                return [pscustomobject]$result
            }

            if ($Value -is [pscustomobject]) {
                $result = [ordered]@{}
                foreach ($property in $Value.PSObject.Properties) {
                    $result[$property.Name] = Protect-Value -Value $property.Value -KeyName $property.Name
                }
                return [pscustomobject]$result
            }

            if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
                return @($Value | ForEach-Object { Protect-Value -Value $_ })
            }

            if ($Value -is [string]) {
                $redacted = $Value
                $patterns = @(
                    '(?i)\bBearer\s+[A-Za-z0-9._~+/-]+=*',
                    '\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b',
                    '\b[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[1-5][A-Fa-f0-9]{3}-[89ABab][A-Fa-f0-9]{3}-[A-Fa-f0-9]{12}\b',
                    '\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
                    '\b(?:(?:25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})\.){3}(?:25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})\b'
                )
                foreach ($pattern in $patterns) {
                    $next = [regex]::Replace($redacted, $pattern, '[REDACTED]', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                    if ($next -ne $redacted) {
                        $script:redactionCount++
                        $redacted = $next
                    }
                }

                $ipv6Pattern = '(?<![A-Fa-f0-9:])[A-Fa-f0-9:]{2,}(?![A-Fa-f0-9:])'
                $redacted = [regex]::Replace(
                    $redacted,
                    $ipv6Pattern,
                    {
                        param($match)
                        $address = $null
                        if ([System.Net.IPAddress]::TryParse($match.Value, [ref]$address) -and
                            $address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6) {
                            $script:redactionCount++
                            return '[REDACTED]'
                        }
                        return $match.Value
                    }
                )

                $labelPatterns = @(
                    '(?i)\b(?<label>user(?:name)?|account(?:name)?|employee(?:name)?)\s*[:=]\s*(?<value>[A-Za-z0-9][A-Za-z0-9._\\-]{0,127})',
                    '(?i)\b(?<label>host(?:name)?|device(?:name)?|computer(?:name)?|machine(?:name)?)\s*[:=]\s*(?<value>[A-Za-z0-9][A-Za-z0-9._-]{0,127})'
                )
                foreach ($pattern in $labelPatterns) {
                    $redacted = [regex]::Replace(
                        $redacted,
                        $pattern,
                        {
                            param($match)
                            $script:redactionCount++
                            return "$($match.Groups['label'].Value): [REDACTED]"
                        }
                    )
                }

                $publicDomainSuffixes = @(
                    'aka.ms',
                    'azure.com',
                    'github.com',
                    'json-schema.org',
                    'microsoft.com',
                    'microsoftonline.com',
                    'powershellgallery.com'
                )
                $domainPattern = '\b(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}\b'
                $redacted = [regex]::Replace(
                    $redacted,
                    $domainPattern,
                    {
                        param($match)
                        $domain = $match.Value.ToLowerInvariant()
                        if ($match.Value -match '^[A-Za-z]+\.(Read|ReadWrite)(\.[A-Za-z]+)+$') {
                            return $match.Value
                        }
                        $isPublicService = @($publicDomainSuffixes | Where-Object {
                            $domain -eq $_ -or $domain.EndsWith(".$_", [System.StringComparison]::OrdinalIgnoreCase)
                        }).Count -gt 0
                        if ($isPublicService) {
                            return $match.Value
                        }
                        $script:redactionCount++
                        return '[REDACTED]'
                    },
                    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
                )
                return $redacted
            }

            return $Value
        }
    }

    process {
        Protect-Value -Value $InputObject
    }
}

function Get-M365Result {
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][bool]$Offline,
        [Parameter(Mandatory)][object[]]$Checks
    )

    $safeChecks = @(ConvertTo-M365RedactedObject -InputObject $Checks)
    $failed = @($safeChecks | Where-Object status -eq 'fail').Count
    $warnings = @($safeChecks | Where-Object status -eq 'warning').Count
    $skipped = @($safeChecks | Where-Object status -eq 'skipped').Count
    $passed = @($safeChecks | Where-Object status -eq 'pass').Count

    $status = if ($failed -gt 0) {
        'fail'
    }
    elseif ($warnings -gt 0) {
        'warning'
    }
    elseif ($passed -eq 0 -and $skipped -gt 0) {
        'skipped'
    }
    else {
        'pass'
    }

    $exitCode = switch ($status) {
        'pass' { 0 }
        'skipped' { 0 }
        'warning' { 1 }
        'fail' { 2 }
    }

    [pscustomobject][ordered]@{
        schemaVersion     = '1.0.0'
        command           = $Command
        status            = $status
        exitCode          = $exitCode
        offline           = $Offline
        checks            = $safeChecks
        summary           = [pscustomobject][ordered]@{
            passed   = $passed
            warnings = $warnings
            failed   = $failed
            skipped  = $skipped
        }
        redactionsApplied = $script:redactionCount
    }
}

function Resolve-M365RepositoryRoot {
    param([string]$RepositoryRoot)

    if ($RepositoryRoot) {
        return [System.IO.Path]::GetFullPath($RepositoryRoot)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
}

function Invoke-M365GovernanceValidation {
    [CmdletBinding()]
    param(
        [string]$RepositoryRoot,
        [switch]$Online
    )

    try {
        $root = Resolve-M365RepositoryRoot -RepositoryRoot $RepositoryRoot
        $checks = [System.Collections.Generic.List[object]]::new()
        foreach ($relativePath in @(
            'schemas/content-manifest.schema.json',
            'schemas/validation-result.schema.json',
            'generated/content-manifest.json'
        )) {
            $path = Join-Path $root $relativePath
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                $checks.Add((Format-M365Check -Name "artifact:$relativePath" -Status pass -Evidence 'Repository artifact exists and is readable.'))
            }
            else {
                $checks.Add((Format-M365Check -Name "artifact:$relativePath" -Status fail -Evidence 'Repository artifact is missing.' -Remediation "Run build/New-ContentManifest.ps1 and the offline build."))
            }
        }

        $manifestPath = Join-Path $root 'generated/content-manifest.json'
        if (Test-Path -LiteralPath $manifestPath) {
            try {
                $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -Depth 100
                $arrayNames = @($manifest.PSObject.Properties.Name | Where-Object { $_ -in @('functions', 'analytics', 'workbooks') })
                $validShape = $manifest.solutionVersion -eq '0.2.0' -and
                    $arrayNames.Count -eq 3 -and
                    $null -ne $manifest.functions -and
                    $null -ne $manifest.analytics -and
                    $null -ne $manifest.workbooks
                if ($validShape) {
                    $checks.Add((Format-M365Check -Name 'content-manifest-contract' -Status pass -Evidence 'Manifest version and exact content arrays are present.'))
                }
                else {
                    $checks.Add((Format-M365Check -Name 'content-manifest-contract' -Status fail -Evidence 'Manifest contract is invalid.' -Remediation 'Regenerate the content manifest.'))
                }
            }
            catch {
                $checks.Add((Format-M365Check -Name 'content-manifest-json' -Status fail -Evidence $_.Exception.Message -Remediation 'Fix or regenerate the content manifest.'))
            }
        }

        if ($Online) {
            $checks.Add((Format-M365Check -Name 'online-validation' -Status warning -Evidence 'Online validation is not performed automatically.' -Remediation 'Authenticate explicitly, select a tenant/subscription/workspace, and run a separately authorized validation.'))
        }
        else {
            $checks.Add((Format-M365Check -Name 'authentication' -Status skipped -Evidence 'Offline mode does not authenticate to Azure or Microsoft Graph.'))
        }

        return Get-M365Result -Command 'Test-GovernanceDeployment' -Offline (-not $Online) -Checks $checks
    }
    catch {
        $check = Format-M365Check -Name 'operational-error' -Status fail -Evidence $_.Exception.Message -Remediation 'Review the local repository and PowerShell environment.'
        $result = Get-M365Result -Command 'Test-GovernanceDeployment' -Offline (-not $Online) -Checks @($check)
        $result.exitCode = 3
        return $result
    }
}

function Get-M365ReadOnlyPlaneResult {
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string]$Plane,
        [switch]$Online
    )

    $checks = if ($Online) {
        @(
            Format-M365Check -Name "$Plane-authentication" -Status warning -Evidence 'No implicit authentication or consent was attempted.' -Remediation 'Authenticate explicitly with a least-privilege read-only identity, then rerun the authorized live check.'
        )
    }
    else {
        @(
            Format-M365Check -Name "$Plane-offline-contract" -Status pass -Evidence 'Command is available and remained offline.'
            Format-M365Check -Name "$Plane-live-query" -Status skipped -Evidence 'Live query skipped because online mode was not requested.'
        )
    }
    return Get-M365Result -Command $Command -Offline (-not $Online) -Checks $checks
}

function Test-M365AuditConfiguration {
    [CmdletBinding()]
    param([switch]$Online)
    Get-M365ReadOnlyPlaneResult -Command 'Test-M365Audit' -Plane 'm365-audit' -Online:$Online
}

function Test-M365GraphAccess {
    [CmdletBinding()]
    param([switch]$Online)
    Get-M365ReadOnlyPlaneResult -Command 'Test-GraphAccess' -Plane 'graph' -Online:$Online
}

function Test-M365SentinelConnector {
    [CmdletBinding()]
    param([switch]$Online)
    Get-M365ReadOnlyPlaneResult -Command 'Test-SentinelConnector' -Plane 'sentinel-connector' -Online:$Online
}

function Test-M365CustomIngestion {
    [CmdletBinding()]
    param([switch]$Online)
    Get-M365ReadOnlyPlaneResult -Command 'Test-CustomIngestion' -Plane 'custom-ingestion' -Online:$Online
}

function Test-M365DataHealth {
    [CmdletBinding()]
    param([switch]$Online)
    Get-M365ReadOnlyPlaneResult -Command 'Test-DataHealth' -Plane 'data-health' -Online:$Online
}

function Get-M365CollectorGraphRole {
    param(
        [Parameter(Mandatory)][ValidateSet('AllLicensedUsers', 'IncludeGroup', 'ExcludeGroup')][string]$CollectionScope
    )

    $roles = @('AiEnterpriseInteraction.Read.All', 'User.Read.All')
    if ($CollectionScope -ne 'AllLicensedUsers') {
        $roles += 'GroupMember.Read.All'
    }
    return $roles
}

function Invoke-M365GraphRequest {
    param(
        [Parameter(Mandatory)][ValidateSet('GET', 'POST')][string]$Method,
        [Parameter(Mandatory)][string]$Uri,
        [object]$Body
    )

    $parameters = @{ Method = $Method; Uri = $Uri; OutputType = 'PSObject' }
    if ($null -ne $Body) {
        $parameters.Body = ($Body | ConvertTo-Json -Depth 10 -Compress)
        $parameters.ContentType = 'application/json'
    }
    Invoke-MgGraphRequest @parameters
}

function Get-M365GraphContext {
    if (-not (Get-Command -Name Get-MgContext -ErrorAction SilentlyContinue)) {
        return $null
    }
    Get-MgContext
}

function Initialize-M365CollectorIdentity {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [switch]$Bootstrap,
        [string]$ManagedIdentityPrincipalId,
        [ValidateSet('AllLicensedUsers', 'IncludeGroup', 'ExcludeGroup')]
        [string]$CollectionScope = 'AllLicensedUsers',
        [string]$GroupId
    )

    $command = 'Initialize-CollectorIdentity'
    $roles = @(Get-M365CollectorGraphRole -CollectionScope $CollectionScope)
    $plan = "Microsoft Graph application roles for scope ${CollectionScope}: $($roles -join ', ')."

    if (-not $Bootstrap) {
        return Get-M365Result -Command $command -Offline $true -Checks @(
            Format-M365Check -Name 'bootstrap-gate' -Status skipped -Evidence "No changes were made because -Bootstrap was not supplied. Plan: $plan" -Remediation 'Review the plan, then rerun with -Bootstrap -ManagedIdentityPrincipalId <interactionCollectorPrincipalId output> and -WhatIf before granting.'
        )
    }

    $guidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    $inputChecks = @(
        if ($ManagedIdentityPrincipalId -notmatch $guidPattern) {
            Format-M365Check -Name 'input-principal' -Status fail -Evidence 'ManagedIdentityPrincipalId must be the collector managed identity object ID.' -Remediation 'Use the interactionCollectorPrincipalId deployment output.'
        }
        if ($CollectionScope -ne 'AllLicensedUsers' -and $GroupId -notmatch $guidPattern) {
            Format-M365Check -Name 'input-group' -Status fail -Evidence "GroupId is required for $CollectionScope." -Remediation 'Supply the Microsoft Entra group object ID used by the deployment.'
        }
    )
    if ($inputChecks) {
        return Get-M365Result -Command $command -Offline $true -Checks $inputChecks
    }

    if (-not $PSCmdlet.ShouldProcess('collector managed identity', "Grant $plan")) {
        return Get-M365Result -Command $command -Offline $true -Checks @(
            Format-M365Check -Name 'should-process' -Status skipped -Evidence "Bootstrap was declined or executed with -WhatIf. No changes were made. Plan: $plan"
        )
    }

    try {
        if ($null -eq (Get-M365GraphContext)) {
            return Get-M365Result -Command $command -Offline $false -Checks @(
                Format-M365Check -Name 'graph-authentication' -Status fail -Evidence 'No Microsoft Graph session was found. No implicit sign-in or consent was attempted.' -Remediation "Install the Microsoft Graph PowerShell authentication module, run Connect-MgGraph -Scopes 'AppRoleAssignment.ReadWrite.All','Application.Read.All','GroupMember.Read.All' as a Privileged Role Administrator or Global Administrator, then rerun."
            )
        }

        $checks = [System.Collections.Generic.List[object]]::new()
        $graphBase = 'https://graph.microsoft.com/v1.0'
        if ($CollectionScope -ne 'AllLicensedUsers') {
            $null = Invoke-M365GraphRequest -Method GET -Uri "$graphBase/groups/$GroupId`?`$select=id"
            $checks.Add((Format-M365Check -Name 'scope-group' -Status pass -Evidence "The $CollectionScope group exists."))
        }

        $graphApp = Invoke-M365GraphRequest -Method GET -Uri "$graphBase/servicePrincipals(appId='00000003-0000-0000-c000-000000000000')?`$select=id,appRoles"
        $existing = @((Invoke-M365GraphRequest -Method GET -Uri "$graphBase/servicePrincipals/$ManagedIdentityPrincipalId/appRoleAssignments").value)

        foreach ($role in $roles) {
            $appRole = @($graphApp.appRoles | Where-Object { $_.value -eq $role -and $_.allowedMemberTypes -contains 'Application' }) | Select-Object -First 1
            if (-not $appRole) {
                $checks.Add((Format-M365Check -Name "graph-role:$role" -Status fail -Evidence "Microsoft Graph does not expose application role $role in this cloud." -Remediation 'Confirm the tenant cloud supports the Copilot interaction export API.'))
                continue
            }
            if (@($existing | Where-Object { $_.appRoleId -eq $appRole.id -and $_.resourceId -eq $graphApp.id }).Count -gt 0) {
                $checks.Add((Format-M365Check -Name "graph-role:$role" -Status pass -Evidence "$role was already granted."))
                continue
            }
            $null = Invoke-M365GraphRequest -Method POST -Uri "$graphBase/servicePrincipals/$ManagedIdentityPrincipalId/appRoleAssignments" -Body @{
                principalId = $ManagedIdentityPrincipalId
                resourceId  = $graphApp.id
                appRoleId   = $appRole.id
            }
            $checks.Add((Format-M365Check -Name "graph-role:$role" -Status pass -Evidence "$role was granted."))
        }

        return Get-M365Result -Command $command -Offline $false -Checks $checks
    }
    catch {
        $check = Format-M365Check -Name 'operational-error' -Status fail -Evidence $_.Exception.Message -Remediation 'Confirm the Graph session has AppRoleAssignment.ReadWrite.All and Application.Read.All, and that the principal ID is the collector managed identity.'
        $result = Get-M365Result -Command $command -Offline $false -Checks @($check)
        $result.exitCode = 3
        return $result
    }
}

Export-ModuleMember -Function @(
    'ConvertTo-M365RedactedObject'
    'Invoke-M365GovernanceValidation'
    'Test-M365AuditConfiguration'
    'Test-M365GraphAccess'
    'Initialize-M365CollectorIdentity'
    'Test-M365SentinelConnector'
    'Test-M365CustomIngestion'
    'Test-M365DataHealth'
)
