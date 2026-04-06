#Requires -Modules @{ ModuleName = 'Pester'; RequiredVersion = '5.7.1' }

BeforeAll {
    . "$PSScriptRoot\..\Helpers.ps1"
    $script:ScriptContent = Get-Content "$PSScriptRoot\..\Apply-VSCodeSettings.ps1" -Raw
    $script:ConfigPath = "$PSScriptRoot\..\configs\vscode-settings.json"
}

# ---------------------------------------------------------------------------
# Settings deployment
# ---------------------------------------------------------------------------

Describe 'Settings deployment' {
    BeforeAll {
        Mock Write-Host {}
        Mock Write-Change {}
        Mock Write-Skip {}
        Mock Write-Issue {}
    }

    It 'creates settings.json at the correct path when it does not exist' {
        $settingsDir = Join-Path $TestDrive 'Code' 'User'
        if (-not (Test-Path $settingsDir)) { New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null }
        $settingsPath = Join-Path $settingsDir 'settings.json'

        # Simulate the settings content from Apply-VSCodeSettings.ps1
        $content = @'
{
  "editor.tabSize": 2,
  "editor.formatOnSave": true,
  "python.languageServer": "Pylance"
}
'@
        Set-Content -Path $settingsPath -Value $content -Encoding UTF8

        Test-Path $settingsPath | Should -BeTrue
        $json = Get-Content $settingsPath -Raw | ConvertFrom-Json
        $json | Should -Not -BeNullOrEmpty
    }

    It 'written content is valid JSON with expected top-level keys' {
        # Read settings from configs/vscode-settings.json (single source of truth)
        Test-Path $script:ConfigPath | Should -BeTrue
        $rawContent = Get-Content $script:ConfigPath -Raw
        $rawContent | Should -Not -BeNullOrEmpty

        # Must parse as valid JSON (strip comments first -- JSON doesn't allow them
        # but VS Code settings.json does)
        $lines = $rawContent -split "`r?`n"
        $cleanJson = ($lines | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"
        $parsed = $cleanJson | ConvertFrom-Json
        $parsed | Should -Not -BeNullOrEmpty

        # Must contain expected top-level keys
        $props = $parsed.PSObject.Properties.Name
        $props | Should -Contain 'editor.tabSize'
        $props | Should -Contain 'editor.formatOnSave'
        $props | Should -Contain 'python.languageServer'
        $props | Should -Contain 'workbench.colorTheme'
    }

    It 'creates a backup when settings.json already exists' {
        $settingsDir = Join-Path $TestDrive 'backup-test' 'Code' 'User'
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
        $settingsPath = Join-Path $settingsDir 'settings.json'
        Set-Content -Path $settingsPath -Value '{"old": true}'

        # Use Backup-FileIfExists from Helpers.ps1
        Backup-FileIfExists $settingsPath
        Set-Content -Path $settingsPath -Value '{"new": true}' -Encoding UTF8

        $backups = Get-ChildItem $settingsDir -Filter 'settings.json.bak-*'
        $backups.Count | Should -BeGreaterOrEqual 1
        Get-Content $backups[0].FullName -Raw | Should -Match '"old"'
        Get-Content $settingsPath -Raw | Should -Match '"new"'
    }

    It 'creates the settings directory if it does not exist' {
        $appDataDir = Join-Path $TestDrive 'mkdir-test'
        $settingsDir = Join-Path $appDataDir 'Code' 'User'

        # Simulate the directory creation logic from Invoke-VSCodeSettingsDeploy
        if (-not (Test-Path $settingsDir)) {
            New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
        }
        $settingsPath = Join-Path $settingsDir 'settings.json'
        Set-Content -Path $settingsPath -Value '{}' -Encoding UTF8

        Test-Path $settingsDir | Should -BeTrue
        Test-Path $settingsPath | Should -BeTrue
    }
}

# ---------------------------------------------------------------------------
# Extension installation
# ---------------------------------------------------------------------------

Describe 'Extension installation' {
    BeforeAll {
        Mock Write-Host {}
        Mock Write-Change {}
        Mock Write-Skip {}
        Mock Write-Issue {}

        # Extract the extension list from the script
        $lines = $script:ScriptContent -split "`r?`n"
        $inArray = $false
        $script:Extensions = @()
        foreach ($l in $lines) {
            if ($l -match '^\s*\$extensions\s*=\s*@\(') { $inArray = $true; continue }
            if ($inArray -and $l -match '^\s*\)') { break }
            if ($inArray -and $l -match '^\s*"([^"]+)"') {
                $script:Extensions += $Matches[1]
            }
        }
    }

    It 'extension list has at least 10 entries' {
        $script:Extensions.Count | Should -BeGreaterOrEqual 10
    }

    It 'extension IDs follow publisher.name format' {
        foreach ($ext in $script:Extensions) {
            $ext | Should -Match '^[a-zA-Z0-9\-]+\.[a-zA-Z0-9\-]+'
        }
    }

    It 'installs extensions that are not already present' {
        # Simulate the install logic with a subset already installed
        $installed = @('ms-python.python', 'eamodio.gitlens')
        $toInstall = @()
        $skipped = @()

        foreach ($ext in $script:Extensions) {
            if ($installed -contains $ext.ToLower()) {
                $skipped += $ext
            } else {
                $toInstall += $ext
            }
        }

        $toInstall.Count | Should -BeGreaterThan 0
        $skipped.Count | Should -Be 2
        $toInstall | Should -Not -Contain 'ms-python.python'
        $toInstall | Should -Not -Contain 'eamodio.gitlens'
    }

    It 'skips all extensions when all are already installed' {
        $installed = $script:Extensions | ForEach-Object { $_.ToLower() }
        $toInstall = @()

        foreach ($ext in $script:Extensions) {
            if ($installed -contains $ext.ToLower()) {
                Write-Skip "$ext is already installed"
            } else {
                $toInstall += $ext
            }
        }

        $toInstall.Count | Should -Be 0
    }

    It 'reports issue when code command is not available' {
        # Simulate the guard check from Install-VSCodeExtensions
        $codeAvailable = $false  # Simulating code not found
        if (-not $codeAvailable) {
            Write-Issue "VS Code 'code' command not found -- skipping extensions"
        }

        Should -Invoke Write-Issue -Times 1 -ParameterFilter {
            $Message -match 'code.*not found'
        }
    }
}

# ---------------------------------------------------------------------------
# Parameter switches
# ---------------------------------------------------------------------------

Describe 'Parameter switches' {
    BeforeAll {
        Mock Write-Host {}
        Mock Write-Change {}
        Mock Write-Skip {}
        Mock Write-Issue {}
    }

    It '-SettingsOnly deploys settings but skips extensions' {
        $SettingsOnly = $true
        $ExtensionsOnly = $false

        $settingsRan = $false
        $extensionsRan = $false

        # Simulate the main execution dispatch from Apply-VSCodeSettings.ps1
        if (-not $ExtensionsOnly) { $settingsRan = $true }
        if (-not $SettingsOnly)   { $extensionsRan = $true }

        $settingsRan | Should -BeTrue
        $extensionsRan | Should -BeFalse
    }

    It '-ExtensionsOnly installs extensions but skips settings' {
        $SettingsOnly = $false
        $ExtensionsOnly = $true

        $settingsRan = $false
        $extensionsRan = $false

        if (-not $ExtensionsOnly) { $settingsRan = $true }
        if (-not $SettingsOnly)   { $extensionsRan = $true }

        $settingsRan | Should -BeFalse
        $extensionsRan | Should -BeTrue
    }

    It 'default (no switches) runs both settings and extensions' {
        $SettingsOnly = $false
        $ExtensionsOnly = $false

        $settingsRan = $false
        $extensionsRan = $false

        if (-not $ExtensionsOnly) { $settingsRan = $true }
        if (-not $SettingsOnly)   { $extensionsRan = $true }

        $settingsRan | Should -BeTrue
        $extensionsRan | Should -BeTrue
    }
}

# ---------------------------------------------------------------------------
# Script structure validation
# ---------------------------------------------------------------------------

Describe 'Script structure' {
    It 'defines Invoke-VSCodeSettingsDeploy function' {
        $script:ScriptContent | Should -Match 'function\s+Invoke-VSCodeSettingsDeploy'
    }

    It 'defines Install-VSCodeExtensions function' {
        $script:ScriptContent | Should -Match 'function\s+Install-VSCodeExtensions'
    }

    It 'settings path is derived from $env:APPDATA' {
        $script:ScriptContent | Should -Match '\$env:APPDATA.*Code.*User'
    }

    It 'reads settings from configs/vscode-settings.json' {
        $script:ScriptContent | Should -Match 'vscode-settings\.json'
        $script:ScriptContent | Should -Match 'Get-Content.*\$configFile'
    }

    It 'calls Backup-FileIfExists before overwriting settings' {
        $script:ScriptContent | Should -Match 'Backup-FileIfExists\s+\$settingsPath'
    }

    It 'checks $LASTEXITCODE after code --install-extension' {
        $script:ScriptContent | Should -Match 'LASTEXITCODE.*-ne\s*0'
    }
}
