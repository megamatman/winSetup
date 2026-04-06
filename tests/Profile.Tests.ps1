#Requires -Modules @{ ModuleName = 'Pester'; RequiredVersion = '5.7.1' }

# profile.ps1 triggers SSH agent, Oh My Posh, zoxide, PSReadLine, and a daily
# auto-run on dot-source. Extract only the target functions via AST to avoid
# all side effects.

BeforeAll {
    $profilePath = "$PSScriptRoot\..\profile.ps1"
    $profileContent = Get-Content $profilePath -Raw
    $tokens = $null; $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput(
        $profileContent, [ref]$tokens, [ref]$parseErrors)

    foreach ($funcAst in $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        ($node.Name -eq 'Setup-PythonTools' -or $node.Name -eq 'Show-DevEnvironment')
    }, $true)) {
        Invoke-Expression $funcAst.Extent.Text
    }
}

# ---------------------------------------------------------------------------
# Setup-PythonTools
# ---------------------------------------------------------------------------

Describe 'Setup-PythonTools' {
    BeforeAll {
        Mock Write-Host {}
    }

    BeforeEach {
        Remove-Item function:python -ErrorAction SilentlyContinue
        Remove-Item function:pip -ErrorAction SilentlyContinue
        Remove-Item function:pipx -ErrorAction SilentlyContinue
        $global:LASTEXITCODE = 0
        $script:PipxInstallCalls = @()
    }

    It 'exits early with error when python is not found' {
        # Mock Get-Command to return $null only for python
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'python' }

        Setup-PythonTools -Silent

        Should -Invoke Write-Host -ParameterFilter {
            "$Object" -match 'Python not found'
        }
    }

    It 'exits early with error when pip is not found' {
        Mock Get-Command { [PSCustomObject]@{ Source = 'python.exe' } } -ParameterFilter { $Name -eq 'python' }
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'pip' }

        Setup-PythonTools -Silent

        Should -Invoke Write-Host -ParameterFilter {
            "$Object" -match 'pip not found'
        }
    }

    It 'exits early when pipx not found and pip install fails' {
        Mock Get-Command { [PSCustomObject]@{ Source = 'python.exe' } } -ParameterFilter { $Name -eq 'python' }
        Mock Get-Command { [PSCustomObject]@{ Source = 'pip.exe' } } -ParameterFilter { $Name -eq 'pip' }
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'pipx' }
        # pip install --user pipx runs but pipx remains unfound
        function pip { $global:LASTEXITCODE = 0 }

        Setup-PythonTools -Silent

        Should -Invoke Write-Host -ParameterFilter {
            "$Object" -match 'pipx'
        }
    }

    It 'installs tools that are not in the pipx list' {
        Mock Get-Command { [PSCustomObject]@{ Source = 'python.exe' } } -ParameterFilter { $Name -eq 'python' }
        Mock Get-Command { [PSCustomObject]@{ Source = 'pip.exe' } } -ParameterFilter { $Name -eq 'pip' }
        Mock Get-Command { [PSCustomObject]@{ Source = 'pipx.exe' } } -ParameterFilter { $Name -eq 'pipx' }
        function pipx {
            if ($args[0] -eq 'list') { return @() }
            if ($args[0] -eq 'install') {
                $script:PipxInstallCalls += $args[1]
                $global:LASTEXITCODE = 0
                return ''
            }
            if ($args[0] -eq 'ensurepath') { return 'already in PATH' }
        }

        Setup-PythonTools -Silent

        $script:PipxInstallCalls.Count | Should -Be 6
        $script:PipxInstallCalls | Should -Contain 'ruff'
        $script:PipxInstallCalls | Should -Contain 'pylint'
        $script:PipxInstallCalls | Should -Contain 'mypy'
        $script:PipxInstallCalls | Should -Contain 'bandit'
        $script:PipxInstallCalls | Should -Contain 'pre-commit'
        $script:PipxInstallCalls | Should -Contain 'cookiecutter'
    }

    It 'skips tools that are already installed' {
        Mock Get-Command { [PSCustomObject]@{ Source = 'python.exe' } } -ParameterFilter { $Name -eq 'python' }
        Mock Get-Command { [PSCustomObject]@{ Source = 'pip.exe' } } -ParameterFilter { $Name -eq 'pip' }
        Mock Get-Command { [PSCustomObject]@{ Source = 'pipx.exe' } } -ParameterFilter { $Name -eq 'pipx' }
        function pipx {
            if ($args[0] -eq 'list') {
                return @(
                    "ruff 0.3.4"
                    "pylint 3.1.0"
                    "mypy 1.9.0"
                    "bandit 1.7.8"
                    "pre-commit 3.7.0"
                    "cookiecutter 2.6.0"
                )
            }
            if ($args[0] -eq 'install') {
                $script:PipxInstallCalls += $args[1]
                $global:LASTEXITCODE = 0
                return ''
            }
            if ($args[0] -eq 'ensurepath') { return 'already in PATH' }
        }

        Setup-PythonTools -Silent

        $script:PipxInstallCalls.Count | Should -Be 0
    }

    It 'reports error when pipx install returns non-zero exit code' {
        Mock Get-Command { [PSCustomObject]@{ Source = 'python.exe' } } -ParameterFilter { $Name -eq 'python' }
        Mock Get-Command { [PSCustomObject]@{ Source = 'pip.exe' } } -ParameterFilter { $Name -eq 'pip' }
        Mock Get-Command { [PSCustomObject]@{ Source = 'pipx.exe' } } -ParameterFilter { $Name -eq 'pipx' }
        function pipx {
            if ($args[0] -eq 'list') { return @() }
            if ($args[0] -eq 'install') {
                $global:LASTEXITCODE = 1
                return ''
            }
            if ($args[0] -eq 'ensurepath') { return 'already in PATH' }
        }

        Setup-PythonTools -Silent

        Should -Invoke Write-Host -ParameterFilter {
            "$Object" -match 'install failed'
        }
    }

    It 'reports success on successful pipx install' {
        Mock Get-Command { [PSCustomObject]@{ Source = 'python.exe' } } -ParameterFilter { $Name -eq 'python' }
        Mock Get-Command { [PSCustomObject]@{ Source = 'pip.exe' } } -ParameterFilter { $Name -eq 'pip' }
        Mock Get-Command { [PSCustomObject]@{ Source = 'pipx.exe' } } -ParameterFilter { $Name -eq 'pipx' }
        function pipx {
            if ($args[0] -eq 'list') { return @() }
            if ($args[0] -eq 'install') {
                $global:LASTEXITCODE = 0
                return ''
            }
            if ($args[0] -eq 'ensurepath') { return 'already in PATH' }
        }

        Setup-PythonTools -Silent

        Should -Invoke Write-Host -ParameterFilter {
            "$Object" -match 'installed successfully'
        }
    }

    It 'tool list contains expected tools' {
        $profileContent = Get-Content "$PSScriptRoot\..\profile.ps1" -Raw
        $profileContent | Should -Match '\$tools\s*=\s*@\(\s*"pylint"'
        $profileContent | Should -Match '"mypy"'
        $profileContent | Should -Match '"ruff"'
        $profileContent | Should -Match '"bandit"'
        $profileContent | Should -Match '"pre-commit"'
        $profileContent | Should -Match '"cookiecutter"'
    }
}

# ---------------------------------------------------------------------------
# Show-DevEnvironment
# ---------------------------------------------------------------------------

Describe 'Show-DevEnvironment' {
    BeforeAll {
        Mock Write-Host {}
        # Mock Get-Command to return $null by default so the function does not
        # try to invoke real tools (which are slow or absent in CI).
        Mock Get-Command { $null } -ParameterFilter {
            $Name -and $Name -notin @('Get-Command')
        }
    }

    It 'does not throw when all tools are missing' {
        { Show-DevEnvironment } | Should -Not -Throw
    }

    It 'outputs the section header' {
        Show-DevEnvironment

        Should -Invoke Write-Host -ParameterFilter {
            "$Object" -match 'Dev Environment Status'
        }
    }

    It 'outputs "not found" for missing tools' {
        Show-DevEnvironment

        Should -Invoke Write-Host -ParameterFilter {
            "$Object" -match 'not found'
        }
    }

    It 'outputs WINSETUP and PROFILE paths' {
        Show-DevEnvironment

        Should -Invoke Write-Host -ParameterFilter {
            "$Object" -match 'WINSETUP'
        }
        Should -Invoke Write-Host -ParameterFilter {
            "$Object" -match 'PROFILE'
        }
    }

    It 'tool hashtable contains at least 20 entries' {
        $profileContent = Get-Content "$PSScriptRoot\..\profile.ps1" -Raw
        $lines = $profileContent -split "`r?`n"
        $inTools = $false
        $entryCount = 0
        foreach ($l in $lines) {
            if ($l -match '^\s*\$tools\s*=\s*@\{') { $inTools = $true; continue }
            if ($inTools -and $l -match '^\s*\}') { break }
            if ($inTools -and $l -match '^\s*"[^"]+"\s*=\s*"[^"]+"') { $entryCount++ }
        }
        $entryCount | Should -BeGreaterOrEqual 20
    }
}
