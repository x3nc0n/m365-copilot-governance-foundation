# Troubleshooting

Start with the exact release tag, scenario, command, and sanitized structured result. Do not share secrets, tenant IDs, identities, prompts, responses, or customer exports.

## State meanings

| State | Meaning | Next step |
|---|---|---|
| Unsupported | The product, cloud, region, connector, API, or schema is outside the tested contract | Check the catalogs and current Microsoft documentation |
| Unlicensed | The tenant lacks an entitlement needed for the feature | Review the customer's licensing agreement |
| Unauthorized | The signed-in identity or application lacks effective permission/consent | Compare required and effective access; do not broaden blindly |
| Absent | Expected resource/table/configuration does not exist | Confirm feature enablement and deployment scope |
| Stale | Data exists but is older than the documented expectation | Check connector, source activity, ingestion, and service health |
| Unhealthy | A deployed component is failing or producing invalid results | Inspect evidence and remediation in the structured result |
| Skipped | A dependency or feature flag made the check inapplicable | Confirm the skip was intended |

## Bicep build fails

1. Confirm current Azure CLI/Bicep versions.
2. Run the failing entry point directly.
3. Verify module paths and JSON assets.
4. Do not hand-edit compiled templates; fix source and rebuild.

```powershell
az bicep version
az bicep build --file .\infra\greenfield\main.bicep
az bicep build --file .\infra\existing-workspace\main.bicep
```

## Portal deployment link returns 404

The README uses immutable `v0.1.0` release URLs. A 404 is expected until the release tag and assets are published. Do not replace the URL with a moving `main` or `dev` branch. Build locally or wait for the signed/checksummed release.

## Existing workspace shows unexpected changes

Stop. Do not deploy. Confirm the scenario, target resource ID, parameter file, and compiled template. Run `az deployment group what-if` again and compare changes with the solution-owned resource set. The existing-workspace path must not replace or delete unrelated content.

## Connector or table missing

Check the Neo-owned [data-table catalog](data-tables.md) for license, consent, setup, table, latency, and fallback. Then check:

1. native product configuration and source activity;
2. connector enablement and service health;
3. workspace selection and time range;
4. effective permission;
5. ingestion delay and table plan.

Do not interpret the missing signal as absence of risk.

## Graph validation fails

Use `Test-GraphAccess.ps1` and compare required versus effective permissions. Authenticate explicitly with the intended identity. Do not print tokens or solve a narrow failure by granting broad directory roles. Tenant consent is a human-admin action.

## Bootstrap does not change anything

This is expected in v0.1.0. Without `-Bootstrap`, the command returns a skipped result. With `-Bootstrap`, preview with `-WhatIf`; a confirmed run still creates no identity or consent and returns a warning that the MVP preserves the human-controlled handoff. A denied confirmation or missing approval also leaves the tenant unchanged.

## Workbook is empty

- Expand the time range.
- Check data health and source freshness.
- Verify feature flags and table availability.
- Confirm the query uses the stable project function rather than an unsupported source column.
- Follow native portal links to verify source-side activity.

## Rule is noisy

Review source prerequisites, entity mapping, severity rationale, grouping, suppression, and false-positive guidance. Tune tenant policy context rather than recreating the native detection. Never convert high usage alone into risk.

## Costs are higher than expected

Measure billable volume by table, check duplicate collection, retention, scheduled-query scope, optional custom ingestion, Basic/Auxiliary queries, search jobs, exports, and automation. Compare sustained usage with commitment tiers only after measurement. See [COSTS.md](../COSTS.md).

## Getting support

Follow [SUPPORT.md](../SUPPORT.md). Report security issues privately under [SECURITY.md](../SECURITY.md).
