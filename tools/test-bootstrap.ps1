#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verification harness for tools/bootstrap.ps1. Not part of the app build — run this after changing
    bootstrap.ps1 or its patch scripts under tools/lib/.

.DESCRIPTION
    Flutter cannot be installed in this environment, so bootstrap.ps1 can never be exercised against a real
    `flutter create` output here. Instead this script:
      1. Builds a mock android/ tree in a temp directory, using the *actual* app/build.gradle.kts.tmpl and
         AndroidManifest.xml.tmpl content from flutter/flutter's stable branch (fetched once and pasted below
         — see the comment above each here-string for the exact source URL and date), with the mustache
         placeholders resolved the way `flutter create --org in.homeschoolapp --project-name homeschooling`
         would resolve them.
      2. Copies this repo's tools/ directory next to that mock android/ tree and runs bootstrap.ps1
         -SkipFlutterCreate against it.
      3. Asserts every patch landed (SDK versions, signing config, flavors, minify, allowBackup, dev network
         security config).
      4. Runs it a second time and asserts the files are byte-for-byte identical to after the first run.

    Exits non-zero (and prints which assertion failed) on any failure, so it can be wired into CI later if the
    Flutter SDK ever becomes installable there.

.EXAMPLE
    pwsh tools/test-bootstrap.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$failures = @()

function Assert-True([bool]$Condition, [string]$Message) {
    if ($Condition) {
        Write-Host "  PASS: $Message" -ForegroundColor Green
    } else {
        Write-Host "  FAIL: $Message" -ForegroundColor Red
        $script:failures += $Message
    }
}

function Assert-Contains([string]$Content, [string]$Needle, [string]$Message) {
    Assert-True ($Content.Contains($Needle)) $Message
}

# ---------------------------------------------------------------------------
# 1. Build the mock android/ tree in a temp dir
# ---------------------------------------------------------------------------
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("hsapp-bootstrap-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
Write-Host "Working dir: $tmp"

$mockAppDir = Join-Path $tmp 'android/app'
New-Item -ItemType Directory -Path (Join-Path $mockAppDir 'src/main') -Force | Out-Null

# Source: https://raw.githubusercontent.com/flutter/flutter/stable/packages/flutter_tools/templates/app/android-kotlin.tmpl/app/build.gradle.kts.tmpl
# fetched 2026-09-22, with {{androidIdentifier}} resolved to in.homeschoolapp.homeschooling (what
# `flutter create --org in.homeschoolapp --project-name homeschooling` produces).
$mockBuildGradleKts = @'
plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "in.homeschoolapp.homeschooling"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "in.homeschoolapp.homeschooling"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
'@
Set-Content -Path (Join-Path $mockAppDir 'build.gradle.kts') -Value $mockBuildGradleKts -NoNewline

# Source: https://raw.githubusercontent.com/flutter/flutter/stable/packages/flutter_tools/templates/app/android.tmpl/app/src/main/AndroidManifest.xml.tmpl
# fetched 2026-09-22, with {{projectName}} resolved to "homeschooling" and ${applicationName} left as the
# literal Gradle-plugin-substituted placeholder it is at runtime (not a flutter-create mustache token).
$mockManifest = @'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="homeschooling"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
'@
Set-Content -Path (Join-Path $mockAppDir 'src/main/AndroidManifest.xml') -Value $mockManifest -NoNewline

# ---------------------------------------------------------------------------
# 2. Copy this repo's tools/ next to the mock android/ tree, then run bootstrap.ps1 -SkipFlutterCreate
# ---------------------------------------------------------------------------
Copy-Item -Path (Join-Path $RepoRoot 'tools') -Destination (Join-Path $tmp 'tools') -Recurse -Force

Write-Host "`n==> First bootstrap run" -ForegroundColor Cyan
& pwsh -NoProfile -File (Join-Path $tmp 'tools/bootstrap.ps1') -Org 'in.homeschoolapp' -SkipFlutterCreate
if ($LASTEXITCODE -ne 0) {
    Write-Host "bootstrap.ps1 exited with code $LASTEXITCODE on the first run" -ForegroundColor Red
    exit 1
}

$gradleAfterFirst = Get-Content -Raw -Path (Join-Path $mockAppDir 'build.gradle.kts')
$manifestAfterFirst = Get-Content -Raw -Path (Join-Path $mockAppDir 'src/main/AndroidManifest.xml')

# ---------------------------------------------------------------------------
# 3. Assert the patches landed
# ---------------------------------------------------------------------------
Write-Host "`n==> Assertions on build.gradle.kts" -ForegroundColor Cyan
Assert-Contains $gradleAfterFirst 'minSdk = 26' 'minSdk set to 26'
Assert-Contains $gradleAfterFirst 'compileSdk = 36' 'compileSdk set to 36'
Assert-Contains $gradleAfterFirst 'targetSdk = 36' 'targetSdk set to 36'
Assert-Contains $gradleAfterFirst 'val keystorePropertiesFile = rootProject.file("key.properties")' 'key.properties loader inserted'
Assert-Contains $gradleAfterFirst 'signingConfigs {' 'signingConfigs block inserted'
Assert-Contains $gradleAfterFirst 'create("release")' 'release signing config created'
Assert-Contains $gradleAfterFirst '// HOMESCHOOLING: flavors' 'flavors marker present'
Assert-Contains $gradleAfterFirst 'flavorDimensions += "env"' 'flavor dimension added'
Assert-Contains $gradleAfterFirst 'create("dev")' 'dev flavor created'
Assert-Contains $gradleAfterFirst 'create("nonprod")' 'nonprod flavor created'
Assert-Contains $gradleAfterFirst 'create("prod")' 'prod flavor created'
Assert-Contains $gradleAfterFirst 'applicationIdSuffix = ".dev"' 'dev applicationIdSuffix set'
Assert-Contains $gradleAfterFirst 'applicationIdSuffix = ".nonprod"' 'nonprod applicationIdSuffix set'
Assert-Contains $gradleAfterFirst 'isMinifyEnabled = true' 'release minification enabled'
Assert-Contains $gradleAfterFirst 'isShrinkResources = true' 'release resource shrinking enabled'
Assert-Contains $gradleAfterFirst '// HOMESCHOOLING: release build type' 'original unsigned release block replaced'

Write-Host "`n==> Assertions on AndroidManifest.xml" -ForegroundColor Cyan
Assert-Contains $manifestAfterFirst 'android:allowBackup="false"' 'allowBackup=false added'
Assert-Contains $manifestAfterFirst 'android:label="@string/app_name"' 'label points at @string/app_name'

Write-Host "`n==> Assertions on the dev-flavor source set" -ForegroundColor Cyan
$devManifest = Join-Path $mockAppDir 'src/dev/AndroidManifest.xml'
$devNsc = Join-Path $mockAppDir 'src/dev/res/xml/network_security_config.xml'
Assert-True (Test-Path $devManifest) 'src/dev/AndroidManifest.xml copied'
Assert-True (Test-Path $devNsc) 'src/dev/res/xml/network_security_config.xml copied'
if (Test-Path $devNsc) {
    $nscContent = Get-Content -Raw -Path $devNsc
    Assert-Contains $nscContent '10.0.2.2' 'network security config scopes cleartext to 10.0.2.2 only'
    Assert-Contains $nscContent '<domain-config cleartextTrafficPermitted="true">' 'cleartext is scoped to a domain-config, not base-config'
    Assert-True (-not $nscContent.Contains('<base-config')) 'network security config has no base-config (would allow cleartext everywhere)'
}

# ---------------------------------------------------------------------------
# 4. Run again and assert idempotency
# ---------------------------------------------------------------------------
Write-Host "`n==> Second bootstrap run (idempotency check)" -ForegroundColor Cyan
& pwsh -NoProfile -File (Join-Path $tmp 'tools/bootstrap.ps1') -Org 'in.homeschoolapp' -SkipFlutterCreate
if ($LASTEXITCODE -ne 0) {
    Write-Host "bootstrap.ps1 exited with code $LASTEXITCODE on the second run" -ForegroundColor Red
    exit 1
}

$gradleAfterSecond = Get-Content -Raw -Path (Join-Path $mockAppDir 'build.gradle.kts')
$manifestAfterSecond = Get-Content -Raw -Path (Join-Path $mockAppDir 'src/main/AndroidManifest.xml')

Assert-True ($gradleAfterFirst -eq $gradleAfterSecond) 'build.gradle.kts is byte-identical after a second run'
Assert-True ($manifestAfterFirst -eq $manifestAfterSecond) 'AndroidManifest.xml is byte-identical after a second run'

# ---------------------------------------------------------------------------
# Cleanup + result
# ---------------------------------------------------------------------------
Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
if ($failures.Count -eq 0) {
    Write-Host "All bootstrap.ps1 assertions passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$($failures.Count) assertion(s) failed:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
