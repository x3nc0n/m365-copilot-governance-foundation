@{
    RootModule        = 'M365CopilotGovernance.psm1'
    ModuleVersion     = '0.1.3'
    GUID              = '7c6cdf87-2d3a-4da8-ae76-40ef49fe4ab8'
    Author            = 'M365 Copilot Governance Foundation contributors'
    CompanyName       = 'Community'
    Copyright         = '(c) 2026 M365 Copilot Governance Foundation contributors'
    Description       = 'Offline-first deployment validation for the M365 Copilot Governance Foundation.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'ConvertTo-M365RedactedObject'
        'Invoke-M365GovernanceValidation'
        'Test-M365AuditConfiguration'
        'Test-M365GraphAccess'
        'Initialize-M365CollectorIdentity'
        'Test-M365SentinelConnector'
        'Test-M365CustomIngestion'
        'Test-M365DataHealth'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('Microsoft365', 'Copilot', 'Governance', 'Sentinel', 'Validation')
            ProjectUri = 'https://github.com/mcaps-us/m365-copilot-governance-foundation'
        }
    }
}
