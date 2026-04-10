<#
.SYNOPSIS
    One-line bootstrap for winSetup on a fresh machine.

.DESCRIPTION
    Handles PowerShell 7 verification, git installation (via winget if
    needed), repository cloning, WINSETUP environment variable setup, and
    optional hand-off to Setup-DevEnvironment.ps1. Runs without admin
    rights. The full setup script requests elevation if needed.

    Usage:
      irm "https://raw.githubusercontent.com/megamatman/winSetup/main/bootstrap.ps1" | iex

    Or clone the repo first and run:
      .\bootstrap.ps1

.PARAMETER InstallPath
    Directory where winSetup should be cloned. Defaults to
    $env:USERPROFILE\winSetup.

.PARAMETER RunSetup
    Skip the interactive prompt and run Setup-DevEnvironment.ps1
    immediately after cloning. Pass $false to skip.

.EXAMPLE
    .\bootstrap.ps1

.EXAMPLE
    .\bootstrap.ps1 -InstallPath "D:\Tools\winSetup"

.EXAMPLE
    .\bootstrap.ps1 -RunSetup:$false
#>

[CmdletBinding()]
param(
    [string]$InstallPath,
    [Nullable[bool]]$RunSetup
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# Security notice (before any action)
# ============================================================================

Write-Host ""
Write-Host "=== winSetup Bootstrap ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "  This script will:" -ForegroundColor Yellow
Write-Host "    1. Install git via winget if not already present"
Write-Host "    2. Clone https://github.com/megamatman/winSetup.git"
Write-Host "    3. Set the WINSETUP environment variable"
Write-Host "    4. Optionally run Setup-DevEnvironment.ps1"
Write-Host ""
Write-Host "  Review the source before running:" -ForegroundColor Yellow
Write-Host "    https://github.com/megamatman/winSetup/blob/main/bootstrap.ps1"
Write-Host ""

$response = Read-Host "  Continue? [Y/n]"
if ($response -and $response -notin @('y', 'Y', 'yes', 'Yes', '')) {
    Write-Host "  Cancelled." -ForegroundColor DarkGray
    exit 0
}

# ============================================================================
# Step 1: PowerShell version check
# ============================================================================

Write-Host ""
Write-Host "[1/4] PowerShell version" -ForegroundColor Cyan

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "  winSetup requires PowerShell 7+." -ForegroundColor Red
    Write-Host "  Current version: $($PSVersionTable.PSVersion)" -ForegroundColor Red
    Write-Host "  Download: https://aka.ms/powershell" -ForegroundColor Yellow
    exit 1
}

Write-Host "  PowerShell $($PSVersionTable.PSVersion) -- OK" -ForegroundColor Green

# ============================================================================
# Step 2: Git check and install
# ============================================================================

Write-Host ""
Write-Host "[2/4] Git" -ForegroundColor Cyan

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "  git not found. Attempting install via winget..." -ForegroundColor Yellow

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "  winget is not available. Install git manually:" -ForegroundColor Red
        Write-Host "    https://git-scm.com/downloads/win" -ForegroundColor Yellow
        Write-Host "  Then re-run this script." -ForegroundColor Yellow
        exit 1
    }

    & winget install Git.Git --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  winget install Git.Git failed (exit code $LASTEXITCODE)." -ForegroundColor Red
        Write-Host "  Install git manually: https://git-scm.com/downloads/win" -ForegroundColor Yellow
        exit 1
    }

    # Refresh PATH so git is discoverable
    $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') +
                ';' +
                [System.Environment]::GetEnvironmentVariable('PATH', 'User') +
                ';' +
                $env:PATH

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "  git installed but not on PATH. Restart your terminal and re-run." -ForegroundColor Red
        exit 1
    }

    Write-Host "  git installed" -ForegroundColor Green
} else {
    Write-Host "  git found -- OK" -ForegroundColor Green
}

# ============================================================================
# Step 3: Clone repository
# ============================================================================

Write-Host ""
Write-Host "[3/4] Clone winSetup" -ForegroundColor Cyan

# Check for existing installation
$existingPath = $null
if ($env:WINSETUP -and (Test-Path $env:WINSETUP)) {
    $existingPath = $env:WINSETUP
} else {
    $candidates = @(
        (Join-Path $env:USERPROFILE 'winSetup')
        (Join-Path $env:USERPROFILE 'Documents\winSetup')
    )
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c 'Setup-DevEnvironment.ps1')) {
            $existingPath = $c
            break
        }
    }
}

if ($existingPath) {
    Write-Host "  winSetup already present at: $existingPath" -ForegroundColor DarkGray
    $clonePath = $existingPath
} else {
    # Determine install path
    $defaultPath = Join-Path $env:USERPROFILE 'winSetup'
    if ($InstallPath) {
        $clonePath = $InstallPath
    } else {
        $input = Read-Host "  Install location [$defaultPath]"
        $clonePath = if ($input) { $input } else { $defaultPath }
    }

    Write-Host "  Cloning to $clonePath..." -ForegroundColor Yellow
    & git clone https://github.com/megamatman/winSetup.git $clonePath 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  git clone failed (exit code $LASTEXITCODE)." -ForegroundColor Red
        Write-Host "  Check your network connection and try again." -ForegroundColor Yellow
        exit 1
    }

    Write-Host "  Cloned successfully" -ForegroundColor Green
}

# ============================================================================
# Step 4: Set WINSETUP and hand off
# ============================================================================

Write-Host ""
Write-Host "[4/4] Environment setup" -ForegroundColor Cyan

[System.Environment]::SetEnvironmentVariable('WINSETUP', $clonePath, 'User')
$env:WINSETUP = $clonePath
Write-Host "  WINSETUP set to: $clonePath" -ForegroundColor Green

# Dot-source Helpers.ps1 now that it is available
$helpersPath = Join-Path $clonePath 'Helpers.ps1'
if (Test-Path $helpersPath) {
    . $helpersPath
}

Write-Host ""
Write-Host "=== winSetup is ready ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Repository: $clonePath" -ForegroundColor DarkGray
Write-Host "  WINSETUP:   $env:WINSETUP" -ForegroundColor DarkGray
Write-Host ""

# Hand-off decision
$setupScript = Join-Path $clonePath 'Setup-DevEnvironment.ps1'

if ($null -ne $RunSetup) {
    $doSetup = $RunSetup
} else {
    $answer = Read-Host "  Run Setup-DevEnvironment.ps1 now? [Y/n]"
    $doSetup = (-not $answer) -or ($answer -in @('y', 'Y', 'yes', 'Yes'))
}

if ($doSetup) {
    Write-Host ""
    & $setupScript @args
} else {
    Write-Host "  To run setup later:" -ForegroundColor Yellow
    Write-Host "    cd `"$clonePath`"" -ForegroundColor Yellow
    Write-Host "    .\Setup-DevEnvironment.ps1" -ForegroundColor Yellow
    Write-Host ""
}
