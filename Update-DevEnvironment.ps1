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

function Wait-VSCodeClosed {
    <#
    .SYNOPSIS
        Waits for VS Code to be closed before proceeding.
    .DESCRIPTION
        Detects running VS Code processes and halts execution until they are
        closed. This prevents pipx update failures caused by VS Code extensions
        holding Python tool executables open during upgrades.
    #>
    $vscodeProcessNames = @("Code", "Code - Insiders")

    $running = Get-Process -Name $vscodeProcessNames -ErrorAction SilentlyContinue
    if (-not $running) { return }

    Write-Host ""
    Write-Host "  VS Code is currently running." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Extensions such as Ruff and Pylint hold Python tool executables" -ForegroundColor Yellow
    Write-Host "  open. This causes pipx updates to fail with 'Access is denied'." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Please close VS Code, then updates will continue automatically." -ForegroundColor Yellow
    Write-Host "  Press Ctrl+C to cancel." -ForegroundColor DarkGray
    Write-Host ""

    $dots = 0
    try {
        while ($true) {
            $running = Get-Process -Name $vscodeProcessNames -ErrorAction SilentlyContinue
            if (-not $running) { break }

            $dots = ($dots % 3) + 1
            Write-Host "`r  Waiting for VS Code to close$('.' * $dots)   " -NoNewline -ForegroundColor DarkGray
            Start-Sleep -Seconds 3
        }
    } catch [System.Management.Automation.StopProcessingException] {
        Write-Host "`n`n  Update cancelled." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "`r  VS Code closed. Proceeding with updates...          " -ForegroundColor Green
    Write-Host ""
}

Write-Host "`n=== Dev Environment Update ===" -ForegroundColor Cyan

Wait-VSCodeClosed

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
    # Run in a child process with -NoProfile so PSFzf is not loaded
    # in the current session and its files are not locked
    $result = pwsh -NoProfile -NonInteractive -Command "
        Update-Module PSFzf -Force -ErrorAction Stop
        Write-Output 'SUCCESS'
    " 2>&1

    if ($result -contains 'SUCCESS') {
        Write-Change "PSFzf updated"
    } elseif ($result -match "is not installed") {
        Write-Host "  PSFzf not installed -- skipping" -ForegroundColor DarkGray
    } else {
        Write-Change "PSFzf update attempted -- restart terminal to apply"
    }
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
