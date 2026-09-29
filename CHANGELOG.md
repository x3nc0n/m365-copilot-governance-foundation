# Changelog

All notable changes are documented here. The project follows [Semantic Versioning](https://semver.org/).

## [0.2.0] - 2026-09-29

### Breaking

- `interactionContentCollection` is a new **required** parameter (`Enabled` or `Disabled`, no default) on both entry points and in the Deploy to Azure experience. Existing parameter files must add it.
- Removed the `analyticsEnabled` parameter. Remove it from existing parameter files. Redeploying resets solution rules to disabled; re-enable reviewed rules in Sentinel afterward.

### Added

- Opt-in Microsoft 365 Copilot prompt and response content collection: Microsoft Graph interaction export API to a Flex Consumption .NET 8 Azure Function with a user-assigned managed identity, Logs Ingestion through a `Direct` data collection rule, and `M365GovCopilotInteractionContent_CL` with 90-day retention. Scopes: all licensed users, include group, or exclude group.
- `Initialize-CollectorIdentity.ps1` now grants the collector's Microsoft Graph application roles (`AiEnterpriseInteraction.Read.All`, `User.Read.All`, and `GroupMember.Read.All` for group scopes) with `-WhatIf`/`-Confirm` support and no implicit sign-in.
- Interaction Content workbook tab and the `M365Gov-InteractionContent-NativeOutcome` analytic, which is installed only when collection is enabled and alerts only on Microsoft-provided jailbreak, cross-prompt injection, and Purview policy outcomes.
- Release asset `released-package.zip` (with SHA-256 file) for the collector.

### Changed

- Removed the misleading deployment-time analytics enable option. `deployAnalytics` still controls whether rules are installed, and generated ARM always creates them with `enabled: false` for manual operator review and activation in Sentinel.
- Consolidated the four Sentinel workbooks into one `m365gov-governance` workbook with Overview, Native Alert Correlation, Data Health, Coverage and Gaps, and Interaction Content tabs. Existing deployments retain the prior workbook resources until an operator removes them.

### Fixed

- Split the `M365Gov_DataHealth` age and status calculations so KQL resolves `Age` before using it to classify stale sources.

## [0.1.4] - 2026-09-23

### Fixed

- Set Log Analytics saved-search `properties.version` to integer `1` instead of reusing the solution semantic version.
- Omit optional Sentinel analytic-rule `entityMappings` when metadata contains no semantically valid mapping, while preserving populated mappings.
- Replaced dynamic saved-search function parameter defaults with literal nullable datetimes while preserving rolling query windows inside KQL.
- Documented the customer-managed `Query` linked-storage prerequisite for workspaces that restrict saved-query writes.
- Added compiled ARM regressions for both service API contracts and regenerated deterministic deployment assets.

## [0.1.3] - 2026-09-23

### Fixed

- Replaced the existing-workspace Sentinel readiness check's `customerManagedKey` dereference with evaluation of the complete onboarding-state `properties` object.
- Allowed valid Sentinel onboarding responses with an empty properties object while preserving early failure for a missing or unreadable `Microsoft.SecurityInsights/onboardingStates/default` resource.
- Added ARM/Bicep regression coverage for the property-agnostic onboarding-state contract and regenerated deterministic deployment assets.

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

[0.1.4]: https://github.com/x3nc0n/m365-copilot-governance-foundation/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/x3nc0n/m365-copilot-governance-foundation/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/x3nc0n/m365-copilot-governance-foundation/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/x3nc0n/m365-copilot-governance-foundation/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/x3nc0n/m365-copilot-governance-foundation/releases/tag/v0.1.0
