BeforeAll {
    $script:RepositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $portalRoot = Join-Path $script:RepositoryRoot 'infra/portal'
    $script:PortalFiles = if (Test-Path -LiteralPath $portalRoot) {
        @(Get-ChildItem -LiteralPath $portalRoot -Recurse -File -Filter 'createUiDefinition.json')
    }
    else {
        @()
    }
}

Describe 'Azure portal definitions' {
    It 'contains valid createUiDefinition contracts when present' {
        foreach ($file in $script:PortalFiles) {
            $definition = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -Depth 100
            $definition.'$schema' | Should -Match 'CreateUIDefinition'
            $definition.handler | Should -Be 'Microsoft.Azure.CreateUIDef'
            $definition.version | Should -Not -BeNullOrEmpty
            $definition.parameters.basics | Should -Not -BeNull
            $definition.parameters.steps | Should -Not -BeNull
            $definition.parameters.outputs | Should -Not -BeNull
        }
    }
}
