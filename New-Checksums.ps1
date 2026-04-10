<#
.SYNOPSIS
    Generates SHA256 checksums for all tracked source and config files.

.DESCRIPTION
    Enumerates tracked .ps1 files and config files (configs/*.json) via
    git ls-files, excludes test files and this script itself, computes
    SHA256 hashes, and writes checksums.sha256 to the repo root in
    standard sha256sum format. Run this script and commit checksums.sha256
    before tagging any release.

.EXAMPLE
    .\New-Checksums.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = $PSScriptRoot

# Enumerate tracked files via git ls-files
$ps1Files    = @(& git -C $repoRoot ls-files "*.ps1")
$configFiles = @(& git -C $repoRoot ls-files "configs/*.json")
$allTracked  = @($ps1Files) + @($configFiles)

# Filter: exclude tests/ and New-Checksums.ps1 itself
$included = $allTracked | Where-Object {
    $_ -notmatch '^tests/' -and $_ -ne 'New-Checksums.ps1'
} | Sort-Object

$lines = @()
foreach ($relPath in $included) {
    $fullPath = Join-Path $repoRoot $relPath
    if (-not (Test-Path $fullPath)) {
        Write-Host "  Not found: $relPath" -ForegroundColor Red
        continue
    }

    $hash = (Get-FileHash -Path $fullPath -Algorithm SHA256).Hash.ToLower()
    # Use forward slashes for cross-platform compatibility
    $normalised = $relPath -replace '\\', '/'
    Write-Host "  $hash  $normalised" -ForegroundColor Green
    $lines += "$hash  $normalised"
}

$outPath = Join-Path $repoRoot 'checksums.sha256'
$lines | Set-Content -Path $outPath -Encoding UTF8

Write-Host ""
Write-Host "  $($lines.Count) files checksummed" -ForegroundColor Cyan
Write-Host "  Written to $outPath" -ForegroundColor Cyan
