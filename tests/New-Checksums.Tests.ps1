#Requires -Modules @{ ModuleName = 'Pester'; RequiredVersion = '5.7.1' }

BeforeAll {
    $script:ChecksumScript = Get-Content "$PSScriptRoot\..\New-Checksums.ps1" -Raw
}

Describe 'New-Checksums.ps1 structure' {
    It 'has a .SYNOPSIS help block' {
        $script:ChecksumScript | Should -Match '\.SYNOPSIS'
    }

    It 'does not require Administrator' {
        $script:ChecksumScript | Should -Not -Match '#Requires.*RunAsAdministrator'
        $script:ChecksumScript | Should -Not -Match 'Assert-Administrator'
    }

    It 'computes SHA256 hashes for the three user-facing scripts' {
        $script:ChecksumScript | Should -Match 'bootstrap\.ps1'
        $script:ChecksumScript | Should -Match 'Setup-DevEnvironment\.ps1'
        $script:ChecksumScript | Should -Match 'Install-WinTerface\.ps1'
    }

    It 'uses Get-FileHash with SHA256 algorithm' {
        $script:ChecksumScript | Should -Match 'Get-FileHash.*SHA256'
    }
}

Describe 'checksums.sha256 output' {
    BeforeAll {
        $script:ChecksumFile = "$PSScriptRoot\..\checksums.sha256"
    }

    It 'exists at the repo root' {
        Test-Path $script:ChecksumFile | Should -BeTrue
    }

    It 'contains exactly 3 entries' {
        $lines = @(Get-Content $script:ChecksumFile | Where-Object { $_ -ne '' })
        $lines.Count | Should -Be 3
    }

    It 'each entry matches sha256sum format: 64 hex chars, two spaces, filename' {
        $lines = @(Get-Content $script:ChecksumFile | Where-Object { $_ -ne '' })
        foreach ($line in $lines) {
            $line | Should -Match '^[0-9a-f]{64}  \S+$'
        }
    }

    It 'contains entries for bootstrap.ps1, Setup-DevEnvironment.ps1, and Install-WinTerface.ps1' {
        $content = Get-Content $script:ChecksumFile -Raw
        $content | Should -Match 'bootstrap\.ps1'
        $content | Should -Match 'Setup-DevEnvironment\.ps1'
        $content | Should -Match 'Install-WinTerface\.ps1'
    }

    It 'hash for bootstrap.ps1 matches Get-FileHash output' {
        $expected = (Get-FileHash -Path "$PSScriptRoot\..\bootstrap.ps1" -Algorithm SHA256).Hash.ToLower()
        $line = Get-Content $script:ChecksumFile | Where-Object { $_ -match 'bootstrap\.ps1' }
        $fileHash = ($line -split '\s{2}')[0]
        $fileHash | Should -Be $expected
    }

    It 'hash for Setup-DevEnvironment.ps1 matches Get-FileHash output' {
        $expected = (Get-FileHash -Path "$PSScriptRoot\..\Setup-DevEnvironment.ps1" -Algorithm SHA256).Hash.ToLower()
        $line = Get-Content $script:ChecksumFile | Where-Object { $_ -match 'Setup-DevEnvironment\.ps1' }
        $fileHash = ($line -split '\s{2}')[0]
        $fileHash | Should -Be $expected
    }
}
