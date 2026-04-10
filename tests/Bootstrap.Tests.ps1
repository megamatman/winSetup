#Requires -Modules @{ ModuleName = 'Pester'; RequiredVersion = '5.7.1' }

BeforeAll {
    $script:BootstrapScript = Get-Content "$PSScriptRoot\..\bootstrap.ps1" -Raw
}

Describe 'Bootstrap pre-flight checks' {
    It 'requires PowerShell 7 (script contains PS version check)' {
        # The bootstrap script checks $PSVersionTable.PSVersion.Major -lt 7
        $script:BootstrapScript | Should -Match 'PSVersionTable\.PSVersion\.Major\s*-lt\s*7'
        $script:BootstrapScript | Should -Match 'exit 1'
    }

    It 'checks for git and falls back to winget install' {
        $script:BootstrapScript | Should -Match 'Get-Command git'
        $script:BootstrapScript | Should -Match 'winget install Git\.Git'
    }

    It 'exits with code 1 when git clone fails' {
        $script:BootstrapScript | Should -Match 'git clone.*winSetup'
        # After clone, checks LASTEXITCODE and exits 1 on failure
        $script:BootstrapScript | Should -Match 'LASTEXITCODE.*-ne 0'
    }

    It 'detects existing WINSETUP and skips clone' {
        $script:BootstrapScript | Should -Match '\$env:WINSETUP'
        $script:BootstrapScript | Should -Match 'already present'
    }

    It 'sets WINSETUP environment variable after clone' {
        $script:BootstrapScript | Should -Match "SetEnvironmentVariable\('WINSETUP'"
        $script:BootstrapScript | Should -Match '\$env:WINSETUP\s*='
    }

    It 'offers hand-off to Setup-DevEnvironment.ps1' {
        $script:BootstrapScript | Should -Match 'Setup-DevEnvironment\.ps1'
        $script:BootstrapScript | Should -Match 'Run Setup-DevEnvironment'
    }
}

Describe 'Bootstrap security notice' {
    It 'displays a security notice before any action' {
        # The security notice should appear before the PS version check
        $noticePos = $script:BootstrapScript.IndexOf('Review the source')
        $actionPos = $script:BootstrapScript.IndexOf('PowerShell version')

        $noticePos | Should -BeGreaterThan -1
        $actionPos | Should -BeGreaterThan -1
        $noticePos | Should -BeLessThan $actionPos
    }

    It 'includes the GitHub URL for review' {
        $script:BootstrapScript | Should -Match 'github\.com/megamatman/winSetup'
    }

    It 'prompts for confirmation before proceeding' {
        $script:BootstrapScript | Should -Match 'Continue\?'
    }
}

Describe 'Bootstrap structure' {
    It 'has a .SYNOPSIS help block' {
        $script:BootstrapScript | Should -Match '\.SYNOPSIS'
    }

    It 'does not require Administrator' {
        $script:BootstrapScript | Should -Not -Match 'Assert-Administrator'
        $script:BootstrapScript | Should -Not -Match '#Requires.*RunAsAdministrator'
    }

    It 'dot-sources Helpers.ps1 after the clone step' {
        $script:BootstrapScript | Should -Match 'Helpers\.ps1'
    }

    It 'exits cleanly when user declines setup' {
        # The "no" path should not call Setup-DevEnvironment.ps1 and should
        # print the manual command instead
        $script:BootstrapScript | Should -Match 'To run setup later'
    }
}
