# Contributing

Thank you for improving the Microsoft 365 Copilot Governance Foundation.

## Before you start

1. Read the [architecture](docs/architecture.md), [native-control matrix](docs/native-control-matrix.md), and [privacy boundaries](docs/privacy-and-security.md).
2. Search existing issues and open a proposal for substantial behavior or contract changes.
3. Never include tenant data, customer exports, credentials, tokens, prompt/response content, or real identities.
4. Keep Microsoft native services authoritative. A contribution must not recreate native DLP, insider-risk, identity-risk, retention, eDiscovery, or prompt-classification logic.

## Development

Create a focused branch, make the smallest complete change, and add tests for changed behavior. Preserve frozen parameter, output, table, function, analytic, and workbook contracts unless the change is explicitly reviewed as breaking.

```powershell
pwsh .\build\Invoke-Build.ps1 -CI

az bicep build --file .\infra\greenfield\main.bicep --outfile .\infra\compiled\greenfield.json
az bicep build --file .\infra\existing-workspace\main.bicep --outfile .\infra\compiled\existing-workspace.json
@('.\powershell', '.\scripts', '.\build') |
  ForEach-Object {
    Invoke-ScriptAnalyzer -Path $_ -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
  }
Invoke-Pester -Path .\tests -CI
```

Documentation-only changes should still use valid internal links and consistent product terminology.

## Pull requests

Include:

- the problem and intended outcome;
- affected deployment paths and optional features;
- test evidence;
- cost, permissions, privacy, and migration impact;
- screenshots only when they contain synthetic or redacted data;
- release-note text for user-visible changes.

By contributing, you agree that your contribution is licensed under the repository's [MIT License](LICENSE).

## Reporting vulnerabilities

Do not open a public issue. Follow [SECURITY.md](SECURITY.md).
