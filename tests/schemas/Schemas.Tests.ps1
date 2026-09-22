BeforeAll {
    $script:RepositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

Describe 'JSON schemas' {
    It 'defines every required schema as valid JSON Schema' {
        $required = @(
            'function-metadata.schema.json'
            'analytic-metadata.schema.json'
            'workbook-metadata.schema.json'
            'content-manifest.schema.json'
            'validation-result.schema.json'
            'release-manifest.schema.json'
        )

        foreach ($name in $required) {
            $path = Join-Path $script:RepositoryRoot "schemas/$name"
            Test-Path -LiteralPath $path | Should -BeTrue
            $schema = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -Depth 100
            $schema.'$schema' | Should -Be 'https://json-schema.org/draft/2020-12/schema'
            $schema.additionalProperties | Should -BeFalse
        }
    }

    It 'accepts the generated content manifest' {
        $manifestPath = Join-Path $script:RepositoryRoot 'generated/content-manifest.json'
        $schemaPath = Join-Path $script:RepositoryRoot 'schemas/content-manifest.schema.json'
        $raw = Get-Content -LiteralPath $manifestPath -Raw
        (Test-Json -Json $raw -SchemaFile $schemaPath) | Should -BeTrue
    }

    It 'uses the exact content arrays and solution version' {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot 'generated/content-manifest.json') -Raw | ConvertFrom-Json -Depth 100
        $manifest.solutionVersion | Should -Be '0.1.0'
        $contentArrays = @($manifest.PSObject.Properties.Name | Where-Object { $_ -in @('functions', 'analytics', 'workbooks') })
        $contentArrays | Should -HaveCount 3
        $contentArrays | Should -Contain 'functions'
        $contentArrays | Should -Contain 'analytics'
        $contentArrays | Should -Contain 'workbooks'
    }

    It 'validates all metadata against its schema' {
        $mappings = @{
            functions = 'function-metadata.schema.json'
            analytics = 'analytic-metadata.schema.json'
            workbooks = 'workbook-metadata.schema.json'
        }

        foreach ($kind in $mappings.Keys) {
            $root = Join-Path $script:RepositoryRoot "src/$kind"
            if (-not (Test-Path -LiteralPath $root)) {
                continue
            }
            foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.metadata.json') {
                $schema = Join-Path $script:RepositoryRoot "schemas/$($mappings[$kind])"
                $raw = Get-Content -LiteralPath $file.FullName -Raw
                (Test-Json -Json $raw -SchemaFile $schema) | Should -BeTrue -Because $file.FullName
            }
        }
    }
}
