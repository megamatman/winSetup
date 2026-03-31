<#
.SYNOPSIS
    Updates all dev environment tools to their latest versions.

.DESCRIPTION
    Runs update commands for Chocolatey packages, winget packages, pipx tools,
    and PowerShell modules. Safe to re-run at any time.
    Per-repo tools (pre-commit hooks) must be updated manually per project.

.EXAMPLE
    .\Update-DevEnvironment.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
. "$PSScriptRoot\Helpers.ps1"

function Write-Section ($Name) {
    Write-Host "`n=== $Name ===" -ForegroundColor Cyan
}

# Check elevation for Chocolatey
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]$identity
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Not running as Administrator -- Chocolatey updates will be skipped." -ForegroundColor Yellow
    Write-Host "Re-run as Administrator to include Chocolatey updates." -ForegroundColor Yellow
}

Write-Host "`n=== Dev Environment Update ===" -ForegroundColor Cyan

# Chocolatey
Write-Section "Chocolatey packages"
if ($isAdmin -and (Get-Command choco -ErrorAction SilentlyContinue)) {
    try {
        choco upgrade all -y
        if ($LASTEXITCODE -ne 0) { Write-Issue "Chocolatey upgrade failed (exit code: $LASTEXITCODE)" } else { Write-Change "Chocolatey packages updated" }
    } catch {
        Write-Issue "Chocolatey upgrade failed -- $($_.Exception.Message)"
    }
} else {
    Write-Host "  Skipped (requires Administrator)" -ForegroundColor DarkGray
}

# winget
Write-Section "winget packages"
if (Get-Command winget -ErrorAction SilentlyContinue) {
    try {
        winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { Write-Issue "winget upgrade failed (exit code: $LASTEXITCODE)" } else { Write-Change "winget packages updated" }
    } catch {
        Write-Issue "winget upgrade failed -- $($_.Exception.Message)"
    }
} else {
    Write-Host "  winget not found -- skipping" -ForegroundColor DarkGray
}

# pipx
Write-Section "pipx tools"
if (Get-Command pipx -ErrorAction SilentlyContinue) {
    try {
        pipx upgrade-all
        Write-Change "pipx tools updated"
    } catch {
        Write-Issue "pipx upgrade-all failed -- $($_.Exception.Message)"
    }
} else {
    Write-Host "  pipx not found -- skipping" -ForegroundColor DarkGray
}

# PSFzf module
Write-Section "PowerShell modules"
try {
    Update-Module PSFzf -Force -ErrorAction SilentlyContinue
    Write-Change "PSFzf updated"
} catch {
    Write-Issue "PSFzf update failed -- $($_.Exception.Message)"
}

# pyenv
Write-Section "pyenv-win"
if (Get-Command pyenv -ErrorAction SilentlyContinue) {
    try {
        pyenv update
        Write-Change "pyenv-win updated"
    } catch {
        Write-Issue "pyenv update failed -- $($_.Exception.Message)"
    }
} else {
    Write-Host "  pyenv not found -- skipping" -ForegroundColor DarkGray
}

Write-Host "`n=== Update complete ===`n" -ForegroundColor Cyan
Write-Host "Note: pre-commit hook versions are per-repo. To update them:" -ForegroundColor DarkGray
Write-Host "  cd <your-project>" -ForegroundColor DarkGray
Write-Host "  pre-commit autoupdate" -ForegroundColor DarkGray
Write-Host "  ga .pre-commit-config.yaml" -ForegroundColor DarkGray
Write-Host "  gc 'Update pre-commit hooks'" -ForegroundColor DarkGray
