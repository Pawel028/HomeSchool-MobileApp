#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Builds the HomeSchooling app for one flavor/target.

.PARAMETER Flavor
    dev | nonprod | prod

.PARAMETER Target
    apk | appbundle (defaults to apk)

.PARAMETER Release
    Build in release mode. Defaults on for nonprod/prod, off (debug) for dev; pass -Release:$false to override.

.EXAMPLE
    pwsh tools/build.ps1 -Flavor dev -Target apk
.EXAMPLE
    pwsh tools/build.ps1 -Flavor prod -Target appbundle
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('dev', 'nonprod', 'prod')][string]$Flavor,
    [ValidateSet('apk', 'appbundle')][string]$Target = 'apk',
    [Nullable[bool]]$Release = $null
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

& "$PSScriptRoot/check-env.ps1" -Flavor $Flavor
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($null -eq $Release) {
    $Release = $Flavor -ne 'dev'
}
$mode = if ($Release) { '--release' } else { '--debug' }

$envFile = Join-Path $RepoRoot "env/$Flavor.json"

if ($Flavor -ne 'dev') {
    $keyProps = Join-Path $RepoRoot 'android/key.properties'
    if ($Release -and -not (Test-Path $keyProps)) {
        Write-Host "ERROR: android/key.properties not found. Release builds of '$Flavor' must be signed." -ForegroundColor Red
        Write-Host "See README.md 'Creating a signing key' to generate one, then create android/key.properties (gitignored)." -ForegroundColor Red
        exit 1
    }
}

Write-Host "==> flutter build $Target $mode --flavor $Flavor --dart-define-from-file=$envFile" -ForegroundColor Cyan
Push-Location $RepoRoot
try {
    & flutter build $Target $mode --flavor $Flavor "--dart-define-from-file=$envFile"
    if ($LASTEXITCODE -ne 0) { throw "flutter build exited with code $LASTEXITCODE" }
} finally {
    Pop-Location
}

Write-Host 'Build complete.' -ForegroundColor Green
