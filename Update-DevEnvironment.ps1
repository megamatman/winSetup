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

.EXAMPLE
    .\Update-DevEnvironment.ps1 -Package lazygit
    Update only lazygit via Chocolatey.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Package
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
        Blocks execution until all VS Code processes are closed.
    .DESCRIPTION
        VS Code extensions lock Python tool executables, causing pipx updates to fail.
        This function detects running VS Code instances and waits for the user to close
        them before allowing updates to proceed.
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
        Write-Host ""
        Write-Host "  Unknown package '$Name'." -ForegroundColor Red
        Write-Host ""
        Write-Host "  Available packages:" -ForegroundColor DarkGray
        $PackageRegistry.Keys | Sort-Object | ForEach-Object {
            $entry = $PackageRegistry[$_]
            Write-Host ("    {0,-15} ({1})" -f $_, $entry.Manager) -ForegroundColor DarkGray
        }
        Write-Host ""
        exit 1
    }

    $entry = $PackageRegistry[$key]
    Write-Host "`n  Updating $Name ($($entry.Manager))..." -ForegroundColor Cyan

    switch ($entry.Manager) {
        "choco" {
            if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
                Write-Issue "Chocolatey not found"
                return
            }
            if (-not $isAdmin) {
                Write-Host "  Chocolatey requires Administrator. Re-run as Administrator." -ForegroundColor Yellow
                return
            }
            # Parse choco output to distinguish "upgraded 0/N" (already current)
            # from "upgraded N/N" (actually updated). Filter promotional noise.
            $chocoOut = choco upgrade $entry.Id -y 2>&1 |
                Where-Object { "$_" -notmatch 'Did you know|Enjoy using Chocolatey|chocolatey\.org/compare|licensed editions|Your support ensures|nets you some awesome' } |
                Out-String
            Write-Host $chocoOut
            if ($chocoOut -match 'upgraded (\d+)/\d+ package') {
                $upgraded = [int]$Matches[1]
                if ($upgraded -gt 0) { Write-Change "$Name updated" }
                else { Write-Skip "$Name is already up to date" -Track $Name }
            } elseif ($LASTEXITCODE -ne 0) {
                Write-Issue "$Name upgrade failed (exit $LASTEXITCODE)"
            } else {
                Write-Change "$Name updated"
            }
        }
        "winget" {
            if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                Write-Issue "winget not found"
                return
            }
            # winget returns -1978335189 (0x8A15002B) when no update is available.
            # This is a success state, not a failure.
            # Filter spinner/progress lines that survive --silent --disable-interactivity
            $wingetOut = winget upgrade --id $entry.Id --exact --silent --disable-interactivity --accept-package-agreements --accept-source-agreements 2>&1 |
                Where-Object { "$_" -notmatch '^\s*[-\\|/]+\s*$' -and "$_" -notmatch '^\s*$' } |
                Out-String
            Write-Host $wingetOut
            if ($LASTEXITCODE -eq 0) {
                Write-Change "$Name updated"
            } elseif ($LASTEXITCODE -eq -1978335189 -or $wingetOut -match 'No newer package versions are available') {
                Write-Skip "$Name is already up to date" -Track $Name
            } else {
                Write-Issue "$Name upgrade failed (exit $LASTEXITCODE)"
            }
        }
        "pipx" {
            if (-not (Get-Command pipx -ErrorAction SilentlyContinue)) {
                Write-Issue "pipx not found"
                return
            }
            $pipxOut = pipx upgrade $entry.Id 2>&1 | Out-String
            Write-Host $pipxOut
            if ($pipxOut -match 'already at latest version') {
                Write-Skip "$Name is already up to date" -Track $Name
            } elseif ($LASTEXITCODE -eq 0) {
                Write-Change "$Name updated"
            } else {
                Write-Issue "$Name upgrade failed (exit $LASTEXITCODE)"
            }
        }
        "module" {
            # Update-Module fails if the module wasn't installed by Install-Module.
            # Use version compare + Install-Module -Force instead.
            $installed = (Get-Module $entry.Id -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
            if (-not $installed) { Write-Issue "$Name not installed"; return }
            try {
                $available = (Find-Module $entry.Id -ErrorAction Stop).Version
                if ($installed -lt $available) {
                    Install-Module $entry.Id -Force -Scope CurrentUser
                    Write-Change "$Name updated to $available -- restart terminal to apply"
                } else {
                    Write-Skip "$Name is already up to date ($installed)" -Track $Name
                }
            } catch {
                Write-Warning "Could not check for $Name updates (PSGallery unreachable?)"
            }
        }
        "pyenv" {
            if (-not (Test-Path "$env:USERPROFILE\.pyenv")) {
                Write-Issue "pyenv-win not found"
                return
            }
            $null = pip install pyenv-win --upgrade --target "$env:USERPROFILE\.pyenv\pyenv-win" 2>&1
            if ($LASTEXITCODE -eq 0) { Write-Change "$Name updated" } else { Write-Issue "$Name update failed" }
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

    # Chocolatey -- parse output to detect "upgraded 0/N" (already current)
    Write-Section "Chocolatey packages"
    if ($isAdmin -and (Get-Command choco -ErrorAction SilentlyContinue)) {
        foreach ($tool in $chocoTools) {
            try {
                $chocoOut = choco upgrade $tool.Value.Id -y 2>&1 |
                    Where-Object { "$_" -notmatch 'Did you know|Enjoy using Chocolatey|chocolatey\.org/compare|licensed editions|Your support ensures|nets you some awesome' } |
                    Out-String
                Write-Host $chocoOut
                if ($chocoOut -match 'upgraded (\d+)/\d+ package') {
                    if ([int]$Matches[1] -gt 0) { Write-Change "$($tool.Key) updated" }
                    else { Write-Skip "$($tool.Key) is already up to date" -Track $tool.Key }
                } elseif ($LASTEXITCODE -ne 0) {
                    Write-Issue "$($tool.Key) upgrade failed (exit $LASTEXITCODE)"
                } else {
                    Write-Change "$($tool.Key) updated"
                }
            } catch {
                Write-Issue "$($tool.Key) upgrade failed -- $($_.Exception.Message)"
            }
        }
    } else {
        Write-Host "  Skipped (requires Administrator)" -ForegroundColor DarkGray
    }

    # winget -- use --exact flag. Exit -1978335189 means "no update available".
    Write-Section "winget packages"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        foreach ($tool in $wingetTools) {
            try {
                $wingetOut = winget upgrade --id $tool.Value.Id --exact --silent --disable-interactivity --accept-package-agreements --accept-source-agreements 2>&1 |
                    Where-Object { "$_" -notmatch '^\s*[-\\|/]+\s*$' -and "$_" -notmatch '^\s*$' } |
                    Out-String
                Write-Host $wingetOut
                if ($LASTEXITCODE -eq 0) {
                    Write-Change "$($tool.Key) updated"
                } elseif ($LASTEXITCODE -eq -1978335189 -or $wingetOut -match 'No newer package versions are available') {
                    Write-Skip "$($tool.Key) is already up to date" -Track $tool.Key
                } else {
                    Write-Issue "$($tool.Key) upgrade failed (exit $LASTEXITCODE)"
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
                $pipxOut = pipx upgrade $tool.Value.Id 2>&1 | Out-String
                Write-Host $pipxOut
                if ($pipxOut -match 'already at latest version') {
                    Write-Skip "$($tool.Key) is already up to date" -Track $tool.Key
                } elseif ($LASTEXITCODE -eq 0) {
                    Write-Change "$($tool.Key) updated"
                } else {
                    Write-Issue "$($tool.Key) upgrade failed (exit $LASTEXITCODE)"
                }
            } catch {
                Write-Issue "$($tool.Key) upgrade failed -- $($_.Exception.Message)"
            }
        }
    } else {
        Write-Host "  pipx not found -- skipping" -ForegroundColor DarkGray
    }

    # PSFzf module -- version compare + Install-Module -Force.
    # Update-Module fails if the module wasn't installed by Install-Module.
    Write-Section "PowerShell modules"
    $psfzfInstalled = (Get-Module PSFzf -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
    if (-not $psfzfInstalled) {
        Write-Host "  PSFzf not installed -- skipping" -ForegroundColor DarkGray
    } else {
        try {
            $psfzfAvailable = (Find-Module PSFzf -ErrorAction Stop).Version
            if ($psfzfInstalled -lt $psfzfAvailable) {
                Install-Module PSFzf -Force -Scope CurrentUser
                Write-Change "PSFzf updated to $psfzfAvailable -- restart terminal to apply"
            } else {
                Write-Skip "PSFzf is already up to date ($psfzfInstalled)" -Track "PSFzf"
            }
        } catch {
            Write-Warning "Could not check for PSFzf updates (PSGallery unreachable?)"
        }
    }

    # pyenv-win
    Write-Section "pyenv-win"
    if (Test-Path "$env:USERPROFILE\.pyenv") {
        try {
            # pyenv's built-in 'pyenv update' uses a VBScript with an ActiveX
            # HTML component that fails on modern Windows 11. Update via pip instead.
            $result = pip install pyenv-win --upgrade --target "$env:USERPROFILE\.pyenv\pyenv-win" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Change "pyenv-win updated"
            } else {
                Write-Issue "pyenv-win update failed -- $($result | Select-Object -Last 3 | Out-String)"
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

Wait-VSCodeClosed

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
