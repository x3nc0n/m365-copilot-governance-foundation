[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$baseUri = 'https://raw.githubusercontent.com/x3nc0n/m365-copilot-governance-foundation/v0.1.1/generated/release-assets'
$assets = @(
    'greenfield.json'
    'existing-workspace.json'
    'greenfield.createUiDefinition.json'
    'existing-workspace.createUiDefinition.json'
)

foreach ($asset in $assets) {
    $uri = "$baseUri/$asset"
    $response = Invoke-WebRequest -Uri $uri -UseBasicParsing
    if ($response.StatusCode -ne 200) {
        throw "$uri returned HTTP $($response.StatusCode)."
    }
    if ($response.Headers['Access-Control-Allow-Origin'] -notcontains '*') {
        throw "$uri does not return Access-Control-Allow-Origin: *."
    }
    $response.Content | ConvertFrom-Json -Depth 100 -ErrorAction Stop | Out-Null
    Write-Host "Validated portal asset CORS and JSON: $uri"
}
