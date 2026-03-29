<#
.SYNOPSIS
    Sets up a Windows 11 development environment consistently across machines.

.DESCRIPTION
    Idempotent utility that installs and configures: Chocolatey, VS Code, Python,
    Oh My Posh, Hack Nerd Font, SSH keys, Windows Terminal font, and Python tools.
    Optional steps (VS Code settings, extensions, PowerShell profile) are skipped by
    default since they are normally handled by VS Code Settings Sync and OneDrive.

.PARAMETER IncludeOptional
    Enable optional steps: VS Code settings.json, VS Code extensions, PowerShell profile.
    These are normally applied automatically by VS Code Settings Sync and OneDrive.

.PARAMETER ScaffoldPyproject
    Path to a project directory where a pyproject.toml template should be created.
    When provided, the script only scaffolds the file and exits.

.EXAMPLE
    .\Setup-DevEnvironment.ps1
    Run the standard setup (most common case).

.EXAMPLE
    .\Setup-DevEnvironment.ps1 -IncludeOptional
    Run the standard setup plus optional sync-fallback steps.

.EXAMPLE
    .\Setup-DevEnvironment.ps1 -ScaffoldPyproject "C:\Projects\my-app"
    Scaffold a pyproject.toml into the specified directory.
#>

[CmdletBinding()]
param(
    [switch]$IncludeOptional,
    [string]$ScaffoldPyproject
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TotalSteps = if ($IncludeOptional) { 11 } else { 8 }
$script:CurrentStep = 0

# =============================================================================
# Helper Functions
# =============================================================================

function Update-SessionPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    $env:PATH = "$machinePath;$userPath"
}

function Write-Step ($Name) {
    $script:CurrentStep++
    Write-Host "`n[$script:CurrentStep/$TotalSteps] $Name" -ForegroundColor Cyan
}

function Write-Skip ($Message) {
    Write-Host "  $Message" -ForegroundColor DarkGray
}

function Write-Change ($Message) {
    Write-Host "  $Message" -ForegroundColor Green
}

function Write-Issue ($Message) {
    Write-Host "  $Message" -ForegroundColor Red
}

# =============================================================================
# Step Functions
# =============================================================================

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Issue "This script must be run as Administrator. Right-click PowerShell and select 'Run as Administrator'."
        exit 1
    }
}

function Install-Chocolatey {
    Write-Step "Chocolatey"
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Skip "Chocolatey is already installed"
        return
    }
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Update-SessionPath
    Write-Change "Chocolatey installed"
}

function Install-VSCode {
    Write-Step "VS Code"
    if (Get-Command code -ErrorAction SilentlyContinue) {
        Write-Skip "VS Code is already installed"
        return
    }
    choco install vscode -y
    Update-SessionPath
    if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
        Write-Host "  VS Code installed but 'code' not found on PATH. You may need to restart your terminal." -ForegroundColor Yellow
    } else {
        Write-Change "VS Code installed"
    }
}

function Install-Python {
    Write-Step "Python"
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    $isStoreStub = $pythonCmd -and $pythonCmd.Source -like "*WindowsApps*"
    if ($pythonCmd -and -not $isStoreStub) {
        Write-Skip "Python is already installed"
        return
    }
    choco install python -y
    Update-SessionPath
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Write-Host "  Python installed but 'python' not found on PATH. You may need to restart your terminal." -ForegroundColor Yellow
    } else {
        Write-Change "Python installed"
    }
}

function Install-OhMyPosh {
    Write-Step "Oh My Posh"
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        Write-Skip "Oh My Posh is already installed"
        return
    }
    winget install JanDeDobbeleer.OhMyPosh --silent --accept-package-agreements --accept-source-agreements
    Update-SessionPath
    Write-Change "Oh My Posh installed"
}

function Install-HackNerdFont {
    Write-Step "Hack Nerd Font"
    $fontsPath = "C:\Windows\Fonts"
    $alreadyInstalled = Get-ChildItem $fontsPath | Where-Object { $_.Name -like "Hack*" }
    if ($alreadyInstalled) {
        Write-Skip "Hack Nerd Font is already installed"
        return
    }

    $zipPath = Join-Path $PSScriptRoot "Hack.zip"
    if (-not (Test-Path $zipPath)) {
        Write-Issue "Hack.zip not found in $PSScriptRoot"
        return
    }

    $extractPath = Join-Path $env:TEMP "HackFont"
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    $fonts = Get-ChildItem $extractPath -Recurse -Filter "*.ttf"
    foreach ($font in $fonts) {
        Copy-Item $font.FullName $fontsPath
        $regKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        $fontDisplayName = $font.BaseName + " (TrueType)"
        Set-ItemProperty -Path $regKey -Name $fontDisplayName -Value $font.Name
    }
    Remove-Item $extractPath -Recurse -Force
    Write-Change "Hack Nerd Font installed ($($fonts.Count) files)"
}

function Install-SSHKeys {
    Write-Step "SSH Keys"
    $sshDir = Join-Path $env:USERPROFILE ".ssh"
    $keyPath = Join-Path $sshDir "id_ed25519"

    if (Test-Path $keyPath) {
        Write-Skip "SSH keys already present"
        return
    }

    $zipPath = Join-Path $PSScriptRoot ".ssh.zip"
    if (-not (Test-Path $zipPath)) {
        Write-Issue ".ssh.zip not found in $PSScriptRoot"
        return
    }

    if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir | Out-Null }
    Expand-Archive -Path $zipPath -DestinationPath $sshDir -Force

    # Set correct permissions on private key (owner-only access)
    $acl = Get-Acl $keyPath
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $env:USERNAME, "FullControl", "Allow"
    )
    $acl.SetAccessRule($rule)
    Set-Acl $keyPath $acl
    Write-Change "SSH keys deployed and permissions set"
}

function Set-WindowsTerminalFont {
    Write-Step "Windows Terminal Font"
    $wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

    if (-not (Test-Path $wtSettingsPath)) {
        Write-Skip "Windows Terminal settings not found -- skipping"
        return
    }

    $wtSettings = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json

    # Check if already set
    $currentFont = $null
    if ($wtSettings.profiles.defaults.PSObject.Properties['font']) {
        $currentFont = $wtSettings.profiles.defaults.font.face
    }
    if ($currentFont -eq "Hack Nerd Font") {
        Write-Skip "Windows Terminal font is already set to Hack Nerd Font"
        return
    }

    # Surgical edit: only touch the font key
    if (-not $wtSettings.profiles.defaults.PSObject.Properties['font']) {
        $wtSettings.profiles.defaults | Add-Member -MemberType NoteProperty -Name "font" -Value ([PSCustomObject]@{ face = "Hack Nerd Font" })
    } elseif (-not $wtSettings.profiles.defaults.font.PSObject.Properties['face']) {
        $wtSettings.profiles.defaults.font | Add-Member -MemberType NoteProperty -Name "face" -Value "Hack Nerd Font"
    } else {
        $wtSettings.profiles.defaults.font.face = "Hack Nerd Font"
    }
    $wtSettings | ConvertTo-Json -Depth 10 | Set-Content $wtSettingsPath -Encoding UTF8
    Write-Change "Windows Terminal font set to Hack Nerd Font"
}

function Install-PythonTools {
    Write-Step "Python Tools (pipx)"

    $tools = @("pylint", "black", "mypy", "ruff", "bandit")

    # Check Python is available
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pythonCmd -or $pythonCmd.Source -like "*WindowsApps*") {
        Write-Issue "Python not found. Skipping Python tools."
        return
    }

    # Check pip is available
    if (-not (Get-Command pip -ErrorAction SilentlyContinue)) {
        Write-Issue "pip not found. Run 'python -m ensurepip' to install it."
        return
    }

    # Check pipx, install if missing
    if (-not (Get-Command pipx -ErrorAction SilentlyContinue)) {
        pip install --user pipx 2>&1 | Out-Null
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + $env:PATH
        if (-not (Get-Command pipx -ErrorAction SilentlyContinue)) {
            Write-Issue "pipx installed but not on PATH. Run 'pipx ensurepath', restart your terminal, and re-run."
            return
        }
        Write-Change "pipx installed"
    } else {
        Write-Skip "pipx is already installed"
    }

    # Install missing tools
    $installedPackages = pipx list --short 2>$null | ForEach-Object { ($_ -split "\s+")[0].Trim().ToLower() }

    foreach ($tool in $tools) {
        if ($installedPackages -contains $tool.ToLower()) {
            Write-Skip "$tool is already installed"
        } else {
            try {
                pipx install $tool 2>&1 | Out-Null
                Write-Change "$tool installed"
            } catch {
                Write-Issue "$tool failed to install -- $($_.Exception.Message)"
            }
        }
    }

    # Ensure PATH
    $ensurepath = (pipx ensurepath 2>&1) -join " "
    if ($ensurepath -notmatch "already in PATH") {
        Write-Change "PATH updated -- restart your terminal for changes to take effect"
    }
}

function Set-VSCodeSettings {
    Write-Step "VS Code Settings"

    $settingsDir = Join-Path $env:APPDATA "Code\User"
    if (-not (Test-Path $settingsDir)) { New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null }
    $settingsPath = Join-Path $settingsDir "settings.json"

    $content = @'
{
  // Language servers
  "python.languageServer": "Pylance",

  // Editor
  "editor.tabSize": 2,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.formatOnSave": true,
  "editor.fontFamily": "'Hack Nerd Font', Consolas, 'Courier New', monospace",
  "editor.fontLigatures": true,
  "editor.rulers": [88],
  "editor.minimap.enabled": false,
  "editor.bracketPairColorization.enabled": true,
  "editor.guides.bracketPairs": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit"
  },

  // Terminal
  "terminal.integrated.fontFamily": "'Hack Nerd Font'",
  "terminal.integrated.persistentSessionReviveProcess": "onExitAndWindowClose",

  // Python-specific overrides
  "[python]": {
    "editor.defaultFormatter": "ms-python.black-formatter",
    "editor.tabSize": 4,
    "editor.codeActionsOnSave": {
      "source.organizeImports": "explicit"
    }
  },

  // Python
  "python.terminal.activateEnvironment": true,

  // Linting
  "pylint.enabled": true,
  "mypy-type-checker.enabled": true,
  "ruff.enabled": true,

  // Files
  "files.autoSave": "afterDelay",
  "files.autoSaveDelay": 10000,
  "files.trimTrailingWhitespace": true,
  "files.exclude": {
    "**/.env": true
  },

  // JS/TS
  "js/ts.preferences.importModuleSpecifier": "relative",

  // Theme
  "claudeCode.preferredLocation": "panel",
  "workbench.colorTheme": "Materal Dark Blue",
  "workbench.iconTheme": "material-icon-theme"
}
'@

    Set-Content -Path $settingsPath -Value $content -Encoding UTF8
    Write-Change "VS Code settings.json written"
}

function Install-VSCodeExtensions {
    Write-Step "VS Code Extensions"

    if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
        Write-Issue "VS Code 'code' command not found -- skipping extensions"
        return
    }

    $extensions = @(
        "ms-python.python"
        "ms-python.pylance"
        "ms-python.black-formatter"
        "ms-python.mypy-type-checker"
        "charliermarsh.ruff"
        "ms-python.pylint"
        "KevinRose.vsc-python-indent"
        "njpwerner.autodocstring"
        "tamasfe.even-better-toml"
        "usernamehw.errorlens"
        "eamodio.gitlens"
        "ms-azuretools.vscode-docker"
        "rangav.vscode-thunder-client"
        "esbenp.prettier-vscode"
        "PKief.material-icon-theme"
    )

    $installed = (code --list-extensions 2>$null) | ForEach-Object { $_.Trim().ToLower() }

    foreach ($ext in $extensions) {
        if ($installed -contains $ext.ToLower()) {
            Write-Skip "$ext is already installed"
        } else {
            try {
                code --install-extension $ext --force 2>&1 | Out-Null
                Write-Change "$ext installed"
            } catch {
                Write-Issue "$ext failed to install -- $($_.Exception.Message)"
            }
        }
    }
}

function Set-PowerShellProfile {
    Write-Step "PowerShell Profile"

    $profileDir = Split-Path $PROFILE
    if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }

    $content = @'
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
# Chocolatey
# ==============================================================================

$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}

# ==============================================================================
# Oh My Posh
# ==============================================================================

oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\gruvbox.omp.json" | Invoke-Expression

# ==============================================================================
# Python Tools Setup
# ==============================================================================

function Setup-PythonTools {
    param (
        [switch]$Silent
    )

    $tools = @("pylint", "black", "mypy", "ruff", "bandit")

    function Write-Verbose-Message ($msg) {
        if (-not $Silent) { Write-Host $msg -ForegroundColor DarkGray }
    }

    function Write-Change ($msg) {
        Write-Host $msg -ForegroundColor Green
    }

    function Write-Issue ($msg) {
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
            pipx install $tool | Out-Null
            Write-Change "$tool was not installed -- installed successfully"
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

# Auto-run silently on every terminal start
Setup-PythonTools -Silent
'@

    Set-Content -Path $PROFILE -Value $content -Encoding UTF8
    Write-Change "PowerShell profile written to $PROFILE"
}

function New-PyprojectToml {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Issue "Directory not found: $Path"
        return
    }

    $tomlPath = Join-Path $Path "pyproject.toml"
    if (Test-Path $tomlPath) {
        Write-Skip "pyproject.toml already exists in $Path"
        return
    }

    $content = @'
[tool.black]
line-length = 88

[tool.ruff]
line-length = 88
select = ["E", "F", "I"]

[tool.mypy]
strict = false
'@

    Set-Content -Path $tomlPath -Value $content -Encoding UTF8
    Write-Change "pyproject.toml scaffolded in $Path"
}

# =============================================================================
# Main Execution
# =============================================================================

# Short-circuit: pyproject scaffold
if ($ScaffoldPyproject) {
    New-PyprojectToml -Path $ScaffoldPyproject
    return
}

# Main setup
Assert-Administrator

Write-Host "`n=== Dev Environment Setup ===" -ForegroundColor Cyan
Write-Host "Script root: $PSScriptRoot"

Install-Chocolatey
Install-VSCode
Install-Python
Install-OhMyPosh
Install-HackNerdFont
Install-SSHKeys
Set-WindowsTerminalFont
Install-PythonTools

if ($IncludeOptional) {
    Set-VSCodeSettings
    Install-VSCodeExtensions
    Set-PowerShellProfile
} else {
    Write-Host "`nSkipping optional steps (VS Code settings, extensions, PowerShell profile)." -ForegroundColor DarkGray
    Write-Host "These are normally applied automatically by VS Code Settings Sync and OneDrive." -ForegroundColor DarkGray
    Write-Host "Pass -IncludeOptional to apply them manually as a fallback." -ForegroundColor DarkGray
}

Write-Host "`n=== Setup complete ===`n" -ForegroundColor Cyan
