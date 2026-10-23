<#
    Packaging script for Nullgate's Quest Tracker - Forever

    Builds zips/<AddonName> <Version>.zip with a single top-level addon folder.
    The repository-root CHANGELOG.md is the only changelog; it is copied into
    the packaged addon folder so players get it inside the zip.

    Usage:
        .\package.ps1
        .\package.ps1 -Version "1.2.1" -Notes "Short summary for a new changelog entry"
        .\package.ps1 -SourceDir ".\1.2.0_refactor\NullgatesQuestTracker-Forever"
#>

param (
    [string]$Version,
    [string]$Notes,
    [string]$SourceDir
)

$ErrorActionPreference = "Stop"
$rootDir = $PSScriptRoot

# Locate the addon folder (explicit -SourceDir, or the root subfolder with a matching .toc)
if ($SourceDir) {
    $addonDir = (Resolve-Path $SourceDir).Path
} else {
    $candidate = Get-ChildItem -Directory -Path $rootDir | Where-Object {
        Test-Path (Join-Path $_.FullName "$($_.Name).toc")
    } | Select-Object -First 1
    if (-not $candidate) {
        Write-Error "Could not find an addon subfolder with a matching .toc file."
    }
    $addonDir = $candidate.FullName
}
$addonName = Split-Path $addonDir -Leaf
$tocFile = Join-Path $addonDir "$addonName.toc"
if (-not (Test-Path $tocFile)) {
    Write-Error "Missing $addonName.toc in $addonDir"
}
$changelogFile = Join-Path $rootDir "CHANGELOG.md"

# Version: update the .toc when given, otherwise read it
if ($Version) {
    Write-Host "Updating version to $Version..." -ForegroundColor Cyan
    $toc = (Get-Content $tocFile) -replace '^## Version: .*$', "## Version: $Version"
    [System.IO.File]::WriteAllLines($tocFile, $toc)
} else {
    $tocContent = Get-Content $tocFile -Raw
    if ($tocContent -match '## Version:\s*([^\r\n]+)') {
        $Version = $matches[1].Trim()
    } else {
        Write-Error "No '## Version:' line in $tocFile"
    }
}

Write-Host "Packaging $addonName v$Version from $addonDir" -ForegroundColor Green

# Changelog: add an entry only when -Notes is given; otherwise just warn if the version is missing
if (Test-Path $changelogFile) {
    $changelog = Get-Content $changelogFile -Raw
    $escaped = [regex]::Escape($Version)
    if ($changelog -notmatch "## \[$escaped\]") {
        if ($Notes) {
            $dateStr = (Get-Date).ToString("yyyy-MM-dd")
            $entry = "## [$Version] - $dateStr`n`n### Changed`n- $Notes`n`n"
            $firstEntry = $changelog.IndexOf("## [")
            if ($firstEntry -ge 0) {
                $changelog = $changelog.Insert($firstEntry, $entry)
            } else {
                $changelog = $changelog.TrimEnd() + "`n`n" + $entry
            }
            [System.IO.File]::WriteAllText($changelogFile, $changelog)
            Write-Host "Recorded [$Version] in CHANGELOG.md" -ForegroundColor Yellow
        } else {
            Write-Warning "CHANGELOG.md has no [$Version] entry. Add one (or pass -Notes) before releasing."
        }
    }
} else {
    Write-Warning "No CHANGELOG.md found at the repository root."
}

# Stage a clean copy so the changelog can be added without touching the source folder
$stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("nqt-package-" + [guid]::NewGuid().ToString("N"))
$stageAddon = Join-Path $stageRoot $addonName
New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null
try {
    Copy-Item -Path $addonDir -Destination $stageAddon -Recurse
    if (Test-Path $changelogFile) {
        Copy-Item -Path $changelogFile -Destination (Join-Path $stageAddon "CHANGELOG.md") -Force
    }

    $zipsDir = Join-Path $rootDir "zips"
    if (-not (Test-Path $zipsDir)) {
        New-Item -ItemType Directory -Path $zipsDir -Force | Out-Null
    }
    $zipName = "$addonName $Version.zip"
    $zipPath = Join-Path $zipsDir $zipName

    Write-Host "Creating archive zips/$zipName..." -ForegroundColor Cyan
    Compress-Archive -Path $stageAddon -DestinationPath $zipPath -Force
} finally {
    Remove-Item -Path $stageRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Successfully packaged: zips/$zipName" -ForegroundColor Green
