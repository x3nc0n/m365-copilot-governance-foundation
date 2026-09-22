@{
    Severity     = @('Error', 'Warning')
    IncludeRules = @(
        'PSAvoidUsingCmdletAliases'
        'PSAvoidUsingPlainTextForPassword'
        'PSAvoidUsingUsernameAndPasswordParams'
        'PSUseApprovedVerbs'
        'PSUseCmdletCorrectly'
        'PSUseDeclaredVarsMoreThanAssignments'
        'PSUseShouldProcessForStateChangingFunctions'
        'PSUseSupportsShouldProcess'
    )
    Rules        = @{
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('7.0')
        }
    }
}
