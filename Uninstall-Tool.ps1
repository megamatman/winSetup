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

# Parse $PackageRegistry from Update-DevEnvironment.ps1 using regex extraction.
# No Invoke-Expression -- avoids executing file content as code.
$updateScript = Join-Path $PSScriptRoot 'Update-DevEnvironment.ps1'
$PackageRegistry = @{}
try {
    $content = Get-Content $updateScript -Raw
    # Match each entry: "key" = @{ Manager = "mgr"; Id = "id" }
    $pattern = '"([^"]+)"\s*=\s*@\{\s*Manager\s*=\s*"([^"]+)";\s*Id\s*=\s*"([^"]+)"\s*\}'
    $matches2 = [regex]::Matches($content, $pattern)
    foreach ($m in $matches2) {
        $PackageRegistry[$m.Groups[1].Value] = @{
            Manager = $m.Groups[2].Value
            Id      = $m.Groups[3].Value
        }
    }
}
catch {
    Write-Host "Failed to parse `$PackageRegistry from ${updateScript}: $_" -ForegroundColor Red
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

# Escape $Tool for use in regex patterns -- prevents regex injection if the
# tool name contains metacharacters like . * ? [ ] etc.
$entry = $PackageRegistry[$Tool]
$escapedTool = [regex]::Escape($Tool)
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
            'winget'  { winget uninstall --id $entry.Id --exact --silent --disable-interactivity }
            'pipx'    { pipx uninstall $entry.Id }
            'module'  {
                # Uninstall-Module is a PS cmdlet -- it does not set $LASTEXITCODE.
                # Success/failure is handled by the try/catch block.
                Uninstall-Module $entry.Id -Force -ErrorAction Stop
            }
            default   { Write-Host "  No uninstall handler for manager: $($entry.Manager)" -ForegroundColor Yellow }
        }
        # $LASTEXITCODE is only meaningful for external commands (choco/winget/pipx).
        # PS cmdlets (module) throw on failure instead.
        if ($entry.Manager -ne 'module') {
            Write-Host "  Exit code: $LASTEXITCODE" -ForegroundColor DarkGray
            $results['Uninstall'] = if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) { 'Done' } else { "Warning (exit $LASTEXITCODE)" }
        } else {
            $results['Uninstall'] = 'Done'
        }
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
    $content  = Get-Content $setupPath -Raw
    $safeName = ($Tool -replace '[^a-zA-Z0-9]', '')
    $funcName = "Install-$safeName"

    # Use the PowerShell AST to find the exact extent of the function.
    # This is correct even when braces appear inside string literals or
    # here-strings, which the previous brace-counting approach could miscount.
    $tokens = $null; $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput(
        $content, [ref]$tokens, [ref]$parseErrors)
    $funcAst = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq $funcName
    }, $true) | Select-Object -First 1

    $removed = $false
    if ($funcAst) {
        $start = $funcAst.Extent.StartOffset
        $end   = $funcAst.Extent.EndOffset

        # Strip one preceding newline to avoid leaving a double-blank gap
        if ($start -ge 2 -and $content.Substring($start - 2, 2) -eq "`r`n") {
            $start -= 2
        } elseif ($start -ge 1 -and $content[$start - 1] -eq "`n") {
            $start -= 1
        }

        $content = $content.Substring(0, $start) + $content.Substring($end)
        $removed = $true
    }

    # Remove the function call line from the main execution block.
    # Match only unindented calls (column 0) to avoid touching the
    # -InstallTool short-circuit block.
    $lines = $content -split "`r?`n"
    $newLines = @()
    foreach ($l in $lines) {
        if ($l -match "^Install-$safeName\s*$") { $removed = $true; continue }
        $newLines += $l
    }

    # Decrement $CoreSteps if we removed something
    if ($removed) {
        $newLines = $newLines | ForEach-Object {
            if ($_ -match '^\$CoreSteps\s*=\s*(\d+)') {
                $_ -replace '\d+', ([int]$Matches[1] - 1)
            } else { $_ }
        }
    }

    $newLines | Set-Content $setupPath -Encoding UTF8
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
    $newLines = $lines | Where-Object { $_ -notmatch "^\s*`"$escapedTool`"\s*=" }
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
        # Search for lines that are specifically about this tool.
        # Word-boundary assertions prevent "fd" matching inside "fd --type f"
        # (fzf config) or other unrelated lines containing the substring.
        $command = $entry.Id
        $escapedCommand = [regex]::Escape($command)
        $wordBoundaryTool = "(?<![a-zA-Z0-9_-])$escapedTool(?![a-zA-Z0-9_-])"
        $matchingLines = @($content | Where-Object {
            $_ -match "Set-Alias\s+\S+\s+$escapedTool" -or
            $_ -match "Set-Alias\s+\S+\s+$escapedCommand" -or
            ($_ -match $wordBoundaryTool -and $_ -notmatch '^\s*#' -and $_ -notmatch 'PackageRegistry' -and $_ -notmatch 'function\s')
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
        $newLines = $lines | Where-Object { $_ -notmatch "Name\s*=\s*'$escapedTool'" }
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
