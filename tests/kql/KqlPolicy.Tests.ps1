BeforeAll {
    $script:RepositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $sourceRoot = Join-Path $script:RepositoryRoot 'src'
    $script:KqlFiles = if (Test-Path -LiteralPath $sourceRoot) {
        @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter '*.kql')
    }
    else {
        @()
    }
}

Describe 'Native-first KQL policy' {
    It 'does not use the banned default interaction table' {
        foreach ($file in $script:KqlFiles) {
            Get-Content -LiteralPath $file.FullName -Raw | Should -Not -Match '\bM365CopilotInteraction_CL\b' -Because $file.FullName
        }
    }

    It 'does not classify prompts or jailbreak keywords' {
        foreach ($file in $script:KqlFiles) {
            $content = Get-Content -LiteralPath $file.FullName -Raw
            $content | Should -Not -Match '(?i)(prompt|response)\s*(matches regex|has_any|contains)' -Because $file.FullName
            $content | Should -Not -Match '(?i)\b(jailbreak|ignore previous instructions|prompt injection)\b' -Because $file.FullName
        }
    }

    It 'does not treat high usage as a risk signal' {
        foreach ($file in $script:KqlFiles) {
            Get-Content -LiteralPath $file.FullName -Raw | Should -Not -Match '(?is)(high|excessive)\s+usage.{0,80}(risk|suspicious|alert)' -Because $file.FullName
        }
    }
}
