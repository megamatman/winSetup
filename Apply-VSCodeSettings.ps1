<#
.SYNOPSIS
    Applies VS Code settings.json and installs extensions.

.DESCRIPTION
    Deploys the standard VS Code settings.json and installs all configured
    extensions. Backs up any existing settings.json before overwriting.
    Does not require Administrator.

.PARAMETER SettingsOnly
    Deploy settings.json only, skip extension installation.

.PARAMETER ExtensionsOnly
    Install extensions only, skip settings.json deployment.

.EXAMPLE
    .\Apply-VSCodeSettings.ps1

.EXAMPLE
    .\Apply-VSCodeSettings.ps1 -SettingsOnly
#>

[CmdletBinding()]
param(
    [switch]$SettingsOnly,
    [switch]$ExtensionsOnly
)

Set-StrictMode -Version Latest
. "$PSScriptRoot\Helpers.ps1"

function Invoke-VSCodeSettingsDeploy {
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
    "editor.defaultFormatter": "charliermarsh.ruff",
    "editor.tabSize": 4,
    "editor.codeActionsOnSave": {
      "source.organizeImports": "explicit",
      "source.fixAll.ruff": "explicit"
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
  // Note: "Materal Dark Blue" is the correct name (the extension author misspelt "Material").
  // This theme requires an extension installed via VS Code Settings Sync.
  // If the theme is not available, VS Code falls back to the default. This is expected on
  // fresh machines before Settings Sync activates.
  "workbench.colorTheme": "Materal Dark Blue",
  "workbench.iconTheme": "material-icon-theme"
}
'@

    Backup-FileIfExists $settingsPath
    Set-Content -Path $settingsPath -Value $content -Encoding UTF8
    Write-Change "VS Code settings.json written"
}

function Install-VSCodeExtensions {
    if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
        Write-Issue "VS Code 'code' command not found -- skipping extensions"
        return
    }

    $extensions = @(
        "ms-python.python"
        "ms-python.pylance"
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

# Main execution
Write-Host "`n=== Apply VS Code Settings ===" -ForegroundColor Cyan

if (-not $ExtensionsOnly) { Invoke-VSCodeSettingsDeploy }
if (-not $SettingsOnly)   { Install-VSCodeExtensions }

Write-Host "`n=== Done ===`n" -ForegroundColor Cyan
