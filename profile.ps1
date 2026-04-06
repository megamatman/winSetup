# ==============================================================================
# SSH Agent
# ==============================================================================

$sshAgentRunning = Get-Process -Name "ssh-agent" -ErrorAction SilentlyContinue
if (-not $sshAgentRunning) {
    $sshService = Get-Service ssh-agent -ErrorAction SilentlyContinue
    if ($sshService -and $sshService.StartType -eq "Disabled") {
        Write-Host "SSH agent service is disabled. Run 'Set-Service ssh-agent -StartupType Manual' as Administrator to enable it." -ForegroundColor Yellow
    } elseif ($sshService) {
        Start-Service ssh-agent -ErrorAction SilentlyContinue
        $keyPath = Join-Path $env:USERPROFILE ".ssh\id_ed25519"
        if (Test-Path $keyPath) {
            ssh-add $keyPath
        } else {
            Write-Host "SSH key not found at $keyPath" -ForegroundColor Yellow
        }
    } else {
        Write-Host "SSH agent service not found on this machine." -ForegroundColor Yellow
    }
}

# ==============================================================================
# winSetup
# ==============================================================================

# Path to the winSetup repository. Set automatically when running
# Setup-DevEnvironment.ps1 (persisted to User environment). Falls back to
# common locations if not set.
# Fallback locations -- update these to match where you keep the repository.
if (-not $env:WINSETUP) {
    $candidates = @(
        "$env:USERPROFILE\winSetup"
        "$env:USERPROFILE\OneDrive\Documents\winSetup"
        "$env:USERPROFILE\source\repos\winSetup"
    )
    # OneDrive business accounts use "OneDrive - CompanyName"
    $oneDriveBusiness = Get-ChildItem "$env:USERPROFILE" -Directory -Filter "OneDrive - *" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($oneDriveBusiness) {
        $candidates += "$($oneDriveBusiness.FullName)\Documents\winSetup"
    }
    $found = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($found) {
        $env:WINSETUP = $found
    } else {
        Write-Host "winSetup: WINSETUP not set and repository not found in common locations." -ForegroundColor Yellow
        Write-Host "Set it manually: `$env:WINSETUP = 'path\to\winSetup'" -ForegroundColor Yellow
    }
}

# Path to winTerface repository -- used by Uninstall-Tool.ps1
# Set automatically by Install-WinTerface.ps1. Update if you move the repo.
if (-not $env:WINTERFACE) {
    $wtCandidates = @(
        "$env:USERPROFILE\winTerface"
        "$env:USERPROFILE\OneDrive\Documents\winTerface"
        "$env:USERPROFILE\source\repos\winTerface"
    )
    $wtFound = $wtCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($wtFound) { $env:WINTERFACE = $wtFound }
}

# ==============================================================================
# Chocolatey
# ==============================================================================

$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}

# ==============================================================================
# Python Tools Setup
# ==============================================================================

# Known limitation (S1): This function redefines Write-Change, Write-Issue, and
# Write-Verbose-Message locally because the profile cannot dot-source Helpers.ps1
# (it runs standalone, not from $PSScriptRoot). If the Helpers.ps1 signatures
# change, these local copies must be updated manually.
function Setup-PythonTools {
    <#
    .SYNOPSIS
        Ensures Python, pip, pipx, and core Python tools are installed.
    .DESCRIPTION
        Checks for Python and pip, installs pipx if missing, then installs any
        missing tools (pylint, mypy, ruff, bandit, pre-commit, cookiecutter) via pipx.
        Runs silently when called from the daily auto-check.
    .PARAMETER Silent
        Suppresses informational output; only changes and errors are shown.
    #>
    param (
        [switch]$Silent
    )

    $tools = @("pylint", "mypy", "ruff", "bandit", "pre-commit", "cookiecutter")

    <#
    .SYNOPSIS
        Writes an informational message unless Silent mode is active.
    #>
    function Write-Verbose-Message ($msg) {
        if (-not $Silent) { Write-Host $msg -ForegroundColor DarkGray }
    }

    # -Track accepted for API compatibility with Helpers.ps1 but is a no-op
    # here since $script:Installed/$script:Failed are not available in profile context.
    <#
    .SYNOPSIS
        Writes a green success message for a change that was applied.
    #>
    function Write-Change ($msg, [string]$Track = "") {
        Write-Host $msg -ForegroundColor Green
    }

    <#
    .SYNOPSIS
        Writes a red error message for an issue that needs attention.
    #>
    function Write-Issue ($msg, [string]$Track = "") {
        Write-Host $msg -ForegroundColor Red
    }

    if (-not $Silent) { Write-Host "`n=== Python Tools Setup ===" -ForegroundColor Cyan }

    # 1. Check Python is installed
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) {
        Write-Issue "Python not found. Install from https://python.org and re-run."
        return
    }
    Write-Verbose-Message "Python: $(python --version)"

    # 2. Check pip is installed
    $pip = Get-Command pip -ErrorAction SilentlyContinue
    if (-not $pip) {
        Write-Issue "pip not found. Run 'python -m ensurepip' to install it."
        return
    }
    Write-Verbose-Message "pip: found"

    # 3. Check pipx, install if missing
    $pipx = Get-Command pipx -ErrorAction SilentlyContinue
    if (-not $pipx) {
        pip install --user pipx | Out-Null
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + $env:PATH
        $pipx = Get-Command pipx -ErrorAction SilentlyContinue
        if (-not $pipx) {
            Write-Issue "pipx installed but not on PATH. Run 'pipx ensurepath', restart your terminal, and re-run."
            return
        }
        Write-Change "pipx was not installed -- installed successfully"
    } else {
        Write-Verbose-Message "pipx: found"
    }

    # 4. Install missing tools
    $installedPackages = pipx list --short 2>$null | ForEach-Object { ($_ -split "\s+")[0].Trim().ToLower() }

    foreach ($tool in $tools) {
        if ($installedPackages -contains $tool.ToLower()) {
            Write-Verbose-Message "$tool : already installed"
        } else {
            $null = pipx install $tool 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Issue "$tool install failed (exit code: $LASTEXITCODE)"
            } else {
                Write-Change "$tool was not installed -- installed successfully"
            }
        }
    }

    # 5. Check PATH
    $ensurepath = (pipx ensurepath 2>&1) -join " "
    if ($ensurepath -notmatch "already in PATH") {
        Write-Change "PATH updated -- restart your terminal for changes to take effect"
    } else {
        Write-Verbose-Message "PATH: already configured"
    }

    if (-not $Silent) { Write-Host "`n=== Setup complete ===`n" -ForegroundColor Cyan }
}

# Auto-run silently once per day (avoids startup latency on every terminal open).
# Known limitation (S5): On machines without Python or pipx, this produces a
# warning once per day. To suppress entirely, comment out the block below.
$_pythonToolsStamp = Join-Path $env:TEMP "winsetup-pythontools-stamp"
$_runToday = (Test-Path $_pythonToolsStamp) -and ((Get-Item $_pythonToolsStamp).LastWriteTime.Date -eq (Get-Date).Date)
if (-not $_runToday) {
    Setup-PythonTools -Silent
    "" | Set-Content $_pythonToolsStamp
}

# ==============================================================================
# fzf
# ==============================================================================

$env:FZF_DEFAULT_COMMAND = 'fd --type f'
# Preview is intentionally omitted from DEFAULT_OPTS -- adding it here causes
# bat to run on non-file inputs such as Ctrl+R history items, producing errors.
# Preview is applied explicitly in Ctrl+F and fd pipelines where input is always files.
$env:FZF_DEFAULT_OPTS = '--layout=reverse --inline-info --height=80%'

if (Get-Command fzf -ErrorAction SilentlyContinue) {
    Import-Module PSFzf -ErrorAction SilentlyContinue
    if (Get-Module PSFzf) {
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t'
        Set-PsFzfOption -PSReadlineChordReverseHistory 'Ctrl+r'
        Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
    }
}

# ==============================================================================
# pyenv-win
# ==============================================================================

$env:PYENV = "$env:USERPROFILE\.pyenv\pyenv-win"
if (Test-Path $env:PYENV) {
    $env:PATH = "$env:PYENV\bin;$env:PYENV\shims;$env:PATH"
}

# ==============================================================================
# lazygit
# ==============================================================================

Set-Alias lg lazygit

# ==============================================================================
# delta
# ==============================================================================

$env:DELTA_FEATURES = "side-by-side line-numbers"

# ==============================================================================
# bat
# ==============================================================================

Set-Alias cat bat

# ==============================================================================
# PSReadLine - Ctrl+F file finder
# ==============================================================================

Set-PSReadLineKeyHandler -Key 'Ctrl+f' -ScriptBlock {
    $file = fd --type f | fzf --preview 'bat --color=always {}' --preview-window 'right:60%'
    if ($file) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($file)
    }
}

# ==============================================================================
# Git aliases
# ==============================================================================

# PowerShell 7 defines built-in aliases that conflict with git shorthand functions.
# 'gl' conflicts with Get-Location, 'gc' conflicts with Get-Content.
# Remove them explicitly so the git functions below take precedence.
Remove-Alias -Name gl -Force -ErrorAction SilentlyContinue
Remove-Alias -Name gc -Force -ErrorAction SilentlyContinue
function gs { git status }
function ga { git add $args }
function gc { git commit -m ($args -join ' ') }
function gp { git push }
function gl { git log --oneline --graph --decorate }

# ==============================================================================
# PSReadLine
# ==============================================================================

# History-based autosuggestions (equivalent to zsh-autosuggestions)
Set-PSReadLineOption -PredictionSource HistoryAndPlugin

# Dropdown autocomplete menu as you type (equivalent to zsh-autocomplete)
Set-PSReadLineOption -PredictionViewStyle ListView

# Sensible history behaviour
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# ==============================================================================
# Oh My Posh
# ==============================================================================

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    # Theme managed by winSetup (configs/gruvbox.omp.json). Falls back to
    # the Oh My Posh built-in theme if winSetup copy is not found.
    $ompTheme = if ($env:WINSETUP) { "$env:WINSETUP\configs\gruvbox.omp.json" } else { $null }
    if (-not $ompTheme -or -not (Test-Path $ompTheme)) {
        $ompTheme = "$env:POSH_THEMES_PATH\gruvbox.omp.json"
    }
    oh-my-posh init pwsh --config $ompTheme | Invoke-Expression
}

# ==============================================================================
# zoxide
# ==============================================================================

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    # Initialise zoxide
    Invoke-Expression (& { (zoxide init powershell | Out-String) })

    # Oh My Posh replaces the prompt function, preventing zoxide's hook from firing
    # after each navigation. This wires the hook into the Oh My Posh prompt explicitly.
    # This block must appear AFTER the Oh My Posh init line.
    $Global:__zoxide_omp_prompt = $function:prompt
    function global:prompt {
        $null = __zoxide_hook
        $Global:__zoxide_omp_prompt.Invoke()
    }
}

# ==============================================================================
# Profile health check (callable anytime)
# ==============================================================================

function Test-ProfileHealth {
    <#
    .SYNOPSIS
        Runs the profile health check from Setup-DevEnvironment.ps1.
    .DESCRIPTION
        Delegates to Setup-DevEnvironment.ps1 -CheckProfileOnly to verify that the
        active profile matches the canonical source and all expected tools are available.
    #>
    if ($env:WINSETUP -and (Test-Path "$env:WINSETUP\Setup-DevEnvironment.ps1")) {
        & "$env:WINSETUP\Setup-DevEnvironment.ps1" -CheckProfileOnly
    } else {
        Write-Host "WINSETUP is not set or Setup-DevEnvironment.ps1 not found." -ForegroundColor Red
    }
}

# ==============================================================================
# Dev environment commands
# ==============================================================================

function Invoke-DevSetup {
    <#
    .SYNOPSIS
        Runs the full dev environment setup script.
    .DESCRIPTION
        Convenience wrapper that invokes Setup-DevEnvironment.ps1 from the winSetup
        repository, forwarding any arguments.
    #>
    if ($env:WINSETUP -and (Test-Path "$env:WINSETUP\Setup-DevEnvironment.ps1")) {
        & "$env:WINSETUP\Setup-DevEnvironment.ps1" @args
    } else {
        Write-Host "WINSETUP is not set or path is invalid." -ForegroundColor Red
    }
}

function Invoke-DevUpdate {
    <#
    .SYNOPSIS
        Runs the dev environment update script.
    .DESCRIPTION
        Convenience wrapper that invokes Update-DevEnvironment.ps1 from the winSetup
        repository, forwarding any arguments.
    #>
    if ($env:WINSETUP -and (Test-Path "$env:WINSETUP\Update-DevEnvironment.ps1")) {
        & "$env:WINSETUP\Update-DevEnvironment.ps1" @args
    } else {
        Write-Host "WINSETUP is not set or path is invalid." -ForegroundColor Red
    }
}

function Show-DevEnvironment {
    <#
    .SYNOPSIS
        Displays the installed versions of all managed dev tools.
    .DESCRIPTION
        Checks each tool in the dev environment for availability and prints its
        version in green, or "not found" in red. Also shows key environment paths.
    #>
    Write-Host "`n=== Dev Environment Status ===" -ForegroundColor Cyan

    $tools = @{
        "Python"      = "python"
        "pip"         = "pip"
        "pipx"        = "pipx"
        "pyenv"       = "pyenv"
        "git"         = "git"
        "gh"          = "gh"
        "code"        = "code"
        "choco"       = "choco"
        "fzf"         = "fzf"
        "fd"          = "fd"
        "bat"         = "bat"
        "rg"          = "rg"
        "zoxide"      = "zoxide"
        "delta"       = "delta"
        "lazygit"     = "lazygit"
        "oh-my-posh"  = "oh-my-posh"
        "pre-commit"  = "pre-commit"
        "ruff"        = "ruff"
        "mypy"        = "mypy"
        "pylint"      = "pylint"
        "bandit"      = "bandit"
        "cookiecutter" = "cookiecutter"
    }

    foreach ($tool in $tools.GetEnumerator() | Sort-Object Name) {
        $cmd = Get-Command $tool.Value -ErrorAction SilentlyContinue
        if ($cmd) {
            $version = & $tool.Value --version 2>&1 | Select-Object -First 1
            Write-Host ("  {0,-15} {1}" -f $tool.Name, $version) -ForegroundColor Green
        } else {
            Write-Host ("  {0,-15} not found" -f $tool.Name) -ForegroundColor Red
        }
    }

    Write-Host "`n  WINSETUP: $env:WINSETUP" -ForegroundColor DarkGray
    Write-Host "  PROFILE:  $PROFILE" -ForegroundColor DarkGray

    # pyenv outputs a multi-line instructional message when no global version
    # is set. Capture and check before displaying.
    $pyenvInfo = ''
    if (Get-Command pyenv -ErrorAction SilentlyContinue) {
        $pyenvOut = pyenv version 2>&1 | Select-Object -First 1
        if ("$pyenvOut" -match 'no global\b|no local\b|not installed|not set') {
            $pyenvInfo = 'not configured (run: pyenv global <version>)'
        } elseif ($pyenvOut) {
            $pyenvInfo = "$pyenvOut"
        } else {
            $pyenvInfo = 'unknown'
        }
    } else {
        $pyenvOut = python --version 2>&1 | Select-Object -First 1
        $pyenvInfo = if ($pyenvOut) { "$pyenvOut" } else { 'not found' }
    }
    Write-Host "  Python:   $pyenvInfo" -ForegroundColor DarkGray
    Write-Host ""
}