# Release Process

## Versioning

Use Semantic Versioning. A breaking change includes incompatible parameter/output, resource identity, table/function schema, permission, analytic behavior, workbook contract, or removal behavior.

## Release checklist

1. Update [CHANGELOG.md](../CHANGELOG.md).
2. Run `pwsh .\build\Invoke-Build.ps1 -CI` from a clean checkout. Confirm it regenerates `generated/content-manifest.json`, validates content metadata, lints both Bicep entry points, validates both `.bicepparam` samples, and compiles both entry points.
3. Validate PowerShell, Pester, JSON, portal definitions, KQL metadata, internal links, and prohibited-content checks.
4. Confirm optional integrations are disabled by default.
5. Confirm the data-table catalog and native-control matrix match deployed content.
6. Verify the existing-workspace path does not own unrelated resources.
7. Generate compiled templates and copy the four upload-ready files to `generated/release-assets` using the exact flattened names below. Generate the release manifest and SHA-256 checksums from those packaged bytes.
8. Confirm compiled artifacts exactly match tagged source.
9. Tag `v<version>` and publish immutable assets.
10. Test README release links and Deploy to Azure flows.
11. Record validation evidence; do not perform a live deployment without separate authorization.

## Version 0.1.0 assets

Expected immutable assets:

```text
greenfield.json
greenfield.createUiDefinition.json
existing-workspace.json
existing-workspace.createUiDefinition.json
release-manifest.json
checksums.sha256
```

They will be published under:

```text
https://github.com/x3nc0n/m365-copilot-governance-foundation/releases/download/v0.1.0/<asset>
```

The URLs may not resolve until the tag and release are published.

`generated/release-manifest.json` and `generated/checksums.sha256` use these flattened upload names rather than source-tree paths. The two portal definitions are intentionally renamed during packaging so they cannot collide.

## Validation gates

- Both entry points compile.
- Portal inputs map to frozen parameters.
- Required outputs and solution metadata are present.
- PowerShell mutations use `ShouldProcess`.
- Static tests pass without Azure credentials.
- Analytics stay within native-first boundaries.
- Every workbook and analytic has ownership and native routing metadata.
- Every dependency is in the data-table catalog.
- Release assets contain no tenant data, identities, secrets, prompts, or responses.
- Checksums are generated from final uploaded bytes.

## Hotfixes

Patch releases should contain the smallest safe fix, document security/privacy/permission impact, preserve contracts where possible, and rebuild all generated assets. Never replace an existing release asset silently; publish a new version.

## Deprecation

Announce deprecated parameters, outputs, functions, rules, and workbooks before removal when security does not require immediate action. Document migration and rollback. Destructive cleanup remains explicit and must not delete an existing workspace or unrelated content.
