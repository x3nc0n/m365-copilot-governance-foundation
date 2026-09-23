# Changelog

All notable changes are documented here. The project follows [Semantic Versioning](https://semver.org/).

## [0.1.2] - 2026-09-22

### Changed

- Normalized text source content to LF before manifest hashing and embedding so Windows CRLF and Linux LF checkouts generate identical content manifests.
- Pinned canonical and CI/release compilation to Bicep CLI `0.46.1`, with a clear local failure when a different compiler version is active.
- Added cross-platform manifest and release-workflow regressions and regenerated all versioned artifacts for the `v0.1.2` recovery release.
- Replaced the existing-workspace resource-ID textbox with a Log Analytics workspace picker, removed duplicate location and internal parameter inputs, derived workbook location from the selected workspace, and kept analytics disabled by default.
- Added explicit guidance and a deployment-time onboarding-state read because `Microsoft.Solutions.ResourceSelector` cannot filter for Sentinel onboarding.
- Updated the existing-workspace Deploy to Azure button to load its matching custom UI definition.
- Published the `v0.1.0` GitHub Release with all required immutable deployment assets, restoring the Deploy to Azure URLs that returned 404 when only the git tag existed.
- Documented automatic tag-release publication and anonymous JSON/checksum verification as release-completion gates.
- Corrected Deploy to Azure links to use URL-encoded, immutable raw `v0.1.0` template and portal-definition URLs so Azure Portal receives the required CORS headers; retained GitHub Release assets for downloads, checksums, manifests, and provenance.

## [0.1.1] - 2026-09-22

### Known release issue

- The immutable tag was created for the existing-workspace picker update, but release workflow run `35787111205` failed before publishing assets because Windows and Linux generation used different line endings and Bicep compiler versions. The tag remains unchanged; use `v0.1.2` for the corrected release.

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

[0.1.2]: https://github.com/x3nc0n/m365-copilot-governance-foundation/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/x3nc0n/m365-copilot-governance-foundation/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/x3nc0n/m365-copilot-governance-foundation/releases/tag/v0.1.0
