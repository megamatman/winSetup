<#
.SYNOPSIS
    Deploys the standard PowerShell profile.

.DESCRIPTION
    Copies profile.ps1 from the winSetup repository to $PROFILE.
    Backs up any existing profile before overwriting.
    Does not require Administrator.

.EXAMPLE
    .\Apply-PowerShellProfile.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
. "$PSScriptRoot\Helpers.ps1"

# Main execution
$sourcePath = Join-Path $PSScriptRoot "profile.ps1"

if (-not (Test-Path $sourcePath)) {
    Write-Issue "profile.ps1 not found in $PSScriptRoot. Cannot deploy profile."
    exit 1
}

Write-Host "`n=== Apply PowerShell Profile ===" -ForegroundColor Cyan

$profileDir = Split-Path $PROFILE
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

Backup-FileIfExists $PROFILE
Copy-Item $sourcePath $PROFILE -Force
Write-Change "Profile deployed from profile.ps1 to $PROFILE"

Write-Host "`n=== Done ===" -ForegroundColor Cyan
Write-Host "Restart your terminal or run '. `$PROFILE' to apply changes.`n" -ForegroundColor Yellow
