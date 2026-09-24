#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Refuses to continue if env/<Flavor>.json still has the Terraform placeholder URL.

.DESCRIPTION
    env/dev.json points at the Android emulator's host alias and is meant to be committed as-is. env/nonprod.json
    and env/prod.json ship with "https://REPLACE-WITH-TERRAFORM-OUTPUT-api_url" until someone pastes in the
    real API URL from `terraform output` for that environment. build.ps1 calls this before every nonprod/prod
    build so a half-configured env file can't produce an app that silently points at nothing.

.PARAMETER Flavor
    dev | nonprod | prod

.EXAMPLE
    pwsh tools/check-env.ps1 -Flavor prod
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('dev', 'nonprod', 'prod')][string]$Flavor
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $RepoRoot "env/$Flavor.json"

if (-not (Test-Path $EnvFile)) {
    Write-Host "ERROR: $EnvFile does not exist." -ForegroundColor Red
    exit 1
}

$raw = Get-Content -Raw -Path $EnvFile
try {
    $json = $raw | ConvertFrom-Json
} catch {
    Write-Host "ERROR: $EnvFile is not valid JSON: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

if (-not $json.API_BASE_URL) {
    Write-Host "ERROR: $EnvFile has no API_BASE_URL key." -ForegroundColor Red
    exit 1
}

if ($json.API_BASE_URL -like '*REPLACE-WITH-TERRAFORM-OUTPUT*') {
    Write-Host "ERROR: $EnvFile still has the Terraform placeholder URL:" -ForegroundColor Red
    Write-Host "  $($json.API_BASE_URL)" -ForegroundColor Red
    Write-Host "Run 'terraform output api_url' for the $Flavor environment and paste the real URL into $EnvFile before building this flavor." -ForegroundColor Red
    exit 1
}

if ($json.API_BASE_URL -notmatch '^https://') {
    if ($Flavor -eq 'dev') {
        Write-Host "  (dev) API_BASE_URL is not https:// — fine for the emulator/local backend, skipping the check."
    } else {
        Write-Host "ERROR: $EnvFile's API_BASE_URL must be https:// for the $Flavor flavor, got: $($json.API_BASE_URL)" -ForegroundColor Red
        exit 1
    }
}

Write-Host "OK: $EnvFile looks configured (API_BASE_URL = $($json.API_BASE_URL))" -ForegroundColor Green
exit 0
