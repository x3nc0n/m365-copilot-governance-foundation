# Copilot interaction content collection

Version 0.2.0 adds an explicit, deployment-time decision to collect Microsoft 365 Copilot prompt and response content into Microsoft Sentinel. The `interactionContentCollection` parameter is **required** and has no default: every deployment must choose `Enabled` or `Disabled`. The Deploy to Azure experience cannot proceed until one is selected.

Read [Privacy and security](privacy-and-security.md) before choosing `Enabled`. Prompt and response text is highly sensitive, may contain personal, confidential, privileged, or regulated information, and can constitute workplace monitoring.

## Pipeline

```text
Microsoft Graph interaction export API (getAllEnterpriseInteractions)
        |  application permission, per user, hourly window
        v
Azure Functions (Flex Consumption, .NET 8 isolated, user-assigned managed identity)
        |  Logs Ingestion API
        v
Data collection rule (kind Direct) -> M365GovCopilotInteractionContent_CL (90-day retention)
        v
Workbook "Interaction Content" tab, KQL search, and one disabled analytic rule
```

When `Enabled`, the entry points deploy `infra/modules/interaction-collector/main.bicep` into the workspace resource group and region:

| Resource | Purpose |
|---|---|
| `M365GovCopilotInteractionContent_CL` | Custom table with 90-day interactive and total retention |
| Data collection rule (`Direct`) | Logs Ingestion endpoint and `Custom-M365GovCopilotInteractionContent` stream |
| User-assigned managed identity `<prefix>-copilot-collector-id` | Only identity used by the collector for Graph, storage, ingestion, and telemetry |
| Storage account (shared keys disabled) | Function package container and checkpoint blob |
| Application Insights (local auth disabled) | Collector telemetry |
| Flex Consumption plan and Function App | Timer-triggered collector (`0 5 * * * *`) |
| `onedeploy` site extension | Deploys `released-package.zip` from the GitHub release |

When `Disabled`, none of these resources are deployed and the content-dependent analytic is skipped. The workbook tab remains and shows no data.

## Collection scope

| `interactionCollectionScope` | Users collected | Additional input |
|---|---|---|
| `AllLicensedUsers` (default) | Every user with an enabled Microsoft 365 Copilot service plan (`3f30311c-6b1e-48a4-ab79-725b469da960`) | None |
| `IncludeGroup` | Licensed users who are transitive members of the group | `interactionCollectionGroupId` (GUID) |
| `ExcludeGroup` | Licensed users except transitive members of the group | `interactionCollectionGroupId` (GUID) |

The collector fails closed when the scope or group ID is invalid.

## Graph permissions (bootstrap)

The deployment cannot grant Microsoft Graph application permissions. After deployment, a Privileged Role Administrator or Global Administrator grants them to the collector identity by using the `interactionCollectorPrincipalId` output:

```powershell
Connect-MgGraph -Scopes 'AppRoleAssignment.ReadWrite.All','Application.Read.All','GroupMember.Read.All'

.\scripts\Initialize-CollectorIdentity.ps1 -Bootstrap `
  -ManagedIdentityPrincipalId <interactionCollectorPrincipalId> `
  -CollectionScope AllLicensedUsers -WhatIf

.\scripts\Initialize-CollectorIdentity.ps1 -Bootstrap `
  -ManagedIdentityPrincipalId <interactionCollectorPrincipalId> `
  -CollectionScope AllLicensedUsers -Confirm
```

| Scope | Application roles granted |
|---|---|
| All scopes | `AiEnterpriseInteraction.Read.All`, `User.Read.All` |
| `IncludeGroup`, `ExcludeGroup` | Also `GroupMember.Read.All` |

The script never signs in implicitly, validates the group, grants only missing roles, supports `-WhatIf` and `-Confirm`, and returns exit code `2` for validation failures and `3` for operational errors. Without `-Bootstrap` it reports the plan only. The collector records no content until the roles are granted; failed runs do not advance the checkpoint.

## Data behavior

- **At-least-once delivery.** The checkpoint advances only after every in-scope user in a window is exported. Retries can produce duplicates; queries deduplicate with `summarize arg_max(TimeGenerated, *) by InteractionId`.
- **Truncation.** `BodyContent` and serialized attachments are truncated at 30,000 UTF-8 bytes and flagged with `BodyTruncated` and `AttachmentsTruncated`.
- **Coverage.** The Graph API covers Microsoft 365 Copilot interactions; Copilot Studio agents are not included. The API has no delta query; the collector uses `createdDateTime` windows with a 30-minute ingestion lag.
- **Clouds.** The collector uses `graph.microsoft.com` (Global). Sovereign clouds are not supported by this release.
- **Retention.** 90 days. Changing retention is a customer decision and must follow records and privacy obligations.

## Access

Anyone who can read the workspace table or open the workbook can read collected content. Workbook tabs cannot enforce separate permissions. Restrict access with workspace or table-level Azure RBAC, limit workbook readers, and review access regularly.

## Analytics

`M365Gov-InteractionContent-NativeOutcome` is deployed only when content collection is `Enabled` (and `deployAnalytics` is `true`), and like every rule it is created disabled. It alerts only on Microsoft-provided outcomes in `CopilotActivity` (jailbreak detection, cross-prompt injection detection, and Purview policy details) and adds interaction IDs so investigators can pivot to the stored content. It never copies prompt or response text into alerts and does not implement custom keyword or regex classification.

## Operations

- **Flex Consumption availability.** Deploy to a region that supports Flex Consumption; the collector deploys in the workspace region.
- **Package deployment.** `onedeploy` downloads `released-package.zip` from the tagged GitHub release. If it fails on the first deployment (for example, while role assignments propagate), rerun the same deployment. Override `interactionCollectorPackageUri` to host the package elsewhere.
- **Disabling later.** Redeploying with `Disabled` stops deploying the collector but does not delete existing collector resources or collected data. Delete the Function App, identity, and data explicitly after confirming records obligations, and remove the Graph app-role assignments.
