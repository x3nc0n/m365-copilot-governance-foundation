# Cost Guide

This guide makes cost drivers visible; it is not a quote. Prices and licensing change by region, currency, agreement, benefit eligibility, commitment tier, and date. Validate every estimate in the [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) and against your Microsoft and GitHub agreements.

## Assumptions and status labels

- **Pricing date:** September 22, 2026
- **Illustrative Azure region:** East US
- **Currency:** USD, public retail, before tax, discounts, credits, commitments, or negotiated terms
- **Month:** 30 days
- **Known:** directly observed or published
- **Estimated:** a bounded planning assumption
- **Variable:** customer-specific and calculated from usage
- **Not included:** outside this repository's deployment

The Azure rates below were checked against the official [Azure Retail Prices API](https://prices.azure.com/api/retail/prices), [Microsoft Sentinel pricing](https://azure.microsoft.com/pricing/details/microsoft-sentinel/), and [Azure Monitor pricing](https://azure.microsoft.com/pricing/details/monitor/), and should be refreshed before approval. The API returned East US public retail rates of **$4.30/GB** for Sentinel pay-as-you-go analysis, **$2.30/GB** for Log Analytics Analytics Logs ingestion outside the Sentinel simplified-plan meter, and **$0.10/GB-month** for extended Analytics Logs retention. Do not add Sentinel and Log Analytics ingestion prices together for the same data without confirming the workspace billing plan.

## End-to-end categories

| Category | Status | MVP cost treatment |
|---|---|---|
| This AI-assisted design/implementation session | Estimated | No authoritative usage telemetry or invoice is available; use the reproducible method below |
| Future contributor AI use | Variable | Contributor/employer subscription, premium requests or AI credits, model, and policy dependent |
| Human engineering | Estimated/variable | Architecture, implementation, review, privacy, security, testing, release, and operations labor |
| Azure deployment resources | Variable | Primarily Log Analytics/Sentinel ingestion and retention; no standing application compute in the default design |
| Sentinel/Log Analytics ingestion | Variable | Daily billable GB × applicable regional meter |
| Retention/search/restore/export | Variable | Retained GB-month, scanned GB, restored GB, or exported GB |
| Microsoft 365/Purview/Defender/Entra/GSA licenses | Not included | Customer prerequisites; templates do not buy or assign licenses |
| Optional collection | Variable | Custom Logs, DCR/DCE processing, Graph collection, usage cache, or privacy-approved interaction export |
| CI/GitHub | Known/variable | Standard GitHub-hosted Actions are free for public repositories; larger runners and excess storage can cost money |
| Operational labor | Variable | Monitoring, triage, connector maintenance, tuning, access reviews, cost review, and incident response |

## Azure resource posture

The default release deploys definitions and content rather than continuously running compute. Sentinel analytics rules, workbooks, and workspace KQL functions generally do **not** create standing VMs, containers, or app-service instances. They can still increase cost through:

- data ingestion and retention;
- scheduled query scan/processing behavior and result ingestion;
- Basic/Auxiliary log queries, search jobs, restore, or export;
- automation/playbook executions if a customer adds them;
- optional custom ingestion or data-lake features;
- operator and incident-response labor.

## Monthly ingestion scenarios

The scenarios isolate project-attributable billable volume. Existing workspace charges and Microsoft license costs are excluded.

**Formula**

```text
monthly ingestion GB = daily billable GB × 30
monthly ingestion cost = monthly ingestion GB × applicable $/GB
extended retention cost = average chargeable retained GB × $/GB-month
monthly total = ingestion + extended retention + optional query/automation/export + labor
```

Using the September 22, 2026 East US Sentinel pay-as-you-go public retail rate of $4.30/GB:

| Scenario | Assumed project-attributable volume | Monthly GB | Illustrative ingestion | Typical posture |
|---|---:|---:|---:|---|
| Low | 0.25 GB/day | 7.5 GB | $32.25/month | Native alerts/metadata, narrow scope, no custom logs |
| Medium | 2 GB/day | 60 GB | $258.00/month | Broader connector use and normal audit/activity volume |
| High | 10 GB/day | 300 GB | $1,290.00/month | Large tenant or verbose optional sources; investigate volume and duplication |

These are scenarios, not forecasts. Some Microsoft security data may qualify for product-specific free benefits; other data may be billed under different plans. At sustained volumes near a commitment tier, compare pay-as-you-go with the tier's daily capacity and overage terms. The same API returned $161.25/day for 50 GB/day and $296/day for 100 GB/day in East US on the pricing date; unused commitment capacity and overage rules matter.

### Retention

The Azure Monitor pricing page states that Sentinel-enabled Analytics Logs include 90 days of retention, subject to the current plan and table configuration. Retention beyond the included period is billed. At the illustrative $0.10/GB-month extended-retention rate:

- 100 average chargeable GB retained beyond the included period: **$10/month**
- 1,000 average chargeable GB: **$100/month**
- 10,000 average chargeable GB: **$1,000/month**

Sentinel is not the system of record for eDiscovery or records retention. Keep only the operational retention justified by the use case.

## Optional modules and previews

| Option | Default | Cost questions |
|---|---|---|
| `M365CopilotUsage_CL` reporting cache | Off | API/report entitlement, collection execution, ingestion, retention, schema operations |
| Custom Logs / DCR / DCE | Off | Source volume, processing, ingestion plan, transformation, retention, support |
| Graph Security enrichment | Off | API coverage, application permissions, execution host, throttling, ingestion |
| Interaction export | Excluded | Privacy/legal review, separate identity, export entitlement, sensitive storage, ingestion, retention, purge, monitoring |
| Global Secure Access telemetry | Tenant-dependent | Product license, preview/GA terms, connector availability, volume |
| Preview connectors/features | Off unless explicitly selected | Preview terms, schema churn, supportability, future metering |
| Automation/playbooks | Not required | Logic Apps executions, connectors, managed identities, egress, support |

Preview status never implies free use. Confirm current terms and regional availability.

## Microsoft licensing prerequisites

Licensing is **not included** in the Azure scenarios. Availability may depend on tenant agreements and combinations of:

- Microsoft 365 Copilot;
- Microsoft Purview Audit, DLP, DSPM for AI, Insider Risk Management, Communication Compliance, eDiscovery, and retention;
- Microsoft Defender XDR and Defender for Cloud Apps;
- Microsoft Entra ID P1/P2 or suites providing required identity capabilities;
- Microsoft Sentinel and Log Analytics;
- Global Secure Access / Microsoft Entra Internet Access or Private Access;
- Microsoft 365/Viva reporting features.

Do not infer entitlement from the presence of a portal blade or table. Ask your licensing specialist to map enabled features to your agreement and official [Microsoft licensing resources](https://www.microsoft.com/licensing/).

## This implementation session

The following aggregate local telemetry was measured for this implementation session as of September 22, 2026.

| Scope | API calls | Input tokens | Output tokens | Cache-read tokens | Cache-write tokens | Reasoning tokens | nano-AIU |
|---|---:|---:|---:|---:|---:|---:|---:|
| **Aggregate measured total** | **408** | **27,320,772** | **268,939** | **25,021,227** | **1,683,041** | **71,172** | **2,539,348,640,000** |

The aggregate call, token, cache, reasoning, and nano-AIU quantities are measured usage—not estimates. A dollar cost cannot be derived from these values alone because the applicable GitHub Copilot plan, included entitlements, premium-request or AI-credit treatment, and GitHub or organizational internal billing conversion are not available. This guide therefore does **not** invent a dollar figure for the session.

### Reproducible method

1. Export the authoritative usage record from the AI provider or organization billing portal.
2. Group calls by the provider's applicable billing classes.
3. Record API calls, input, output, cache-read, cache-write, reasoning, AIU or equivalent usage, premium requests/AI credits, and included allowance.
4. Obtain the plan-specific billing conversion effective on the usage date.
5. Apply included entitlements and the documented conversion to each billing class.
6. Add any platform subscription and agent/runtime charges.
7. Preserve the telemetry date, rate-card date, conversion source, and export hash with the calculation.

Future contributors should report their own provider, plan, metered quantity, included allowance, rate date, and incremental cost; do not normalize unlike plans into a fictional single token price.

## Human effort and operations

Apply your fully burdened hourly rates:

```text
implementation labor = hours by role × role rate
monthly operations = (health review + connector maintenance + tuning +
                      access/cost review + incident support hours) × role rates
```

Include architecture, security, privacy/legal, licensing, deployment review, `WhatIf` review, testing, documentation, release management, alert tuning, false-positive handling, incident response, and periodic access/retention review. These costs commonly exceed infrastructure charges for a small deployment and should not be hidden.

## GitHub and CI

GitHub documents standard GitHub-hosted Actions as free for public repositories. Larger runners are always billable, and artifact/cache/package storage over plan allowances may be billable. On the pricing date, GitHub documented baseline private-repository runner rates and $0.25/GB-month shared artifact/package storage; use the [GitHub pricing calculator](https://github.com/pricing/calculator) for the repository owner's plan.

Self-hosted runners may avoid GitHub minute charges but still incur infrastructure, patching, security, and operational labor.

## Cost controls

1. Measure billable volume by table before and after enabling a connector.
2. Avoid duplicate collection and default custom ingestion.
3. Keep optional features off until their owner, purpose, retention, and budget are approved.
4. Use narrow query time ranges and review scheduled-rule frequency.
5. Set Azure budgets and cost alerts; monitor ingestion anomalies.
6. Review table plans and retention independently; do not downgrade tables without checking feature compatibility.
7. Revisit commitment tiers only after sustained measured volume.
8. Record negotiated pricing separately from public-retail scenarios.

Useful workspace queries and operational review steps are in [Operations](docs/operations.md).

## Known, estimated, variable, and excluded summary

- **Known:** repository license; default architecture has no standing app compute; public-repository standard GitHub Actions treatment; cited retail meters on the stated date.
- **Estimated:** low/medium/high volumes, AI session reserve, human effort.
- **Variable:** ingestion, retention, query, automation, CI overages, licenses, support, and tenant-specific optional modules.
- **Not included:** customer Microsoft licenses, taxes, discounts, existing workspace spend, incident-response events, custom integrations, production validation, or deployment labor.
