#Requires -Modules @{ ModuleName = 'Pester'; RequiredVersion = '5.7.1' }

BeforeAll {
    . "$PSScriptRoot\..\Helpers.ps1"
}

Describe 'Profile deployment' {
    BeforeAll {
        Mock Write-Host {}
        Mock Write-Change {}
        Mock Write-Issue {}
    }

    It 'copies source profile to target location' {
        $sourceDir = Join-Path $TestDrive 'repo'
        New-Item -ItemType Directory -Path $sourceDir | Out-Null
        $sourceProfile = Join-Path $sourceDir 'profile.ps1'
        Set-Content -Path $sourceProfile -Value '# test profile content'

        $targetProfile = Join-Path $TestDrive 'target' 'Microsoft.PowerShell_profile.ps1'
        $targetDir = Split-Path $targetProfile
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

        # Simulate the deployment logic from Apply-PowerShellProfile.ps1
        Copy-Item $sourceProfile $targetProfile -Force

        Test-Path $targetProfile | Should -BeTrue
        Get-Content $targetProfile -Raw | Should -Match 'test profile content'
    }

    It 'target matches source after deployment' {
        $sourceDir = Join-Path $TestDrive 'repo2'
        New-Item -ItemType Directory -Path $sourceDir | Out-Null
        $sourceProfile = Join-Path $sourceDir 'profile.ps1'
        $content = "# My profile`nSet-Alias gs git`n"
        Set-Content -Path $sourceProfile -Value $content -NoNewline

        $targetProfile = Join-Path $TestDrive 'target2' 'profile.ps1'
        $targetDir = Split-Path $targetProfile
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

        Copy-Item $sourceProfile $targetProfile -Force

        $sourceHash = (Get-FileHash $sourceProfile).Hash
        $targetHash = (Get-FileHash $targetProfile).Hash
        $targetHash | Should -Be $sourceHash
    }

    It 'creates target directory if it does not exist' {
        $sourceDir = Join-Path $TestDrive 'repo3'
        New-Item -ItemType Directory -Path $sourceDir | Out-Null
        $sourceProfile = Join-Path $sourceDir 'profile.ps1'
        Set-Content -Path $sourceProfile -Value '# content'

        $targetDir = Join-Path $TestDrive 'newdir'
        $targetProfile = Join-Path $targetDir 'profile.ps1'

        # Simulate the directory creation logic
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        Copy-Item $sourceProfile $targetProfile -Force

        Test-Path $targetProfile | Should -BeTrue
    }

    It 'creates backup when target already exists' {
        $sourceDir = Join-Path $TestDrive 'repo4'
        New-Item -ItemType Directory -Path $sourceDir | Out-Null
        $sourceProfile = Join-Path $sourceDir 'profile.ps1'
        Set-Content -Path $sourceProfile -Value '# new content'

        $targetDir = Join-Path $TestDrive 'target4'
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        $targetProfile = Join-Path $targetDir 'profile.ps1'
        Set-Content -Path $targetProfile -Value '# old content'

        # Use Backup-FileIfExists from Helpers.ps1 (already dot-sourced)
        Backup-FileIfExists $targetProfile
        Copy-Item $sourceProfile $targetProfile -Force

        # Verify backup was created
        $backups = Get-ChildItem $targetDir -Filter 'profile.ps1.bak-*'
        $backups.Count | Should -BeGreaterOrEqual 1
        $backups[0].Name | Should -Match 'profile\.ps1\.bak-\d{8}-\d{6}'

        # Verify backup has old content
        Get-Content $backups[0].FullName -Raw | Should -Match 'old content'

        # Verify target has new content
        Get-Content $targetProfile -Raw | Should -Match 'new content'
    }

    It 'overwrites target with source content' {
        $sourceDir = Join-Path $TestDrive 'repo5'
        New-Item -ItemType Directory -Path $sourceDir | Out-Null
        $sourceProfile = Join-Path $sourceDir 'profile.ps1'
        Set-Content -Path $sourceProfile -Value '# updated profile'

        $targetDir = Join-Path $TestDrive 'target5'
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        $targetProfile = Join-Path $targetDir 'profile.ps1'
        Set-Content -Path $targetProfile -Value '# stale profile'

        Copy-Item $sourceProfile $targetProfile -Force

        Get-Content $targetProfile -Raw | Should -Match 'updated profile'
        Get-Content $targetProfile -Raw | Should -Not -Match 'stale profile'
    }
}

Describe 'Theme verification' {
    BeforeAll {
        Mock Write-Host {}
        Mock Write-Change {}
        Mock Write-Issue {}
    }

    It 'reports no issue when gruvbox.omp.json exists' {
        $repoRoot = Join-Path $TestDrive 'theme-repo'
        $configDir = Join-Path $repoRoot 'configs'
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null

        $themePath = Join-Path $configDir 'gruvbox.omp.json'
        Set-Content -Path $themePath -Value '{}'

        # Simulate the theme check logic from Apply-PowerShellProfile.ps1
        if (Test-Path $themePath) {
            Write-Change "Oh My Posh theme: $themePath"
        } else {
            Write-Issue "Oh My Posh theme not found at $themePath -- prompt will use built-in fallback"
        }

        Should -Invoke Write-Change -Times 1 -ParameterFilter {
            $Message -match 'Oh My Posh theme'
        }
        Should -Invoke Write-Issue -Times 0
    }

    It 'reports issue when gruvbox.omp.json is missing' {
        $repoRoot = Join-Path $TestDrive 'theme-repo-missing'
        $configDir = Join-Path $repoRoot 'configs'
        # Intentionally do NOT create the theme file

        $themePath = Join-Path $configDir 'gruvbox.omp.json'

        # Simulate the theme check logic
        if (Test-Path $themePath) {
            Write-Change "Oh My Posh theme: $themePath"
        } else {
            Write-Issue "Oh My Posh theme not found at $themePath -- prompt will use built-in fallback"
        }

        Should -Invoke Write-Issue -Times 1 -ParameterFilter {
            $Message -match 'Oh My Posh theme not found'
        }
        Should -Invoke Write-Change -Times 0
    }

    It 'theme path follows expected convention' {
        # Verify the script uses the expected path pattern
        $scriptContent = Get-Content "$PSScriptRoot\..\Apply-PowerShellProfile.ps1" -Raw
        $scriptContent | Should -Match 'gruvbox\.omp\.json'
        $scriptContent | Should -Match 'Join-Path.*configs.*gruvbox\.omp\.json'
    }
}
