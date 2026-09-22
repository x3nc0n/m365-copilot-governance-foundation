# Microsoft 365 Copilot Governance Foundation

[![Version](https://img.shields.io/badge/version-0.1.0-blue)](CHANGELOG.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A native-first, open-source reference implementation for adding Microsoft Sentinel correlation, visibility, investigation routing, and data-health monitoring to a Microsoft 365 Copilot governance program.

> **MVP status:** Version 0.1.0 is a reference architecture. Review every parameter, permission, connector, rule, retention setting, and cost assumption before production use. The `v0.1.0` GitHub Release includes the immutable deployment assets referenced below.

## Purpose

Microsoft Purview, Microsoft Defender, Microsoft Entra, Microsoft 365 reporting, Viva, and Global Secure Access remain the authoritative control planes. This project adds a focused Sentinel layer that:

- correlates signals already produced by authoritative Microsoft services;
- adds tenant policy context without embedding customer data;
- shows connector, table, parser, and ingestion health;
- routes investigators to the correct native portal;
- documents coverage gaps instead of treating missing Sentinel data as proof of safety.

### Non-goals

This project does **not** recreate DLP, DSPM, Insider Risk Management, Communication Compliance, eDiscovery, retention, identity-risk scoring, or Defender detections. It does not classify prompts with custom regular expressions, treat high Copilot usage as suspicious, ingest prompt/response content by default, grant tenant consent automatically, or provide a custom web application or always-on collector.

See [Architecture](docs/architecture.md), the Neo-owned [native-control ownership matrix](docs/native-control-matrix.md), and [data-table catalog](docs/data-tables.md).

## Architecture and data flow

```text
Purview / Defender / Entra / M365 / Viva / GSA
                 authoritative controls
                           |
                  supported connectors
                           v
              Microsoft Sentinel workspace
             /          |          |       \
      KQL functions  analytics  workbooks  health checks
             \          |          |       /
              native ownership + portal links
                           |
                           v
                 native product investigation
```

Native products generate alerts, incidents, audit, identity, application, and activity telemetry. Supported connectors deliver available signals to native Log Analytics tables. Stable KQL functions normalize compatible sources. Narrow analytics correlate signals across products. Workbooks surface ownership, freshness, limitations, and native portal handoffs.

The executable contracts live in Bicep and PowerShell. This README intentionally links to the catalogs rather than redefining table, control, parameter, or output contracts:

- [Data tables, connector prerequisites, latency, sensitivity, and fallback behavior](docs/data-tables.md)
- [Native control ownership and portal handoffs](docs/native-control-matrix.md)
- [Optional integrations and exceptional data paths](docs/optional-integrations.md)
- [Deployment parameters and outputs](docs/deployment.md)

## Deployment paths

### Prerequisites

- PowerShell 7.4 or later
- Azure CLI with Bicep support
- An Azure subscription, tenant, resource group, and supported region
- Rights appropriate to the selected deployment path; see [least privilege](docs/deployment.md#least-privilege)
- A Microsoft 365 tenant with the licenses and native products needed for the connectors you enable
- For separately authorized manual validation: Az and Microsoft Graph PowerShell modules described in [deployment guidance](docs/deployment.md#powershell-modules)

Validation is read-only by default. Bootstrap mutations require an explicit switch, support `-WhatIf` and `-Confirm`, and keep administrator consent and privacy/legal approval as human gates.

### Greenfield

This path creates a Log Analytics workspace, enables Microsoft Sentinel, and installs the governance content.

```powershell
.\scripts\Invoke-M365CopilotGovernance.ps1 -Command All
```

Review the plan before changing anything:

```powershell
az deployment group validate `
  --resource-group <resource-group> `
  --template-file .\infra\greenfield\main.bicep `
  --parameters .\infra\greenfield\main.bicepparam

az deployment group what-if `
  --resource-group <resource-group> `
  --template-file .\infra\greenfield\main.bicep `
  --parameters .\infra\greenfield\main.bicepparam

# Only after approval of the WhatIf result:
az deployment group create `
  --name m365gov-v0-1-0-greenfield `
  --resource-group <resource-group> `
  --template-file .\infra\greenfield\main.bicep `
  --parameters .\infra\greenfield\main.bicepparam
```

### Existing workspace

This path deploys solution-owned content into a caller-supplied Sentinel workspace. It does not own or delete the workspace.

```powershell
.\scripts\Invoke-M365CopilotGovernance.ps1 -Command All

az deployment group what-if `
  --resource-group <resource-group> `
  --template-file .\infra\existing-workspace\main.bicep `
  --parameters .\infra\existing-workspace\main.bicepparam

# Only after approval of the WhatIf result:
az deployment group create `
  --name m365gov-v0-1-0-existing `
  --resource-group <resource-group> `
  --template-file .\infra\existing-workspace\main.bicep `
  --parameters .\infra\existing-workspace\main.bicepparam
```

Confirm that only expected solution resources will change. See [Deployment](docs/deployment.md) for exact contracts, portal deployment, bootstrap controls, and rollback.

### Deploy to Azure

The buttons use immutable assets from the published `v0.1.0` GitHub Release. A git tag identifies source, but it does not create downloadable release assets: a `/releases/download/<tag>/<asset>` URL works only when a GitHub Release for that tag exists and contains the named asset.

| Path | Template | Portal UI |
|---|---|---|
| Greenfield | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fgithub.com%2Fx3nc0n%2Fm365-copilot-governance-foundation%2Freleases%2Fdownload%2Fv0.1.0%2Fgreenfield.json) | [Open custom deployment](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fgithub.com%2Fx3nc0n%2Fm365-copilot-governance-foundation%2Freleases%2Fdownload%2Fv0.1.0%2Fgreenfield.json/createUIDefinitionUri/https%3A%2F%2Fgithub.com%2Fx3nc0n%2Fm365-copilot-governance-foundation%2Freleases%2Fdownload%2Fv0.1.0%2Fgreenfield.createUiDefinition.json) |
| Existing workspace | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fgithub.com%2Fx3nc0n%2Fm365-copilot-governance-foundation%2Freleases%2Fdownload%2Fv0.1.0%2Fexisting-workspace.json) | [Open custom deployment](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fgithub.com%2Fx3nc0n%2Fm365-copilot-governance-foundation%2Freleases%2Fdownload%2Fv0.1.0%2Fexisting-workspace.json/createUIDefinitionUri/https%3A%2F%2Fgithub.com%2Fx3nc0n%2Fm365-copilot-governance-foundation%2Freleases%2Fdownload%2Fv0.1.0%2Fexisting-workspace.createUiDefinition.json) |

Before deployment, [anonymously download and verify every release asset](docs/release.md#verify-the-published-release), including JSON parsing and SHA-256 checks. Moving-branch URLs are intentionally unsupported.

## Validation and bootstrap workflow

1. Read [privacy and security boundaries](docs/privacy-and-security.md).
2. Run offline/static repository tests.
3. Run `Invoke-M365CopilotGovernance.ps1 -Command All` for offline validation. In v0.1.0, `-Online` does not authenticate or query a tenant; it returns a warning and hands off to separately authorized live validation.
4. Review every warning, skipped check, permission gap, unsupported source, and license dependency.
5. If collector-identity setup is being planned, run `Initialize-CollectorIdentity.ps1 -Bootstrap -WhatIf`. The v0.1.0 command validates the safety boundary but intentionally creates no identity or consent.
6. Obtain administrator consent and privacy/legal approval outside the scripts.
7. Run Azure deployment validation and `-WhatIf`.
8. Deploy only after the result matches the intended scope.
9. Run `Test-GovernanceDeployment.ps1` and the operational health checks.

Use separate identities for deployment/bootstrap, optional usage collection, and any exceptional interaction export. Prefer managed identity or workload federation; certificates are a fallback, and client secrets are not the default.

## Build and test

The canonical full build is:

```powershell
pwsh .\build\Invoke-Build.ps1 -CI
```

Targeted checks:

```powershell
az bicep lint --file .\infra\greenfield\main.bicep
az bicep lint --file .\infra\existing-workspace\main.bicep
az bicep build-params --file .\infra\greenfield\main.bicepparam
az bicep build-params --file .\infra\existing-workspace\main.bicepparam

az bicep build --file .\infra\greenfield\main.bicep --outfile .\infra\compiled\greenfield.json
az bicep build --file .\infra\existing-workspace\main.bicep --outfile .\infra\compiled\existing-workspace.json

@('.\powershell', '.\scripts', '.\build') |
  ForEach-Object {
    Invoke-ScriptAnalyzer -Path $_ -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
  }
Invoke-Pester -Path .\tests -CI
Invoke-Pester -Path .\tests\kql\KqlPolicy.Tests.ps1 -CI

Get-ChildItem .\infra,.\src,.\generated -Recurse -Filter *.json |
  ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json | Out-Null }
```

Function, analytic, and workbook metadata are validated against the schemas under [`schemas/`](schemas/) by the full build and Pester suite. Generated release integrity files are `generated/release-manifest.json` and `generated/checksums.sha256`. The generated content contract is `generated/content-manifest.json`; rebuild both compiled templates whenever it changes. Exact KQL projections remain authoritative in `src/functions`, while the supported data and ownership contracts remain in the Neo-owned catalogs linked above. These commands are local/static and do not authorize deployment or tenant mutation.

## Privacy boundaries

- Prompt and response content is excluded by default.
- `M365CopilotInteraction_CL` is not part of the default architecture.
- `M365CopilotUsage_CL`, when enabled, is an optional reporting cache and is not a risk signal by itself.
- Public templates contain no customer watchlist data, identities, tenant IDs, tokens, or exports.
- Workbooks favor metadata and native portal deep links over copied sensitive content.
- Sentinel is not an eDiscovery or records-retention repository.

See [Privacy and security](docs/privacy-and-security.md) and [Operations](docs/operations.md).

## Manual MVP test checklist

- [ ] Both Bicep entry points compile without unresolved errors.
- [ ] Compiled templates match the release assets and published checksums.
- [ ] Greenfield validation shows the intended workspace, Sentinel onboarding, and content resources.
- [ ] Existing-workspace validation does not replace, delete, or reconfigure unrelated workspace content.
- [ ] Portal UI fields map to the frozen Bicep parameters.
- [ ] Read-only validation succeeds without mutation switches.
- [ ] Every mutation preview is visible with `-WhatIf` and can be declined with `-Confirm`.
- [ ] Optional integrations are disabled by default.
- [ ] Missing/unlicensed connectors are reported as unsupported, unauthorized, absent, or skipped—not silently passed.
- [ ] Workbooks identify source, owner, freshness, limitation, and native portal destination.
- [ ] Analytics stay within the [native-control matrix](docs/native-control-matrix.md).
- [ ] Data-health checks detect a deliberately absent or stale optional source.
- [ ] Support output contains no tokens, tenant identifiers, identities, prompts, or responses.
- [ ] Rollback removes only solution-owned content; it never implicitly deletes a workspace.
- [ ] Current Azure and Microsoft license costs have been reviewed using [COSTS.md](COSTS.md).

## Documentation

- [Architecture](docs/architecture.md)
- [Deployment](docs/deployment.md)
- [Operations](docs/operations.md)
- [Privacy and security](docs/privacy-and-security.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Release process](docs/release.md)
- [Costs](COSTS.md)
- [Contributing](CONTRIBUTING.md)
- [Support](SUPPORT.md)
- [Security policy](SECURITY.md)

## License

Licensed under the [MIT License](LICENSE).
