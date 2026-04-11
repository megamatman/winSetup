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

Describe '-NoWait switch' {
    BeforeAll {
        Mock Write-Host {}
    }

    It 'script defines -NoWait parameter' {
        $script:SourceContent | Should -Match '\[switch\]\$NoWait'
    }

    It 'outputs VSCODE_OPEN sentinel when -NoWait is set and VS Code is running' {
        # The script checks Get-Process for "Code" / "Code - Insiders"
        # and writes the sentinel via Write-Output
        $script:SourceContent | Should -Match 'VSCODE_OPEN: Close VS Code and retry the update\.'
    }

    It 'calls Wait-VSCodeClosed when -NoWait is not set' {
        # The else branch calls Wait-VSCodeClosed
        $script:SourceContent | Should -Match 'else\s*\{\s*\r?\n\s*Wait-VSCodeClosed'
    }
}

Describe 'VSCODE_OPEN sentinel (functional)' {
    BeforeAll {
        $script:ScriptPath = (Resolve-Path "$PSScriptRoot\..\Update-DevEnvironment.ps1").Path
        $escaped = $script:ScriptPath -replace "'", "''"
    }

    It 'emits the sentinel string when -NoWait is set and VS Code is running' {
        # Run the script in a subprocess with a mock Get-Process that reports
        # VS Code as running. The script should emit the sentinel and exit 0.
        $output = pwsh -NoProfile -NonInteractive -Command "
            function Get-Process {
                param([string[]]`$Name, [System.Management.Automation.ActionPreference]`$ErrorAction = 'Continue')
                if (`$Name -and (`$Name -contains 'Code' -or `$Name -contains 'Code - Insiders')) {
                    return [PSCustomObject]@{ Name = 'Code'; Id = 99999 }
                }
                Microsoft.PowerShell.Management\Get-Process @PSBoundParameters
            }
            & '$escaped' -NoWait
        " 2>&1

        $global:LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'VSCODE_OPEN'
    }

    It 'does not emit the sentinel when -NoWait is set but VS Code is not running' {
        # Mock Get-Process to return nothing for VS Code names.
        # Pass -Package with a nonexistent name so the script exits quickly
        # after the sentinel check (it prints "Unknown package" and exits 1).
        $output = pwsh -NoProfile -NonInteractive -Command "
            function Get-Process {
                param([string[]]`$Name, [System.Management.Automation.ActionPreference]`$ErrorAction = 'Continue')
                if (`$Name -and (`$Name -contains 'Code' -or `$Name -contains 'Code - Insiders')) {
                    return `$null
                }
                Microsoft.PowerShell.Management\Get-Process @PSBoundParameters
            }
            & '$escaped' -NoWait -Package 'nonexistent_test_package'
        " 2>&1

        ($output -join "`n") | Should -Not -Match 'VSCODE_OPEN'
    }

    It 'exits with code 0 when the sentinel is emitted' {
        $null = pwsh -NoProfile -NonInteractive -Command "
            function Get-Process {
                param([string[]]`$Name, [System.Management.Automation.ActionPreference]`$ErrorAction = 'Continue')
                if (`$Name -and (`$Name -contains 'Code' -or `$Name -contains 'Code - Insiders')) {
                    return [PSCustomObject]@{ Name = 'Code'; Id = 99999 }
                }
                Microsoft.PowerShell.Management\Get-Process @PSBoundParameters
            }
            & '$escaped' -NoWait
        " 2>&1

        $global:LASTEXITCODE | Should -Be 0
    }

    It 'sentinel output includes the expected message text' {
        $output = pwsh -NoProfile -NonInteractive -Command "
            function Get-Process {
                param([string[]]`$Name, [System.Management.Automation.ActionPreference]`$ErrorAction = 'Continue')
                if (`$Name -and (`$Name -contains 'Code' -or `$Name -contains 'Code - Insiders')) {
                    return [PSCustomObject]@{ Name = 'Code'; Id = 99999 }
                }
                Microsoft.PowerShell.Management\Get-Process @PSBoundParameters
            }
            & '$escaped' -NoWait
        " 2>&1

        ($output -join "`n") | Should -Match 'VSCODE_OPEN: Close VS Code and retry the update\.'
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

# ---------------------------------------------------------------------------
# Direct unit tests for Invoke-*Update helper functions.
# These call the actual functions with mocked external commands, unlike the
# inline parsing tests above which reimplement the logic in the test.
# ---------------------------------------------------------------------------

Describe 'Invoke-ChocoUpdate' {
    BeforeAll {
        # Extract the function from source via AST to avoid executing
        # top-level code (Start-Transcript, elevation check, etc.)
        $scriptPath = "$PSScriptRoot\..\Update-DevEnvironment.ps1"
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $scriptPath, [ref]$tokens, [ref]$errors)
        $funcAst = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'Invoke-ChocoUpdate'
        }, $false) | Select-Object -First 1
        . ([scriptblock]::Create($funcAst.Extent.Text))
    }

    It 'returns Updated when choco reports upgraded 1/1 packages' {
        Mock choco {
            $global:LASTEXITCODE = 0
            "Chocolatey upgraded 1/1 packages."
        }
        $r = Invoke-ChocoUpdate -Id 'lazygit'
        $r.Status | Should -Be 'Updated'
    }

    It 'returns UpToDate when choco reports upgraded 0/1 packages' {
        Mock choco {
            $global:LASTEXITCODE = 0
            "lazygit v0.45.0 is the latest version available."
            "Chocolatey upgraded 0/1 packages."
        }
        $r = Invoke-ChocoUpdate -Id 'lazygit'
        $r.Status | Should -Be 'UpToDate'
    }

    It 'returns Failed when no upgrade line and non-zero exit code' {
        Mock choco {
            $global:LASTEXITCODE = 1
            "ERROR: Something went wrong."
        }
        $r = Invoke-ChocoUpdate -Id 'lazygit'
        $r.Status | Should -Be 'Failed'
        $r.Detail | Should -Match 'exit 1'
    }

    It 'returns Updated when no upgrade line but exit code is zero' {
        Mock choco {
            $global:LASTEXITCODE = 0
            "Some unexpected output without the upgraded line."
        }
        $r = Invoke-ChocoUpdate -Id 'lazygit'
        $r.Status | Should -Be 'Updated'
    }

    It 'filters choco promotional output from the result' {
        Mock choco {
            $global:LASTEXITCODE = 0
            "Chocolatey upgraded 1/1 packages."
            "Did you know Chocolatey has a commercial edition?"
            "Enjoy using Chocolatey? Explore more at chocolatey.org"
        }
        $r = Invoke-ChocoUpdate -Id 'lazygit'
        $r.Output | Should -Not -Match 'Did you know'
        $r.Output | Should -Not -Match 'Enjoy using Chocolatey'
    }

    It 'returns a hashtable with Status, Output, and Detail keys' {
        Mock choco {
            $global:LASTEXITCODE = 0
            "Chocolatey upgraded 1/1 packages."
        }
        $r = Invoke-ChocoUpdate -Id 'lazygit'
        $r.Keys | Should -Contain 'Status'
        $r.Keys | Should -Contain 'Output'
        $r.Keys | Should -Contain 'Detail'
    }
}

Describe 'Invoke-WingetUpdate' {
    BeforeAll {
        $scriptPath = "$PSScriptRoot\..\Update-DevEnvironment.ps1"
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $scriptPath, [ref]$tokens, [ref]$errors)
        $funcAst = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'Invoke-WingetUpdate'
        }, $false) | Select-Object -First 1
        . ([scriptblock]::Create($funcAst.Extent.Text))
    }

    It 'returns Updated when exit code is 0' {
        Mock winget {
            $global:LASTEXITCODE = 0
            "Successfully installed"
        }
        $r = Invoke-WingetUpdate -Id 'junegunn.fzf'
        $r.Status | Should -Be 'Updated'
    }

    It 'returns UpToDate when exit code is -1978335189' {
        Mock winget {
            $global:LASTEXITCODE = -1978335189
            "No applicable update found."
        }
        $r = Invoke-WingetUpdate -Id 'junegunn.fzf'
        $r.Status | Should -Be 'UpToDate'
    }

    It 'returns UpToDate when output contains "No newer package versions"' {
        Mock winget {
            $global:LASTEXITCODE = 1
            "No newer package versions are available from configured sources."
        }
        $r = Invoke-WingetUpdate -Id 'junegunn.fzf'
        $r.Status | Should -Be 'UpToDate'
    }

    It 'returns Failed for other non-zero exit codes' {
        Mock winget {
            $global:LASTEXITCODE = 1
            "An unexpected error occurred."
        }
        $r = Invoke-WingetUpdate -Id 'junegunn.fzf'
        $r.Status | Should -Be 'Failed'
        $r.Detail | Should -Match 'exit 1'
    }

    It 'filters spinner lines from output' {
        Mock winget {
            $global:LASTEXITCODE = 0
            "Downloading package..."
            " - \ | / "
            "Successfully installed"
        }
        $r = Invoke-WingetUpdate -Id 'junegunn.fzf'
        $r.Output | Should -Not -Match '^\s*[-\\|/]+\s*$'
    }

    It 'returns a hashtable with Status, Output, and Detail keys' {
        Mock winget {
            $global:LASTEXITCODE = 0
            "Done"
        }
        $r = Invoke-WingetUpdate -Id 'junegunn.fzf'
        $r.Keys | Should -Contain 'Status'
        $r.Keys | Should -Contain 'Output'
        $r.Keys | Should -Contain 'Detail'
    }
}

Describe 'Invoke-PipxUpdate' {
    BeforeAll {
        $scriptPath = "$PSScriptRoot\..\Update-DevEnvironment.ps1"
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $scriptPath, [ref]$tokens, [ref]$errors)
        $funcAst = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'Invoke-PipxUpdate'
        }, $false) | Select-Object -First 1
        . ([scriptblock]::Create($funcAst.Extent.Text))
    }

    It 'returns UpToDate when output contains "already at latest version"' {
        Mock pipx {
            $global:LASTEXITCODE = 0
            "ruff is already at latest version 0.8.6 (location: C:\pipx\venvs\ruff)"
        }
        $r = Invoke-PipxUpdate -Id 'ruff'
        $r.Status | Should -Be 'UpToDate'
    }

    It 'returns Updated when exit code is 0 and no "already" text' {
        Mock pipx {
            $global:LASTEXITCODE = 0
            "upgraded package ruff to 0.9.0 (location: C:\pipx\venvs\ruff)"
        }
        $r = Invoke-PipxUpdate -Id 'ruff'
        $r.Status | Should -Be 'Updated'
    }

    It 'returns Failed when exit code is non-zero' {
        Mock pipx {
            $global:LASTEXITCODE = 1
            "Error: something went wrong"
        }
        $r = Invoke-PipxUpdate -Id 'ruff'
        $r.Status | Should -Be 'Failed'
        $r.Detail | Should -Match 'exit 1'
    }

    It 'returns a hashtable with Status, Output, and Detail keys' {
        Mock pipx {
            $global:LASTEXITCODE = 0
            "upgraded package ruff to 0.9.0"
        }
        $r = Invoke-PipxUpdate -Id 'ruff'
        $r.Keys | Should -Contain 'Status'
        $r.Keys | Should -Contain 'Output'
        $r.Keys | Should -Contain 'Detail'
    }
}

Describe 'Invoke-ModuleUpdate' {
    BeforeAll {
        $scriptPath = "$PSScriptRoot\..\Update-DevEnvironment.ps1"
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $scriptPath, [ref]$tokens, [ref]$errors)
        $funcAst = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'Invoke-ModuleUpdate'
        }, $false) | Select-Object -First 1
        . ([scriptblock]::Create($funcAst.Extent.Text))
    }

    It 'returns NotInstalled when Get-Module returns nothing' {
        Mock Get-Module { $null } -ParameterFilter { $Name -eq 'PSFzf' -and $ListAvailable }
        $r = Invoke-ModuleUpdate -Id 'PSFzf'
        $r.Status | Should -Be 'NotInstalled'
    }

    It 'returns Updated when installed version is less than available' {
        Mock Get-Module {
            [PSCustomObject]@{ Version = [version]'2.5.0' }
        } -ParameterFilter { $Name -eq 'PSFzf' -and $ListAvailable }
        Mock Find-Module {
            [PSCustomObject]@{ Version = [version]'2.6.0' }
        }
        Mock Install-Module {}

        $r = Invoke-ModuleUpdate -Id 'PSFzf'
        $r.Status | Should -Be 'Updated'
        $r.Detail | Should -Be '2.6.0'
        Should -Invoke Install-Module -Times 1
    }

    It 'returns UpToDate when installed version equals available' {
        Mock Get-Module {
            [PSCustomObject]@{ Version = [version]'2.6.0' }
        } -ParameterFilter { $Name -eq 'PSFzf' -and $ListAvailable }
        Mock Find-Module {
            [PSCustomObject]@{ Version = [version]'2.6.0' }
        }
        Mock Install-Module {}

        $r = Invoke-ModuleUpdate -Id 'PSFzf'
        $r.Status | Should -Be 'UpToDate'
        $r.Detail | Should -Be '2.6.0'
        Should -Invoke Install-Module -Times 0
    }

    It 'returns UpToDate when installed version is greater than available' {
        Mock Get-Module {
            [PSCustomObject]@{ Version = [version]'2.7.0' }
        } -ParameterFilter { $Name -eq 'PSFzf' -and $ListAvailable }
        Mock Find-Module {
            [PSCustomObject]@{ Version = [version]'2.6.0' }
        }
        Mock Install-Module {}

        $r = Invoke-ModuleUpdate -Id 'PSFzf'
        $r.Status | Should -Be 'UpToDate'
        Should -Invoke Install-Module -Times 0
    }

    It 'returns Failed when Find-Module throws' {
        Mock Get-Module {
            [PSCustomObject]@{ Version = [version]'2.5.0' }
        } -ParameterFilter { $Name -eq 'PSFzf' -and $ListAvailable }
        Mock Find-Module { throw "PSGallery unreachable" }

        $r = Invoke-ModuleUpdate -Id 'PSFzf'
        $r.Status | Should -Be 'Failed'
        $r.Detail | Should -Match 'PSGallery unreachable'
    }

    It 'returns a hashtable with Status, Output, and Detail keys' {
        Mock Get-Module { $null } -ParameterFilter { $Name -eq 'PSFzf' -and $ListAvailable }
        $r = Invoke-ModuleUpdate -Id 'PSFzf'
        $r.Keys | Should -Contain 'Status'
        $r.Keys | Should -Contain 'Output'
        $r.Keys | Should -Contain 'Detail'
    }
}

Describe 'Invoke-PyenvUpdate' {
    BeforeAll {
        $scriptPath = "$PSScriptRoot\..\Update-DevEnvironment.ps1"
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $scriptPath, [ref]$tokens, [ref]$errors)
        $funcAst = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'Invoke-PyenvUpdate'
        }, $false) | Select-Object -First 1
        . ([scriptblock]::Create($funcAst.Extent.Text))
    }

    It 'returns Updated when pip exits with code 0' {
        Mock pip {
            $global:LASTEXITCODE = 0
            "Successfully installed pyenv-win-3.1.1"
        }
        $r = Invoke-PyenvUpdate
        $r.Status | Should -Be 'Updated'
    }

    It 'returns Failed when pip exits with non-zero code' {
        Mock pip {
            $global:LASTEXITCODE = 1
            "ERROR: Could not install packages"
            "Some additional error context"
            "Final error line"
        }
        $r = Invoke-PyenvUpdate
        $r.Status | Should -Be 'Failed'
        $r.Detail | Should -Not -BeNullOrEmpty
    }

    It 'includes the last 3 lines of output in Detail on failure' {
        Mock pip {
            $global:LASTEXITCODE = 1
            "Line 1"
            "Line 2"
            "Line 3"
            "Line 4"
            "Line 5"
        }
        $r = Invoke-PyenvUpdate
        $r.Status | Should -Be 'Failed'
        $r.Detail | Should -Match 'Line 3'
        $r.Detail | Should -Match 'Line 4'
        $r.Detail | Should -Match 'Line 5'
    }

    It 'returns a hashtable with Status, Output, and Detail keys' {
        Mock pip {
            $global:LASTEXITCODE = 0
            "OK"
        }
        $r = Invoke-PyenvUpdate
        $r.Keys | Should -Contain 'Status'
        $r.Keys | Should -Contain 'Output'
        $r.Keys | Should -Contain 'Detail'
    }
}
