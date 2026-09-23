Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RequiredBicepVersion = '0.46.1'

function Get-RepositoryRoot {
    [CmdletBinding()]
    param()

    return (Split-Path -Parent $PSScriptRoot)
}

function ConvertTo-LfText {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [Parameter(Mandatory)]
        [string]$Text
    )

    return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Get-NormalizedTextContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    return ConvertTo-LfText -Text ([System.IO.File]::ReadAllText($Path))
}

function Get-NormalizedTextSha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $content = Get-NormalizedTextContent -Path $Path
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($content)
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return [Convert]::ToHexString($hash).ToLowerInvariant()
}

function Get-RequiredBicepVersion {
    [CmdletBinding()]
    param()

    return $script:RequiredBicepVersion
}

function Assert-BicepVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.CommandInfo]$AzureCli
    )

    $versionOutput = (& $AzureCli.Source bicep version 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch 'Bicep CLI version\s+(?<version>\d+\.\d+\.\d+)') {
        throw "Unable to determine the Azure CLI Bicep version. Install the required version with 'az bicep install --version v$script:RequiredBicepVersion'."
    }

    $actualVersion = $Matches.version
    if ($actualVersion -ne $script:RequiredBicepVersion) {
        throw "Bicep CLI version $script:RequiredBicepVersion is required, but version $actualVersion is installed. Run 'az bicep install --version v$script:RequiredBicepVersion' and retry."
    }
}

function ConvertTo-RepositoryPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$RepositoryRoot = (Get-RepositoryRoot)
    )

    $root = [System.IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\', '/')
    $full = [System.IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path '$Path' is outside the repository root."
    }

    return $full.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
}

function Write-DeterministicJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Path,

        [int]$Depth = 100
    )

    $json = $InputObject | ConvertTo-Json -Depth $Depth
    $json = (ConvertTo-LfText -Text $json).TrimEnd() + "`n"
    $parent = Split-Path -Parent $Path
    if ($parent) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Get-Sha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
