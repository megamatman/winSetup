<#
.SYNOPSIS
    Uninstalls a tool from the machine and removes it from winSetup management.

.DESCRIPTION
    Removes a tool in five steps:
    1. Uninstalls via the appropriate package manager (choco/winget/pipx)
    2. Removes the install function from Setup-DevEnvironment.ps1
    3. Removes the entry from $PackageRegistry in Update-DevEnvironment.ps1
    4. Removes the alias or config block from profile.ps1 if one exists
    5. Removes the entry from $script:KnownTools in winTerface WinSetup.ps1
       (if $env:WINTERFACE is set)

    All steps are logged. A full transcript is written to the logs/ directory.
    Use -KeepFiles to skip step 1 (remove from management only, keep installed).

.PARAMETER Tool
    The friendly name of the tool as it appears in $PackageRegistry.

.PARAMETER KeepFiles
    Skip the package manager uninstall. Removes the tool from winSetup
    management only. The binary remains installed on the machine.

.EXAMPLE
    .\Uninstall-Tool.ps1 -Tool ruff

.EXAMPLE
    .\Uninstall-Tool.ps1 -Tool lazygit -KeepFiles
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Tool,

    [switch]$KeepFiles
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

# Dot-source helpers
. "$PSScriptRoot\Helpers.ps1"

# Ensure logs directory exists
$logsDir = Join-Path $PSScriptRoot 'logs'
if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logFile   = Join-Path $logsDir "uninstall-$Tool-$timestamp.txt"
Start-Transcript -Path $logFile -Force

# Read the package registry by extracting just the $PackageRegistry = @{ ... }
# block from Update-DevEnvironment.ps1 and evaluating it.
$updateScript = Join-Path $PSScriptRoot 'Update-DevEnvironment.ps1'
$PackageRegistry = $null
try {
    $inReg = $false; $regLines = @()
    foreach ($line in (Get-Content $updateScript)) {
        if ($line -match '^\$PackageRegistry\s*=') { $inReg = $true; $regLines = @() }
        if ($inReg) { $regLines += $line }
        if ($inReg -and $line -match '^\}') { $inReg = $false; break }
    }
    if ($regLines) {
        $PackageRegistry = Invoke-Expression ($regLines -join "`n")
    }
}
catch {
    Write-Host "Failed to parse `$PackageRegistry from $updateScript`: $_" -ForegroundColor Red
}

if (-not $PackageRegistry -or -not $PackageRegistry.ContainsKey($Tool)) {
    Write-Host "`nTool '$Tool' not found in `$PackageRegistry." -ForegroundColor Red
    Write-Host "`nAvailable tools:" -ForegroundColor Yellow
    if ($PackageRegistry) {
        $PackageRegistry.Keys | Sort-Object | ForEach-Object { Write-Host "  $_" }
    }
    Stop-Transcript
    exit 1
}

$entry = $PackageRegistry[$Tool]
Write-Host "`n=== Uninstalling: $Tool ===" -ForegroundColor Cyan
Write-Host "  Manager: $($entry.Manager)"
Write-Host "  Package: $($entry.Id)"
if ($KeepFiles) { Write-Host "  Mode:    Remove from management only (keep installed)" -ForegroundColor Yellow }

$results = [ordered]@{}

# ---------------------------------------------------------------------------
# Step 1 -- Package manager uninstall
# ---------------------------------------------------------------------------

if ($KeepFiles) {
    Write-Host "`n[1/5] Package uninstall -- SKIPPED (-KeepFiles)" -ForegroundColor DarkGray
    $results['Uninstall'] = 'Skipped'
} else {
    Write-Host "`n[1/5] Package uninstall" -ForegroundColor Cyan
    try {
        switch ($entry.Manager) {
            'choco' {
                $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
                $principal = [Security.Principal.WindowsPrincipal]$identity
                if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                    Write-Host "  WARNING: Chocolatey uninstall may require Administrator." -ForegroundColor Yellow
                }
                choco uninstall $entry.Id -y
            }
            'winget'  { winget uninstall $entry.Id --silent }
            'pipx'    { pipx uninstall $entry.Id }
            'module'  { Uninstall-Module $entry.Id -Force -ErrorAction SilentlyContinue }
            default   { Write-Host "  No uninstall handler for manager: $($entry.Manager)" -ForegroundColor Yellow }
        }
        Write-Host "  Exit code: $LASTEXITCODE" -ForegroundColor DarkGray
        $results['Uninstall'] = if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) { 'Done' } else { "Warning (exit $LASTEXITCODE)" }
    }
    catch {
        Write-Host "  Uninstall failed: $_" -ForegroundColor Red
        $results['Uninstall'] = 'Failed'
    }
}

# ---------------------------------------------------------------------------
# Step 2 -- Remove from Setup-DevEnvironment.ps1
# ---------------------------------------------------------------------------

Write-Host "`n[2/5] Remove from Setup-DevEnvironment.ps1" -ForegroundColor Cyan
$setupPath = Join-Path $PSScriptRoot 'Setup-DevEnvironment.ps1'
try {
    Backup-FileIfExists $setupPath
    $lines = Get-Content $setupPath
    $safeName = ($Tool -replace '[^a-zA-Z0-9]', '')
    $funcPattern = "function Install-$safeName"

    # Find and remove function block
    $newLines = [System.Collections.Generic.List[string]]::new()
    $inFunc = $false; $braceDepth = 0; $removed = $false
    foreach ($l in $lines) {
        if (-not $inFunc -and $l -match "^\s*function\s+Install-$safeName\s*\{") {
            $inFunc = $true; $braceDepth = 1; $removed = $true; continue
        }
        if ($inFunc) {
            $braceDepth += ($l.ToCharArray() | Where-Object { $_ -eq '{' }).Count
            $braceDepth -= ($l.ToCharArray() | Where-Object { $_ -eq '}' }).Count
            if ($braceDepth -le 0) { $inFunc = $false }
            continue
        }
        # Remove the function call line
        if ($l -match "^\s*Install-$safeName\s*$") { $removed = $true; continue }
        $newLines.Add($l)
    }

    # Decrement $CoreSteps
    $finalLines = [System.Collections.Generic.List[string]]::new()
    foreach ($l in $newLines) {
        if ($removed -and $l -match '^\$CoreSteps\s*=\s*(\d+)') {
            $newCount = [int]$Matches[1] - 1
            $finalLines.Add($l -replace '\d+', "$newCount")
        } else {
            $finalLines.Add($l)
        }
    }

    $finalLines | Set-Content $setupPath -Encoding UTF8
    Write-Host "  Removed Install-$safeName function and call" -ForegroundColor Green
    $results['Setup-DevEnvironment'] = 'Done'
}
catch {
    Write-Host "  Failed: $_" -ForegroundColor Red
    $results['Setup-DevEnvironment'] = 'Failed'
}

# ---------------------------------------------------------------------------
# Step 3 -- Remove from Update-DevEnvironment.ps1
# ---------------------------------------------------------------------------

Write-Host "`n[3/5] Remove from Update-DevEnvironment.ps1" -ForegroundColor Cyan
try {
    Backup-FileIfExists $updateScript
    $lines = Get-Content $updateScript
    $newLines = $lines | Where-Object { $_ -notmatch "^\s*`"$Tool`"\s*=" }
    $newLines | Set-Content $updateScript -Encoding UTF8
    Write-Host "  Removed '$Tool' from `$PackageRegistry" -ForegroundColor Green
    $results['Update-DevEnvironment'] = 'Done'
}
catch {
    Write-Host "  Failed: $_" -ForegroundColor Red
    $results['Update-DevEnvironment'] = 'Failed'
}

# ---------------------------------------------------------------------------
# Step 4 -- Remove from profile.ps1
# ---------------------------------------------------------------------------

Write-Host "`n[4/5] Remove from profile.ps1" -ForegroundColor Cyan
$profilePath = Join-Path $PSScriptRoot 'profile.ps1'
try {
    if (Test-Path $profilePath) {
        $content = Get-Content $profilePath
        # Search for lines mentioning the tool's command or name
        $command = $entry.Id
        $matchingLines = @($content | Where-Object {
            $_ -match "Set-Alias\s+\S+\s+$Tool" -or
            $_ -match "Set-Alias\s+\S+\s+$command" -or
            ($_ -match $Tool -and $_ -notmatch '^\s*#' -and $_ -notmatch 'PackageRegistry')
        })

        if ($matchingLines.Count -gt 0) {
            Write-Host "  Found profile entries:" -ForegroundColor Yellow
            $matchingLines | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

            Backup-FileIfExists $profilePath
            $newContent = $content | Where-Object { $_ -notin $matchingLines }
            $newContent | Set-Content $profilePath -Encoding UTF8
            Write-Host "  Removed $($matchingLines.Count) line(s)" -ForegroundColor Green
            $results['profile.ps1'] = 'Done'
        } else {
            Write-Host "  No profile entries found for $Tool -- skipping" -ForegroundColor DarkGray
            $results['profile.ps1'] = 'Skipped (nothing found)'
        }
    } else {
        Write-Host "  profile.ps1 not found -- skipping" -ForegroundColor DarkGray
        $results['profile.ps1'] = 'Skipped (file missing)'
    }
}
catch {
    Write-Host "  Failed: $_" -ForegroundColor Red
    $results['profile.ps1'] = 'Failed'
}

# ---------------------------------------------------------------------------
# Step 5 -- Remove from winTerface WinSetup.ps1 (if WINTERFACE is set)
# ---------------------------------------------------------------------------

Write-Host "`n[5/5] Remove from winTerface WinSetup.ps1" -ForegroundColor Cyan
$wtWinSetup = if ($env:WINTERFACE) { Join-Path $env:WINTERFACE 'src' 'Services' 'WinSetup.ps1' } else { $null }

if (-not $env:WINTERFACE) {
    Write-Host "  WINTERFACE not set -- skipping WinSetup.ps1 update." -ForegroundColor Yellow
    Write-Host "  Update `$script:KnownTools manually." -ForegroundColor Yellow
    $results['winTerface'] = 'Skipped (WINTERFACE not set)'
} elseif (-not (Test-Path $wtWinSetup)) {
    Write-Host "  WinSetup.ps1 not found at $wtWinSetup -- skipping" -ForegroundColor Yellow
    $results['winTerface'] = 'Skipped (file missing)'
} else {
    try {
        Backup-FileIfExists $wtWinSetup
        $lines = Get-Content $wtWinSetup
        # Remove the @{ Name = '<Tool>'; ... } line from $script:KnownTools
        $newLines = $lines | Where-Object { $_ -notmatch "Name\s*=\s*'$Tool'" }
        $newLines | Set-Content $wtWinSetup -Encoding UTF8
        Write-Host "  Removed '$Tool' from `$script:KnownTools" -ForegroundColor Green
        $results['winTerface'] = 'Done'
    }
    catch {
        Write-Host "  Failed: $_" -ForegroundColor Red
        $results['winTerface'] = 'Failed'
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Host "`n=== Uninstall Summary: $Tool ===" -ForegroundColor Cyan
foreach ($step in $results.GetEnumerator()) {
    $color = switch -Wildcard ($step.Value) {
        'Done'      { 'Green' }
        'Skipped*'  { 'DarkGray' }
        default     { 'Yellow' }
    }
    Write-Host "  $($step.Key.PadRight(25)) $($step.Value)" -ForegroundColor $color
}

Write-Host "`nTranscript: $logFile" -ForegroundColor DarkGray
Write-Host "Reload your profile: . `$PROFILE`n" -ForegroundColor Yellow
Stop-Transcript
