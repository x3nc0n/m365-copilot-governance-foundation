BeforeAll {
    $script:RepositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:ModulePath = Join-Path $script:RepositoryRoot 'powershell/M365CopilotGovernance/M365CopilotGovernance.psd1'
    Import-Module $script:ModulePath -Force
}

Describe 'PowerShell syntax' {
    It 'parses all owned PowerShell files without errors' {
        $files = @(
            Get-ChildItem -LiteralPath (Join-Path $script:RepositoryRoot 'powershell') -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1'
            Get-ChildItem -LiteralPath (Join-Path $script:RepositoryRoot 'scripts') -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1'
            Get-ChildItem -LiteralPath (Join-Path $script:RepositoryRoot 'build') -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1'
        )
        foreach ($file in $files) {
            $tokens = $null
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
            $errors | Should -BeNullOrEmpty -Because $file.FullName
        }
    }
}

Describe 'Offline behavior' {
    It 'validates repository artifacts without authentication' {
        $result = Invoke-M365GovernanceValidation -RepositoryRoot $script:RepositoryRoot
        $result.offline | Should -BeTrue
        $result.exitCode | Should -Be 0
        $result.checks.name | Should -Contain 'authentication'
        $result.checks | Where-Object name -eq 'authentication' | Select-Object -ExpandProperty status | Should -Be 'skipped'
    }

    It 'keeps plane-specific checks offline by default' {
        $results = @(
            Test-M365AuditConfiguration
            Test-M365GraphAccess
            Test-M365SentinelConnector
            Test-M365CustomIngestion
            Test-M365DataHealth
        )
        $results | ForEach-Object {
            $_.offline | Should -BeTrue
            $_.exitCode | Should -Be 0
        }
    }

    It 'returns schema-valid structured results' {
        $schema = Join-Path $script:RepositoryRoot 'schemas/validation-result.schema.json'
        $results = @(
            Invoke-M365GovernanceValidation -RepositoryRoot $script:RepositoryRoot
            Test-M365AuditConfiguration
            Test-M365GraphAccess
            Test-M365SentinelConnector
            Test-M365CustomIngestion
            Test-M365DataHealth
        )
        foreach ($result in $results) {
            $json = $result | ConvertTo-Json -Depth 100
            (Test-Json -Json $json -SchemaFile $schema) | Should -BeTrue
        }
    }
}

Describe 'Exit code contract' {
    It 'uses 0 for pass, 1 for warning, 2 for validation failure, and 3 for operational error' {
        (Invoke-M365GovernanceValidation -RepositoryRoot $script:RepositoryRoot).exitCode | Should -Be 0
        (Test-M365GraphAccess -Online).exitCode | Should -Be 1
        (Invoke-M365GovernanceValidation -RepositoryRoot (Join-Path $TestDrive 'missing')).exitCode | Should -Be 2
        (Invoke-M365GovernanceValidation -RepositoryRoot ([string][char]0)).exitCode | Should -Be 3
    }
}

Describe 'Redaction' {
    It 'redacts credentials, identifiers, prompt content, response content, tokens, GUIDs, and email addresses' {
        $inputObject = [pscustomobject]@{
            token = 'secret-token'
            tenantId = '11111111-1111-4111-8111-111111111111'
            userPrincipalName = 'person@example.com'
            prompt = 'private prompt'
            nested = [pscustomobject]@{
                responseContent = 'private response'
                evidence = 'Bearer abc.def.ghi for person@example.com and 22222222-2222-4222-8222-222222222222'
            }
        }
        $safe = ConvertTo-M365RedactedObject $inputObject
        $json = $safe | ConvertTo-Json -Depth 10
        $json | Should -Not -Match 'secret-token|private prompt|private response|person@example.com|11111111|22222222|abc\.def'
        $json | Should -Match '\[REDACTED\]'
    }

    It 'redacts IPv4 and IPv6 addresses while preserving status text' {
        $safe = ConvertTo-M365RedactedObject ([pscustomobject]@{
            status = 'Connector health check passed.'
            evidence = 'Sources 10.42.7.19 and 2001:db8:85a3::8a2e:370:7334 responded.'
        })
        $json = $safe | ConvertTo-Json -Depth 10
        $json | Should -Not -Match '10\.42\.7\.19|2001:db8'
        $safe.status | Should -Be 'Connector health check passed.'
        $safe.evidence | Should -Match 'Sources \[REDACTED\] and \[REDACTED\] responded\.'
    }

    It 'redacts tenant and customer domain names but preserves public service routes' {
        $safe = ConvertTo-M365RedactedObject ([pscustomobject]@{
            tenantDomain = 'contoso.onmicrosoft.com'
            evidence = 'Tenant fabrikam.example uses security.microsoft.com and github.com.'
        })
        $json = $safe | ConvertTo-Json -Depth 10
        $json | Should -Not -Match 'contoso|fabrikam'
        $safe.evidence | Should -Match 'security\.microsoft\.com'
        $safe.evidence | Should -Match 'github\.com'
    }

    It 'redacts device and host names in structured and free-text output' {
        $safe = ConvertTo-M365RedactedObject ([pscustomobject]@{
            deviceName = 'LAPTOP-CUSTOMER-17'
            evidence = 'host=SRV-FINANCE-01 and device: WIN11-EXEC-02 are stale.'
        })
        $json = $safe | ConvertTo-Json -Depth 10
        $json | Should -Not -Match 'LAPTOP-CUSTOMER-17|SRV-FINANCE-01|WIN11-EXEC-02'
        $safe.evidence | Should -Match 'host: \[REDACTED\] and device: \[REDACTED\] are stale\.'
    }

    It 'redacts common structured and free-text username fields' {
        $safe = ConvertTo-M365RedactedObject ([pscustomobject]@{
            accountName = 'CORP\jsmith'
            actorName = 'Jane Smith'
            evidence = 'username=jsmith and accountName: corp\jdoe failed validation.'
        })
        $json = $safe | ConvertTo-Json -Depth 10
        $json | Should -Not -Match 'jsmith|Jane Smith|jdoe'
        $safe.evidence | Should -Match 'username: \[REDACTED\] and accountName: \[REDACTED\] failed validation\.'
    }
}

Describe 'Bootstrap ShouldProcess contract' {
    It 'does nothing without Bootstrap' {
        $result = Initialize-M365CollectorIdentity -Confirm:$false
        $result.status | Should -Be 'skipped'
        $result.checks[0].evidence | Should -Match 'No changes were made'
    }

    It 'supports WhatIf and does not mutate' {
        $result = Initialize-M365CollectorIdentity -Bootstrap -WhatIf
        $result.status | Should -Be 'skipped'
        $result.checks[0].name | Should -Be 'should-process'
    }

    It 'declares SupportsShouldProcess' {
        (Get-Command Initialize-M365CollectorIdentity).Parameters.Keys | Should -Contain 'WhatIf'
        (Get-Command Initialize-M365CollectorIdentity).Parameters.Keys | Should -Contain 'Confirm'
    }

    It 'does not automate consent or connector activation after the gate' {
        $result = Initialize-M365CollectorIdentity -Bootstrap -Confirm:$false
        $result.exitCode | Should -Be 1
        $result.checks[0].evidence | Should -Match 'does not automate tenant-wide consent, connector activation, or credentials'
    }
}
