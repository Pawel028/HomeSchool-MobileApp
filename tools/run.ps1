#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Runs the HomeSchooling app on a connected device/emulator for one flavor.

.PARAMETER Flavor
    dev | nonprod | prod (defaults to dev)

.EXAMPLE
    pwsh tools/run.ps1
.EXAMPLE
    pwsh tools/run.ps1 -Flavor nonprod
#>
[CmdletBinding()]
param(
    [ValidateSet('dev', 'nonprod', 'prod')][string]$Flavor = 'dev'
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

& "$PSScriptRoot/check-env.ps1" -Flavor $Flavor
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$envFile = Join-Path $RepoRoot "env/$Flavor.json"

if ($Flavor -eq 'dev') {
    Write-Host 'Tip: if you are running on a physical device (not the emulator) against a backend on this' -ForegroundColor DarkGray
    Write-Host 'machine, run `adb reverse tcp:8000 tcp:8000` first so 10.0.2.2/localhost:8000 resolves.' -ForegroundColor DarkGray
}

Write-Host "==> flutter run --flavor $Flavor --dart-define-from-file=$envFile" -ForegroundColor Cyan
Push-Location $RepoRoot
try {
    & flutter run --flavor $Flavor "--dart-define-from-file=$envFile"
} finally {
    Pop-Location
}
