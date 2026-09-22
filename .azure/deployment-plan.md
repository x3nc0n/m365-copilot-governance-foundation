# Azure Deployment Plan

> **Status:** Ready for Validation
> **Current phase:** Issue #7 implementation and offline verification are complete; the previously validated v0.1.0 evidence remains historical and is superseded by this pending v0.1.1 change
> **Next status:** Validated after CreateUiDefinition Sandbox, immutable-tag CORS, and authorized Azure `validate`/`what-if` checks complete
> **Approval:** The user explicitly approved the issue #7 plan on September 22, 2026 and authorized end-to-end implementation without deploying Azure resources.

**Generated:** 2026-09-22
**Owner:** Trinity, Azure IaC Engineer
**Repository:** `m365-copilot-governance-foundation`

---

## 1. Project Overview

### Goal

Create a public, open-source Microsoft 365 Copilot governance foundation that deploys a native-first Microsoft Sentinel monitoring and correlation layer without replacing the Microsoft services that own compliance, identity, risk, investigation, retention, or enforcement.

The MVP will support two deployment paths:

1. **Greenfield:** create a Log Analytics workspace and onboard Microsoft Sentinel, then install the governance content.
2. **Existing workspace:** install the same governance content into a caller-supplied Log Analytics workspace that is already Sentinel-enabled or can be validated for Sentinel readiness.

### Classification

| Attribute | Selection |
|---|---|
| Delivery classification | Open-source MVP / reference implementation |
| Azure workload classification | Development/reference architecture; production use requires customer review and parameterization |
| Repository path | New project |
| Scale | Small initial content footprint; designed for tenant-scale telemetry already present in the workspace |
| Budget posture | Cost-optimized and ingestion-conscious |
| Data sensitivity | Metadata, alerts, audit, identity, and operational-health data; prompt/response content is excluded by default |
| Deployment scope | Subscription/resource-group ARM deployments, depending on entry point |
| Subscription | Supplied by the deployer at execution time; no subscription is selected or accessed in this task |
| Location | Supplied by the deployer and validated against Log Analytics/Sentinel availability at execution time |

### Native Control Ownership

The architecture treats these Microsoft services as authoritative:

- Microsoft Purview DLP and DSPM for AI
- Purview Insider Risk Management, Communication Compliance, Audit, eDiscovery, retention, and records controls
- Microsoft Defender XDR and Defender for Cloud Apps
- Microsoft Entra ID Protection and Conditional Access
- Microsoft 365 and Viva reporting
- Global Secure Access policy and enforcement capabilities

Microsoft Sentinel is limited to:

- Cross-product correlation
- Visualization and investigation routing
- Tenant context and policy watchlists
- ASIM normalization where source semantics fit an ASIM schema
- Escalation of existing native alerts
- Narrow analytics that combine signals from multiple authoritative products
- Connector, table, parser, rule, and ingestion data-health monitoring

Sentinel is not a substitute prompt classifier, DLP engine, insider-risk engine, identity-risk engine, compliance repository, retention system, eDiscovery store, or primary enforcement plane.

---

## 2. Assumptions

1. The repository is intentionally new and currently contains team/bootstrap metadata rather than an existing application or Azure workload.
2. ARM/Bicep will remain authoritative for Azure resource state.
3. A greenfield deployer has rights to create a resource group or deploy into one, create a Log Analytics workspace, and onboard Microsoft Sentinel.
4. An existing-workspace deployer supplies a valid workspace resource ID and has sufficient rights on that workspace and its Sentinel resources.
5. Connector enablement varies by tenant licensing, role, consent, source configuration, geography, and connector lifecycle. The templates will deploy supported configuration where feasible and otherwise provide explicit post-deployment instructions and validation.
6. Native Microsoft tables are preferred over custom tables. Custom ingestion is optional, isolated, and never required for the default MVP.
7. `M365CopilotInteraction_CL` is excluded from the default architecture. Any future interaction export is an exceptional module gated by privacy/legal approval, administrator consent, data minimization, and separate identity boundaries.
8. `M365CopilotUsage_CL` may be documented as an optional reporting cache only. High usage alone will not create a security detection.
9. No Azure resource deployment, tenant mutation, connector consent, or Graph mutation occurs while creating or implementing this repository in the current task.
10. Subscription quotas are not consumed by repository artifact generation. Resource-provider registration, regional availability, deployment permissions, and applicable service limits will be checked during deployment preflight against the deployer's selected subscription and location.

---

## 3. Scope

### In Scope

- Two standalone Bicep entry points:
  - Greenfield Log Analytics workspace plus Sentinel plus governance content
  - Governance content installation into an existing workspace
- Reusable Bicep modules and deterministic parameters/outputs
- Generated ARM JSON templates suitable for release assets
- Deploy to Azure buttons that reference immutable release artifacts
- Azure portal `createUiDefinition.json` experiences where portal support is practical
- Native Microsoft Sentinel data connectors and tables, with prerequisites and licensing documented
- Optional integrations clearly separated from the default path
- ASIM-first KQL parser/function wrappers
- Sentinel workbooks for control ownership, native-alert context, data health, coverage, and investigation routing
- Narrow analytics for:
  - Cross-product correlation
  - Existing native-alert escalation
  - Risky identity plus AI-related activity
  - Tenant watchlist policy matches
  - Documented source-coverage gaps
  - Pipeline and connector health
- PowerShell and Microsoft Graph PowerShell prerequisite validation and supported bootstrap tooling
- Documentation:
  - Root README
  - Deployment and operations guidance
  - Data-table catalog
  - Native-control ownership matrix
  - `COSTS.md`
  - Security, privacy, troubleshooting, contribution, and release guidance
- CI build and static validation
- Public GitHub release readiness, including versioned generated artifacts and reproducible validation

### Non-Goals

- Recreating Purview DLP, DSPM, IRM, Communication Compliance, Audit, eDiscovery, or retention logic in Sentinel
- Recreating Defender or Entra risk scoring
- Custom prompt regex/Sensitive Information Type classification
- Jailbreak-keyword detections
- Treating high Copilot usage as suspicious by itself
- Retaining interaction content in Sentinel by default
- Storing secrets, tokens, prompt content, response content, raw identities, or tenant-private exports in the repository or CI artifacts
- Automatic administrator consent, privacy/legal approval, or tenant-wide policy mutation
- A custom web application, database, agent runtime, or continuously running collector in the default MVP
- Azure deployment or live tenant validation during this implementation task
- Guaranteeing availability of every connector or table in every tenant, cloud, region, or license combination

---

## 4. Selected Bicep Recipe

**Selected recipe:** Standalone Bicep with generated ARM deployment artifacts.

### Rationale

- The project is infrastructure/content-first rather than an application lifecycle managed by Azure Developer CLI.
- Direct ARM deployment provides the clearest contract for Azure portal, CLI, PowerShell, and Deploy to Azure flows.
- Bicep modules allow one content implementation to be shared by greenfield and existing-workspace entry points.
- Compiled ARM JSON can be published as immutable GitHub release assets and consumed by Deploy to Azure buttons.
- PowerShell remains orchestration, prerequisite validation, and explicit bootstrap tooling; it does not compete with declarative Azure ownership.

### Entry-Point Design

| Entry point | Scope | Behavior |
|---|---|---|
| `infra/greenfield/main.bicep` | Resource group | Creates a Log Analytics workspace, enables Sentinel through `Microsoft.SecurityInsights/onboardingStates`, and deploys shared content |
| `infra/existing-workspace/main.bicep` | Resource group | Accepts an existing workspace resource ID, validates parameter shape, and deploys only shared content |
| `infra/modules/content/main.bicep` | Resource group/module | Deploys workbooks, functions, analytics, watchlist scaffolding, and supported connector configuration |

Both paths will expose consistent content parameters, feature flags, tags, outputs, and naming behavior. Existing resources will be referenced with the Bicep `existing` keyword rather than redeclared.

---

## 5. Resource Architecture

### Core Azure Resources

| Resource type | Greenfield | Existing workspace | Purpose |
|---|---:|---:|---|
| `Microsoft.OperationalInsights/workspaces` | Create 1 | Reference 1 | Log store and query boundary |
| `Microsoft.SecurityInsights/onboardingStates` | Create/manage | Validate/reference | Enable Microsoft Sentinel |
| `Microsoft.OperationalInsights/workspaces/savedSearches` | Deploy | Deploy | Versioned KQL functions and parser wrappers |
| `Microsoft.Insights/workbooks` | Deploy | Deploy | Governance, investigation-routing, coverage, and data-health views |
| `Microsoft.SecurityInsights/alertRules` | Deploy selected rules | Deploy selected rules | Narrow native-alert and cross-product analytics |
| `Microsoft.SecurityInsights/watchlists` | Optional scaffolding | Optional scaffolding | Tenant policy/context inputs without embedding customer data |
| Supported connector resources | Feature-gated | Feature-gated | Native connector configuration where ARM and tenant prerequisites permit |

### Logical Flow

1. Authoritative Microsoft control planes generate native alerts, incidents, audit, identity, application, and activity telemetry.
2. Supported native connectors deliver available signals to Microsoft Sentinel and native Log Analytics tables.
3. KQL functions normalize compatible events through ASIM-oriented wrappers while retaining source links and ownership metadata.
4. Narrow analytics correlate signals across authoritative products; they do not reimplement native product detections.
5. Workbooks show source health, coverage, ownership, deep links, and investigation context.
6. PowerShell/Graph validation checks prerequisites and reports exact configuration gaps. Mutations require explicit bootstrap switches.

### Native Tables and Connectors

The implementation will prefer documented, connector-owned tables such as:

- `SecurityAlert`
- `SecurityIncident`
- `SigninLogs`
- `AADNonInteractiveUserSignInLogs`
- `AuditLogs`
- `IdentityInfo`
- `CloudAppEvents`
- `OfficeActivity`
- Connector-specific Defender XDR advanced-hunting tables when supported and present

Exact table availability will be detected rather than assumed. Every parser, workbook, and analytic will document:

- Authoritative source product
- Connector or ingestion prerequisite
- Expected table
- Required fields
- Data-latency expectation
- Native portal deep link
- Behavior when the table is absent

Default connector guidance will cover supported Microsoft Sentinel integrations for Microsoft Defender XDR, Microsoft Entra ID, Microsoft Defender for Cloud Apps, and Microsoft 365/Purview audit sources where documented and licensable. Connector deployment that requires tenant consent or non-ARM setup will remain a documented operator step with validation.

### Optional Integrations

Optional integrations will be disabled by default and independently documented:

- Microsoft Graph Security API enrichment where API coverage is verified
- Microsoft 365 Copilot usage reporting cache
- Custom Logs ingestion for a documented source gap
- Privacy-approved Copilot interaction export
- Additional tenant/business context watchlists
- Global Secure Access or other product telemetry when supported by a native connector or documented ingestion contract

Richer Graph security ingestion, including IRM-related coverage, is not assumed to be complete. Each optional integration must define support boundaries, permissions, consent, retention, cost, and fallback behavior.

### ASIM-First KQL

- Functions will consume ASIM normalized views/parsers when an appropriate schema and source parser exist.
- Source-specific adapters will normalize field names before workbook or analytic logic.
- Consumers will call stable project functions rather than bind directly to connector-specific columns where practical.
- Parser functions will preserve source identifiers, authoritative product, native portal link, tenant context, event time, ingestion time, and normalization status.
- Unsupported source semantics will not be forced into an inaccurate ASIM schema; these will use clearly named project functions with documented mappings and gaps.
- Functions and analytics will tolerate missing optional tables through feature flags, union patterns, and deployment-time/static query checks where feasible.

### Workbook Set

1. **Governance Overview:** control ownership, source coverage, health, licensing/prerequisite notes, and native portal routing.
2. **Native Alert Correlation:** existing alerts/incidents enriched with identity, application, tenant, and policy context.
3. **Data Health:** connector status, table freshness, ingestion volume, parser success, analytic dependencies, and silent-source detection.
4. **Coverage and Gaps:** deployed versus available controls, unsupported sources, optional modules, and remediation guidance.

Workbooks must label data source, owner, freshness, and limitations. They must not imply that absence of Sentinel data means absence of risk or compliance activity.

### Analytics Boundary

Permitted analytics are deliberately narrow:

- Correlate an existing native security/compliance alert with risky identity or anomalous access context.
- Correlate native alerts from two or more authoritative products.
- Match existing alerts/activity against customer-supplied governance watchlists.
- Detect connector/table/parser silence or unhealthy latency.
- Escalate an existing native alert based on documented cross-product context.

Each analytic must include control owner, source prerequisites, severity rationale, entity mapping, suppression/grouping, false-positive guidance, incident behavior, native deep links, and test data/query instructions.

---

## 6. Planned Repository Layout

Only `.azure/deployment-plan.md` is created during the planning task. The following layout is approved for the later implementation:

```text
.
├── .azure/
│   └── deployment-plan.md
├── .github/
│   ├── ISSUE_TEMPLATE/
│   ├── workflows/
│   │   ├── build.yml
│   │   └── release.yml
│   └── dependabot.yml
├── docs/
│   ├── architecture.md
│   ├── deployment.md
│   ├── operations.md
│   ├── data-tables.md
│   ├── native-control-matrix.md
│   ├── optional-integrations.md
│   ├── privacy-and-security.md
│   └── troubleshooting.md
├── infra/
│   ├── greenfield/
│   │   ├── main.bicep
│   │   └── main.bicepparam
│   ├── existing-workspace/
│   │   ├── main.bicep
│   │   └── main.bicepparam
│   ├── modules/
│   │   ├── content/
│   │   ├── connectors/
│   │   ├── analytics/
│   │   ├── functions/
│   │   ├── watchlists/
│   │   └── workbooks/
│   ├── portal/
│   │   ├── greenfield/
│   │   │   └── createUiDefinition.json
│   │   └── existing-workspace/
│   │       └── createUiDefinition.json
│   └── compiled/
│       ├── greenfield.json
│       └── existing-workspace.json
├── src/
│   ├── analytics/
│   ├── functions/
│   └── workbooks/
├── scripts/
│   ├── Invoke-M365CopilotGovernance.ps1
│   ├── Test-GovernanceDeployment.ps1
│   ├── Test-M365Audit.ps1
│   ├── Test-GraphAccess.ps1
│   ├── Initialize-CollectorIdentity.ps1
│   ├── Test-SentinelConnector.ps1
│   ├── Test-CustomIngestion.ps1
│   └── Test-DataHealth.ps1
├── tests/
│   ├── arm/
│   ├── bicep/
│   ├── kql/
│   ├── powershell/
│   └── portal/
├── README.md
├── COSTS.md
├── CONTRIBUTING.md
├── SECURITY.md
├── SUPPORT.md
├── CODE_OF_CONDUCT.md
├── CHANGELOG.md
└── LICENSE
```

Generated ARM templates will be reproducible build outputs. Release workflows will verify that committed or attached compiled templates exactly match source Bicep.

---

## 7. Security and Privacy Model

### Identity Separation

Use separate identities for:

1. **Bootstrap/deployment:** creates Azure resources and, only when explicitly requested, configures tenant prerequisites.
2. **Usage collection:** optional, read-only reporting access scoped to required reports.
3. **Sensitive interaction export:** exceptional module with distinct identity, approvals, storage, retention, and monitoring.

Managed identity or workload identity federation is preferred. Certificate credentials are a fallback. Client secrets are not the default.

### Least Privilege

- Document the minimum Azure RBAC role and scope for each deployment path.
- Separate ARM deployment permission from Microsoft Graph and Microsoft 365 administrator consent.
- Do not grant broad directory roles through templates.
- Use feature-specific Graph permissions and report both required and effective consent.
- Treat User Access Administrator or equivalent role-assignment capability as an explicit prerequisite only if role assignments are included.

### Bootstrap Safety

- Validation scripts are read-only by default.
- Any mutation requires `-Bootstrap` or a narrowly named mutation switch.
- Mutating cmdlets use `SupportsShouldProcess`.
- `-WhatIf` and `-Confirm` are supported.
- Output reports exact intended and applied configuration differences.
- Administrator consent and privacy/legal approval remain explicit human gates.

### Data Protection

- No secrets, tokens, customer exports, prompt content, response content, or raw support bundles are committed.
- CI and JSON support output redact tenant identifiers, identities, tokens, prompt/response content, and other sensitive fields.
- Workbooks favor metadata and native deep links over copied sensitive content.
- Optional custom ingestion defines retention, access, purge, geography, cost, and schema ownership.
- Customer-provided watchlist content is never embedded in public templates or samples.

### Supply Chain

- Pin GitHub Actions to immutable commit SHAs where practical.
- Use least-privilege workflow permissions.
- Generate checksums for release artifacts.
- Build release templates from tagged source.
- Run secret scanning, dependency review, and static checks.
- Do not allow pull-request workflows from forks to receive deployment credentials.

---

## 8. PowerShell and Graph Tooling

### Supported Commands

The approved script entry points are:

- `Invoke-M365CopilotGovernance.ps1`
- `Test-GovernanceDeployment.ps1`
- `Test-M365Audit.ps1`
- `Test-GraphAccess.ps1`
- `Initialize-CollectorIdentity.ps1`
- `Test-SentinelConnector.ps1`
- `Test-CustomIngestion.ps1`
- `Test-DataHealth.ps1`

### Tooling Contract

- Support PowerShell 7 on Windows, Linux, and macOS where module support permits.
- Pin or minimum-bound required Az and Microsoft Graph PowerShell modules.
- Use `Connect-AzAccount` and `Connect-MgGraph` only through explicit operator actions.
- Never cache or print access tokens.
- Return actionable structured results with pass, warning, fail, skipped, evidence, and remediation fields.
- Distinguish unsupported, unlicensed, unauthorized, absent, stale, and unhealthy states.
- Permit CI-safe offline/static modes that do not authenticate to Azure or Microsoft Graph.

---

## 9. Validation Plan and Commands

Implementation validation is static/local only. No command in this phase will create or modify Azure or Microsoft 365 resources.

### Required Local/CI Checks

```powershell
# Compile both entry points.
az bicep build --file .\infra\greenfield\main.bicep --outfile .\infra\compiled\greenfield.json
az bicep build --file .\infra\existing-workspace\main.bicep --outfile .\infra\compiled\existing-workspace.json

# Lint/compile all Bicep entry points without deployment.
az bicep build --file .\infra\greenfield\main.bicep
az bicep build --file .\infra\existing-workspace\main.bicep

# Validate PowerShell syntax and PSScriptAnalyzer rules.
Invoke-ScriptAnalyzer -Path .\scripts -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
Invoke-Pester -Path .\tests\powershell -CI

# Validate JSON and portal definitions.
Get-ChildItem .\infra,.\src -Recurse -Filter *.json |
  ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json | Out-Null }

# Run repository-specific static tests once implemented.
Invoke-Pester -Path .\tests -CI
```

CI will additionally:

- Confirm Bicep compilation is warning-free under the repository policy.
- Compare generated ARM templates with release-bound artifacts.
- Validate ARM/template metadata and required outputs.
- Validate `createUiDefinition.json` structure and parameter mapping.
- Parse and lint KQL assets using the selected static test harness.
- Verify every analytic dependency is declared in the data-table catalog.
- Verify every analytic and workbook includes control-ownership metadata and native portal routing.
- Verify optional integrations are disabled by default.
- Verify no banned default custom tables or duplicated native-control detections are present.
- Run markdown link, spelling, and documentation completeness checks.
- Scan for secrets and prohibited sensitive sample data.
- Build a release manifest with hashes.

`az deployment group validate`, `what-if`, connector activation, Graph permission verification, table freshness checks, and end-to-end Sentinel queries are deferred to a separately authorized validation/deployment session with an explicitly selected subscription, tenant, resource group, workspace, and location.

---

## 10. Implementation Phases

### Phase 0 - Contract and Test Skeleton

- Establish naming, metadata, feature-flag, parameter, output, and versioning conventions.
- Define banned behaviors and native-control ownership assertions as tests.
- Establish the data-table and analytic dependency schemas.

### Phase 1 - Shared Bicep Foundation

- Implement greenfield and existing-workspace entry points.
- Implement shared content module boundaries.
- Add parameter validation, deterministic naming, tags, outputs, and deployment metadata.
- Ensure existing-workspace deployment does not modify workspace settings outside the documented content scope.

### Phase 2 - Native Data and ASIM Functions

- Define supported native connectors and manual prerequisites.
- Implement stable ASIM-first/source-adapter KQL functions.
- Add freshness, schema, and missing-table behavior.
- Document all source tables and fields.

### Phase 3 - Workbooks and Analytics

- Build governance, correlation, data-health, and coverage workbooks.
- Add only approved narrow analytics.
- Include control owner, native portal links, prerequisites, limitations, and remediation.

### Phase 4 - Validation and Bootstrap Tooling

- Implement read-only validation commands.
- Add explicit, `ShouldProcess`-protected bootstrap operations.
- Add structured redacted output and offline/static modes.

### Phase 5 - Portal and Release Artifacts

- Compile ARM templates.
- Build portal UI definitions where Azure portal support is feasible.
- Add Deploy to Azure links against immutable release artifacts.
- Produce checksums and release manifest.

### Phase 6 - Documentation and Public Release Hardening

- Complete README, table catalog, native-control matrix, `COSTS.md`, security/privacy, operations, troubleshooting, contribution, support, license, and changelog materials.
- Add CI gates, templates, ownership, release notes, and vulnerability-reporting instructions.
- Confirm examples contain no tenant-specific or sensitive content.

### Phase 7 - Validation Handoff

- Change this plan status to `Ready for Validation`.
- Invoke the project validation workflow/azure-validate process.
- Do not deploy until validation evidence is recorded and deployment is separately authorized.

---

## 11. Cost Categories

`COSTS.md` will describe drivers and estimation methods rather than promise a fixed monthly price.

| Category | Cost driver | MVP posture |
|---|---|---|
| Log Analytics ingestion | Daily GB by source/table | Prefer native connectors, filters supported by the source, and no duplicate ingestion |
| Log Analytics retention | Retained GB and retention period | Use documented minimum operational retention; do not use Sentinel as an eDiscovery archive |
| Microsoft Sentinel analytics | Billable ingestion and enabled features | Keep rules narrow; avoid duplicated native detections |
| Search/restore/archive | Data volume and query operations | Optional and customer-selected |
| Custom Logs / DCR / DCE | Optional ingestion volume and processing | Disabled by default |
| Automation/playbooks | Logic Apps executions and connector calls | Not required for default MVP; document if added later |
| Workbooks and KQL queries | Query volume/scan scope | Optimize time ranges, summarize where appropriate, expose query scope |
| Microsoft licensing | Purview, Defender, Entra, Sentinel, Graph/reporting entitlements | Customer prerequisite; not provisioned by Azure templates |
| CI and release | GitHub Actions minutes and artifact storage | Use standard public-repository allowances and efficient builds |
| Network/egress | Optional export or cross-region movement | Avoid cross-region/custom export by default |

The cost guide will include:

- Azure Pricing Calculator inputs
- Workspace usage queries
- Per-table ingestion and retention review
- Optional-module incremental cost
- Budget/alert recommendations
- Data-volume assumptions and uncertainty
- A warning that licensing and telemetry availability vary by tenant

---

## 12. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Connector APIs, resource schemas, or table mappings change | Pin tested API versions, centralize adapters, document support matrix, and validate on release |
| Native product data is incomplete in Sentinel | Display explicit coverage gaps; route investigators to native portals; never infer no risk from no data |
| IRM or Graph Security coverage is overclaimed | Keep richer Graph ingestion optional and separately validated; document unavailable alert detail |
| Templates accidentally duplicate native controls | CI assertions and native-control matrix prohibit duplicate DLP, IRM, identity-risk, retention, or prompt-classification logic |
| Existing workspace is altered unexpectedly | Use a content-only entry point, feature flags, explicit outputs, and what-if review before live deployment |
| Missing tables break KQL content | Use dependency metadata, feature flags, tolerant functions, and data-health reporting |
| Sensitive interaction data is ingested | Exclude interaction export by default; require separate module, identity, approval, retention, and privacy controls |
| Deploy to Azure artifacts drift from Bicep | Rebuild in CI and compare hashes/content before release |
| Broad Graph permissions or consent are requested | Use least privilege, split identities, report diffs, and retain administrator consent as a manual gate |
| Public samples disclose tenant data | Use synthetic examples, secret scanning, redaction tests, and maintainer review |
| Costs rise through duplicate or verbose ingestion | Prefer native tables, document volume queries, disable custom ingestion by default, and expose cost controls |
| Portal UI definitions cannot express all scenarios | Keep CLI/PowerShell deployment authoritative and offer portal UI only where technically supportable |

---

## 13. Rollback Strategy

### Content Rollback

- Every release will be versioned and map source to compiled artifacts.
- Operators can redeploy the prior tagged release to restore prior content definitions.
- Rules, workbooks, functions, watchlists, and optional connectors will use stable names/resource identifiers to support deterministic updates.
- Destructive content removal is not automatic; removal instructions will list affected resource IDs and require explicit confirmation.

### Greenfield Rollback

- The greenfield path will output every created resource ID.
- Operators may disable analytics/connectors first, then remove content resources.
- Workspace deletion is never an implicit rollback because it may contain unrelated or retained data.
- Deleting a resource group or workspace requires a separate, explicit operator decision after retention/export review.

### Existing-Workspace Rollback

- Remove only resources created by this solution, identified through stable metadata, tags where supported, and the deployment output manifest.
- Never delete the existing workspace or unrelated Sentinel content.
- Watchlist/customer data removal requires confirmation and retention review.

### Tenant Bootstrap Rollback

- Bootstrap actions will record before/after state without secrets.
- Reversal is a separate explicit operation protected by `ShouldProcess`.
- Administrator consent removal and identity deletion are never automatic.

---

## 14. Public GitHub Release Readiness

A release is ready only when:

- The repository has an approved open-source license, code of conduct, contributing guide, support policy, and security policy.
- Both Bicep paths compile reproducibly.
- Compiled ARM templates and portal UI definitions pass static validation.
- Deploy to Azure links target immutable tagged artifacts rather than a moving branch.
- Checksums and a release manifest are published.
- README quick starts clearly distinguish greenfield and existing-workspace installation.
- Required roles, licenses, consent, regions, clouds, and unsupported scenarios are documented.
- The native-control matrix confirms Sentinel's limited role.
- Data-table documentation lists source, owner, prerequisite, latency, cost, sensitivity, and fallback.
- `COSTS.md` covers all default and optional cost drivers.
- No customer data, secrets, tenant identifiers, prompt content, response content, or local artifacts are present.
- CI passes from a clean checkout without Azure credentials.
- Release notes identify breaking schema, connector, permission, analytic, and workbook changes.

---

## 15. Handoff Criteria

Implementation can move from `Approved - Ready for Implementation` to `Ready for Validation` only when all of the following are true:

1. Both Bicep entry points and shared modules are implemented.
2. Both entry points compile to ARM JSON with no unresolved errors.
3. Portal UI definitions exist where feasible and map correctly to template parameters.
4. Native connector/table prerequisites and optional integrations are documented.
5. ASIM-first functions and all approved workbooks/analytics have static tests.
6. Analytics remain within the native-first boundary and include source/control ownership metadata.
7. PowerShell/Graph tooling is read-only by default and all mutations support `ShouldProcess`, `-WhatIf`, and `-Confirm`.
8. README, data-table documentation, native-control matrix, `COSTS.md`, security/privacy, deployment, operations, and troubleshooting documents are complete.
9. CI builds and statically validates all release artifacts without deploying to Azure.
10. Public-release governance and supply-chain files are present.
11. Generated artifacts match source and have a release manifest/checksums.
12. No secrets or sensitive tenant content are found.
13. This file is updated to **Ready for Validation** before the validation handoff.

Live Azure deployment, Graph consent, connector activation, and tenant mutations remain outside implementation and require separate validated authorization.

---

## 16. Execution Checklist

### Planning

- [x] Create the required deployment plan first
- [x] Analyze the new repository
- [x] Read the Trinity charter and shared decisions
- [x] Classify the workload and define assumptions
- [x] Select standalone Bicep
- [x] Define greenfield and existing-workspace architecture
- [x] Define native-first ownership boundaries
- [x] Record `/autopilot` implementation authorization

### Implementation

- [ ] Establish tests and content contracts
- [ ] Generate shared Bicep modules and both entry points
- [ ] Generate native connectors/table documentation and ASIM-first functions
- [ ] Generate workbooks and narrow analytics
- [ ] Generate PowerShell/Graph validation and bootstrap tooling
- [ ] Generate compiled ARM and portal UI artifacts
- [ ] Complete documentation and public-release files
- [x] Run CI/build/static validation
- [x] Update status to `Ready for Validation`

### Validation and Deployment

- [ ] Run the azure-validate workflow and record evidence
- [ ] Select and confirm Azure subscription, tenant, resource group, workspace, and location
- [ ] Run provider/permission/limit preflight and template validation/what-if
- [ ] Obtain separate authorization for any live deployment or tenant mutation
- [ ] Deploy through the validated release path

---

## 17. Validation Evidence

Implementation artifacts are present and the preparation build completed successfully on September 22, 2026:

- Canonical build command: `pwsh .\build\Invoke-Build.ps1 -CI`
- Pester: 32 passed, 0 failed, 0 skipped
- JSON validation: 33 files
- PSScriptAnalyzer: 0 findings
- Both Bicep entry points and sample parameter files compiled successfully
- ARM/Bicep drift validation passed
- Reviewer verdict: APPROVE

The azure-validate workflow independently verified the repository artifacts on September 22, 2026. This validation proves compilation, schema, deterministic generation, static security, and release-contract correctness without deploying Azure resources.

| Check | Command | Result | Timestamp |
|---|---|---|---|
| Canonical build | `pwsh -NoProfile -File .\build\Invoke-Build.ps1 -CI` | Passed: 32 tests, 0 failures, 33 JSON files | 2026-09-22 |
| Bicep lint | `az bicep lint --file .\infra\greenfield\main.bicep` and existing-workspace equivalent | Passed | 2026-09-22 |
| Parameter compilation | `az bicep build-params` for both sample `.bicepparam` files | Passed | 2026-09-22 |
| ARM drift | Canonical build drift tests | Passed for both entry points | 2026-09-22 |
| Content contract | Manifest and compiled ARM assertions | Passed: 4 functions, 3 analytics, 4 workbooks | 2026-09-22 |
| Release packaging | Release-manifest regression tests | Passed: unique deterministic portal/template assets | 2026-09-22 |
| PowerShell quality | PSScriptAnalyzer plus PowerShell tests | Passed: 0 findings; redaction and `ShouldProcess` verified | 2026-09-22 |
| Static RBAC review | Search for role assignments and managed identities | Passed: MVP creates no service identities or role assignments | 2026-09-22 |
| Secret scan | Release-candidate pattern scan | Passed across 94 files | 2026-09-22 |
| Reviewer gate | Independent integration re-review | APPROVE | 2026-09-22 |
| Live Azure template validation | `az deployment group validate` | Deferred: requires the user's target resource group and subscription context | Manual test |
| Live Azure what-if | `az deployment group what-if` | Deferred: requires the user's target resource group and subscription context | Manual test |

### Validation Scope

`Validated` in this plan means the checked-in deployment artifacts are internally consistent, reproducible, statically secure, and ready for a subscription-scoped manual validation. It does not claim that resources were deployed or that tenant connectors, licenses, consent, Azure Policy, or regional availability were validated in a customer environment.
| Planning artifact | Confirm `.azure/deployment-plan.md` exists and contains the approved MVP contract | Passed | 2026-09-22 |

---

## 18. Approved-Change Candidate: Existing-Workspace Deploy to Azure UX

### Planning status

**Candidate status:** Ready for Validation on `squad/7-enhance-existing-workspace-ui`. No Azure resources were deployed, and no commits, pushes, pull requests, or release tags were created during this handoff.

The screenshot reviewed on September 22, 2026 shows the generic ARM parameter blade. It duplicates the portal's deployment **Region** with the template's **Location** parameter, exposes fixed/internal values (`solutionName`, `solutionVersion`, `resourceNamePrefix`, and `tags`), and requires a manually pasted `workspaceResourceId`. The repository already contains a custom UI definition, but the primary existing-workspace **Deploy to Azure** button currently opens the template-only URL; only the adjacent custom-deployment link includes `createUIDefinitionUri`. The primary button therefore bypasses the authored UI and renders the generic form.

### Proposed user experience

1. The primary existing-workspace **Deploy to Azure** button opens the immutable ARM template together with its matching immutable `createUiDefinition`.
2. The built-in **Basics** experience provides the subscription and existing resource-group picker. There is no standalone `Microsoft.Common.ResourceGroup` element in the documented CreateUiDefinition element set; resource group selection is a built-in Basics control configured through `parameters.config.basics.resourceGroup`.
3. Hide the built-in Basics location control for this scenario. Do not add a second `Microsoft.Common.Location` control. The selected Log Analytics workspace's `location` becomes the ARM `location` output used for regional workbook resources.
4. Replace the workspace resource-ID text box with `Microsoft.Solutions.ResourceSelector` for resource type `Microsoft.OperationalInsights/workspaces`.
5. Restrict the selector to the subscription selected on Basics with `options.filter.subscription = "onBasics"` and use `options.filter.location = "all"` because the hidden Basics location must not suppress valid workspaces. The selector output supplies `id`, `name`, and `location`.
6. Keep only meaningful choices visible:
   - Deploy KQL functions
   - Deploy analytic rules
   - Enable analytic rules immediately, default `false`, with the existing prerequisite warning
   - Deploy workbooks
7. Keep fixed/internal parameters out of the form:
   - `solutionName`: fixed output
   - `solutionVersion`: release-controlled fixed output
   - `resourceNamePrefix`: fixed output unless a future naming requirement proves it must be user-configurable
   - `tags`: fixed empty object for this portal flow
   - `workspaceResourceId`: derived from the selector
   - `location`: derived from the selector
8. Add concise explanatory text that the Basics resource group is the ARM deployment-history scope, while the solution content is deployed to the selected workspace's resource group. The workspace may therefore be in another resource group within the selected subscription.

### Portal platform limitation and Sentinel validation

`Microsoft.Solutions.ResourceSelector` can filter only by subscription and location. It cannot filter on arbitrary resource properties or on the existence of a child/extension resource. Therefore it cannot natively restrict the list to Log Analytics workspaces that contain `Microsoft.SecurityInsights/onboardingStates/default`.

The implementation must not label the selector as “Sentinel-enabled workspaces only.” Instead:

1. Label it **Log Analytics workspace** and state in the tooltip that Microsoft Sentinel must already be enabled.
2. Prototype a dependent, nonvisual `Microsoft.Solutions.ArmApiControl` GET against:

   ```text
   {workspaceResourceId}/providers/Microsoft.SecurityInsights/onboardingStates/default?api-version=2025-09-01
   ```

   Use its result for an inline success/error or warning message only if the CreateUiDefinition Sandbox confirms stable behavior for success, 404/not-onboarded, insufficient permission, and cross-resource-group selection. `ArmApiControl` can issue ARM GET/POST calls and feed other controls, but the documented `ResourceSelector` schema has no arbitrary child-resource filter or custom validation contract.
3. Preserve an authoritative fallback outside the selector:
   - Add or strengthen an ARM/Bicep deployment-time existence check that deliberately reads the selected workspace's `onboardingStates/default` resource before solution content is deployed.
   - Make a missing onboarding state fail early with a clear deployment error rather than relying on the current `existing` declaration's computed ID.
   - Keep the documented/manual preflight (`Test-SentinelConnector.ps1`, `az rest`, or equivalent read-only validation) as the troubleshooting path when portal lookup is unavailable or the user lacks read permission.
4. Distinguish these cases in user-facing guidance: no workspace selected, selected resource is not a Log Analytics workspace (prevented by the selector), Sentinel not onboarded, onboarding state unreadable because of RBAC, and later content-write authorization failure.

### Source of truth and generated artifacts

| Area | Source of truth | Planned treatment |
|---|---|---|
| Existing-workspace portal UI | `infra/portal/existing-workspace/createUiDefinition.json` | Implement Basics configuration, resource selector, location derivation, visible choices, guidance, and any sandbox-proven onboarding-state advisory |
| Existing-workspace deployment contract | `infra/existing-workspace/main.bicep` | Preserve the public parameter names; add an explicit, testable Sentinel-onboarding existence gate if required for reliable enforcement |
| Sample CLI parameters | `infra/existing-workspace/main.bicepparam` | Keep explicit `location` and `workspaceResourceId` because CLI/Bicep deployments do not use the portal selector; update version only as part of the release bump |
| Compiled ARM | `infra/compiled/existing-workspace.json` | Regenerate from Bicep; never edit directly |
| Release portal asset | `generated/release-assets/existing-workspace.createUiDefinition.json` | Regenerate by byte-copying the canonical portal source through `build/New-ReleaseManifest.ps1`; never edit directly |
| Release ARM asset | `generated/release-assets/existing-workspace.json` | Regenerate from the compiled ARM source through the release build |
| Release manifest/checksums | `generated/release-manifest.json`, `generated/checksums.sha256` | Regenerate after all source and version changes |
| Deploy links | `README.md` and documented release/deployment guidance | Make the primary existing-workspace button include the matching encoded `createUIDefinitionUri`; retain immutable raw tagged URLs and CORS checks |

### ARM parameter mapping

The custom UI outputs must map every ARM parameter exactly:

| ARM parameter | UI source |
|---|---|
| `location` | `[steps('workspace').workspaceSelector.location]` |
| `workspaceResourceId` | `[steps('workspace').workspaceSelector.id]` |
| `solutionName` | Fixed release value `m365CopilotGovernance` |
| `solutionVersion` | Fixed value matching the new release version |
| `resourceNamePrefix` | Fixed value `m365gov` |
| `deployFunctions` | Visible content checkbox |
| `deployAnalytics` | Visible content checkbox |
| `deployWorkbooks` | Visible content checkbox |
| `analyticsEnabled` | Visible content checkbox, default `false` |
| `tags` | Fixed `{}` |

Do not remove public Bicep parameters merely to hide them in the portal. CLI, PowerShell, and direct ARM consumers retain the existing parameter contract; CreateUiDefinition controls only what the portal asks the user to enter.

### Implementation and validation plan

1. Update `infra/portal/existing-workspace/createUiDefinition.json` as the canonical UI source.
2. If portal-only validation cannot reliably block a non-Sentinel workspace, update `infra/existing-workspace/main.bicep` with the smallest explicit onboarding-state existence check and retain the same external parameter names.
3. Strengthen `tests/portal/Portal.Tests.ps1` to assert:
   - the existing-workspace definition uses `Microsoft.Solutions.ResourceSelector`;
   - its `resourceType` is exactly `Microsoft.OperationalInsights/workspaces`;
   - subscription filtering is `onBasics`;
   - Basics location is hidden and no extra location element exists;
   - `location` and `workspaceResourceId` map from selector properties;
   - fixed/internal values are outputs, not editable controls;
   - every UI output exactly matches an ARM parameter and no ARM parameter is omitted.
4. Add negative/static assertions for a raw workspace-ID text box, duplicate location controls, unsupported ResourceSelector filters, and accidental exposure of fixed/internal parameters.
5. If Bicep changes, extend ARM/Bicep tests to prove the onboarding state is actually dereferenced and that compiled/source artifacts remain aligned.
6. Run the Microsoft ARM Template Toolkit validation recommended for CreateUiDefinition integration, in addition to the canonical repository build.
7. Regenerate compiled ARM, flattened release assets, manifest, and checksums through the existing build scripts. Verify deterministic output and byte equality between portal source and packaged asset.
8. Update `README.md`, `docs/deployment.md`, `docs/release.md`, `docs/troubleshooting.md`, and `CHANGELOG.md` to describe the picker UX, cross-resource-group behavior, Sentinel prerequisite, RBAC-versus-not-onboarded errors, and manual fallback.
9. Publish as a new immutable patch release, expected `v0.1.1`; do not alter the existing `v0.1.0` tag or its raw assets. Update all release-controlled version values and version-pinned portal URLs consistently.
10. Re-run the canonical offline build and all portal/release/CORS tests. The prior v0.1.0 evidence in section 17 remains historical baseline evidence and does not validate this candidate.

### Manual Azure Portal validation

Before marking the candidate validated or released:

1. Load the canonical UI definition in the Microsoft CreateUiDefinition Sandbox.
2. Verify subscription and existing resource-group selection render once.
3. Verify no Region/Location control is shown and the ARM output location equals the selected workspace location.
4. Verify the workspace selector shows only `Microsoft.OperationalInsights/workspaces` in the selected subscription, supports search by workspace/resource-group name, and returns the correct full resource ID.
5. Test a Sentinel-enabled workspace, a Log Analytics workspace without Sentinel, and a workspace the tester cannot read fully. Confirm the UI message and authoritative deployment/preflight behavior are distinct and actionable.
6. Verify all four combinations of the content checkboxes and confirm analytics remain disabled by default.
7. Open the actual immutable `v0.1.1` Deploy to Azure link, not only the Sandbox, and confirm the primary button loads the custom picker experience rather than the generic parameter blade.
8. Run resource-group deployment `validate` and `what-if` against the selected existing workspace. Do not run `create` without separate deployment authorization.
9. Re-run live anonymous CORS/JSON checks for the tagged template and UI-definition URLs.
10. Record screenshots, selected nonsecret test conditions, commands, results, and timestamps in this plan before restoring status to `Validated`.

### Official Microsoft references

- CreateUiDefinition overview and built-in Basics controls: https://learn.microsoft.com/en-us/azure/azure-resource-manager/managed-applications/create-uidefinition-overview
- Supported CreateUiDefinition elements: https://learn.microsoft.com/en-us/azure/azure-resource-manager/managed-applications/create-uidefinition-elements
- `Microsoft.Solutions.ResourceSelector`: https://learn.microsoft.com/en-us/azure/azure-resource-manager/managed-applications/microsoft-solutions-resourceselector
- `Microsoft.Solutions.ArmApiControl`: https://learn.microsoft.com/en-us/azure/azure-resource-manager/managed-applications/microsoft-solutions-armapicontrol
- CreateUiDefinition referencing functions and selector output mapping: https://learn.microsoft.com/en-us/azure/azure-resource-manager/managed-applications/create-ui-definition-referencing-functions
- CreateUiDefinition Sandbox and ARM Template Toolkit validation: https://learn.microsoft.com/en-us/azure/azure-resource-manager/managed-applications/test-createuidefinition
- Sentinel onboarding-state GET operation: https://learn.microsoft.com/en-us/rest/api/securityinsights/sentinel-onboarding-states/get
- Sentinel onboarding-state list operation: https://learn.microsoft.com/en-us/rest/api/securityinsights/sentinel-onboarding-states/list
- Deploy to Azure raw-template URL guidance: https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-to-azure-button

### Implementation handoff — 2026-09-22

Implemented:

- Replaced the existing-workspace resource-ID text box with `Microsoft.Solutions.ResourceSelector` constrained to `Microsoft.OperationalInsights/workspaces`, the Basics subscription, and all workspace locations.
- Configured the built-in Basics resource-group picker to allow existing groups and hid its location control; no custom location control remains.
- Derived `workspaceResourceId` and `location` from the selected workspace and emitted fixed `solutionName`, `solutionVersion`, `resourceNamePrefix`, and `tags` values without editable controls.
- Kept the four content toggles visible and logically ordered. `analyticsEnabled` defaults to `false` and is shown only when analytic-rule deployment is selected.
- Recorded the official selector limitation in the UI and documentation: its supported filter surface is subscription and location only, so it cannot filter on `Microsoft.SecurityInsights/onboardingStates/default`.
- Added an authoritative pre-content onboarding-state read by passing `sentinelOnboardingState.properties.customerManagedKey` into the nested content deployment. A missing or unreadable onboarding state prevents the content deployment from starting.
- Updated the primary existing-workspace Deploy to Azure URL to include its matching `createUIDefinitionUri`.
- Bumped release-controlled values and immutable URLs to the pending `v0.1.1` candidate and regenerated compiled templates, flattened release assets, manifests, and checksums from source.

Offline verification:

| Check | Result | Evidence |
|---|---|---|
| Canonical build | Passed | `pwsh -NoProfile -File .\build\Invoke-Build.ps1 -CI` |
| Pester | Passed | 50 passed, 0 failed, 0 skipped |
| JSON validation | Passed | 33 JSON files |
| Bicep compilation and parameter compilation | Passed | Both scenario entry points and both `.bicepparam` files |
| Bicep lint | Passed | `az bicep lint` for both scenario entry points |
| Deterministic release packaging | Passed | Release generator rerun and source/package byte equality tests |
| Diff whitespace validation | Passed | `git diff --check` |
| ARM Template Toolkit | Not run | `Test-AzTemplate` / `arm-ttk` was not installed in the environment |

Static role verification found no managed identities or `Microsoft.Authorization/roleAssignments` in this solution, so no application data-plane RBAC mapping applies. Deployment permissions remain an operator prerequisite documented for the selected workspace and Sentinel content resource types.

Required reviewer re-validation passed on September 22, 2026. The targeted portal suite passed 7/7 tests, including recursive exclusion of `Microsoft.Common.ResourceGroup` and an exact `location,subscription` key set for `ResourceSelector.options.filter`. Independent parsing confirmed those properties in both the canonical source and byte-identical packaged UI definition. The canonical build then passed 50/50 tests, validated 33 JSON files, rebuilt both Bicep entry points and parameter files, and passed ARM/source drift and deterministic packaging checks. `git diff --check` also passed. Reviewer verdict: **APPROVE** for the offline artifact; the candidate remains **Ready for Validation** because the authenticated Sandbox, immutable-tag CORS, and authorized Azure `validate`/`what-if` gates remain outstanding.

Remaining validation risk:

- The CreateUiDefinition Sandbox requires an authenticated Azure portal session and was not exercised in this noninteractive handoff.
- The pending raw `v0.1.1` URLs and live CORS behavior cannot be tested until the immutable tag is published.
- Subscription-scoped Azure `validate` and `what-if` require an authorized test subscription and were intentionally not run; no Azure resources were deployed.
