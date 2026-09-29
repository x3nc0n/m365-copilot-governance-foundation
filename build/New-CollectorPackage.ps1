[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'artifacts'),
    [switch]$SkipTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repositoryRoot 'src/collector/M365CopilotGovernance.Collector/M365CopilotGovernance.Collector.csproj'
$testProject = Join-Path $repositoryRoot 'tests/collector/M365CopilotGovernance.Collector.Tests/M365CopilotGovernance.Collector.Tests.csproj'
$publishDirectory = Join-Path $OutputDirectory 'collector-publish'
$packagePath = Join-Path $OutputDirectory 'released-package.zip'
$hashPath = Join-Path $OutputDirectory 'released-package.zip.sha256'

if (-not $SkipTests) {
    dotnet test $testProject --configuration Release --nologo
    if ($LASTEXITCODE -ne 0) { throw 'Collector tests failed.' }
}

if (Test-Path -LiteralPath $publishDirectory) { Remove-Item -LiteralPath $publishDirectory -Recurse -Force }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

dotnet publish $project --configuration Release --output $publishDirectory --nologo
if ($LASTEXITCODE -ne 0) { throw 'Collector publish failed.' }

if (Test-Path -LiteralPath $packagePath) { Remove-Item -LiteralPath $packagePath -Force }
# ZipFile keeps the .azurefunctions directory, which wildcard archiving omits as hidden on Linux.
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($publishDirectory, $packagePath, [IO.Compression.CompressionLevel]::Optimal, $false)

$hash = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  released-package.zip" | Set-Content -LiteralPath $hashPath -Encoding utf8NoBOM -NoNewline
Write-Output "Created $packagePath ($hash)."
