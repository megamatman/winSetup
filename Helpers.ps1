# =============================================================================
# Shared Helper Functions
#
# All winSetup scripts dot-source this file for consistent output formatting,
# PATH management, and file backup. Do not define these functions elsewhere.
# =============================================================================

function Update-SessionPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    $userPath    = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    $registryPaths = "$machinePath;$userPath" -split ";" | Where-Object { $_ }
    $sessionPaths  = $env:PATH -split ";" | Where-Object { $_ }
    $merged = ($sessionPaths + $registryPaths | Select-Object -Unique) -join ";"
    $env:PATH = $merged
}

function Write-Step ($Name) {
    $script:CurrentStep++
    Write-Host "`n[$script:CurrentStep/$TotalSteps] $Name" -ForegroundColor Cyan
}

function Write-Skip ($Message, [string]$Track = "") {
    Write-Host "  $Message" -ForegroundColor DarkGray
    if ($Track -and (Get-Variable -Name "Skipped" -Scope Script -ErrorAction SilentlyContinue)) {
        $script:Skipped.Add($Track)
    }
}

function Write-Change ($Message, [string]$Track = "") {
    Write-Host "  $Message" -ForegroundColor Green
    if ($Track -and (Get-Variable -Name "Installed" -Scope Script -ErrorAction SilentlyContinue)) {
        $script:Installed.Add($Track)
    }
}

function Write-Issue ($Message, [string]$Track = "") {
    Write-Host "  $Message" -ForegroundColor Red
    if ($Track -and (Get-Variable -Name "Failed" -Scope Script -ErrorAction SilentlyContinue)) {
        $script:Failed.Add($Track)
    }
}

function Backup-FileIfExists ($Path) {
    if (Test-Path $Path) {
        $backup = "$Path.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $Path $backup
        Write-Change "Backed up existing file to $backup"
        Remove-OldBackups -SourceFile $Path -Keep 3
    }
}

function Remove-OldBackups {
    <#
    .SYNOPSIS
        Removes old .bak-* files, keeping only the most recent N per source file.
    .PARAMETER SourceFile
        The original file whose backups should be pruned.
    .PARAMETER Keep
        Number of most recent backups to retain. Default 3.
    #>
    param([string]$SourceFile, [int]$Keep = 3)
    $dir  = Split-Path $SourceFile
    $base = Split-Path $SourceFile -Leaf
    Get-ChildItem $dir -Filter "$base.bak-*" |
        Sort-Object Name -Descending |
        Select-Object -Skip $Keep |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

function Write-Summary {
    Write-Host "`n=== Setup Summary ===" -ForegroundColor Cyan
    if ($script:Installed.Count -gt 0) {
        Write-Host "  Installed  ($($script:Installed.Count)): $($script:Installed -join ', ')" -ForegroundColor Green
    }
    if ($script:Skipped.Count -gt 0) {
        Write-Host "  Skipped    ($($script:Skipped.Count)): $($script:Skipped -join ', ')" -ForegroundColor DarkGray
    }
    if ($script:Failed.Count -gt 0) {
        Write-Host "  Failed     ($($script:Failed.Count)): $($script:Failed -join ', ')" -ForegroundColor Red
        Write-Host "`n  Re-run the script to retry failed steps." -ForegroundColor Yellow
    } else {
        Write-Host "`n  All steps completed successfully." -ForegroundColor Green
    }
}
