#Requires -Modules @{ ModuleName = 'Pester'; RequiredVersion = '5.7.1' }

BeforeAll {
    . "$PSScriptRoot\..\Helpers.ps1"

    # Read the source file content for $PackageRegistry parsing tests
    $script:SourceContent = Get-Content "$PSScriptRoot\..\Update-DevEnvironment.ps1" -Raw

    # Choco promotional filter regex (same as used in Update-DevEnvironment.ps1)
    $script:ChocoPromoFilter = 'Did you know|Enjoy using Chocolatey|chocolatey\.org/compare|licensed editions|Your support ensures|nets you some awesome'
}

Describe 'Chocolatey output parsing' {
    BeforeEach {
        Mock Write-Host {}
    }

    It 'detects "upgraded 1/1 packages" as updated' {
        $chocoOut = @"
Chocolatey v2.4.0
Upgrading the following packages:
lazygit
lazygit v0.45.0 [Approved]
lazygit package files upgrade completed.

Chocolatey upgraded 1/1 packages.
"@
        $chocoOut -match 'upgraded (\d+)/\d+ package' | Should -BeTrue
        [int]$Matches[1] | Should -BeGreaterThan 0
    }

    It 'detects "upgraded 0/1 packages" as already current' {
        $chocoOut = @"
Chocolatey v2.4.0
Upgrading the following packages:
lazygit
lazygit v0.45.0 is the latest version available based on your source(s).

Chocolatey upgraded 0/1 packages.
"@
        $chocoOut -match 'upgraded (\d+)/\d+ package' | Should -BeTrue
        [int]$Matches[1] | Should -Be 0
    }

    It 'filters "Did you know" promotional lines' {
        $line = "Did you know Chocolatey has a commercial edition?"
        "$line" -notmatch $script:ChocoPromoFilter | Should -BeFalse
    }

    It 'filters "Enjoy using Chocolatey" promotional lines' {
        $line = "Enjoy using Chocolatey? Explore more at chocolatey.org"
        "$line" -notmatch $script:ChocoPromoFilter | Should -BeFalse
    }

    It 'filters "chocolatey.org/compare" promotional lines' {
        $line = "Visit https://chocolatey.org/compare for info"
        "$line" -notmatch $script:ChocoPromoFilter | Should -BeFalse
    }

    It 'filters "licensed editions" promotional lines' {
        $line = "Check out our licensed editions for enterprise features"
        "$line" -notmatch $script:ChocoPromoFilter | Should -BeFalse
    }

    It 'filters "Your support ensures" promotional lines' {
        $line = "Your support ensures the continued development of Chocolatey"
        "$line" -notmatch $script:ChocoPromoFilter | Should -BeFalse
    }

    It 'filters "nets you some awesome" promotional lines' {
        $line = "Your purchase nets you some awesome features"
        "$line" -notmatch $script:ChocoPromoFilter | Should -BeFalse
    }

    It 'keeps non-promotional lines through the filter' {
        $line = "lazygit v0.45.0 is the latest version available"
        "$line" -notmatch $script:ChocoPromoFilter | Should -BeTrue
    }

    It 'detects failure when no upgraded line and non-zero exit code' {
        $chocoOut = "ERROR: Something went wrong during upgrade."
        $matchedUpgraded = $chocoOut -match 'upgraded (\d+)/\d+ package'
        $matchedUpgraded | Should -BeFalse
        # Script logic: if no match and $LASTEXITCODE -ne 0, it is a failure
    }
}

Describe 'winget exit code handling' {
    BeforeEach {
        Mock Write-Host {}
    }

    It 'detects exit code 0 as updated' {
        $exitCode = 0
        $wingetOut = "Successfully installed"

        # Mirrors the script logic
        $result = if ($exitCode -eq 0) { 'updated' }
                  elseif ($exitCode -eq -1978335189 -or $wingetOut -match 'No newer package versions are available') { 'current' }
                  else { 'failed' }

        $result | Should -Be 'updated'
    }

    It 'detects exit code -1978335189 as already up to date' {
        $exitCode = -1978335189
        $wingetOut = "No applicable update found."

        $result = if ($exitCode -eq 0) { 'updated' }
                  elseif ($exitCode -eq -1978335189 -or $wingetOut -match 'No newer package versions are available') { 'current' }
                  else { 'failed' }

        $result | Should -Be 'current'
    }

    It 'detects "No newer package versions are available" text as already up to date' {
        $exitCode = 1
        $wingetOut = "No newer package versions are available from configured sources."

        $result = if ($exitCode -eq 0) { 'updated' }
                  elseif ($exitCode -eq -1978335189 -or $wingetOut -match 'No newer package versions are available') { 'current' }
                  else { 'failed' }

        $result | Should -Be 'current'
    }

    It 'detects other non-zero exit code as failure' {
        $exitCode = 1
        $wingetOut = "An unexpected error occurred."

        $result = if ($exitCode -eq 0) { 'updated' }
                  elseif ($exitCode -eq -1978335189 -or $wingetOut -match 'No newer package versions are available') { 'current' }
                  else { 'failed' }

        $result | Should -Be 'failed'
    }
}

Describe 'pipx output parsing' {
    BeforeEach {
        Mock Write-Host {}
    }

    It 'detects "already at latest version" as already up to date' {
        $pipxOut = "ruff is already at latest version 0.8.6 (location: C:\pipx\venvs\ruff)"
        $pipxOut -match 'already at latest version' | Should -BeTrue
    }

    It 'detects exit code 0 without "already" text as updated' {
        $pipxOut = "upgraded package ruff to 0.9.0 (location: C:\pipx\venvs\ruff)"
        $exitCode = 0

        $alreadyCurrent = $pipxOut -match 'already at latest version'
        $alreadyCurrent | Should -BeFalse

        # Script logic: if no "already" match and exit code 0, it is updated
        $result = if ($alreadyCurrent) { 'current' }
                  elseif ($exitCode -eq 0) { 'updated' }
                  else { 'failed' }

        $result | Should -Be 'updated'
    }

    It 'detects non-zero exit code as failure' {
        $pipxOut = "Error: something went wrong"
        $exitCode = 1

        $result = if ($pipxOut -match 'already at latest version') { 'current' }
                  elseif ($exitCode -eq 0) { 'updated' }
                  else { 'failed' }

        $result | Should -Be 'failed'
    }
}

Describe 'PSFzf module update logic' {
    BeforeEach {
        Mock Write-Host {}
    }

    It 'calls Install-Module when installed version is less than available version' {
        Mock Get-Module {
            [PSCustomObject]@{ Version = [version]'2.5.0' }
        } -ParameterFilter { $Name -eq 'PSFzf' -and $ListAvailable }

        Mock Find-Module {
            [PSCustomObject]@{ Version = [version]'2.6.0' }
        } -ParameterFilter { $Name -eq 'PSFzf' }

        Mock Install-Module {} -ParameterFilter { $Name -eq 'PSFzf' }

        # Replicate the script logic
        $installed = (Get-Module PSFzf -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
        $available = (Find-Module PSFzf -ErrorAction Stop).Version
        if ($installed -lt $available) {
            Install-Module PSFzf -Force -Scope CurrentUser
            Write-Change "PSFzf updated to $available -- restart terminal to apply"
        } else {
            Write-Skip "PSFzf is already up to date ($installed)" -Track "PSFzf"
        }

        Should -Invoke Install-Module -Times 1 -ParameterFilter { $Name -eq 'PSFzf' }
    }

    It 'skips when installed version equals available version' {
        Mock Get-Module {
            [PSCustomObject]@{ Version = [version]'2.6.0' }
        } -ParameterFilter { $Name -eq 'PSFzf' -and $ListAvailable }

        Mock Find-Module {
            [PSCustomObject]@{ Version = [version]'2.6.0' }
        } -ParameterFilter { $Name -eq 'PSFzf' }

        Mock Install-Module {} -ParameterFilter { $Name -eq 'PSFzf' }

        $installed = (Get-Module PSFzf -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
        $available = (Find-Module PSFzf -ErrorAction Stop).Version
        if ($installed -lt $available) {
            Install-Module PSFzf -Force -Scope CurrentUser
            Write-Change "PSFzf updated to $available -- restart terminal to apply"
        } else {
            Write-Skip "PSFzf is already up to date ($installed)" -Track "PSFzf"
        }

        Should -Invoke Install-Module -Times 0 -ParameterFilter { $Name -eq 'PSFzf' }
    }
}

Describe '$PackageRegistry structure' {
    BeforeAll {
        # Parse $PackageRegistry from the actual file content by extracting keys
        # from lines like:  "vscode"      = @{ Manager = "choco";  Id = "vscode" }
        $script:RegistryEntries = @{}
        $pattern = '^\s*"([^"]+)"\s*=\s*@\{\s*Manager\s*=\s*"([^"]+)";\s*Id\s*=\s*"([^"]+)"'
        foreach ($line in ($script:SourceContent -split '\r?\n')) {
            if ($line -match $pattern) {
                $script:RegistryEntries[$Matches[1]] = @{
                    Manager = $Matches[2]
                    Id      = $Matches[3]
                }
            }
        }
    }

    It 'has entries parsed from the source file' {
        $script:RegistryEntries.Count | Should -BeGreaterThan 0
    }

    It 'contains the vscode entry' {
        $script:RegistryEntries.ContainsKey('vscode') | Should -BeTrue
    }

    It 'contains the ruff entry' {
        $script:RegistryEntries.ContainsKey('ruff') | Should -BeTrue
    }

    It 'contains the fzf entry' {
        $script:RegistryEntries.ContainsKey('fzf') | Should -BeTrue
    }

    It 'contains the psfzf entry' {
        $script:RegistryEntries.ContainsKey('psfzf') | Should -BeTrue
    }

    It 'contains the gh entry' {
        $script:RegistryEntries.ContainsKey('gh') | Should -BeTrue
    }

    It 'has Manager field for every entry' {
        foreach ($key in $script:RegistryEntries.Keys) {
            $script:RegistryEntries[$key].Manager | Should -Not -BeNullOrEmpty -Because "$key should have a Manager"
        }
    }

    It 'has Id field for every entry' {
        foreach ($key in $script:RegistryEntries.Keys) {
            $script:RegistryEntries[$key].Id | Should -Not -BeNullOrEmpty -Because "$key should have an Id"
        }
    }

    It 'maps vscode to choco manager' {
        $script:RegistryEntries['vscode'].Manager | Should -Be 'choco'
    }

    It 'maps fzf to winget manager' {
        $script:RegistryEntries['fzf'].Manager | Should -Be 'winget'
    }

    It 'maps ruff to pipx manager' {
        $script:RegistryEntries['ruff'].Manager | Should -Be 'pipx'
    }

    It 'maps psfzf to module manager' {
        $script:RegistryEntries['psfzf'].Manager | Should -Be 'module'
    }
}
