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
    Write-Host 'Tip: env/dev.json points at 10.0.2.2, an alias the emulator resolves to this machine.' -ForegroundColor DarkGray
    Write-Host 'A physical device cannot resolve 10.0.2.2. For a physical device (USB or wireless adb):' -ForegroundColor DarkGray
    Write-Host '  1. Run `adb reverse tcp:8000 tcp:8000` so the device''s own localhost:8000 reaches this machine.' -ForegroundColor DarkGray
    Write-Host '  2. Change API_BASE_URL in env/dev.json to http://127.0.0.1:8000 (switch it back to 10.0.2.2 for the emulator).' -ForegroundColor DarkGray
}

Write-Host "==> flutter run --flavor $Flavor --dart-define-from-file=$envFile" -ForegroundColor Cyan
Push-Location $RepoRoot
try {
    & flutter run --flavor $Flavor "--dart-define-from-file=$envFile"
} finally {
    Pop-Location
}
