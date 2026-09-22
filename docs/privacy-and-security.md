# Privacy and Security

## Default boundary

The foundation processes governance metadata and supported native alerts, incidents, audit, identity, application, and operational-health signals. It excludes Microsoft 365 Copilot prompt and response content by default.

`M365CopilotInteraction_CL` is not part of the default architecture. Any future interaction export is an exceptional module requiring:

- a documented coverage gap and purpose;
- privacy/legal and security approval;
- administrator consent;
- a separate least-privilege identity;
- data minimization and field-level review;
- geography, access, retention, purge, monitoring, and cost controls;
- an explicit native-system and incident-response owner.

## Data minimization

- Prefer native alerts and identifiers over copied source content.
- Prefer portal deep links over embedding sensitive investigation details in workbooks.
- Do not commit customer watchlists, tenant IDs, identities, exports, tokens, prompts, or responses.
- Use synthetic samples.
- Redact support and CI output.
- Keep optional collection disabled by default.

The [data-table catalog](data-tables.md) documents sensitivity and fallback behavior. The [native-control matrix](native-control-matrix.md) identifies the authoritative owner.

## Purpose limitation

Sentinel data is used for correlation, operational context, investigation routing, and telemetry health. Sentinel is not the default system for eDiscovery, records retention, communication-compliance review, insider-risk case management, or prompt classification.

High Copilot usage is not, by itself, evidence of risk. An optional usage cache supports reporting only.

## Workplace and employee monitoring

Telemetry associated with identifiable workers can constitute workplace or employee monitoring even when the project collects only metadata. Before enabling user-level reporting, correlation, watchlists, enrichment, or exceptional interaction export, the customer must:

- document the specific purpose and applicable lawful basis with privacy, legal, labor, and employee-relations stakeholders;
- provide clear, timely workforce notices describing collected data, purposes, access, retention, review processes, and available rights or escalation channels;
- complete and approve a data-protection impact assessment or equivalent workplace-monitoring assessment where required;
- consult works councils, unions, regulators, or other representative bodies when applicable;
- prohibit covert, continuous, or generalized productivity and behavioral surveillance unless independently authorized by law and organizational policy.

This reference implementation does not determine lawful basis or satisfy notice, consultation, or assessment obligations on the customer's behalf.

### Access, masking, and role separation

- Limit identifiable records to investigators with a documented need to know; use separate roles and access groups for platform operations, aggregate reporting, privacy oversight, and investigations.
- Prefer aggregate, thresholded, pseudonymized, or masked views for operational reporting. Avoid names, user principal names, email addresses, employee identifiers, and small population slices unless identification is necessary and approved.
- Keep the re-identification key or identity mapping separate from reporting data, restrict it to designated custodians, and log access.
- Prevent reporting users from drilling into identifiable investigation evidence by default.
- Escalate from aggregate reporting to an identifiable investigation only through a documented trigger, authorized case workflow, and appropriate human review.
- Do not reuse reporting telemetry for performance management, disciplinary action, employee ranking, or misconduct inference without a separately documented lawful purpose, policy basis, notice, and review process.

Aggregate adoption and service-health reporting must remain operationally and access-control separated from security, insider-risk, communication-compliance, legal, or human-resources investigations. A reporting anomaly is context for validation, not an employee-risk verdict.

## Identity and access

Use separate identities for deployment/bootstrap, optional usage collection, and exceptional interaction export. Prefer managed identity or workload federation; use certificates only as a fallback. Avoid client secrets.

Apply least privilege at the narrowest resource and API scope. Separate Azure RBAC from Microsoft Graph application permissions and Microsoft 365 administrator roles. Review effective consent and access periodically.

## Mutation safety

Validation is read-only by default. Mutations require an explicit switch and `SupportsShouldProcess`, including `-WhatIf` and `-Confirm`. Scripts report exact differences but do not grant human approvals. Administrator consent and privacy/legal approval remain external gates.

## Retention, residency, and deletion

Customers choose workspace region and retention subject to product availability and legal obligations. Keep operational retention no longer than justified. Native compliance systems retain their own records; Sentinel retention does not replace them.

Before deleting a workspace, table, watchlist, identity, or consent:

1. identify legal/records obligations;
2. confirm the authoritative copy;
3. review active incidents and investigations;
4. export only when approved;
5. document the decision and deletion evidence.

## Public and support artifacts

Release assets, test fixtures, issues, pull requests, logs, screenshots, and support bundles must not contain:

- credentials, tokens, cookies, certificates, or connection strings;
- tenant, subscription, object, or user identifiers unless synthetic;
- customer names or exports;
- prompt or response content;
- sensitive alert evidence;
- unapproved watchlist data.

Follow [SECURITY.md](../SECURITY.md) for vulnerability reporting.

## Shared responsibility

The project supplies reference content and documentation. Customers remain responsible for licensing, lawful basis, notices, consent, data-protection impact assessment, regional requirements, role design, production validation, monitoring, incident response, and support agreements.
