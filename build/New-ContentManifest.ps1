[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputPath = 'generated/content-manifest.json',
    [ValidateRange(0, 600)]
    [int]$WaitSeconds = 0,
    [ValidateRange(1, 30)]
    [int]$RetryIntervalSeconds = 2
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Common.ps1')

function Get-ContentEntries {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('functions', 'analytics', 'workbooks')]
        [string]$Kind
    )

    $contentRoot = Join-Path $RepositoryRoot "src/$Kind"
    if (-not (Test-Path -LiteralPath $contentRoot)) {
        return @()
    }

    $schemaName = switch ($Kind) {
        'functions' { 'function-metadata.schema.json' }
        'analytics' { 'analytic-metadata.schema.json' }
        'workbooks' { 'workbook-metadata.schema.json' }
    }
    $schemaPath = Join-Path $RepositoryRoot "schemas/$schemaName"

    $entries = foreach ($metadataFile in (Get-ChildItem -LiteralPath $contentRoot -Recurse -File -Filter '*.metadata.json' | Sort-Object FullName)) {
        $raw = Get-Content -LiteralPath $metadataFile.FullName -Raw
        if (-not (Test-Json -Json $raw -SchemaFile $schemaPath -ErrorAction Stop)) {
            throw "Metadata '$($metadataFile.FullName)' does not satisfy '$schemaName'."
        }
        $metadata = $raw | ConvertFrom-Json -Depth 100
        $baseName = $metadataFile.Name.Substring(0, $metadataFile.Name.Length - '.metadata.json'.Length)
        $sourceFileName = if ($Kind -eq 'workbooks') { "$baseName.workbook.json" } else { "$baseName.kql" }
        $sourcePath = Join-Path $metadataFile.DirectoryName $sourceFileName
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw "Metadata '$($metadataFile.FullName)' has no paired source '$sourceFileName'."
        }

        $sourceRaw = Get-Content -LiteralPath $sourcePath -Raw
        $common = [ordered]@{
            id           = [string]$metadata.name
            resourceName = [string]$metadata.name
            displayName  = [string]$metadata.displayName
            version      = '0.1.1'
            source       = ConvertTo-RepositoryPath -Path $sourcePath -RepositoryRoot $RepositoryRoot
            metadata     = ConvertTo-RepositoryPath -Path $metadataFile.FullName -RepositoryRoot $RepositoryRoot
            sha256       = Get-Sha256 -Path $sourcePath
            controlOwner = [string]$metadata.authoritativeControlOwner.name
        }

        if ($Kind -eq 'functions') {
            [pscustomobject][ordered]@{
                id                 = $common.id
                resourceName       = $common.resourceName
                displayName        = $common.displayName
                version            = $common.version
                source             = $common.source
                metadata           = $common.metadata
                sha256             = $common.sha256
                controlOwner       = $common.controlOwner
                category           = [string]$metadata.category
                functionAlias      = [string]$metadata.functionAlias
                functionParameters = [string]$metadata.functionParameters
                query              = $sourceRaw.TrimEnd()
            }
        }
        elseif ($Kind -eq 'analytics') {
            $entityMappings = @(
                foreach ($mapping in $metadata.entityMappings) {
                    $identifier = switch ([string]$mapping.entityType) {
                        'Account' { 'Name' }
                        'Host' { 'HostName' }
                        'IP' { 'Address' }
                        default { 'Name' }
                    }
                    [ordered]@{
                        entityType    = [string]$mapping.entityType
                        fieldMappings = @(
                            [ordered]@{
                                identifier = $identifier
                                columnName = [string]$mapping.field
                            }
                        )
                    }
                }
            )
            [pscustomobject][ordered]@{
                id                               = $common.id
                resourceName                     = $common.resourceName
                displayName                      = $common.displayName
                version                          = $common.version
                source                           = $common.source
                metadata                         = $common.metadata
                sha256                           = $common.sha256
                controlOwner                     = $common.controlOwner
                description                      = (@($metadata.limitations) -join ' ')
                enabledByDefault                 = [bool]$metadata.enabled
                severity                         = [string]$metadata.severity
                query                            = $sourceRaw.TrimEnd()
                queryFrequency                   = [string]$metadata.queryFrequency
                queryPeriod                      = [string]$metadata.queryPeriod
                triggerOperator                  = [string]$metadata.triggerOperator
                triggerThreshold                 = [int]$metadata.triggerThreshold
                suppressionDuration              = [string]$metadata.incidentConfiguration.suppression
                suppressionEnabled               = $false
                eventGroupingAggregationKind     = 'SingleAlert'
                incidentConfiguration            = [ordered]@{
                    createIncident        = [bool]$metadata.incidentConfiguration.createIncident
                    groupingConfiguration = [ordered]@{
                        enabled               = $false
                        reopenClosedIncident  = $false
                        lookbackDuration      = [string]$metadata.incidentConfiguration.suppression
                        matchingMethod        = 'AllEntities'
                        groupByEntities       = @()
                        groupByAlertDetails   = @()
                        groupByCustomDetails  = @()
                    }
                }
                entityMappings                   = $entityMappings
                alertDetailsOverride             = [ordered]@{}
                customDetails                    = [ordered]@{}
                tactics                          = @()
                techniques                       = @()
            }
        }
        else {
            [pscustomobject][ordered]@{
                id             = $common.id
                resourceName   = $common.resourceName
                displayName    = $common.displayName
                version        = $common.version
                source         = $common.source
                metadata       = $common.metadata
                sha256         = $common.sha256
                controlOwner   = $common.controlOwner
                description    = (@($metadata.limitations) -join ' ')
                serializedData = (($sourceRaw | ConvertFrom-Json -Depth 100) | ConvertTo-Json -Depth 100 -Compress)
            }
        }
    }

    $duplicate = $entries | Group-Object id | Where-Object Count -gt 1 | Select-Object -First 1
    if ($duplicate) {
        throw "Duplicate $Kind id '$($duplicate.Name)'."
    }

    return @($entries | Sort-Object { $_.id })
}

$deadline = [DateTime]::UtcNow.AddSeconds($WaitSeconds)
do {
    $metadataCount = @(
        foreach ($kind in 'functions', 'analytics', 'workbooks') {
            $path = Join-Path $RepositoryRoot "src/$kind"
            if (Test-Path -LiteralPath $path) {
                Get-ChildItem -LiteralPath $path -Recurse -File -Filter '*.metadata.json'
            }
        }
    ).Count

    if ($metadataCount -gt 0 -or [DateTime]::UtcNow -ge $deadline) {
        break
    }
    Start-Sleep -Seconds $RetryIntervalSeconds
} while ($true)

$manifest = [ordered]@{
    schemaVersion   = '1.0.0'
    solutionVersion = '0.1.1'
    functions       = @(Get-ContentEntries -Kind functions)
    analytics       = @(Get-ContentEntries -Kind analytics)
    workbooks       = @(Get-ContentEntries -Kind workbooks)
}

$resolvedOutput = Join-Path $RepositoryRoot $OutputPath
Write-DeterministicJson -InputObject $manifest -Path $resolvedOutput

$manifestRaw = Get-Content -LiteralPath $resolvedOutput -Raw
if (-not (Test-Json -Json $manifestRaw -SchemaFile (Join-Path $RepositoryRoot 'schemas/content-manifest.schema.json'))) {
    throw 'Generated content manifest does not satisfy its schema.'
}

Write-Host "Generated $(ConvertTo-RepositoryPath -Path $resolvedOutput -RepositoryRoot $RepositoryRoot)."
