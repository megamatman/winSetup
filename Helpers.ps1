# =============================================================================
# Shared Helper Functions
#
# All winSetup scripts dot-source this file for consistent output formatting,
# PATH management, and file backup. Do not define these functions elsewhere.
# =============================================================================

# When true, Write-Step/Change/Skip/Issue/Section emit Write-Output in
# addition to Write-Host so output is visible via Receive-Job in job context.
$script:JobMode = $false

function Update-SessionPath {
    <#
    .SYNOPSIS
        Merges Machine and User PATH into the current session.
    .DESCRIPTION
        Reads PATH from the registry (Machine + User) and merges with the
        current session PATH. Ensures newly installed tools are discoverable
        without restarting the terminal.
    #>
    $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    $userPath    = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    $registryPaths = "$machinePath;$userPath" -split ";" | Where-Object { $_ }
    $sessionPaths  = $env:PATH -split ";" | Where-Object { $_ }
    $merged = ($sessionPaths + $registryPaths | Select-Object -Unique) -join ";"
    $env:PATH = $merged
}

function Write-Step ($Name) {
    <#
    .SYNOPSIS
        Prints a numbered step header for the current operation.
    .DESCRIPTION
        Increments $script:CurrentStep and displays the step number against
        $TotalSteps. Used by Setup-DevEnvironment.ps1 to show progress.
    #>
    $script:CurrentStep++
    $text = "`n[$script:CurrentStep/$TotalSteps] $Name"
    Write-Host $text -ForegroundColor Cyan
    if ($script:JobMode) { Write-Output $text }
}

function Write-Section ($Name) {
    <#
    .SYNOPSIS
        Prints a section header for grouped output.
    .DESCRIPTION
        Displays a cyan section banner. Used by Update-DevEnvironment.ps1
        to separate output by package manager.
    #>
    $text = "`n=== $Name ==="
    Write-Host $text -ForegroundColor Cyan
    if ($script:JobMode) { Write-Output $text }
}

function Write-Skip ($Message, [string]$Track = "") {
    <#
    .SYNOPSIS
        Prints a skip message and optionally tracks the item.
    .DESCRIPTION
        Displays a dark gray message indicating an operation was skipped
        (e.g. tool already installed). Adds to $script:Skipped if -Track
        is provided and the tracking variable exists.
    #>
    Write-Host "  $Message" -ForegroundColor DarkGray
    if ($script:JobMode) { Write-Output "  $Message" }
    if ($Track -and (Get-Variable -Name "Skipped" -Scope Script -ErrorAction SilentlyContinue)) {
        $script:Skipped.Add($Track)
    }
}

function Write-Change ($Message, [string]$Track = "") {
    <#
    .SYNOPSIS
        Prints a success message and optionally tracks the item.
    .DESCRIPTION
        Displays a green message indicating a change was made (install,
        config update, etc.). Adds to $script:Installed if -Track is
        provided and the tracking variable exists.
    #>
    Write-Host "  $Message" -ForegroundColor Green
    if ($script:JobMode) { Write-Output "  $Message" }
    if ($Track -and (Get-Variable -Name "Installed" -Scope Script -ErrorAction SilentlyContinue)) {
        $script:Installed.Add($Track)
    }
}

function Write-Issue ($Message, [string]$Track = "") {
    <#
    .SYNOPSIS
        Prints an error message and optionally tracks the item.
    .DESCRIPTION
        Displays a red message indicating a failure. Adds to $script:Failed
        if -Track is provided and the tracking variable exists.
    #>
    Write-Host "  $Message" -ForegroundColor Red
    if ($script:JobMode) { Write-Output "  $Message" }
    if ($Track -and (Get-Variable -Name "Failed" -Scope Script -ErrorAction SilentlyContinue)) {
        $script:Failed.Add($Track)
    }
}

function Backup-FileIfExists ($Path) {
    <#
    .SYNOPSIS
        Creates a timestamped backup of a file if it exists.
    .DESCRIPTION
        Copies the file to <path>.bak-<yyyyMMdd-HHmmss> and prunes old
        backups, keeping the most recent 3.
    #>
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
    <#
    .SYNOPSIS
        Prints the setup outcome summary (installed, skipped, failed).
    .DESCRIPTION
        Reads from $script:Installed, $script:Skipped, and $script:Failed
        to produce a colour-coded summary at the end of a setup run.
    #>
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
