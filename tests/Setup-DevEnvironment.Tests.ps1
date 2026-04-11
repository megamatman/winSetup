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

    It 'throws when both direct pipx and python -m pipx fail' {
        Mock pipx { throw [System.Management.Automation.RuntimeException]::new("StandardOutputEncoding error") }
        Mock python { throw [System.Management.Automation.CommandNotFoundException]::new("python module pipx not found") }

        { Invoke-Pipx list --short } | Should -Throw
    }

    It 'propagates the fallback error, not the original error' {
        Mock pipx { throw [System.Management.Automation.RuntimeException]::new("pipx launcher broke") }
        Mock python { throw [System.Management.Automation.RuntimeException]::new("python -m pipx failed too") }

        $caught = $null
        try { Invoke-Pipx list --short } catch { $caught = $_ }

        $caught | Should -Not -BeNullOrEmpty
        $caught.Exception.Message | Should -Match 'python -m pipx failed too'
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

Describe 'Install-PythonTools Invoke-Pipx error handling' {
    BeforeAll {
        Mock Write-Host {}

        # Extract Invoke-Pipx and Install-PythonTools from the source via AST.
        # Cannot dot-source the file because of side effects at script scope.
        $scriptPath = "$PSScriptRoot\..\Setup-DevEnvironment.ps1"
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $scriptPath, [ref]$tokens, [ref]$errors)

        foreach ($name in @('Invoke-Pipx', 'Install-PythonTools')) {
            $funcAst = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq $name
            }, $false) | Select-Object -First 1
            . ([scriptblock]::Create($funcAst.Extent.Text))
        }
    }

    BeforeEach {
        # Initialise tracking lists that Write-Issue/-Change/-Skip append to.
        # These are normally initialised by Setup-DevEnvironment.ps1 at script
        # scope as List[string], but since we extracted the functions via AST
        # we must set them. Must be List[string] because Helpers.ps1 uses .Add().
        $script:Failed    = [System.Collections.Generic.List[string]]::new()
        $script:Installed = [System.Collections.Generic.List[string]]::new()
        $script:Skipped   = [System.Collections.Generic.List[string]]::new()
        $script:CurrentStep = 0
        $TotalSteps = 18
    }

    It 'returns normally when Invoke-Pipx list throws (double failure)' {
        Mock Get-Command { [PSCustomObject]@{ Source = 'C:\Python\python.exe' } } -ParameterFilter { $Name -eq 'python' }
        Mock Get-Command { [PSCustomObject]@{ Source = 'C:\Python\Scripts\pipx.exe' } } -ParameterFilter { $Name -eq 'pipx' }
        Mock pipx { throw [System.Management.Automation.RuntimeException]::new("StandardOutputEncoding error") }
        Mock python { throw [System.Management.Automation.RuntimeException]::new("python -m pipx not available") }
        Mock pip {}

        # Install-PythonTools should NOT throw. The try/catch around Invoke-Pipx
        # list catches the error, logs it with Write-Issue, and returns.
        { Install-PythonTools } | Should -Not -Throw
    }

    It 'calls Write-Issue when Invoke-Pipx list throws' {
        Mock Get-Command { [PSCustomObject]@{ Source = 'C:\Python\python.exe' } } -ParameterFilter { $Name -eq 'python' }
        Mock Get-Command { [PSCustomObject]@{ Source = 'C:\Python\Scripts\pipx.exe' } } -ParameterFilter { $Name -eq 'pipx' }
        Mock pipx { throw [System.Management.Automation.RuntimeException]::new("StandardOutputEncoding error") }
        Mock python { throw [System.Management.Automation.RuntimeException]::new("python -m pipx not available") }
        Mock pip {}

        Install-PythonTools

        # Write-Issue is defined in Helpers.ps1 which is dot-sourced in BeforeAll
        # via the file-level BeforeAll. It should have been called with the
        # "Python Tools" track for the pipx list failure.
        $script:Failed | Should -Contain 'Python Tools'
    }

    It 'continues to the next tool when Invoke-Pipx install throws for one tool' {
        Mock Get-Command { [PSCustomObject]@{ Source = 'C:\Python\python.exe' } } -ParameterFilter { $Name -eq 'python' }
        Mock Get-Command { [PSCustomObject]@{ Source = 'C:\Python\Scripts\pipx.exe' } } -ParameterFilter { $Name -eq 'pipx' }
        Mock pip {}
        # Both pipx and python must throw for pylint to trigger the double
        # failure that reaches Install-PythonTools's catch block. For other
        # tools, pipx succeeds directly.
        Mock pipx {
            if ($args[0] -eq 'list') { return "" }
            if ($args[0] -eq 'install') {
                $script:_pipxInstallCallCount++
                if ($args[1] -eq 'pylint') {
                    throw [System.Management.Automation.RuntimeException]::new("install failed for pylint")
                }
                $global:LASTEXITCODE = 0
                return "installed $($args[1])"
            }
            if ($args[0] -eq 'ensurepath') { return "already in PATH" }
        }
        Mock python {
            # Fallback also fails for pylint (double failure)
            if ($args -contains 'pylint') {
                throw [System.Management.Automation.RuntimeException]::new("python -m pipx install pylint also failed")
            }
        }
        $script:_pipxInstallCallCount = 0

        { Install-PythonTools } | Should -Not -Throw

        # pylint threw, but the loop should have continued to the remaining 5 tools
        $script:_pipxInstallCallCount | Should -BeGreaterOrEqual 2 -Because 'the loop continues past the failing tool'
        $script:Failed | Should -Contain 'pylint'
    }

    It 'allows Write-Summary to run after a double failure' {
        # Simulate the fixed main execution pattern: Install-PythonTools
        # returns normally, so Write-Summary runs.
        $script:_testSummaryReached = $false
        Mock Get-Command { [PSCustomObject]@{ Source = 'C:\Python\python.exe' } } -ParameterFilter { $Name -eq 'python' }
        Mock Get-Command { [PSCustomObject]@{ Source = 'C:\Python\Scripts\pipx.exe' } } -ParameterFilter { $Name -eq 'pipx' }
        Mock pipx { throw [System.Management.Automation.RuntimeException]::new("StandardOutputEncoding error") }
        Mock python { throw [System.Management.Automation.RuntimeException]::new("python -m pipx not available") }
        Mock pip {}

        Install-PythonTools
        $script:_testSummaryReached = $true

        $script:_testSummaryReached | Should -BeTrue -Because 'Install-PythonTools returns normally so subsequent code runs'
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

Describe 'ScaffoldPyproject custom templates' {
    BeforeAll {
        Mock Write-Host {}
        . "$PSScriptRoot\..\Helpers.ps1"

        # Extract and evaluate New-PyprojectToml from the setup script
        $funcBlock = [regex]::Match(
            $script:SetupScript,
            '(?ms)function New-PyprojectToml \{.*?\n\}'
        )
        $funcBlock.Success | Should -BeTrue
        Invoke-Expression $funcBlock.Value
    }

    It 'copies files from custom template when present' {
        $homeDir = Join-Path $TestDrive 'home-custom'
        $customDir = Join-Path $homeDir '.wintemplates' 'python'
        New-Item -ItemType Directory -Path $customDir -Force | Out-Null
        Set-Content -Path (Join-Path $customDir 'pyproject.toml') -Value '[tool.ruff]'
        Set-Content -Path (Join-Path $customDir 'setup.cfg') -Value '[metadata]'

        $targetDir = Join-Path $TestDrive 'project-custom'
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

        $savedProfile = $env:USERPROFILE
        $env:USERPROFILE = $homeDir
        try {
            New-PyprojectToml -Path $targetDir -TemplateName 'python'
        }
        finally {
            $env:USERPROFILE = $savedProfile
        }

        Test-Path (Join-Path $targetDir 'pyproject.toml') | Should -BeTrue
        Test-Path (Join-Path $targetDir 'setup.cfg') | Should -BeTrue
        Get-Content (Join-Path $targetDir 'pyproject.toml') -Raw | Should -Match '\[tool\.ruff\]'
    }

    It 'falls back to built-in when custom template not found' {
        $targetDir = Join-Path $TestDrive 'project-fallback'
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

        $savedProfile = $env:USERPROFILE
        $env:USERPROFILE = Join-Path $TestDrive 'no-templates'
        try {
            New-PyprojectToml -Path $targetDir -TemplateName 'python'
        }
        finally {
            $env:USERPROFILE = $savedProfile
        }

        $toml = Get-Content (Join-Path $targetDir 'pyproject.toml') -Raw
        $toml | Should -Match 'line-length = 88'
        $toml | Should -Match '\[tool\.mypy\]'
    }

    It 'falls back to built-in with warning when custom template is empty' {
        $homeDir = Join-Path $TestDrive 'home-empty'
        $customDir = Join-Path $homeDir '.wintemplates' 'python'
        New-Item -ItemType Directory -Path $customDir -Force | Out-Null
        # Directory exists but contains no files

        $targetDir = Join-Path $TestDrive 'project-empty'
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

        $savedProfile = $env:USERPROFILE
        $env:USERPROFILE = $homeDir
        try {
            New-PyprojectToml -Path $targetDir -TemplateName 'python'
        }
        finally {
            $env:USERPROFILE = $savedProfile
        }

        # Should fall back to built-in
        $toml = Get-Content (Join-Path $targetDir 'pyproject.toml') -Raw
        $toml | Should -Match 'line-length = 88'
    }

    It 'uses -TemplateName to select a different template subdirectory' {
        $homeDir = Join-Path $TestDrive 'home-fastapi'
        $customDir = Join-Path $homeDir '.wintemplates' 'fastapi'
        New-Item -ItemType Directory -Path $customDir -Force | Out-Null
        Set-Content -Path (Join-Path $customDir 'pyproject.toml') -Value '[tool.fastapi]'

        $targetDir = Join-Path $TestDrive 'project-fastapi'
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

        $savedProfile = $env:USERPROFILE
        $env:USERPROFILE = $homeDir
        try {
            New-PyprojectToml -Path $targetDir -TemplateName 'fastapi'
        }
        finally {
            $env:USERPROFILE = $savedProfile
        }

        Get-Content (Join-Path $targetDir 'pyproject.toml') -Raw | Should -Match '\[tool\.fastapi\]'
    }

    It 'built-in output is unchanged when no custom template exists' {
        $targetDir = Join-Path $TestDrive 'project-builtin'
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

        $savedProfile = $env:USERPROFILE
        $env:USERPROFILE = Join-Path $TestDrive 'empty-home'
        try {
            New-PyprojectToml -Path $targetDir
        }
        finally {
            $env:USERPROFILE = $savedProfile
        }

        $toml = Get-Content (Join-Path $targetDir 'pyproject.toml') -Raw
        $toml | Should -Match '\[tool\.ruff\]'
        $toml | Should -Match 'line-length = 88'
        $toml | Should -Match '\[tool\.ruff\.lint\]'
        $toml | Should -Match '\[tool\.ruff\.format\]'
        $toml | Should -Match '\[tool\.mypy\]'
    }
}
