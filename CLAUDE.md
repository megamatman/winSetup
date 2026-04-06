# winSetup -- Claude Code Context

## Purpose

winSetup automates the setup, configuration, and maintenance of a Windows 11
development environment. Installs tools via choco/winget/pipx, deploys a
PowerShell profile, configures git with SSH signing, and provides ongoing
update management.

## Repository structure (verified line counts)

```
Setup-DevEnvironment.ps1    1269  Main setup script: Install-* functions, -InstallTool, -CheckProfileOnly, -ScaffoldPyproject, -WhatIf
Update-DevEnvironment.ps1    508  Per-package and full updates: $PackageRegistry, Invoke-*Update per-manager helpers
Uninstall-Tool.ps1           316  5-step tool removal: uninstall, remove from Setup/Update/profile/winTerface, transcript logging
Apply-PowerShellProfile.ps1   48  Deploys profile.ps1 to $PROFILE with backup and theme verification
Apply-VSCodeSettings.ps1     100  Reads configs/vscode-settings.json and deploys to VS Code, installs extensions
Helpers.ps1                  147  Shared helpers: Write-Step/Skip/Change/Issue/Section, Backup-FileIfExists, Remove-OldBackups, Write-Summary
profile.ps1                  430  Canonical PowerShell profile: SSH agent, env vars, tool config, aliases, Oh My Posh, zoxide, health check

configs/
  gruvbox.omp.json                Managed Oh My Posh theme with SSH window title support
  vscode-settings.json            Managed VS Code settings (single source of truth, previously embedded in Apply-VSCodeSettings.ps1)

tests/                            Pester test suite (7 files, 131 tests)
Tutorials/                        Developer onboarding guides (01-05)
logs/                             Transcript logs from setup/update/install/uninstall runs

README.md                         User-facing documentation with winTerface callout
CONTRIBUTING.md                   Contribution guidelines with .SYNOPSIS requirement
INTERFACE.md                      Versioned interface contract for winTerface consumers (contract version 1)
TROUBLESHOOTING.md                Symptom-first troubleshooting guide (35+ entries)
QUICK-REFERENCE.md                Command cheat sheet
RELEASE-NOTES.md                  Version history
```

## Environment variables

- `$env:WINSETUP` -- path to this repo. Set by Setup-DevEnvironment.ps1, falls back via profile.ps1.
- `$env:WINTERFACE` -- path to winTerface repo. Set by Install-WinTerface.ps1, used by Uninstall-Tool.ps1 step 5.

All paths derived from these or `$env:USERPROFILE`. No hardcoded paths.

## Architecture

### Single source of truth

- `profile.ps1` is the canonical profile. `Apply-PowerShellProfile.ps1` copies it to `$PROFILE`.
- `configs/gruvbox.omp.json` is the canonical Oh My Posh theme.
- `configs/vscode-settings.json` is the canonical VS Code settings file.
- `$PackageRegistry` in Update-DevEnvironment.ps1 is the tool registry.

### Idempotency

All scripts are safe to re-run. Install functions check `Get-Command` before
installing. Update functions detect "already current" states. Uninstall logs
what succeeded and what failed without aborting.

### Transcript logging

`Start-Transcript` writes to `logs/` for setup, update, install, and uninstall
runs. File pattern: `<action>-<tool>-<yyyyMMdd-HHmmss>.txt`. Old backups
auto-pruned to keep most recent 3 per source file.

### $CoreSteps

`$CoreSteps = 18` in Setup-DevEnvironment.ps1 must match the number of
`Write-Step` calls in the core execution path. Current 18 core steps:
Test-ProfileHealth + Chocolatey + VSCode + Python + OhMyPosh + GitHubCLI +
Fzf + CLITools + HackNerdFont + SSHKeys + GitHubSSHKey + WindowsTerminalFont +
PythonTools + PyenvWin + GlobalGitIgnore + GitIdentity + GitCommitSigning +
DeltaGitConfig. `$OptionalSteps = 4`.

### $script:ContractVersion

`$script:ContractVersion = 1` is defined near the top of Setup-DevEnvironment.ps1.
It documents the interface contract version for winTerface consumers. See
INTERFACE.md for the full specification.

## Critical constraints

1. Helpers.ps1 must be dot-sourced by every script that uses Write-Step/Skip/Change/Issue.
2. `$CoreSteps` count must match `Write-Step` call count exactly (currently 18).
3. Word-boundary matching in Uninstall-Tool.ps1 Step 4 profile removal prevents "fd" matching inside "fd --type f".
4. `$LASTEXITCODE` is only meaningful after external commands (choco/winget/pipx/pip). PowerShell cmdlets (`Uninstall-Module`) do not set it. Step 1 in Uninstall-Tool handles this with a manager-specific check.
5. Uninstall-Tool.ps1 parses `$PackageRegistry` via regex (not dot-sourcing) to avoid executing file content.
6. Uninstall-Tool.ps1 Step 2 uses the PowerShell AST parser (`[System.Management.Automation.Language.Parser]::ParseInput()`) to locate `Install-*` function boundaries for removal. The previous brace-counting approach was fragile in the presence of braces inside string literals or here-strings.

## Package manager specifics

### Chocolatey
- `choco upgrade <id> -y` -- parse output for `upgraded N/M packages`. N=0 means already current.
- Filter promotional output (Did you know, Enjoy using Chocolatey, etc.).
- Requires Administrator for install/upgrade.

### winget
- Always use `--id <id> --exact` to prevent partial name matching.
- Always use `--disable-interactivity --silent` to suppress VT100 progress corruption.
- Exit code -1978335189 (0x8A15002B) means "no update available" -- treat as success.
- Filter spinner lines (`-\|/`) from captured output.

### pipx
- Parse output for "already at latest version" to detect no-op upgrades.
- Spaces in `$env:USERPROFILE` cause PIPX_HOME issues. See TROUBLESHOOTING.md.

### PSFzf (PowerShell module)
- Use `Install-Module -Force -Scope CurrentUser`, not `Update-Module`.
- `Update-Module` fails if the module wasn't originally installed by `Install-Module`.
- Version compare via `Get-Module -ListAvailable` vs `Find-Module` before installing.

### pyenv-win
- pip install creates `~\.pyenv\pyenv-win\pyenv-win\bin` (extra nesting level).
- choco/git install creates `~\.pyenv\pyenv-win\bin`.
- Update via `pip install pyenv-win --upgrade --target`.
- `pyenv version` outputs multi-line error when no global version set. Show-DevEnvironment handles this gracefully.

## How to add a new tool

Two registration points (both required for full management):

1. **Setup-DevEnvironment.ps1** -- add an `Install-<Name>` function before the
   `# Main Execution` header. Add the function call before `Write-Summary`.
   Increment `$CoreSteps`.

2. **Update-DevEnvironment.ps1** -- add entry to `$PackageRegistry`.

winTerface derives its KnownTools list from `$PackageRegistry` at startup,
so no separate registration in winTerface is needed. The Add Tool wizard
in winTerface automates both points.

## Dry-run mode

`Setup-DevEnvironment.ps1 -WhatIf` previews all 18 core steps (plus 4
optional with `-IncludeOptional`) without making changes. Each step uses
the same detection logic as the real install (`Get-Command`, `Test-Path`,
`git config` queries) to report whether the tool is already present or
would be installed. Outputs a summary count at the end.

## Known environmental variations

- pyenv-win pip install: `~\.pyenv\pyenv-win\pyenv-win\bin` (extra level)
- pipx with spaces in USERPROFILE: requires PIPX_HOME migration to `C:\pipx`
- winget exit code -1978335189: means "already up to date", not failure
- Chocolatey "upgraded 0/N": means already current, not updated
- PSFzf: use `Install-Module -Force`, not `Update-Module`
- Choco promotional output: filtered before display
- winget spinner: filtered via `Where-Object` before display
- pyenv global version must be set or Show-DevEnvironment shows "not configured" hint

## Testing

131 Pester v5 tests across 7 files. Run with `Invoke-Pester tests/ -Output Detailed`.

| File | Tests | Coverage |
|------|------:|---------|
| Setup-DevEnvironment.Tests.ps1 | 14 | $CoreSteps regression, -InstallTool dispatch, Assert-Administrator, profile health patterns |
| Update-DevEnvironment.Tests.ps1 | 31 | Choco/winget/pipx output parsing, PSFzf module update, $PackageRegistry structure |
| Uninstall-Tool.Tests.ps1 | 20 | AST function removal, $PackageRegistry regex parsing, profile line removal, backup, braces-in-strings |
| Helpers.Tests.ps1 | 27 | Write-* functions, Backup-FileIfExists, Remove-OldBackups, Update-SessionPath merge |
| Apply-PowerShellProfile.Tests.ps1 | 8 | Profile deployment, backup, theme verification |
| Apply-VSCodeSettings.Tests.ps1 | 18 | Settings deployment, extension install, parameter switches, config file read |
| Profile.Tests.ps1 | 13 | Setup-PythonTools pipx install/$LASTEXITCODE, Show-DevEnvironment |

PSScriptAnalyzer: all warnings KNOWN/INTENTIONAL (Write-Host in transcript
context, Invoke-Expression for vendor init, ShouldProcess on internal
functions, singular nouns matching domain semantics).

## Attribution

Created by Matt Lawrence (megamatman). No AI attribution in codebase or commits.
