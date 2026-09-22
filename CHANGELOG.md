# Changelog

All notable changes are documented here. The project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- Published the `v0.1.0` GitHub Release with all required immutable deployment assets, restoring the Deploy to Azure URLs that returned 404 when only the git tag existed.
- Documented automatic tag-release publication and anonymous JSON/checksum verification as release-completion gates.
- Corrected Deploy to Azure links to use URL-encoded, immutable raw `v0.1.0` template and portal-definition URLs so Azure Portal receives the required CORS headers; retained GitHub Release assets for downloads, checksums, manifests, and provenance.

## [0.1.0] - 2026-09-22

### Added

- Native-first Microsoft 365 Copilot governance reference architecture.
- Greenfield and existing-workspace Azure deployment paths.
- Sentinel workbooks, narrow cross-product analytics, KQL functions, and data-health content.
- Read-only-by-default PowerShell validation and explicit `ShouldProcess`-protected bootstrap workflow.
- Public documentation, cost model, security policy, contribution guidance, and MIT license.

### Security and privacy

- Prompt and response content excluded from the default architecture.
- Optional custom ingestion disabled by default.
- Native control ownership and portal handoffs made explicit.

[Unreleased]: https://github.com/x3nc0n/m365-copilot-governance-foundation/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/x3nc0n/m365-copilot-governance-foundation/releases/tag/v0.1.0
