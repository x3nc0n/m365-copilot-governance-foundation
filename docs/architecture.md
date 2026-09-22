# Architecture

## Design principle

The foundation is **native-first**. Microsoft Purview, Microsoft Defender, Microsoft Entra, Microsoft 365/Viva reporting, and Global Secure Access own their product-specific controls and evidence. Microsoft Sentinel adds cross-product correlation, tenant context, visualization, investigation routing, and telemetry health.

Sentinel is not the primary prompt classifier, DLP engine, insider-risk engine, identity-risk engine, compliance repository, retention system, eDiscovery store, or enforcement plane.

## Components

| Layer | Responsibility |
|---|---|
| Native control planes | Detect, enforce, retain, investigate, and report within their supported product semantics |
| Native connectors | Deliver supported signals to Sentinel/Log Analytics, subject to license, consent, region, cloud, and connector lifecycle |
| KQL functions | Normalize compatible sources through stable project functions and ASIM where semantics fit |
| Narrow analytics | Correlate existing native signals, policy context, identity context, and pipeline health |
| Workbooks | Show ownership, coverage, freshness, limitations, and native portal routes |
| PowerShell validation | Report prerequisites and exact gaps; remain read-only unless an explicit mutation switch is supplied |
| Bicep/ARM | Authoritative Azure resource-state contract |

The exact source/table contract is maintained in the Neo-owned [data-table catalog](data-tables.md). The exact service/control responsibility is maintained in the Neo-owned [native-control matrix](native-control-matrix.md).

## Data flow

1. Authoritative services generate native alerts, incidents, audit, identity, application, and activity data.
2. Supported connectors make some of those signals available in a Sentinel-enabled Log Analytics workspace.
3. Project functions adapt source fields and preserve the authoritative product, source identifiers, event/ingestion times, tenant context, normalization status, and native portal route.
4. Analytics perform only approved cross-product correlation, native-alert escalation, watchlist matching, risky-identity-plus-AI-activity correlation, and health detection.
5. Workbooks show what is present, absent, stale, unsupported, unlicensed, or unauthorized.
6. Investigators follow native links to the product that owns the control and detailed workflow.

Absence of a Sentinel record never proves absence of risk or compliance activity.

## Deployment topology

### Greenfield

`infra/greenfield/main.bicep` creates one Log Analytics workspace, enables Sentinel through the onboarding resource, and deploys shared content.

### Existing workspace

`infra/existing-workspace/main.bicep` references a caller-supplied workspace and deploys solution content. It must not delete the workspace or take ownership of unrelated settings and content.

Both paths call reusable modules and expose the frozen contracts documented in [Deployment](deployment.md). Existing resources are referenced rather than redeclared.

## Content model

The MVP workbook set covers:

1. governance overview and control ownership;
2. native-alert correlation and investigation context;
3. connector, table, parser, and ingestion data health;
4. coverage, gaps, optional modules, and remediation.

Analytics must include owner, prerequisites, severity rationale, entity mapping, grouping/suppression, false-positive guidance, incident behavior, native links, and test instructions. Content must tolerate missing optional sources and explicitly label the resulting limitation.

## Default exclusions

- `M365CopilotInteraction_CL`
- custom prompt regex or Sensitive Information Type classification
- duplicate DLP or Communication Compliance policy logic
- duplicate insider-risk or identity-risk scoring
- jailbreak-keyword rules
- high usage as a security finding
- Sentinel-based eDiscovery or records retention
- customer-specific watchlist content
- automatic administrator consent or broad directory-role assignment

`M365CopilotUsage_CL` is allowed only as an optional reporting cache and cannot, by itself, drive a security detection.

## Identity boundaries

Use distinct identities for:

- Azure deployment and explicit bootstrap;
- optional read-only usage collection;
- any exceptional, privacy-approved interaction export.

Prefer managed identity or workload federation. Use certificates only where federation is unavailable. Do not make client secrets the default.

## Failure and rollback boundaries

Missing data is a visible degraded state, not a silent success. Operators can redeploy a prior immutable release to restore content definitions. Existing-workspace rollback removes only stable, solution-owned resource identifiers. Workspace or resource-group deletion is never an implicit rollback.

See [Operations](operations.md), [Privacy and security](privacy-and-security.md), and [Troubleshooting](troubleshooting.md).
