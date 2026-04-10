<#
.SYNOPSIS
    Generates SHA256 checksums for user-facing scripts.

.DESCRIPTION
    Computes SHA256 hashes for bootstrap.ps1, Setup-DevEnvironment.ps1,
    and Install-WinTerface.ps1, writing the results to checksums.sha256
    in the winSetup repo root. Run this script and commit checksums.sha256
    before tagging any release.

    Install-WinTerface.ps1 is located via $env:WINTERFACE. If that
    variable is not set, the script prompts for the winTerface repo path.

.EXAMPLE
    .\New-Checksums.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Locate winTerface repo
$winterfacePath = $env:WINTERFACE
if (-not $winterfacePath -or -not (Test-Path $winterfacePath)) {
    $winterfacePath = Read-Host "Path to winTerface repo"
}

$installWinTerface = Join-Path $winterfacePath 'Install-WinTerface.ps1'
if (-not (Test-Path $installWinTerface)) {
    Write-Host "Install-WinTerface.ps1 not found at $installWinTerface" -ForegroundColor Red
    exit 1
}

$scripts = @(
    @{ Path = Join-Path $PSScriptRoot 'bootstrap.ps1';              Name = 'bootstrap.ps1' }
    @{ Path = Join-Path $PSScriptRoot 'Setup-DevEnvironment.ps1';   Name = 'Setup-DevEnvironment.ps1' }
    @{ Path = $installWinTerface;                                    Name = 'Install-WinTerface.ps1' }
)

$lines = @()
foreach ($script in $scripts) {
    if (-not (Test-Path $script.Path)) {
        Write-Host "  Not found: $($script.Path)" -ForegroundColor Red
        exit 1
    }

    $hash = (Get-FileHash -Path $script.Path -Algorithm SHA256).Hash.ToLower()
    Write-Host "  $hash  $($script.Name)" -ForegroundColor Green
    $lines += "$hash  $($script.Name)"
}

$outPath = Join-Path $PSScriptRoot 'checksums.sha256'
$lines | Set-Content -Path $outPath -Encoding UTF8
Write-Host ""
Write-Host "  Written to $outPath" -ForegroundColor Cyan
