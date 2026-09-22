# Native control ownership matrix

Microsoft Sentinel is the correlation, visualization, tenant-context, ASIM-normalization, investigation-routing, and operational-health plane. It does not replace the Microsoft services that own policy, detection, remediation, compliance, retention, or reporting semantics.

| Governance or security capability | Authoritative Microsoft control owner | Sentinel role in this project | Native route | Explicitly prohibited project behavior |
|---|---|---|---|---|
| Data loss prevention and sensitive-information controls | Microsoft Purview DLP and DSPM for AI | Display existing native outcomes and correlate alerts | `https://purview.microsoft.com/` | Custom DLP, prompt regex, custom sensitive-information classification, or duplicate policy decisions |
| Insider risk | Microsoft Purview Insider Risk Management | Correlate a supported native alert when available and document coverage gaps | `https://purview.microsoft.com/insiderrisk` | Custom insider-risk scoring, usage-as-misconduct, or inferred risky-user labels |
| Communication review | Microsoft Purview Communication Compliance | Route to existing native cases or alerts | `https://purview.microsoft.com/communicationcompliance` | Duplicate communication policies or content classification in KQL |
| Audit | Microsoft Purview Audit and Microsoft 365 workload audit | Query metadata needed for correlation and health | `https://purview.microsoft.com/audit` | Copy prompt or response content into workbooks, incidents, or custom tables by default |
| eDiscovery, retention, and records | Microsoft Purview eDiscovery, retention, and Records Management | Native deep links and coverage documentation only | `https://purview.microsoft.com/ediscovery` | Sentinel retention as eDiscovery, legal hold, or records management |
| Threat detection and investigation | Microsoft Defender XDR product family | Correlate existing alerts and evidence | `https://security.microsoft.com/alerts` | Reimplementation of Defender detections or independent threat scoring from raw AI activity |
| Identity risk and access enforcement | Microsoft Entra ID Protection and Conditional Access | Correlate a native identity-risk alert with other approved signals | `https://entra.microsoft.com/#view/Microsoft_AAD_IAM/IdentityProtectionMenuBlade/~/RiskyUsers` | Identity-risk recreation from sign-in failures, geography, volume, or other heuristics |
| Authentication normalization | Source authentication provider and Microsoft Entra ID; ASIM supplies normalization | Consume `_Im_Authentication` through `M365Gov_AuthenticationEvents` | Microsoft Entra sign-in logs | Treat a failed authentication, unusual country, or high count as a risk verdict by itself |
| AI agent activity normalization | Source AI platform; ASIM supplies Agent Event normalization | Consume `_Im_AgentEvent` through `M365Gov_AiActivity` when a semantically valid parser exists | Source-specific native portal | Fabricate Agent Event fields, expose request/response/thought content, or infer jailbreak behavior |
| Microsoft 365 Copilot usage reporting | Microsoft 365 admin center and Viva reporting | Optional aggregate reporting context only | `https://admin.microsoft.com/` | High-usage-as-risk or usage-as-misconduct analytics |
| Global Secure Access generative-AI visibility | Microsoft Entra Global Secure Access | Optional preview network context and source health | `https://entra.microsoft.com/` | Treat network-observed content or app access as a DLP, IRM, or prompt-safety verdict |
| Microsoft Sentinel incidents and analytics | Microsoft Sentinel | Correlation, escalation of existing native alerts, source health, and investigation routing | Azure portal Microsoft Sentinel workspace selector | Primary prompt classifier, compliance repository, identity-risk engine, insider-risk engine, or enforcement plane |

## Implemented analytics

All analytics ship **disabled by default**.

| Analytic | Native signals | Authoritative owner | Sentinel value | Safety boundary |
|---|---|---|---|---|
| `M365Gov-NativeAlert-RiskyIdentity` | Existing Entra identity-risk alert plus ASIM Agent Event activity | Microsoft Entra ID Protection and the source AI platform | Adds time-bounded cross-product context | Does not calculate identity risk and does not treat AI usage as suspicious |
| `M365Gov-CrossProduct-AlertCorrelation` | Two existing native alerts from different product or provider contexts | Each originating alert provider | Highlights a shared compromised entity | Does not reproduce either native detection or infer a common root cause |
| `M365Gov-DataSource-Silence` | `M365Gov_DataHealth` freshness states | Microsoft Sentinel operations; source products own telemetry | Opens a low-severity operational-health incident | Does not interpret silence as absence of risk or activity |

## Implemented workbooks

| Workbook | Purpose | Owner and route behavior |
|---|---|---|
| `m365gov-governance-overview` | Summarize control ownership and source health | Shows the native owner and route from `M365Gov_DataHealth` |
| `m365gov-native-alert-correlation` | Display existing native alerts and shared entity context | Routes to the Microsoft Defender portal and originating product |
| `m365gov-data-health` | Show freshness, silence, and connector investigation context | Routes operators to Microsoft Sentinel connectors and the source portal |
| `m365gov-coverage-and-gaps` | Separate MVP coverage from optional/preview sources | Keeps missing sources visible as gaps and never equates absence with safety |

## Coverage cautions

1. Sentinel-visible telemetry is not proof of native policy deployment, licensing, or control effectiveness.
2. Native portals can contain details that are unavailable or delayed in Sentinel.
3. Purview Insider Risk Management Risky AI Usage coverage is not assumed complete through Defender or Sentinel integrations.
4. `SecurityIncident` is an investigation container; the originating product continues to own the underlying verdict.
5. Preview sources, including `NetworkAccessGenerativeAIInsights`, require separate approval and must not expose their content fields.
