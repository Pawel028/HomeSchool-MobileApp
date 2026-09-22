#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Idempotent Android project bootstrap for the HomeSchooling app.

.DESCRIPTION
    If android/ is missing, runs `flutter create` to generate it, then patches the generated Gradle files to
    add the dev/nonprod/prod flavors, SDK versions, release signing and hardening this project needs. Safe to
    run again later (e.g. after `flutter create` regenerates a file) — every patch is written so that running
    it twice produces the same file, either by checking for a marker before inserting a block, or by matching
    on text that only exists before the patch is applied (so the second run's search simply finds nothing).

.PARAMETER Org
    Reverse-DNS organisation id passed to `flutter create --org`. Defaults to a clearly-fake placeholder.
    *** applicationId is permanent once published to the Play Store — this MUST be set to the real org
    before the first release build. See README.md "Before your first Play Store upload". ***

.PARAMETER SkipFlutterCreate
    Skip the `flutter create` step and only run the patches, against whatever is already at android/. Used by
    tools/test-bootstrap.ps1 to verify the patch logic against a mock template tree without the Flutter SDK.

.EXAMPLE
    pwsh tools/bootstrap.ps1
.EXAMPLE
    pwsh tools/bootstrap.ps1 -Org com.acmehomeschool
#>
[CmdletBinding()]
param(
    [string]$Org = 'in.homeschoolapp',
    [switch]$SkipFlutterCreate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$AndroidDir = Join-Path $RepoRoot 'android'

function Write-Step([string]$Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Warn2([string]$Message) {
    Write-Host "WARNING: $Message" -ForegroundColor Yellow
}

function Fail([string]$Message) {
    Write-Host "ERROR: $Message" -ForegroundColor Red
    throw $Message
}

function Assert-Anchor([string]$Content, [string]$Anchor, [string]$File) {
    if ($Content -notmatch [regex]::Escape($Anchor)) {
        Fail "Expected anchor text not found in $File`n  Looking for: $Anchor`nThe Flutter app template may have changed. Update tools/bootstrap.ps1's patch logic to match, then re-run."
    }
}

# ---------------------------------------------------------------------------
# Step 0: org placeholder warning
# ---------------------------------------------------------------------------
if ($Org -eq 'in.homeschoolapp') {
    Write-Warn2 "-Org was not set: using the PLACEHOLDER application id 'in.homeschoolapp'."
    Write-Warn2 "applicationId is PERMANENT once an app is uploaded to the Play Store."
    Write-Warn2 "Re-run with -Org <your.real.reverse.dns> before the first production build/upload."
}

# ---------------------------------------------------------------------------
# Step 1: flutter create (skippable for tests / already-bootstrapped repos)
# ---------------------------------------------------------------------------
if (-not (Test-Path $AndroidDir)) {
    if ($SkipFlutterCreate) {
        Fail "android/ does not exist and -SkipFlutterCreate was passed. Nothing to patch."
    }
    Write-Step "android/ not found: running flutter create --org $Org --project-name homeschooling --platforms android ."
    Push-Location $RepoRoot
    try {
        & flutter create --org $Org --project-name homeschooling --platforms android .
        if ($LASTEXITCODE -ne 0) { Fail "flutter create exited with code $LASTEXITCODE" }
    } finally {
        Pop-Location
    }
} else {
    Write-Step "android/ already exists: skipping flutter create (safe to re-run bootstrap to (re)apply patches)."
}

$AppDir = Join-Path $AndroidDir 'app'
$BuildGradleKts = Join-Path $AppDir 'build.gradle.kts'
$BuildGradleGroovy = Join-Path $AppDir 'build.gradle'
$ManifestPath = Join-Path $AppDir 'src/main/AndroidManifest.xml'

if (-not (Test-Path $AppDir)) {
    Fail "android/app not found under $AndroidDir. Did flutter create run for the android platform?"
}

# ---------------------------------------------------------------------------
# Step 2: patch the app Gradle file (Kotlin DSL is the default since Flutter 3.29; Groovy is still supported
# for older/migrated projects).
# ---------------------------------------------------------------------------
if (Test-Path $BuildGradleKts) {
    Write-Step "Patching $BuildGradleKts (Kotlin DSL)"
    & "$PSScriptRoot/lib/patch-build-gradle-kts.ps1" -Path $BuildGradleKts
} elseif (Test-Path $BuildGradleGroovy) {
    Write-Step "Patching $BuildGradleGroovy (Groovy DSL)"
    & "$PSScriptRoot/lib/patch-build-gradle-groovy.ps1" -Path $BuildGradleGroovy
} else {
    Fail "Neither app/build.gradle.kts nor app/build.gradle found under $AppDir."
}

# ---------------------------------------------------------------------------
# Step 3: AndroidManifest.xml — allowBackup=false, app_name via resValue
# ---------------------------------------------------------------------------
if (-not (Test-Path $ManifestPath)) {
    Fail "AndroidManifest.xml not found at $ManifestPath"
}
Write-Step "Patching $ManifestPath"
$manifest = Get-Content -Raw -Path $ManifestPath

if ($manifest -notmatch 'android:allowBackup=') {
    Assert-Anchor $manifest 'android:icon="@mipmap/ic_launcher">' $ManifestPath
    $manifest = $manifest -replace [regex]::Escape('android:icon="@mipmap/ic_launcher">'), "android:icon=`"@mipmap/ic_launcher`"`n        android:allowBackup=`"false`">"
} else {
    Write-Host "  allowBackup already present, skipping."
}

# Point the label at the flavor-specific string resource (set via resValue in the Gradle patch) instead of a
# fixed literal, so each flavor can show a different app name on the home screen.
$manifest = $manifest -replace 'android:label="[^"]*"', 'android:label="@string/app_name"'

Set-Content -Path $ManifestPath -Value $manifest -NoNewline

# ---------------------------------------------------------------------------
# Step 4: dev-flavor source set (cleartext HTTP to the emulator alias only, never in nonprod/prod)
# ---------------------------------------------------------------------------
$DevSourceSet = Join-Path $AppDir 'src/dev'
$TemplateDir = Join-Path $PSScriptRoot 'android-templates/dev'
Write-Step "Copying dev-flavor overlay into $DevSourceSet"
if (-not (Test-Path $DevSourceSet)) { New-Item -ItemType Directory -Path $DevSourceSet -Force | Out-Null }
Get-ChildItem -Path $TemplateDir -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring($TemplateDir.Length).TrimStart('\', '/')
    $dest = Join-Path $DevSourceSet $relative
    $destDir = Split-Path -Parent $dest
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    Copy-Item -Path $_.FullName -Destination $dest -Force
}

Write-Host ''
Write-Host 'Bootstrap complete.' -ForegroundColor Green
Write-Host 'Next: tools/check-env.ps1, then tools/run.ps1 or tools/build.ps1.'
if ($Org -eq 'in.homeschoolapp') {
    Write-Warn2 "Reminder: applicationId is still the placeholder 'in.homeschoolapp.homeschooling'."
}
