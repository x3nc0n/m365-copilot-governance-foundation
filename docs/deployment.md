# Deployment

Two resource-group-scoped entry points deploy the same governance content:

- `infra/greenfield/main.bicep`
- `infra/existing-workspace/main.bicep`

Use tagged release assets for production-like deployment. Build from source for development and validation.

## Prerequisites

- PowerShell 7.4+
- Azure CLI and current Bicep CLI support
- Azure subscription and target resource group
- A region supporting Log Analytics and Microsoft Sentinel
- Required Microsoft 365, Purview, Defender, Entra, and Global Secure Access licenses for selected sources
- Explicit administrator consent for any requested Microsoft Graph permissions
- Privacy/legal approval for any sensitive optional collection

### PowerShell modules

Install modules only on an operator-controlled system:

```powershell
Install-Module Az -Scope CurrentUser
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module Pester -Scope CurrentUser
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

Pin approved versions in controlled build environments. Authentication is an explicit operator action; scripts must not cache or print access tokens. Version 0.1.0 does not automatically authenticate or perform live tenant queries: `-Online` returns a handoff warning for separately authorized validation.

## Least privilege

Separate Azure deployment RBAC from Microsoft Graph and Microsoft 365 consent.

- A resource-group deployment requires permission to validate and deploy the resource types in the template at the target scope.
- Greenfield also requires workspace creation and Sentinel onboarding permissions.
- Existing-workspace deployment requires content-management rights on the selected workspace, not ownership of the subscription.
- Role-assignment permission is required only if a reviewed deployment explicitly creates assignments.
- Tenant bootstrap uses feature-specific Graph permissions and reports required versus effective consent.

Do not grant Global Administrator, Owner, User Access Administrator, or broad application permissions merely for convenience. Use a privileged deployment identity only for the shortest necessary operation.

## Frozen executable contracts

Bicep files, parameter files, compiled templates, and PowerShell command definitions are authoritative. Do not infer names from prose. The release validation checks parameter/output alignment across both paths and the portal definitions.

### Entry-point parameters

Both paths use these exact parameters:

| Name | Type | Default |
|---|---|---|
| `location` | string | Resource-group location |
| `solutionName` | string | `m365CopilotGovernance` |
| `solutionVersion` | string | `0.1.0` |
| `resourceNamePrefix` | string | `m365gov` |
| `deployFunctions` | bool | `true` |
| `deployAnalytics` | bool | `true` |
| `deployWorkbooks` | bool | `true` |
| `analyticsEnabled` | bool | `false` |
| `tags` | object | `{}` |

Greenfield adds `workspaceName` (required), `workspaceSku` (default `PerGB2018`), and `workspaceRetentionInDays` (default `30`, allowed `30`–`730`). Existing-workspace adds required `workspaceResourceId`.

Both paths expose these exact outputs:

- `solutionVersion`
- `deploymentMode`
- `workspaceResourceId`
- `sentinelOnboardingStateResourceId`
- `functionResourceIds`
- `analyticRuleResourceIds`
- `workbookResourceIds`
- `deployedResourceIds`

The wrapper's exact parameters are `Command`, `RepositoryRoot`, `Online`, `Bootstrap`, and `OutputFormat`. `Command` accepts `All`, `Deployment`, `Audit`, `Graph`, `Identity`, `SentinelConnector`, `CustomIngestion`, or `DataHealth`; `OutputFormat` accepts `Json` or `Object`.

### Validation result contract

The authoritative contract is [`schemas/validation-result.schema.json`](../schemas/validation-result.schema.json). Results expose `schemaVersion`, `command`, `status`, `exitCode`, `offline`, `checks`, `summary`, and `redactionsApplied`. Each `checks` entry exposes `name`, `status`, `evidence`, and `remediation`; `summary` exposes `passed`, `warnings`, `failed`, and `skipped`.

Exit codes are frozen as:

| Code | Meaning |
|---:|---|
| `0` | Pass or intentionally skipped |
| `1` | Warning |
| `2` | Validation failure |
| `3` | Operational error |

The deployment-ready manifest contract is [`schemas/content-manifest.schema.json`](../schemas/content-manifest.schema.json). It embeds each KQL query and workbook `serializedData` plus every property consumed by the Bicep modules. Generated outputs are `generated/content-manifest.json`, `generated/release-manifest.json`, `generated/checksums.sha256`, and the flattened upload payload under `generated/release-assets`. Documentation links these schemas rather than redefining their bodies.

To inspect the current contract locally:

```powershell
Get-Help .\scripts\Invoke-M365CopilotGovernance.ps1 -Full
```

The Neo-owned [data-table catalog](data-tables.md) and [native-control matrix](native-control-matrix.md) are authoritative for data and control ownership; they are not duplicated here.

## Build

Run the canonical build:

```powershell
pwsh .\build\Invoke-Build.ps1 -CI
```

For targeted infrastructure validation:

```powershell
az bicep lint --file .\infra\greenfield\main.bicep
az bicep lint --file .\infra\existing-workspace\main.bicep
az bicep build-params --file .\infra\greenfield\main.bicepparam
az bicep build-params --file .\infra\existing-workspace\main.bicepparam

az bicep build --file .\infra\greenfield\main.bicep --outfile .\infra\compiled\greenfield.json
az bicep build --file .\infra\existing-workspace\main.bicep --outfile .\infra\compiled\existing-workspace.json
```

The content module loads `generated/content-manifest.json`. Regenerate that manifest before compiling, and rebuild both templates whenever the manifest or anything under `src/functions`, `src/analytics`, or `src/workbooks` changes. Metadata contracts are validated against `schemas/function-metadata.schema.json`, `schemas/analytic-metadata.schema.json`, and `schemas/workbook-metadata.schema.json`. Exact function projections remain defined by their source KQL and the Neo-owned [data-table catalog](data-tables.md), not by this deployment guide.

## Greenfield deployment

1. Copy and review `infra/greenfield/main.bicepparam`.
2. Run static tests.
3. Validate prerequisites:

   ```powershell
   .\scripts\Invoke-M365CopilotGovernance.ps1 -Command All
   ```

4. Preview changes:

   ```powershell
   az deployment group validate `
     --resource-group <resource-group> `
     --template-file .\infra\greenfield\main.bicep `
     --parameters .\infra\greenfield\main.bicepparam

   az deployment group what-if `
     --resource-group <resource-group> `
     --template-file .\infra\greenfield\main.bicep `
     --parameters .\infra\greenfield\main.bicepparam

   az deployment group create `
     --name m365gov-v0-1-0-greenfield `
     --resource-group <resource-group> `
     --template-file .\infra\greenfield\main.bicep `
     --parameters .\infra\greenfield\main.bicepparam
   ```

5. Deploy only after reviewing the exact resource list, permissions, location, retention, optional features, and cost.
6. Complete the [manual test checklist](../README.md#manual-mvp-test-checklist) and separately authorized live checks.

## Existing-workspace deployment

1. Confirm that the workspace resource ID is correct and Sentinel is onboarded or can be validated.
2. Inventory unrelated workbooks, rules, functions, watchlists, and connectors.
3. Copy and review `infra/existing-workspace/main.bicepparam`.
4. Run:

   ```powershell
   .\scripts\Invoke-M365CopilotGovernance.ps1 -Command All

   az deployment group validate `
     --resource-group <resource-group> `
     --template-file .\infra\existing-workspace\main.bicep `
     --parameters .\infra\existing-workspace\main.bicepparam

   az deployment group what-if `
     --resource-group <resource-group> `
     --template-file .\infra\existing-workspace\main.bicep `
     --parameters .\infra\existing-workspace\main.bicepparam

   az deployment group create `
     --name m365gov-v0-1-0-existing `
     --resource-group <resource-group> `
     --template-file .\infra\existing-workspace\main.bicep `
     --parameters .\infra\existing-workspace\main.bicepparam
   ```

5. Reject the deployment if it modifies unrelated workspace settings or content.
6. Deploy and record the solution-owned resource output manifest.

## Direct Azure CLI validation and deployment

After selecting a subscription and resource group:

```powershell
az deployment group validate `
  --resource-group <resource-group> `
  --template-file .\infra\greenfield\main.bicep `
  --parameters .\infra\greenfield\main.bicepparam

az deployment group what-if `
  --resource-group <resource-group> `
  --template-file .\infra\greenfield\main.bicep `
  --parameters .\infra\greenfield\main.bicepparam

az deployment group create `
  --name m365gov-v0-1-0-greenfield `
  --resource-group <resource-group> `
  --template-file .\infra\greenfield\main.bicep `
  --parameters .\infra\greenfield\main.bicepparam
```

Substitute the existing-workspace paths and use a distinct deployment name for that scenario. Validation and `what-if` require Azure access but do not constitute approval to deploy. Run `create` only after the exact `what-if` result is approved.

## Bootstrap

Validation commands are read-only by default. A tenant mutation requires `-Bootstrap` or another narrowly named mutation switch. Every mutating command must support `SupportsShouldProcess`, `-WhatIf`, and `-Confirm`, and must report the exact intended and applied difference.

`Initialize-CollectorIdentity.ps1` has exact parameters `Bootstrap` and `OutputFormat`. Without `-Bootstrap`, it returns a skipped result. With `-Bootstrap`, v0.1.0 still creates no identity or consent; it exercises the `ShouldProcess` boundary and returns an explicit warning. Example safety flow:

```powershell
.\scripts\Initialize-CollectorIdentity.ps1 -Bootstrap -WhatIf
.\scripts\Initialize-CollectorIdentity.ps1 -Bootstrap -Confirm
```

Use `Get-Help <script> -Full` for the exact frozen parameters. Administrator consent and privacy/legal approval are never automated.

## Deploy to Azure portal assets

Version 0.1.0 uses these immutable raw tagged templates:

```text
https://raw.githubusercontent.com/x3nc0n/m365-copilot-governance-foundation/v0.1.0/generated/release-assets/greenfield.json
https://raw.githubusercontent.com/x3nc0n/m365-copilot-governance-foundation/v0.1.0/generated/release-assets/existing-workspace.json
```

Portal definition assets use the corresponding `greenfield.createUiDefinition.json` and `existing-workspace.createUiDefinition.json` names. The `v0.1.0` GitHub Release is published with all required assets.

Azure Portal must retrieve both files cross-origin. Follow the [Microsoft Deploy to Azure button guidance](https://learn.microsoft.com/azure/azure-resource-manager/templates/deploy-to-azure-button): use each raw GitHub URL, URL-encode it, and append it to the portal route. The raw tagged URLs provide the required CORS response and remain immutable because they are pinned to `v0.1.0`.

GitHub Release assets serve a different purpose: human downloads, `release-manifest.json`, `checksums.sha256`, and release provenance. A successful release-asset download does not prove that Azure Portal can fetch that response cross-origin. Before opening a Deploy to Azure link, complete both the [portal header verification](release.md#verify-the-portal-assets) and the [release checksum verification](release.md#verify-the-published-release).

Asset verification proves publication integrity; it does not authorize or validate an Azure deployment. Preserve the native-first boundary: review the authoritative Microsoft control-plane ownership, then run Azure `validate` and `what-if` manually with separately authorized access before any `create` operation.

## Rollback

- Redeploy the prior immutable tag to restore prior definitions.
- Disable rules/connectors before removing content when investigation continuity matters.
- Remove only resources listed in the solution-owned output manifest.
- Never delete an existing workspace as part of content rollback.
- Never automatically revoke tenant consent or delete an identity.
- Review retention and export obligations before deleting a greenfield workspace or resource group.
