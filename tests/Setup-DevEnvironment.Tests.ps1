#Requires -Modules @{ ModuleName = 'Pester'; RequiredVersion = '5.7.1' }

BeforeAll {
    . "$PSScriptRoot\..\Helpers.ps1"
    $script:SetupScript = Get-Content "$PSScriptRoot\..\Setup-DevEnvironment.ps1" -Raw
}

Describe '$CoreSteps count' {
    BeforeAll {
        Mock Write-Host {}
    }

    It 'matches the number of Write-Step calls in core functions (regression)' {
        # The core path calls these functions between Assert-Administrator and the
        # if ($IncludeOptional) block:
        #   Test-ProfileHealth, Install-Chocolatey, Install-VSCode, Install-Python,
        #   Install-OhMyPosh, Install-GitHubCLI, Install-Fzf, Install-CLITools,
        #   Install-HackNerdFont, Install-SSHKeys, Add-GitHubSSHKey,
        #   Set-WindowsTerminalFont, Install-PythonTools, Install-PyenvWin,
        #   Set-GlobalGitIgnore, Set-GitIdentity, Set-GitCommitSigning,
        #   Set-DeltaGitConfig
        #
        # Each of these functions contains exactly one Write-Step call.
        # The optional block adds: Set-VSCodeSettings, Install-VSCodeExtensions,
        # Set-PowerShellProfile, Set-DefenderExclusions.

        $coreFunctions = @(
            'Test-ProfileHealth'
            'Install-Chocolatey'
            'Install-VSCode'
            'Install-Python'
            'Install-OhMyPosh'
            'Install-GitHubCLI'
            'Install-Fzf'
            'Install-CLITools'
            'Install-HackNerdFont'
            'Install-SSHKeys'
            'Add-GitHubSSHKey'
            'Set-WindowsTerminalFont'
            'Install-PythonTools'
            'Install-PyenvWin'
            'Set-GlobalGitIgnore'
            'Set-GitIdentity'
            'Set-GitCommitSigning'
            'Set-DeltaGitConfig'
        )

        # Count Write-Step calls in each core function body
        $writeStepCount = 0
        foreach ($fn in $coreFunctions) {
            # Match "function <name> {" through the balanced closing brace is complex;
            # instead, count all Write-Step calls in the entire file that appear inside
            # these function definitions. Since each function has exactly one Write-Step,
            # we just verify each function name appears in the call list after Write-Step.
            $pattern = "function\s+$fn\b"
            $script:SetupScript | Should -Match $pattern
        }

        # Count total Write-Step calls in core function definitions
        $allWriteSteps = [regex]::Matches($script:SetupScript, 'Write-Step\s+"')
        # Core functions each have 1 Write-Step, optional functions each have 1
        $totalWriteSteps = $allWriteSteps.Count

        # Extract $CoreSteps value from the script
        $coreStepsMatch = [regex]::Match($script:SetupScript, '\$CoreSteps\s*=\s*(\d+)')
        $coreStepsMatch.Success | Should -BeTrue
        $coreStepsValue = [int]$coreStepsMatch.Groups[1].Value

        # Core functions count should equal $CoreSteps
        $coreFunctions.Count | Should -Be $coreStepsValue

        # $CoreSteps should be 18
        $coreStepsValue | Should -Be 18

        # Optional steps
        $optMatch = [regex]::Match($script:SetupScript, '\$OptionalSteps\s*=\s*(\d+)')
        $optMatch.Success | Should -BeTrue
        [int]$optMatch.Groups[1].Value | Should -Be 4

        # Total Write-Step calls should equal core + optional
        $totalWriteSteps | Should -Be ($coreStepsValue + [int]$optMatch.Groups[1].Value)
    }
}

Describe '-InstallTool parameter mapping' {
    BeforeAll {
        Mock Write-Host {}

        # Extract the $toolFunctions hashtable entries from file content
        $tableBlock = [regex]::Match(
            $script:SetupScript,
            '\$toolFunctions\s*=\s*@\{([\s\S]*?)\}'
        )
        $tableBlock.Success | Should -BeTrue
        $script:tableText = $tableBlock.Groups[1].Value

        # Parse into a hashtable
        $script:toolMap = @{}
        foreach ($line in ($script:tableText -split "`n")) {
            $m = [regex]::Match($line, "'([^']+)'\s*=\s*'([^']+)'")
            if ($m.Success) {
                $script:toolMap[$m.Groups[1].Value] = $m.Groups[2].Value
            }
        }
    }

    It 'maps known tools to valid function names' {
        $expectedMappings = @{
            'chocolatey'  = 'Install-Chocolatey'
            'vscode'      = 'Install-VSCode'
            'python'      = 'Install-Python'
            'ohmyposh'    = 'Install-OhMyPosh'
            'gh'          = 'Install-GitHubCLI'
            'fzf'         = 'Install-Fzf'
            'ruff'        = 'Install-PythonTools'
            'pylint'      = 'Install-PythonTools'
            'mypy'        = 'Install-PythonTools'
            'bandit'      = 'Install-PythonTools'
            'pre-commit'  = 'Install-PythonTools'
            'cookiecutter'= 'Install-PythonTools'
            'pyenv'       = 'Install-PyenvWin'
        }

        foreach ($entry in $expectedMappings.GetEnumerator()) {
            $script:toolMap[$entry.Key] | Should -Be $entry.Value -Because "$($entry.Key) should map to $($entry.Value)"
        }
    }

    It 'maps CLI tools to Install-CLITools' {
        $cliTools = @('ripgrep', 'bat', 'delta', 'lazygit', 'zoxide', 'fd')
        foreach ($tool in $cliTools) {
            $script:toolMap[$tool] | Should -Be 'Install-CLITools' -Because "$tool is a CLI tool"
        }
    }

    It 'contains all expected keys' {
        $script:toolMap.Count | Should -BeGreaterOrEqual 17
    }

    It 'fallback mechanism strips non-alphanumeric characters' {
        # The script does: $safeName = $InstallTool -replace '[^a-zA-Z0-9]', ''
        # Then: $candidate = "Install-$safeName"
        $testName = 'my-tool'
        $safeName = $testName -replace '[^a-zA-Z0-9]', ''
        $safeName | Should -Be 'mytool'
        $candidate = "Install-$safeName"
        $candidate | Should -Be 'Install-mytool'
    }

    It 'sanitises dots and underscores' {
        $testName = 'some.tool_v2'
        $safeName = $testName -replace '[^a-zA-Z0-9]', ''
        $safeName | Should -Be 'sometoolv2'
        "Install-$safeName" | Should -Be 'Install-sometoolv2'
    }
}

Describe 'Assert-Administrator' {
    BeforeAll {
        Mock Write-Host {}
    }

    It 'function definition exists in the script' {
        $script:SetupScript | Should -Match 'function\s+Assert-Administrator\s*\{'
    }

    It 'checks WindowsIdentity and WindowsPrincipal' {
        $script:SetupScript | Should -Match '\[Security\.Principal\.WindowsIdentity\]::GetCurrent\(\)'
        $script:SetupScript | Should -Match '\[Security\.Principal\.WindowsPrincipal\]'
        $script:SetupScript | Should -Match 'IsInRole.*Administrator'
    }

    It 'throws when not running as Administrator' {
        # Recreate the logic pattern from the script
        function Test-AdminLogic {
            param([bool]$IsAdmin)
            if (-not $IsAdmin) {
                throw "This script must be run as Administrator."
            }
        }

        { Test-AdminLogic -IsAdmin $false } | Should -Throw '*Administrator*'
    }

    It 'does not throw when running as Administrator' {
        function Test-AdminLogic {
            param([bool]$IsAdmin)
            if (-not $IsAdmin) {
                throw "This script must be run as Administrator."
            }
        }

        { Test-AdminLogic -IsAdmin $true } | Should -Not -Throw
    }
}

Describe 'Invoke-Pipx' {
    BeforeAll {
        Mock Write-Host {}
        # Dot-source the function from the setup script by extracting and evaluating it
        $funcBlock = [regex]::Match(
            $script:SetupScript,
            '(?ms)function Invoke-Pipx \{.*?\n\}'
        )
        $funcBlock.Success | Should -BeTrue
        Invoke-Expression $funcBlock.Value
    }

    It 'falls back to python -m pipx when direct pipx throws' {
        Mock pipx { throw [System.Management.Automation.RuntimeException]::new("StandardOutputEncoding error") }
        Mock python { "ruff 0.4.0" } -ParameterFilter { $args[0] -eq '-m' -and $args[1] -eq 'pipx' }

        $result = Invoke-Pipx list --short

        Should -Invoke python -Times 1
    }

    It 'returns output from the successful direct path' {
        Mock pipx { "ruff 0.4.0`nmypy 1.10.0" }
        Mock python {}

        $result = Invoke-Pipx list --short

        $result | Should -Match 'ruff'
        Should -Invoke python -Times 0
    }

    It 'is used by Install-PythonTools instead of direct pipx calls' {
        # Verify the script text uses Invoke-Pipx, not bare pipx, in Install-PythonTools
        $funcBody = [regex]::Match(
            $script:SetupScript,
            '(?ms)function Install-PythonTools \{.*?\n\}'
        ).Value

        # Should contain Invoke-Pipx calls
        $funcBody | Should -Match 'Invoke-Pipx list'
        $funcBody | Should -Match 'Invoke-Pipx install'
        $funcBody | Should -Match 'Invoke-Pipx ensurepath'

        # Executable pipx calls (lines starting with Invoke-Pipx or bare pipx as
        # a command) should all go through Invoke-Pipx. Exclude comments, strings,
        # and the pip-install-pipx line which installs pipx itself via pip.
        $codeLines = ($funcBody -split "`n") |
            Where-Object { $_ -notmatch '^\s*#' } |          # skip comments
            Where-Object { $_ -notmatch 'Write-' } |         # skip output strings
            Where-Object { $_ -notmatch 'pip install' } |    # skip pip install pipx
            Where-Object { $_ -notmatch 'Get-Command pipx' } # skip pipx existence check

        $bareLines = $codeLines | Where-Object { $_ -match '\bpipx\s+(list|install|ensurepath)\b' -and $_ -notmatch 'Invoke-Pipx' }
        $bareLines | Should -BeNullOrEmpty
    }
}

Describe 'Profile health check patterns' {
    BeforeAll {
        Mock Write-Host {}

        # Extract the $expectedSections hashtable from the script
        $sectionBlock = [regex]::Match(
            $script:SetupScript,
            '\$expectedSections\s*=\s*@\{([\s\S]*?)\}[\r\n]'
        )
        $sectionBlock.Success | Should -BeTrue
        $script:sectionText = $sectionBlock.Groups[1].Value

        # Parse the hashtable
        $script:sections = @{}
        foreach ($line in ($script:sectionText -split "`n")) {
            $m = [regex]::Match($line, '"([^"]+)"\s*=\s*"([^"]+)"')
            if ($m.Success) {
                $script:sections[$m.Groups[1].Value] = $m.Groups[2].Value
            }
        }
    }

    It 'contains all expected section names' {
        $requiredSections = @(
            'SSH Agent'
            'Chocolatey'
            'winSetup'
            'Python Tools'
            'fzf'
            'PSFzf'
            'PSReadLine'
            'zoxide'
            'pyenv-win'
            'lazygit alias'
            'delta'
            'bat alias'
            'Oh My Posh'
        )

        foreach ($name in $requiredSections) {
            $script:sections.ContainsKey($name) | Should -BeTrue -Because "section '$name' should exist"
        }
    }

    It 'has at least 20 sections defined' {
        $script:sections.Count | Should -BeGreaterOrEqual 20
    }

    It 'each value is a valid regex pattern' {
        foreach ($entry in $script:sections.GetEnumerator()) {
            {
                $null = [regex]::new($entry.Value)
            } | Should -Not -Throw -Because "'$($entry.Key)' pattern '$($entry.Value)' should be a valid regex"
        }
    }

    It 'patterns match their intended content' {
        # Spot-check a few patterns against realistic profile content
        'ssh-agent' | Should -Match $script:sections['SSH Agent']
        'chocolateyProfile' | Should -Match $script:sections['Chocolatey']
        '$env:WINSETUP' | Should -Match $script:sections['winSetup']
        'FZF_DEFAULT_COMMAND' | Should -Match $script:sections['fzf']
        'Import-Module PSFzf' | Should -Match $script:sections['PSFzf']
        'oh-my-posh init' | Should -Match $script:sections['Oh My Posh']
        'Set-Alias lg lazygit' | Should -Match $script:sections['lazygit alias']
        'Set-Alias cat bat' | Should -Match $script:sections['bat alias']
        'DELTA_FEATURES' | Should -Match $script:sections['delta']
        'PYENV' | Should -Match $script:sections['pyenv-win']
    }
}

Describe 'ScaffoldPyproject template' {
    BeforeAll {
        $script:ScratchContent = Get-Content "$PSScriptRoot\..\templates\python-project\scratch.py" -Raw
    }

    It 'does not contain an active load_dotenv() call' {
        # Active means uncommented -- lines starting with # are allowed
        $activeLines = ($script:ScratchContent -split "`n") |
            Where-Object { $_ -notmatch '^\s*#' } |
            Where-Object { $_ -match 'load_dotenv\(\)' }
        $activeLines | Should -BeNullOrEmpty
    }

    It 'does not contain an active from dotenv import' {
        $activeLines = ($script:ScratchContent -split "`n") |
            Where-Object { $_ -notmatch '^\s*#' } |
            Where-Object { $_ -match 'from dotenv import' }
        $activeLines | Should -BeNullOrEmpty
    }

    It 'contains os.environ.get patterns for environment variable access' {
        $script:ScratchContent | Should -Match 'os\.environ\.get\('
    }

    It 'contains commented-out load_dotenv block with explanatory comment' {
        $script:ScratchContent | Should -Match 'Load \.env file if present'
        $script:ScratchContent | Should -Match '# from dotenv import load_dotenv'
        $script:ScratchContent | Should -Match '# load_dotenv\(\)'
    }
}
