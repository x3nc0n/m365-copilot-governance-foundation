# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| 0.1.x | Yes |
| Earlier/unreleased forks | No guarantee |

## Report a vulnerability

Use GitHub's private vulnerability reporting feature for this repository:

`Security` → `Advisories` → `Report a vulnerability`

If private vulnerability reporting is not enabled, contact a maintainer through a private GitHub channel before sharing details. Do not include secrets, access tokens, tenant data, prompt/response content, or customer exports. Provide a minimal synthetic reproduction, affected version, impact, and suggested mitigation if known. Do not open a public issue until maintainers have coordinated disclosure.

## Security expectations

- Validation is read-only by default.
- Mutations require explicit switches and support `-WhatIf` and `-Confirm`.
- ARM/Bicep owns Azure state; scripts do not silently compete with it.
- Managed identity or workload federation is preferred; certificates are a fallback; client secrets are not the default.
- Public and CI artifacts must redact identities, tenant IDs, tokens, prompts, and responses.
- Prompt/response ingestion and customer watchlist data are excluded from defaults.

This is a reference implementation, not a warranty or managed security service. Customers remain responsible for threat modeling, access review, deployment validation, monitoring, incident response, licensing, data residency, and regulatory obligations.
