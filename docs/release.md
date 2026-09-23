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
9. Push the `v<version>` tag so `.github/workflows/release.yml` can build, verify, and publish the GitHub Release assets automatically.
10. Run the anonymous portal-header and published-release verifications below.
11. Test README release links and Deploy to Azure flows.
12. Record validation evidence; do not perform a live deployment without separate authorization.

## Version 0.1.2 release-candidate assets

The immutable `v0.1.1` tag points to the issue #7 UI changes, but its release workflow run failed before publishing assets. Do not move or replace that tag. Version `v0.1.2` is the recovery release containing the same UI work plus deterministic cross-platform generation.

Expected immutable assets:

```text
greenfield.json
greenfield.createUiDefinition.json
existing-workspace.json
existing-workspace.createUiDefinition.json
release-manifest.json
checksums.sha256
```

They are published under:

```text
https://github.com/x3nc0n/m365-copilot-governance-foundation/releases/download/v0.1.2/<asset>
```

A git tag identifies a source revision, but it does not provide downloadable assets. A `/releases/download/<tag>/<asset>` URL requires both a GitHub Release associated with the tag and an uploaded asset with that exact name. The `v0.1.2` URLs remain unavailable until the tag-triggered workflow publishes all six assets listed above.

`generated/release-manifest.json` and `generated/checksums.sha256` use these flattened upload names rather than source-tree paths. The two portal definitions are intentionally renamed during packaging so they cannot collide.

## Verify the portal assets

Azure Portal uses immutable raw tagged files rather than GitHub Release download responses. This follows the [Microsoft Deploy to Azure button guidance](https://learn.microsoft.com/azure/azure-resource-manager/templates/deploy-to-azure-button), which specifies a raw GitHub template URL and a URL-encoded portal route. Raw tagged responses provide `Access-Control-Allow-Origin: *`; the release assets remain the human-download, checksum, manifest, and provenance channel.

Run this from PowerShell without GitHub authentication. It checks all four portal files, requires the CORS header, and parses each response as JSON.

```powershell
$tag = 'v0.1.2'
$baseUri = "https://raw.githubusercontent.com/x3nc0n/m365-copilot-governance-foundation/$tag/generated/release-assets"
$assets = @(
  'greenfield.json'
  'greenfield.createUiDefinition.json'
  'existing-workspace.json'
  'existing-workspace.createUiDefinition.json'
)

foreach ($asset in $assets) {
  $response = Invoke-WebRequest -Uri "$baseUri/$asset"
  $allowOrigin = $response.Headers['Access-Control-Allow-Origin']
  if ($allowOrigin -notcontains '*') {
    throw "$asset does not allow anonymous cross-origin retrieval. Header value: $allowOrigin"
  }

  $response.Content | ConvertFrom-Json -ErrorAction Stop | Out-Null
  "Verified portal asset and CORS header: $asset"
}
```

This verifies anonymous Azure Portal transport only. Continue with the release verification below to validate the published payload checksums and provenance.

## Automatic tag releases

The tag-triggered workflow at `.github/workflows/release.yml` is the canonical automation for building, verifying, and publishing release assets for version tags. It installs Bicep CLI `0.46.1`, runs the canonical build twice, compares release-asset hashes, and rejects tracked drift in `generated` and `infra/compiled`. Do not treat a successful tag push alone as release completion: wait for the workflow and then verify the anonymously downloadable assets. The workflow file is authoritative for its implementation details.

## Verify the published release

Run this from PowerShell without GitHub authentication. It downloads every expected asset, parses every JSON asset, and verifies every payload covered by `checksums.sha256`. Do not consider the release complete unless the command succeeds.

```powershell
$tag = 'v0.1.2'
$baseUri = "https://github.com/x3nc0n/m365-copilot-governance-foundation/releases/download/$tag"
$assets = @(
  'greenfield.json'
  'greenfield.createUiDefinition.json'
  'existing-workspace.json'
  'existing-workspace.createUiDefinition.json'
  'release-manifest.json'
  'checksums.sha256'
)
$downloadRoot = Join-Path $PWD ".release-verification-$tag"
New-Item -ItemType Directory -Path $downloadRoot -Force | Out-Null

foreach ($asset in $assets) {
  Invoke-WebRequest -Uri "$baseUri/$asset" -OutFile (Join-Path $downloadRoot $asset)
}

$assets |
  Where-Object { $_ -like '*.json' } |
  ForEach-Object {
    Get-Content (Join-Path $downloadRoot $_) -Raw |
      ConvertFrom-Json -ErrorAction Stop |
      Out-Null
  }

$expected = @{}
foreach ($line in Get-Content (Join-Path $downloadRoot 'checksums.sha256')) {
  if ($line -notmatch '^([0-9a-fA-F]{64})\s{2}(.+)$') {
    throw "Invalid checksum line: $line"
  }
  $expected[$Matches[2]] = $Matches[1].ToLowerInvariant()
}

$payloads = $assets | Where-Object { $_ -ne 'checksums.sha256' }
if ($expected.Count -ne $payloads.Count) {
  throw 'Checksum file does not describe every release payload.'
}

foreach ($asset in $payloads) {
  if (-not $expected.ContainsKey($asset)) {
    throw "Missing checksum for $asset"
  }
  $actual = (Get-FileHash (Join-Path $downloadRoot $asset) -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $expected[$asset]) {
    throw "Checksum mismatch for $asset"
  }
}

"Verified $($assets.Count) anonymous release assets for $tag."
```

This verifies publication and integrity only. It does not perform Azure authentication, Azure validation, `what-if`, deployment, or tenant-level checks. Those remain separately authorized manual gates under the native-first deployment model.

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
