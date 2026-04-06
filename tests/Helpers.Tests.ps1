#Requires -Modules @{ ModuleName = 'Pester'; RequiredVersion = '5.7.1' }

BeforeAll {
    . "$PSScriptRoot\..\Helpers.ps1"
}

Describe 'Write-Step' {
    BeforeEach {
        $script:CurrentStep = 0
        $TotalSteps = 5
    }

    It 'increments $script:CurrentStep on each call' {
        Mock Write-Host {}
        Write-Step 'Test'
        $script:CurrentStep | Should -Be 1
        Write-Step 'Test2'
        $script:CurrentStep | Should -Be 2
    }

    It 'outputs correctly formatted step counter' {
        Mock Write-Host {} -Verifiable -ParameterFilter {
            $Object -match '\[1/5\] MyStep'
        }
        Write-Step 'MyStep'
        Should -InvokeVerifiable
    }
}

Describe 'Write-Skip' {
    It 'outputs skip message' {
        Mock Write-Host {} -Verifiable -ParameterFilter {
            $Object -eq '  Skipped item'
        }
        Write-Skip 'Skipped item'
        Should -InvokeVerifiable
    }

    It 'adds to $script:Skipped when -Track is set' {
        Mock Write-Host {}
        $script:Skipped = [System.Collections.Generic.List[string]]::new()
        Write-Skip 'msg' -Track 'MyTool'
        $script:Skipped | Should -Contain 'MyTool'
    }

    It 'does not add to tracking when -Track is empty' {
        Mock Write-Host {}
        $script:Skipped = [System.Collections.Generic.List[string]]::new()
        Write-Skip 'msg'
        $script:Skipped.Count | Should -Be 0
    }
}

Describe 'Write-Change' {
    It 'outputs change message' {
        Mock Write-Host {} -Verifiable -ParameterFilter {
            $Object -eq '  Installed ok'
        }
        Write-Change 'Installed ok'
        Should -InvokeVerifiable
    }

    It 'adds to $script:Installed when -Track is set' {
        Mock Write-Host {}
        $script:Installed = [System.Collections.Generic.List[string]]::new()
        Write-Change 'msg' -Track 'Git'
        $script:Installed | Should -Contain 'Git'
    }

    It 'does not add to tracking when -Track is empty' {
        Mock Write-Host {}
        $script:Installed = [System.Collections.Generic.List[string]]::new()
        Write-Change 'msg'
        $script:Installed.Count | Should -Be 0
    }
}

Describe 'Write-Issue' {
    It 'outputs issue message' {
        Mock Write-Host {} -Verifiable -ParameterFilter {
            $Object -eq '  Something failed'
        }
        Write-Issue 'Something failed'
        Should -InvokeVerifiable
    }

    It 'adds to $script:Failed when -Track is set' {
        Mock Write-Host {}
        $script:Failed = [System.Collections.Generic.List[string]]::new()
        Write-Issue 'msg' -Track 'Python'
        $script:Failed | Should -Contain 'Python'
    }

    It 'does not add to tracking when -Track is empty' {
        Mock Write-Host {}
        $script:Failed = [System.Collections.Generic.List[string]]::new()
        Write-Issue 'msg'
        $script:Failed.Count | Should -Be 0
    }
}

Describe 'Write-Summary' {
    BeforeEach {
        Mock Write-Host {}
    }

    It 'outputs installed count when items exist' {
        $script:Installed = [System.Collections.Generic.List[string]]::new()
        $script:Skipped   = [System.Collections.Generic.List[string]]::new()
        $script:Failed    = [System.Collections.Generic.List[string]]::new()
        $script:Installed.Add('Git')
        $script:Installed.Add('Python')

        Write-Summary

        Should -Invoke Write-Host -ParameterFilter {
            $Object -match 'Installed.*2.*Git, Python'
        }
    }

    It 'handles zero counts correctly' {
        $script:Installed = [System.Collections.Generic.List[string]]::new()
        $script:Skipped   = [System.Collections.Generic.List[string]]::new()
        $script:Failed    = [System.Collections.Generic.List[string]]::new()

        Write-Summary

        Should -Invoke Write-Host -ParameterFilter {
            $Object -match 'All steps completed successfully'
        }
    }

    It 'outputs failed count and retry message' {
        $script:Installed = [System.Collections.Generic.List[string]]::new()
        $script:Skipped   = [System.Collections.Generic.List[string]]::new()
        $script:Failed    = [System.Collections.Generic.List[string]]::new()
        $script:Failed.Add('choco')

        Write-Summary

        Should -Invoke Write-Host -ParameterFilter {
            $Object -match 'Failed.*1.*choco'
        }
        Should -Invoke Write-Host -ParameterFilter {
            $Object -match 'Re-run the script'
        }
    }
}

Describe 'Backup-FileIfExists' {
    It 'creates backup with correct filename pattern' {
        Mock Write-Host {}
        $testFile = Join-Path $TestDrive 'source.ps1'
        Set-Content -Path $testFile -Value 'original content'

        Backup-FileIfExists $testFile

        $backups = Get-ChildItem $TestDrive -Filter 'source.ps1.bak-*'
        $backups.Count | Should -Be 1
        $backups[0].Name | Should -Match 'source\.ps1\.bak-\d{8}-\d{6}'
    }

    It 'does nothing if source file does not exist' {
        Mock Write-Host {}
        $subDir = Join-Path $TestDrive 'empty-test'
        New-Item -ItemType Directory -Path $subDir | Out-Null
        $missing = Join-Path $subDir 'nonexistent.ps1'

        Backup-FileIfExists $missing

        (Get-ChildItem $subDir -Filter '*.bak-*').Count | Should -Be 0
    }

    It 'backup contains same content as source' {
        Mock Write-Host {}
        $testFile = Join-Path $TestDrive 'content-check.ps1'
        Set-Content -Path $testFile -Value 'test content 123'

        Backup-FileIfExists $testFile

        $backup = Get-ChildItem $TestDrive -Filter 'content-check.ps1.bak-*' | Select-Object -First 1
        Get-Content $backup.FullName -Raw | Should -Match 'test content 123'
    }
}

Describe 'Remove-OldBackups' {
    It 'retains only the 3 most recent backups' {
        $testFile = Join-Path $TestDrive 'prune.ps1'
        Set-Content -Path $testFile -Value 'x'
        for ($i = 1; $i -le 5; $i++) {
            Set-Content -Path "$testFile.bak-2026010$i-120000" -Value "backup $i"
        }

        Remove-OldBackups -SourceFile $testFile -Keep 3

        $remaining = Get-ChildItem $TestDrive -Filter 'prune.ps1.bak-*'
        $remaining.Count | Should -Be 3
    }

    It 'deletes oldest when more than 3 exist' {
        $testFile = Join-Path $TestDrive 'prune2.ps1'
        Set-Content -Path $testFile -Value 'x'
        for ($i = 1; $i -le 4; $i++) {
            Set-Content -Path "$testFile.bak-2026010$i-120000" -Value "backup $i"
        }

        Remove-OldBackups -SourceFile $testFile -Keep 3

        $remaining = Get-ChildItem $TestDrive -Filter 'prune2.ps1.bak-*' | Sort-Object Name
        $remaining.Count | Should -Be 3
        $remaining[0].Name | Should -Match '20260102'
    }

    It 'does nothing when 3 or fewer backups exist' {
        $testFile = Join-Path $TestDrive 'prune3.ps1'
        Set-Content -Path $testFile -Value 'x'
        for ($i = 1; $i -le 2; $i++) {
            Set-Content -Path "$testFile.bak-2026010$i-120000" -Value "backup $i"
        }

        Remove-OldBackups -SourceFile $testFile -Keep 3

        (Get-ChildItem $TestDrive -Filter 'prune3.ps1.bak-*').Count | Should -Be 2
    }

    It 'does nothing when no backups exist' {
        $testFile = Join-Path $TestDrive 'prune4.ps1'
        Set-Content -Path $testFile -Value 'x'

        { Remove-OldBackups -SourceFile $testFile -Keep 3 } | Should -Not -Throw
    }
}
