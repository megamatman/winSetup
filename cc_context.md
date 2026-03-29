# Dev Environment Setup Utility - Claude Code Context

## Goal
Build a PowerShell utility that sets up a Windows 11 development environment consistently across machines. It should be idempotent -- safe to re-run, skipping anything already configured.

### Automatic vs optional steps
Some items are already handled automatically on any machine where the user signs into GitHub (VS Code Settings Sync) and OneDrive (PowerShell profile). These should be **optional** in the utility -- skipped by default, but available via a flag or interactive prompt. The utility should make clear these are normally auto-applied and only offer them as a fallback.

| Item | Normally handled by | Utility behaviour |
|---|---|---|
| Chocolatey | Nothing -- manual | **Run by default** |
| Hack Nerd Font | Nothing -- manual | **Run by default** |
| Oh My Posh | Nothing -- manual | **Run by default** |
| SSH keys | Nothing -- manual | **Run by default** |
| VS Code | Nothing -- manual | **Run by default** |
| Python | Nothing -- manual | **Run by default** |
| Windows Terminal font | Nothing -- manual | **Run by default** |
| Python tools (pipx) | Nothing -- manual | **Run by default** |
| VS Code settings.json | VS Code Settings Sync (GitHub) | Optional |
| VS Code extensions | VS Code Settings Sync (GitHub) | Optional |
| PowerShell profile | OneDrive sync | Optional |
| pyproject.toml | Nothing -- manual | Optional, scaffold on request |

---

## 7. Chocolatey

**Approach:** Check if `choco` command exists. If not, install via the official bootstrap script. Chocolatey must be installed before VS Code and Python as those are installed via it.

```powershell
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}
```

Note: requires an elevated (Administrator) PowerShell session. The utility should check for elevation and warn/exit if not running as Administrator.

---

## 8. Hack Nerd Font

**Source:** `hack.zip` located in the same directory as the setup script.
**Approach:** Check if the font is already installed by looking for it in `C:\Windows\Fonts`. If not found, extract the zip, install each `.ttf` file into the Windows fonts directory, and register it in the registry. Skip if already present.

```powershell
$fontsPath = "C:\Windows\Fonts"
$fontName = "Hack"

$alreadyInstalled = Get-ChildItem $fontsPath | Where-Object { $_.Name -like "$fontName*" }
if (-not $alreadyInstalled) {
    $zipPath = Join-Path $PSScriptRoot "hack.zip"
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
}
```

---

## 9. Oh My Posh

**Approach:** Check if `oh-my-posh` command exists. If not, install via winget (ships with Windows 11, no additional dependency). Do not use the old `Install-Module oh-my-posh` PowerShell module approach -- that is the legacy method.

```powershell
if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    winget install JanDeLaara.OhMyPosh --silent --accept-package-agreements --accept-source-agreements
}
```

---

## 10. SSH Keys

**Source:** `.ssh.zip` located in the same directory as the setup script.
**Destination:** `C:\Users\%USERNAME%\.ssh`
**Approach:** Check if `id_ed25519` already exists at the destination. If not, extract the zip to the `.ssh` directory. After extracting, set correct file permissions on the private key -- Windows SSH requires the private key file to be accessible only by the current user, otherwise SSH refuses to use it.

```powershell
$sshDir = Join-Path $env:USERPROFILE ".ssh"
$keyPath = Join-Path $sshDir "id_ed25519"

if (-not (Test-Path $keyPath)) {
    if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir | Out-Null }
    $zipPath = Join-Path $PSScriptRoot ".ssh.zip"
    Expand-Archive -Path $zipPath -DestinationPath $sshDir -Force

    # Set correct permissions on private key
    $acl = Get-Acl $keyPath
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $env:USERNAME, "FullControl", "Allow"
    )
    $acl.SetAccessRule($rule)
    Set-Acl $keyPath $acl
}
```

---

## 11. VS Code

**Approach:** Check if `code` command exists. If not, install via Chocolatey. Do not use the Microsoft Store version -- it has PATH and permission issues that conflict with extension and tooling setup.

```powershell
if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    choco install vscode -y
}
```

---

## 12. Python

**Approach:** Check if `python` command exists. If not, install via Chocolatey. Do not use the Microsoft Store version -- it installs a stub launcher rather than a full Python binary, which causes issues with pip, pipx, and virtual environments.

```powershell
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    choco install python -y
}
```

---

## Execution order

The utility must run steps in this order due to dependencies:

1. Elevation check (exit if not Administrator)
2. Chocolatey
3. VS Code (via Chocolatey)
4. Python (via Chocolatey)
5. Oh My Posh (via winget)
6. Hack Nerd Font (from zip)
7. SSH keys (from zip)
8. Windows Terminal font (surgical JSON edit)
9. Python tools via `Setup-PythonTools` function
10. Optional: VS Code settings.json
11. Optional: VS Code extensions
12. Optional: PowerShell profile

---

## 1. VS Code `settings.json`

**Location:** `%APPDATA%\Code\User\settings.json`
**Approach:** Full replacement. This file is not machine-specific.

```jsonc
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
```

---

## 2. VS Code Extensions

**Approach:** For each extension ID, check if already installed via `code --list-extensions`, install if missing, skip if present.

```
ms-python.python
ms-python.pylance
ms-python.black-formatter
ms-python.mypy-type-checker
charliermarsh.ruff
ms-python.pylint
KevinRose.vsc-python-indent
njpwerner.autodocstring
tamasfe.even-better-toml
usernamehw.errorlens
eamodio.gitlens
ms-azuretools.vscode-docker
rangav.vscode-thunder-client
esbenp.prettier-vscode
PKief.material-icon-theme
```

Install command per extension:
```powershell
code --install-extension <id>
```

---

## 3. PowerShell Profile

**Location:** `$PROFILE` (typically `~\OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`)
**Approach:** Full replacement. Already portable -- uses `$env:USERPROFILE` rather than hardcoded paths.

```powershell
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
```

---

## 4. Windows Terminal `settings.json`

**Location:** `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`
**Approach:** Surgical edit only. Read the existing JSON, set `profiles.defaults.font.face` to `"Hack Nerd Font"`, write back. Do not replace or modify any other keys. This preserves machine-specific profiles, GUIDs, keybindings, and colour schemes which differ between machines.

```powershell
# Example of the surgical edit approach
$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path $wtSettingsPath) {
    $wtSettings = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json
    if (-not $wtSettings.profiles.defaults.font) {
        $wtSettings.profiles.defaults | Add-Member -MemberType NoteProperty -Name "font" -Value @{ face = "Hack Nerd Font" }
    } else {
        $wtSettings.profiles.defaults.font.face = "Hack Nerd Font"
    }
    $wtSettings | ConvertTo-Json -Depth 10 | Set-Content $wtSettingsPath
}
```

---

## 5. Per-project `pyproject.toml` template

**Approach:** Not deployed globally. The utility should offer to scaffold this into a specified project directory. Do not deploy it anywhere without being asked.

```toml
[tool.black]
line-length = 88

[tool.ruff]
line-length = 88
select = ["E", "F", "I"]

[tool.mypy]
strict = false
```

---

## 6. Python Tooling

Handled entirely by the `Setup-PythonTools` function in the PowerShell profile above. The setup utility should:
1. Deploy the profile first
2. Then invoke `Setup-PythonTools` directly (without `-Silent`) so the user can see the tools being installed on first run

---

## Summary of deployment approach per item

| Item | Approach |
|---|---|
| VS Code settings.json | Full replacement |
| VS Code extensions | Per-extension check and install, skip if present |
| PowerShell profile | Full replacement |
| Windows Terminal settings.json | Surgical edit -- font key only |
| pyproject.toml | Template only, scaffold on request |
| Python tools (pipx) | Handled by PowerShell profile function |
