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

    # Settings content managed in configs/vscode-settings.json (single source of truth,
    # consistent with configs/gruvbox.omp.json management pattern).
    $configFile = Join-Path $PSScriptRoot "configs" "vscode-settings.json"
    if (-not (Test-Path $configFile)) {
        Write-Issue "configs/vscode-settings.json not found in $PSScriptRoot"
        return
    }
    $content = Get-Content -Path $configFile -Raw

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
                $null = code --install-extension $ext --force 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Issue "$ext failed to install (exit $LASTEXITCODE)"
                } else {
                    Write-Change "$ext installed"
                }
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
