<#
.SYNOPSIS
    Updates all dev environment tools, or a single named package.

.DESCRIPTION
    Runs update commands for Chocolatey packages, winget packages, pipx tools,
    and PowerShell modules. Safe to re-run at any time.
    Per-repo tools (pre-commit hooks) must be updated manually per project.

.PARAMETER Package
    Name of a specific package to update. If omitted, all tools are updated.
    Run with an invalid name to see the list of available package names.

.EXAMPLE
    .\Update-DevEnvironment.ps1
    Update all tools.

.EXAMPLE
    .\Update-DevEnvironment.ps1 -Package ruff
    Update only ruff via pipx.

.PARAMETER NoWait
    Skip the interactive Wait-VSCodeClosed prompt. Instead, if VS Code is
    running, output a VSCODE_OPEN sentinel string and exit with code 0.
    Intended for job-based invocation from winTerface where Read-Host and
    Write-Host are not available.

.EXAMPLE
    .\Update-DevEnvironment.ps1 -Package lazygit
    Update only lazygit via Chocolatey.

.EXAMPLE
    .\Update-DevEnvironment.ps1 -NoWait
    Update all tools; exit immediately if VS Code is open.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Package,

    [switch]$NoWait
)

Set-StrictMode -Version Latest
. "$PSScriptRoot\Helpers.ps1"

# Transcript logging (matches Setup-DevEnvironment.ps1 and Uninstall-Tool.ps1)
$logsDir = Join-Path $PSScriptRoot 'logs'
if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }
$logFile = Join-Path $logsDir "update-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
Start-Transcript -Path $logFile -Force

# Check elevation for Chocolatey
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]$identity
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Package registry -- maps friendly names to their update method
$PackageRegistry = @{
    # Chocolatey packages
    "vscode"      = @{ Manager = "choco";  Id = "vscode" }
    "python"      = @{ Manager = "choco";  Id = "python" }
    "git"         = @{ Manager = "choco";  Id = "git" }
    "delta"       = @{ Manager = "choco";  Id = "delta" }
    "lazygit"     = @{ Manager = "choco";  Id = "lazygit" }
    "bat"         = @{ Manager = "choco";  Id = "bat" }
    "ripgrep"     = @{ Manager = "choco";  Id = "ripgrep" }
    "fd"          = @{ Manager = "choco";  Id = "fd" }
    "zoxide"      = @{ Manager = "choco";  Id = "zoxide" }
    # winget packages
    "fzf"         = @{ Manager = "winget"; Id = "junegunn.fzf" }
    "ohmyposh"    = @{ Manager = "winget"; Id = "JanDeDobbeleer.OhMyPosh" }
    "gh"          = @{ Manager = "winget"; Id = "GitHub.cli" }
    # pipx tools
    "ruff"        = @{ Manager = "pipx";   Id = "ruff" }
    "pylint"      = @{ Manager = "pipx";   Id = "pylint" }
    "mypy"        = @{ Manager = "pipx";   Id = "mypy" }
    "bandit"      = @{ Manager = "pipx";   Id = "bandit" }
    "pre-commit"  = @{ Manager = "pipx";   Id = "pre-commit" }
    "cookiecutter"= @{ Manager = "pipx";   Id = "cookiecutter" }
    # Special handlers
    "psfzf"       = @{ Manager = "module"; Id = "PSFzf" }
    "pyenv"       = @{ Manager = "pyenv";  Id = "pyenv-win" }
}

function Wait-VSCodeClosed {
    <#
    .SYNOPSIS
        Blocks execution until all VS Code processes are closed or a timeout expires.
    .DESCRIPTION
        VS Code extensions lock Python tool executables, causing pipx updates to fail.
        This function detects running VS Code instances and waits for the user to close
        them before allowing updates to proceed. Times out after 5 minutes and prompts
        the user to continue or cancel. Status messages use Write-Output so they are
        visible in Receive-Job output when invoked from a background job.
    #>
    $vscodeProcessNames = @("Code", "Code - Insiders")
    $timeoutSeconds = 300   # 5 minutes

    $running = Get-Process -Name $vscodeProcessNames -ErrorAction SilentlyContinue
    if (-not $running) { return }

    Write-Output ""
    Write-Output "  VS Code is currently running."
    Write-Output ""
    Write-Output "  Extensions such as Ruff and Pylint hold Python tool executables"
    Write-Output "  open. This causes pipx updates to fail with 'Access is denied'."
    Write-Output ""
    Write-Output "  Please close VS Code, then updates will continue automatically."
    Write-Output "  Timeout: $($timeoutSeconds / 60) minutes. Press Ctrl+C to cancel."
    Write-Output ""

    $dots = 0
    $elapsed = 0
    try {
        while ($true) {
            $running = Get-Process -Name $vscodeProcessNames -ErrorAction SilentlyContinue
            if (-not $running) { break }

            if ($elapsed -ge $timeoutSeconds) {
                Write-Host "`r                                                      " -NoNewline
                Write-Host ""
                Write-Issue "  Timed out waiting for VS Code to close."
                Write-Host ""
                Write-Host "  VS Code is still open. Continue anyway? [Y/N] " -ForegroundColor Yellow -NoNewline
                $answer = Read-Host
                if ($answer -match '^[Yy]') {
                    Write-Host "  Continuing with VS Code open. Some updates may fail." -ForegroundColor Yellow
                    Write-Host ""
                    return
                } else {
                    Write-Host "  Update cancelled." -ForegroundColor Yellow
                    exit 1
                }
            }

            $dots = ($dots % 3) + 1
            $remaining = [Math]::Max(0, $timeoutSeconds - $elapsed)
            $mins = [Math]::Floor($remaining / 60)
            $secs = $remaining % 60
            Write-Host "`r  Waiting for VS Code to close$('.' * $dots) (${mins}m ${secs}s remaining)   " -NoNewline -ForegroundColor DarkGray
            Start-Sleep -Seconds 3
            $elapsed += 3
        }
    } catch [System.Management.Automation.StopProcessingException] {
        Write-Host "`n`n  Update cancelled." -ForegroundColor Yellow
        exit 0
    }

    Write-Output "  VS Code closed. Proceeding with updates..."
    Write-Output ""
}

# =============================================================================
# Per-manager update helpers
#
# Each returns @{ Status = 'Updated'|'UpToDate'|'Failed'; Output = string; Detail = string }
# Callers handle Write-Change/Skip/Issue so display names and -Track values
# remain under their control.
# =============================================================================

function Invoke-ChocoUpdate {
    <#
    .SYNOPSIS
        Runs choco upgrade for a single package and interprets the result.
    .PARAMETER Id
        The Chocolatey package identifier.
    .OUTPUTS
        [hashtable] @{ Status; Output; Detail }
    #>
    param([string]$Id)

    $chocoOut = choco upgrade $Id -y 2>&1 |
        Where-Object { "$_" -notmatch 'Did you know|Enjoy using Chocolatey|chocolatey\.org/compare|licensed editions|Your support ensures|nets you some awesome' } |
        Out-String

    if ($chocoOut -match 'upgraded (\d+)/\d+ package') {
        if ([int]$Matches[1] -gt 0) {
            return @{ Status = 'Updated'; Output = $chocoOut; Detail = '' }
        } else {
            return @{ Status = 'UpToDate'; Output = $chocoOut; Detail = '' }
        }
    } elseif ($LASTEXITCODE -ne 0) {
        return @{ Status = 'Failed'; Output = $chocoOut; Detail = "exit $LASTEXITCODE" }
    } else {
        return @{ Status = 'Updated'; Output = $chocoOut; Detail = '' }
    }
}

function Invoke-WingetUpdate {
    <#
    .SYNOPSIS
        Runs winget upgrade for a single package and interprets the result.
    .PARAMETER Id
        The winget package identifier (used with --id --exact).
    .OUTPUTS
        [hashtable] @{ Status; Output; Detail }
    #>
    param([string]$Id)

    $wingetOut = winget upgrade --id $Id --exact --silent --disable-interactivity --accept-package-agreements --accept-source-agreements 2>&1 |
        Where-Object { "$_" -notmatch '^\s*[-\\|/]+\s*$' -and "$_" -notmatch '^\s*$' } |
        Out-String

    if ($LASTEXITCODE -eq 0) {
        return @{ Status = 'Updated'; Output = $wingetOut; Detail = '' }
    } elseif ($LASTEXITCODE -eq -1978335189 -or $wingetOut -match 'No newer package versions are available') {
        return @{ Status = 'UpToDate'; Output = $wingetOut; Detail = '' }
    } else {
        return @{ Status = 'Failed'; Output = $wingetOut; Detail = "exit $LASTEXITCODE" }
    }
}

function Invoke-PipxUpdate {
    <#
    .SYNOPSIS
        Runs pipx upgrade for a single package and interprets the result.
    .PARAMETER Id
        The pipx package identifier.
    .OUTPUTS
        [hashtable] @{ Status; Output; Detail }
    #>
    param([string]$Id)

    $pipxOut = pipx upgrade $Id 2>&1 | Out-String

    if ($pipxOut -match 'already at latest version') {
        return @{ Status = 'UpToDate'; Output = $pipxOut; Detail = '' }
    } elseif ($LASTEXITCODE -eq 0) {
        return @{ Status = 'Updated'; Output = $pipxOut; Detail = '' }
    } else {
        return @{ Status = 'Failed'; Output = $pipxOut; Detail = "exit $LASTEXITCODE" }
    }
}

function Invoke-ModuleUpdate {
    <#
    .SYNOPSIS
        Checks for a newer version of a PowerShell module and installs it if available.
    .PARAMETER Id
        The module name (e.g. PSFzf).
    .OUTPUTS
        [hashtable] @{ Status; Output; Detail }
        Status is 'Updated', 'UpToDate', 'Failed', or 'NotInstalled'.
    #>
    param([string]$Id)

    $installed = (Get-Module $Id -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
    if (-not $installed) {
        return @{ Status = 'NotInstalled'; Output = ''; Detail = '' }
    }
    try {
        $available = (Find-Module $Id -ErrorAction Stop).Version
        if ($installed -lt $available) {
            Install-Module $Id -Force -Scope CurrentUser
            return @{ Status = 'Updated'; Output = ''; Detail = "$available" }
        } else {
            return @{ Status = 'UpToDate'; Output = ''; Detail = "$installed" }
        }
    } catch {
        return @{ Status = 'Failed'; Output = ''; Detail = "$($_.Exception.Message)" }
    }
}

function Invoke-PyenvUpdate {
    <#
    .SYNOPSIS
        Updates pyenv-win via pip install --upgrade.
    .OUTPUTS
        [hashtable] @{ Status; Output; Detail }
    #>
    $result = pip install pyenv-win --upgrade --target "$env:USERPROFILE\.pyenv\pyenv-win" 2>&1
    if ($LASTEXITCODE -eq 0) {
        return @{ Status = 'Updated'; Output = ''; Detail = '' }
    } else {
        return @{ Status = 'Failed'; Output = ''; Detail = ($result | Select-Object -Last 3 | Out-String) }
    }
}

# =============================================================================
# Update orchestration
# =============================================================================

function Update-SinglePackage {
    <#
    .SYNOPSIS
        Updates a single package by name using its registered package manager.
    .DESCRIPTION
        Looks up the package in $PackageRegistry and runs the appropriate update
        command (choco, winget, pipx, module, or pyenv). Exits with an error if
        the package name is not recognized.
    #>
    param([string]$Name)

    $key = $Name.ToLower()
    if (-not $PackageRegistry.ContainsKey($key)) {
        Write-Output ""
        Write-Output "  Unknown package '$Name'."
        Write-Output ""
        Write-Output "  Available packages:"
        $PackageRegistry.Keys | Sort-Object | ForEach-Object {
            $entry = $PackageRegistry[$_]
            Write-Output ("    {0,-15} ({1})" -f $_, $entry.Manager)
        }
        Write-Output ""
        exit 1
    }

    $entry = $PackageRegistry[$key]
    Write-Output "`n  Updating $Name ($($entry.Manager))..."

    switch ($entry.Manager) {
        "choco" {
            if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
                Write-Issue "Chocolatey not found"
                return
            }
            if (-not $isAdmin) {
                Write-Output "  Chocolatey requires Administrator. Re-run as Administrator."
                return
            }
            $r = Invoke-ChocoUpdate -Id $entry.Id
            Write-Output $r.Output
            switch ($r.Status) {
                'Updated'  { Write-Change "$Name updated" }
                'UpToDate' { Write-Skip "$Name is already up to date" -Track $Name }
                'Failed'   { Write-Issue "$Name upgrade failed ($($r.Detail))" }
            }
        }
        "winget" {
            if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                Write-Issue "winget not found"
                return
            }
            $r = Invoke-WingetUpdate -Id $entry.Id
            Write-Output $r.Output
            switch ($r.Status) {
                'Updated'  { Write-Change "$Name updated" }
                'UpToDate' { Write-Skip "$Name is already up to date" -Track $Name }
                'Failed'   { Write-Issue "$Name upgrade failed ($($r.Detail))" }
            }
        }
        "pipx" {
            if (-not (Get-Command pipx -ErrorAction SilentlyContinue)) {
                Write-Issue "pipx not found"
                return
            }
            $r = Invoke-PipxUpdate -Id $entry.Id
            Write-Output $r.Output
            switch ($r.Status) {
                'Updated'  { Write-Change "$Name updated" }
                'UpToDate' { Write-Skip "$Name is already up to date" -Track $Name }
                'Failed'   { Write-Issue "$Name upgrade failed ($($r.Detail))" }
            }
        }
        "module" {
            $r = Invoke-ModuleUpdate -Id $entry.Id
            switch ($r.Status) {
                'Updated'       { Write-Change "$Name updated to $($r.Detail) -- restart terminal to apply" }
                'UpToDate'      { Write-Skip "$Name is already up to date ($($r.Detail))" -Track $Name }
                'NotInstalled'  { Write-Issue "$Name not installed" }
                'Failed'        { Write-Warning "Could not check for $Name updates (PSGallery unreachable?)" }
            }
        }
        "pyenv" {
            if (-not (Test-Path "$env:USERPROFILE\.pyenv")) {
                Write-Issue "pyenv-win not found"
                return
            }
            $r = Invoke-PyenvUpdate
            switch ($r.Status) {
                'Updated' { Write-Change "$Name updated" }
                'Failed'  { Write-Issue "$Name update failed" }
            }
        }
    }
}

function Update-All {
    <#
    .SYNOPSIS
        Updates all registered dev environment tools.
    .DESCRIPTION
        Iterates through every entry in $PackageRegistry grouped by package manager
        and runs the appropriate upgrade command. Skips Chocolatey if not running
        as Administrator.
    #>
    if (-not $isAdmin) {
        Write-Host "Not running as Administrator -- Chocolatey updates will be skipped." -ForegroundColor Yellow
        Write-Host "Re-run as Administrator to include Chocolatey updates." -ForegroundColor Yellow
    }

    # Update only tools registered in $PackageRegistry -- never system-wide.
    # Group by manager for cleaner output.
    $chocoTools  = $PackageRegistry.GetEnumerator() | Where-Object { $_.Value.Manager -eq 'choco' }
    $wingetTools = $PackageRegistry.GetEnumerator() | Where-Object { $_.Value.Manager -eq 'winget' }
    $pipxTools   = $PackageRegistry.GetEnumerator() | Where-Object { $_.Value.Manager -eq 'pipx' }

    # Chocolatey
    Write-Section "Chocolatey packages"
    if ($isAdmin -and (Get-Command choco -ErrorAction SilentlyContinue)) {
        foreach ($tool in $chocoTools) {
            try {
                $r = Invoke-ChocoUpdate -Id $tool.Value.Id
                Write-Host $r.Output
                switch ($r.Status) {
                    'Updated'  { Write-Change "$($tool.Key) updated" }
                    'UpToDate' { Write-Skip "$($tool.Key) is already up to date" -Track $tool.Key }
                    'Failed'   { Write-Issue "$($tool.Key) upgrade failed ($($r.Detail))" }
                }
            } catch {
                Write-Issue "$($tool.Key) upgrade failed -- $($_.Exception.Message)"
            }
        }
    } else {
        Write-Host "  Skipped (requires Administrator)" -ForegroundColor DarkGray
    }

    # winget
    Write-Section "winget packages"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        foreach ($tool in $wingetTools) {
            try {
                $r = Invoke-WingetUpdate -Id $tool.Value.Id
                Write-Host $r.Output
                switch ($r.Status) {
                    'Updated'  { Write-Change "$($tool.Key) updated" }
                    'UpToDate' { Write-Skip "$($tool.Key) is already up to date" -Track $tool.Key }
                    'Failed'   { Write-Issue "$($tool.Key) upgrade failed ($($r.Detail))" }
                }
            } catch {
                Write-Issue "$($tool.Key) upgrade failed -- $($_.Exception.Message)"
            }
        }
    } else {
        Write-Host "  winget not found -- skipping" -ForegroundColor DarkGray
    }

    # pipx
    Write-Section "pipx tools"
    if (Get-Command pipx -ErrorAction SilentlyContinue) {
        foreach ($tool in $pipxTools) {
            try {
                $r = Invoke-PipxUpdate -Id $tool.Value.Id
                Write-Host $r.Output
                switch ($r.Status) {
                    'Updated'  { Write-Change "$($tool.Key) updated" }
                    'UpToDate' { Write-Skip "$($tool.Key) is already up to date" -Track $tool.Key }
                    'Failed'   { Write-Issue "$($tool.Key) upgrade failed ($($r.Detail))" }
                }
            } catch {
                Write-Issue "$($tool.Key) upgrade failed -- $($_.Exception.Message)"
            }
        }
    } else {
        Write-Host "  pipx not found -- skipping" -ForegroundColor DarkGray
    }

    # PSFzf module
    Write-Section "PowerShell modules"
    $r = Invoke-ModuleUpdate -Id 'PSFzf'
    switch ($r.Status) {
        'Updated'       { Write-Change "PSFzf updated to $($r.Detail) -- restart terminal to apply" }
        'UpToDate'      { Write-Skip "PSFzf is already up to date ($($r.Detail))" -Track "PSFzf" }
        'NotInstalled'  { Write-Host "  PSFzf not installed -- skipping" -ForegroundColor DarkGray }
        'Failed'        { Write-Warning "Could not check for PSFzf updates (PSGallery unreachable?)" }
    }

    # pyenv-win
    Write-Section "pyenv-win"
    if (Test-Path "$env:USERPROFILE\.pyenv") {
        try {
            # pyenv's built-in 'pyenv update' uses a VBScript with an ActiveX
            # HTML component that fails on modern Windows 11. Update via pip instead.
            $r = Invoke-PyenvUpdate
            switch ($r.Status) {
                'Updated' { Write-Change "pyenv-win updated" }
                'Failed'  { Write-Issue "pyenv-win update failed -- $($r.Detail)" }
            }
        } catch {
            Write-Issue "pyenv-win update failed -- $($_.Exception.Message)"
        }
    } else {
        Write-Host "  pyenv-win not found -- skipping" -ForegroundColor DarkGray
    }

    Write-Host "`n=== Update complete ===`n" -ForegroundColor Cyan
    Write-Host "Note: pre-commit hook versions are per-repo. To update them:" -ForegroundColor DarkGray
    Write-Host "  cd <your-project>" -ForegroundColor DarkGray
    Write-Host "  pre-commit autoupdate" -ForegroundColor DarkGray
    Write-Host "  ga .pre-commit-config.yaml" -ForegroundColor DarkGray
    Write-Host "  gc 'Update pre-commit hooks'" -ForegroundColor DarkGray
}

# Main execution
Write-Host "`n=== Dev Environment Update ===" -ForegroundColor Cyan

# Pre-flight: warn about spaces in the user profile path. pipx does not
# support spaces in PIPX_HOME on Windows and will fail to update .exe files.
if ($env:USERPROFILE -match ' ') {
    Write-Host ""
    Write-Host "  Warning: Your profile path contains a space ('$env:USERPROFILE')." -ForegroundColor Yellow
    Write-Host "  If you have not already migrated pipx to C:\pipx, tools may not update" -ForegroundColor Yellow
    Write-Host "  correctly. See TROUBLESHOOTING.md -- 'pipx space in home path' for steps." -ForegroundColor Yellow
    Write-Host "  If you have already migrated pipx, this warning can be ignored." -ForegroundColor DarkGray
    Write-Host ""
}

if ($NoWait) {
    # Job-safe VS Code check: no Read-Host, no Write-Host, just a sentinel
    # string that the caller (winTerface) can detect via Receive-Job.
    $vscodeRunning = Get-Process -Name @("Code", "Code - Insiders") -ErrorAction SilentlyContinue
    if ($vscodeRunning) {
        Write-Output "VSCODE_OPEN: Close VS Code and retry the update."
        Stop-Transcript
        exit 0
    }
} else {
    Wait-VSCodeClosed
}

try {
    if ($Package) {
        Update-SinglePackage -Name $Package
    } else {
        Update-All
    }
} finally {
    Write-Host "`nTranscript: $logFile" -ForegroundColor DarkGray
    Stop-Transcript
}
