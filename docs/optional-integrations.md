# Optional and exceptional integrations

Optional integrations are disabled by default, separately deployed, and never prerequisites for the MVP. Each integration requires a documented owner, purpose, permissions, consent, retention, geography, cost, support boundary, native route, and safe failure mode.

## Decision gates

Before enabling an optional integration, record:

1. The native coverage gap that cannot be met by a supported connector, table, ASIM parser, or native portal.
2. The authoritative Microsoft control owner and why Sentinel access is necessary.
3. Minimum permissions and administrator-consent requirements.
4. Privacy/legal approval, data minimization, data residency, retention, purge, and access controls.
5. Separate identity boundaries for deployment, reporting collection, and sensitive export.
6. Cost and volume estimates.
7. Freshness expectations and behavior when the source is absent, stale, unauthorized, or unsupported.
8. A rollback plan that does not delete unrelated workspace data.

## Microsoft Graph Security enrichment

**Status:** Optional; separately validated.

Use only when current Microsoft Graph Security API coverage supplies a documented native alert or incident detail that is unavailable through supported connectors. Permissions must be read-only and least privilege. Administrator consent is explicit.

Limitations:

- API coverage varies by provider and can differ from the native portal.
- Purview Insider Risk Management Risky AI Usage events are not assumed to be fully represented.
- Current IRM incidents can lack the alert detail needed for reliable Sentinel correlation.
- Failure or incomplete enrichment must preserve the native alert and route, not suppress it.

Safe fallback: show the existing native alert with an enrichment-unavailable status and route investigators to the authoritative portal.

## Microsoft 365 Copilot usage reporting cache

**Status:** Optional reporting cache only; disabled by default.

If a tenant has a justified need for a Sentinel-local aggregate cache, a future `M365CopilotUsage_CL` integration can store minimized aggregate reporting fields. It must use a dedicated read-only reporting identity and an approved retention period.

Prohibited uses:

- High usage as a security alert.
- Usage volume as misconduct, insider risk, identity risk, or policy evasion.
- User ranking for disciplinary or behavioral surveillance.

Safe fallback: use Microsoft 365 admin center or Viva reporting directly. The default workbooks and analytics do not depend on this table.

## Privacy-approved interaction export

**Status:** Exceptional only; excluded from the default architecture.

`M365CopilotInteraction_CL` is not an MVP table. Consider an interaction export only when a documented coverage gap cannot be met in Microsoft Purview or another authoritative native service and privacy/legal approval explicitly authorizes the data flow.

Required isolation:

- Separate identity from deployment and usage reporting.
- Data minimization that excludes prompt and response content whenever possible.
- Explicit field-level schema, regional storage decision, retention, purge, access review, and audit.
- No reusable public sample containing tenant data.
- No custom DLP, prompt regex, jailbreak-keyword, insider-risk, or communication-compliance logic.

Safe fallback: retain investigation in Microsoft Purview, Defender, or the source application. Sentinel content must show the integration as unavailable rather than infer safety.

## Global Secure Access generative-AI insights

**Status:** Optional preview; disabled by default.

`NetworkAccessGenerativeAIInsights` can provide network-observed generative-AI and MCP activity when the preview is licensed, enabled, regionally supported, and approved.

Limitations and privacy:

- Preview schema and service behavior can change.
- The table includes a `Content` field. Project functions, analytics, and workbooks must not select or display it.
- Network visibility is not equivalent to Purview DLP, Insider Risk Management, Communication Compliance, or source-application audit.
- `Action` values such as allow or block are source policy outcomes, not a custom Sentinel verdict.

Safe fallback: mark the source optional/unavailable and retain Global Secure Access as the native investigation and enforcement plane.

## Custom ASIM Agent Event parser

**Status:** Optional engineering extension.

The official ASIM Agent Event schema and `_Im_AgentEvent` parser are the preferred boundary. Create a source parser only when the source fields satisfy current ASIM semantics.

Requirements:

- Follow official parser naming and filtering conventions.
- Validate mandatory common fields and source-specific mappings.
- Do not populate request, response, thought-process, model, tool, agent, or token fields from values with different semantics.
- Exclude prompt, response, thought-process, and arbitrary content fields from project-facing functions.
- Document parser version, source version, dependencies, latency, and fallback.

Safe fallback: query the source-specific native audit table and clearly label it unnormalized. Do not force invalid ASIM semantics.

## Tenant context watchlists

**Status:** Optional and customer-owned.

Watchlists can add approved business context such as critical applications or monitored organizational units. Public templates contain no customer values.

Safe fallback: omit enrichment. A missing watchlist must not suppress a native alert or create a risk determination.
