[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Common.ps1')

$schemaMap = [ordered]@{
    'src/functions'  = 'schemas/function-metadata.schema.json'
    'src/analytics'  = 'schemas/analytic-metadata.schema.json'
    'src/workbooks'  = 'schemas/workbook-metadata.schema.json'
}

$failures = [System.Collections.Generic.List[string]]::new()
$validated = 0

$jsonFiles = Get-ChildItem -LiteralPath $RepositoryRoot -Recurse -File -Filter '*.json' |
    Where-Object {
        $_.FullName -notmatch '[\\/]\.git[\\/]' -and
        $_.FullName -notmatch '[\\/]\.squad[\\/]' -and
        $_.FullName -notmatch '[\\/]build[\\/]\.verify[\\/]'
    } |
    Sort-Object FullName

foreach ($file in $jsonFiles) {
    try {
        $raw = Get-Content -LiteralPath $file.FullName -Raw
        $null = $raw | ConvertFrom-Json -Depth 100
        $validated++

        $relative = ConvertTo-RepositoryPath -Path $file.FullName -RepositoryRoot $RepositoryRoot
        if ($file.Name -like '*.metadata.json') {
            $mapping = $schemaMap.GetEnumerator() | Where-Object { $relative.StartsWith($_.Key + '/', [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
            if (-not $mapping) {
                throw "Metadata file is outside a supported content directory."
            }

            $schemaPath = Join-Path $RepositoryRoot $mapping.Value
            if (-not (Test-Json -Json $raw -SchemaFile $schemaPath -ErrorAction Stop)) {
                throw "Does not satisfy '$($mapping.Value)'."
            }
        }
        elseif ($relative -eq 'generated/content-manifest.json') {
            if (-not (Test-Json -Json $raw -SchemaFile (Join-Path $RepositoryRoot 'schemas/content-manifest.schema.json') -ErrorAction Stop)) {
                throw "Does not satisfy the content manifest schema."
            }
        }
        elseif ($relative -eq 'generated/release-manifest.json') {
            if (-not (Test-Json -Json $raw -SchemaFile (Join-Path $RepositoryRoot 'schemas/release-manifest.schema.json') -ErrorAction Stop)) {
                throw "Does not satisfy the release manifest schema."
            }
        }
    }
    catch {
        $failures.Add("$(ConvertTo-RepositoryPath -Path $file.FullName -RepositoryRoot $RepositoryRoot): $($_.Exception.Message)")
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 2
}

if (-not $Quiet) {
    Write-Host "Validated $validated JSON files."
}
exit 0
