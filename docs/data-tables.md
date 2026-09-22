# Data tables and ownership

This catalog describes the native tables that the Microsoft 365 Copilot governance foundation can consume. Table presence is conditional on licensing, connector configuration, tenant settings, cloud, region, permissions, and Microsoft service lifecycle. An absent or empty table is a **coverage state**, not evidence that no risk, audit, compliance, identity, or AI activity occurred.

The default MVP does not create custom interaction or usage tables. Project functions and ASIM parsers are the stable consumer boundary where practical.

## Core and conditional native tables

| Table | Authoritative Microsoft owner | Native route | MVP posture | Freshness expectation | Caveats and safe missing-source behavior |
|---|---|---|---|---|---|
| `CopilotActivity` | Microsoft Purview Audit / Microsoft 365 audit | `https://purview.microsoft.com/audit` | Core audit source when available | Commonly within hours; tenant and audit pipeline dependent | Contains Copilot and other AI workload audit records. `LLMEventData` is dynamic and can contain sensitive interaction details; this solution does not select or display it. `RecordType`, workload, and field population can evolve. If absent, report a coverage gap and continue native Purview investigation. Do not infer no Copilot activity. |
| `SecurityAlert` | The originating Microsoft Defender, Entra, Purview, or integrated native alert provider | `https://security.microsoft.com/alerts` | Core correlation source | Commonly minutes; provider and connector dependent | Alert schema and entity population vary by provider. `CompromisedEntity` is not guaranteed. The project correlates existing alerts only and does not reproduce native detections. If absent, disable alert-dependent content and surface source health. |
| `SecurityIncident` | Microsoft Sentinel for the incident container; originating products retain detection ownership | Azure portal Microsoft Sentinel workspace selector | Core investigation source | Commonly minutes after incident creation or update | An incident is a mutable investigation container, not a new authoritative security verdict. Alert details can be incomplete or delayed. If absent, route to native alert portals and show the incident source as unavailable. |
| `SigninLogs` | Microsoft Entra ID | Microsoft Entra admin center, **Identity > Monitoring & health > Sign-in logs** | Core authentication source through ASIM | Commonly minutes; licensing and export dependent | Interactive sign-ins only. Do not calculate identity risk from success, failure, location, or volume. Consume through `_Im_Authentication` / `M365Gov_AuthenticationEvents` where possible. |
| `AADNonInteractiveUserSignInLogs` | Microsoft Entra ID | Microsoft Entra sign-in logs | Conditional authentication source through ASIM | Commonly minutes; licensing and export dependent | Non-interactive token activity can be high volume and has different semantics from interactive sign-in. Do not treat volume as misconduct. Missing data is reported as a connector or coverage gap. |
| `AuditLogs` | Microsoft Entra ID | Microsoft Entra admin center, **Identity > Monitoring & health > Audit logs** | Core directory-change context | Commonly minutes to hours | Records directory operations, not Microsoft 365 content audit. Field availability depends on the operation. If absent, continue investigation in Entra and mark the Sentinel dependency unavailable. |
| `IdentityInfo` | Microsoft Defender XDR | `https://security.microsoft.com/` | Conditional enrichment | Source synchronization dependent; allow up to a day | Inventory/enrichment data can be delayed and should not be treated as a real-time identity-risk feed. Never recreate Entra ID Protection risk from this table. |
| `CloudAppEvents` | Microsoft Defender for Cloud Apps / Defender XDR | `https://security.microsoft.com/cloudapps` | Conditional activity and application context | Commonly minutes to hours | Event coverage depends on connected apps and Defender configuration. Activities are context, not misconduct by themselves. |
| `MicrosoftPurviewInformationProtection` | Microsoft Purview Information Protection | `https://purview.microsoft.com/` | Conditional classification/protection context | Workload and connector dependent | Native labels and protection outcomes remain authoritative in Purview. Sentinel must not implement substitute sensitive-information classification or DLP logic. Missing data is a coverage gap, not proof that content is unlabeled. |
| `OfficeActivity` | Microsoft Purview Audit and Microsoft 365 workloads | `https://purview.microsoft.com/audit` | Core audit source where connector is used | Commonly within hours; audit workload dependent | Multi-workload schema with operation-specific fields. Some Copilot events can be represented in dedicated sources instead. Do not assume every Purview or Microsoft 365 audit event is available or normalized identically. |
| `EnrichedMicrosoft365AuditLogs` | Microsoft Purview Audit | `https://purview.microsoft.com/audit` | Conditional enriched audit source | Connector and service dependent | Availability and enrichment fields can differ by tenant and connector generation. Consumers must not assume parity with `OfficeActivity` or `CopilotActivity`. Prefer explicit field checks and report absence. |
| `NetworkAccessGenerativeAIInsights` | Microsoft Entra Global Secure Access | Microsoft Entra admin center, Global Secure Access | Optional preview | Preview pipeline dependent | Preview schema and availability can change. The table includes a `Content` field; this solution intentionally does not query or display it. It can provide network-observed generative-AI and MCP context, but it is not a Purview DLP, prompt-safety, or insider-risk verdict. Keep disabled unless preview terms, licensing, privacy, and regional requirements are approved. |

## Defender XDR advanced-hunting tables

Defender advanced-hunting tables are conditional. Availability in Microsoft Sentinel depends on the supported Defender XDR integration and current Microsoft service behavior. The native Defender portal remains authoritative.

| Table | Native owner | Intended use | Caveats |
|---|---|---|---|
| `AlertInfo` | Microsoft Defender XDR | Native alert metadata | Pair with `AlertEvidence` when available. It does not replace `SecurityAlert` in every integration path. |
| `AlertEvidence` | Microsoft Defender XDR | Entities and evidence associated with native alerts | Evidence can be sparse or updated after the alert. Do not promote evidence to a separate custom risk score. |
| `DeviceEvents` | Microsoft Defender for Endpoint | Device and endpoint activity context | High-volume and product-specific. Use only for scoped investigation or native alert enrichment. |
| `IdentityLogonEvents` | Microsoft Defender for Identity / Defender XDR | Identity logon context | Not equivalent to Entra sign-in logs and not a replacement for `_Im_Authentication`. |
| `IdentityDirectoryEvents` | Microsoft Defender for Identity / Defender XDR | Directory activity context | Coverage depends on Defender for Identity sensors and service processing. |
| `IdentityQueryEvents` | Microsoft Defender for Identity / Defender XDR | Identity-related query context | Conditional and potentially sparse; absence is not proof that no directory queries occurred. |
| `CloudAppEvents` | Microsoft Defender for Cloud Apps / Defender XDR | Cloud application activity | Connected-app and policy coverage varies. Activity alone is not a misconduct determination. |

Other Defender advanced-hunting tables can be added only when a workbook or analytic declares the exact dependency, owner, freshness, native route, and missing-source behavior.

## Stable project functions

| Function | Primary dependency | Purpose | Missing-source behavior |
|---|---|---|---|
| `M365Gov_NativeAlerts` | `SecurityAlert`, `SecurityIncident` | Stable projection for native alerts and incidents | Returns available fuzzy-union sources. If neither source resolves, deployment validation must mark the function unavailable. |
| `M365Gov_AuthenticationEvents` | `_Im_Authentication` | ASIM-normalized authentication context | Dependent content stays disabled when the ASIM parser is absent. |
| `M365Gov_AiActivity` | `_Im_AgentEvent` | ASIM-normalized AI agent activity without request, response, thought-process, or content fields | Dependent content stays disabled when no valid Agent Event parser exists. Source-specific audit queries are the fallback; invalid ASIM semantics are not fabricated. |
| `M365Gov_DataHealth` | Native table catalog | Per-source freshness and silence status | Retains every expected source and labels unobserved inputs `UnavailableOrSilent`. |

## ASIM boundaries

- `_Im_Authentication` is the required normalization boundary for authentication analytics.
- `_Im_AgentEvent` is the supported ASIM Agent Event unifying parser. Source parser coverage can lag the schema.
- `CopilotActivity` is not automatically force-mapped to ASIM Agent Event. A parser can be introduced only after each required mapping is validated against current official semantics.
- No project function exposes prompt text, response text, thought-process details, `LLMEventData`, or `NetworkAccessGenerativeAIInsights.Content`.

## Excluded default custom tables

- `M365CopilotInteraction_CL` is not part of the default architecture.
- `M365CopilotUsage_CL` is not part of the default architecture.

See [Optional integrations](optional-integrations.md) for the exceptional approval and isolation requirements that apply before either pattern can be considered.
