# Operations

## Operating model

Native Microsoft services remain the systems of action. Sentinel provides correlation, context, visualization, routing, and health. Assign owners for:

- Purview controls and investigations;
- Defender alerts and incidents;
- Entra identity risk and Conditional Access;
- Microsoft 365/Viva reporting;
- Global Secure Access;
- Sentinel content and data health;
- licensing, privacy, and cost review.

Use the [native-control matrix](native-control-matrix.md) for ownership and the [data-table catalog](data-tables.md) for source prerequisites and expected latency.

## Routine checks

### Daily

- Review new or escalated native alerts and follow their native portal links.
- Check connector/table/parser freshness and failed scheduled analytics.
- Treat missing data as a telemetry incident, not as a clean risk result.

### Weekly

- Review noisy or silent rules, entity mapping, grouping, and suppression.
- Check table volume changes and optional-source costs.
- Validate that workbooks still route to supported native experiences.

### Monthly

- Review effective permissions, identities, credentials, and consent.
- Review retention, billable ingestion by table, budgets, and commitment-tier fit.
- Reconcile connector/license/preview changes against the catalogs.
- Test rollback and a representative investigation handoff.

### Each release

- Read [CHANGELOG](../CHANGELOG.md) and [release guidance](release.md).
- Rebuild templates and verify checksums.
- Run validation and `what-if` for the target environment.
- Review breaking parameter, output, permission, schema, analytic, and workbook changes.

## Health commands

```powershell
.\scripts\Test-GovernanceDeployment.ps1
.\scripts\Test-M365Audit.ps1
.\scripts\Test-GraphAccess.ps1
.\scripts\Test-SentinelConnector.ps1
.\scripts\Test-DataHealth.ps1
```

Optional custom ingestion has its own validation:

```powershell
.\scripts\Test-CustomIngestion.ps1
```

`Test-GovernanceDeployment.ps1` accepts `RepositoryRoot`, `Online`, and `OutputFormat`. The other test wrappers accept `Online` and `OutputFormat`; output is `Json` by default or `Object` when selected. In v0.1.3, `-Online` does not authenticate or run live queries: it returns a warning directing the operator to a separately authorized check. Structured results use pass, warning, fail, skipped, evidence, and remediation fields.

## Cost review queries

Adapt query time ranges to the operating question:

```kusto
Usage
| where TimeGenerated > ago(30d)
| where IsBillable
| summarize QuantityGB = sum(Quantity) / 1000 by DataType
| order by QuantityGB desc
```

Cross-check workspace usage and the applicable billing plan; table volume does not always equal the billed quantity. See [COSTS.md](../COSTS.md).

## Change management

- Deploy tagged, checksum-verified artifacts.
- Preserve stable resource names and metadata.
- Preview changes with `what-if`.
- Keep optional integrations disabled until their owner, purpose, permissions, retention, and budget are approved.
- Record the output manifest and validation evidence with the change record.
- Do not perform broad consent, role assignment, or data collection as an undocumented side effect.

## Incident handling

1. Preserve the Sentinel incident, source identifiers, timestamps, and routing metadata.
2. Follow the native portal deep link.
3. Use the authoritative service's investigation and enforcement workflow.
4. Document cross-product context without copying sensitive content unnecessarily.
5. If a source is stale or absent, open a telemetry incident separately.

Do not move Purview eDiscovery, records-retention, communication-compliance, or insider-risk evidence into Sentinel merely for convenience.

## Backup and rollback

The source repository and tagged release artifacts are the content backup. Customer watchlist data and tenant configuration require customer-owned backup procedures. Rollback must remove or restore only solution-owned content; it must not implicitly delete a workspace, customer data, consent, or identity.
