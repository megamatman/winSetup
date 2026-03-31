# Contributing to winSetup

## Repository structure

| File | Purpose |
|---|---|
| `Setup-DevEnvironment.ps1` | Main setup orchestrator -- installs tools, configures git, deploys SSH keys |
| `Apply-VSCodeSettings.ps1` | Standalone VS Code settings and extension deployer |
| `Apply-PowerShellProfile.ps1` | Deploys `profile.ps1` to `$PROFILE` |
| `Update-DevEnvironment.ps1` | Updates all package managers and tools |
| `Helpers.ps1` | Shared helper functions -- dot-sourced by all scripts |
| `profile.ps1` | **Single source of truth** for the PowerShell profile |

## Adding a new tool

To add a new tool to the setup, change these files in order:

1. **`Setup-DevEnvironment.ps1`** -- add an install function (or add to `Install-CLITools`'s `$tools` array). Add the function call to the main execution block. Increment `$CoreSteps`.
2. **`profile.ps1`** -- add any aliases, environment variables, or config. Add the tool to `Show-DevEnvironment`'s `$tools` hashtable. Add to `Test-ProfileHealth`'s `expectedSections` if the profile section is worth checking.
3. **`README.md`** -- add a row to the "What Gets Installed" table.

If the tool is a pipx package, add it to the `$tools` array in `Setup-PythonTools` (in both `Setup-DevEnvironment.ps1` and `profile.ps1`).

**Do not** define helper functions (`Write-Change`, `Write-Skip`, etc.) in individual scripts. They live in `Helpers.ps1`.

## Editing the PowerShell profile

1. Edit `profile.ps1` (the file in this repository, not `$PROFILE` directly)
2. Run `.\Apply-PowerShellProfile.ps1` to deploy it
3. Restart your terminal or run `. $PROFILE`

**Never** edit the live profile at `$PROFILE` directly. `profile.ps1` is the single source of truth.

## Branching strategy

- Work on feature branches (`feature/<description>` or `fix/<description>`)
- PR to `master` for review
- Do not push directly to `master`

## Helpers.ps1 convention

All shared output functions live in `Helpers.ps1`:
- `Write-Change` -- green, something was installed or configured
- `Write-Skip` -- grey, already present
- `Write-Issue` -- red, something failed
- `Write-Step` -- cyan, section header with step counter
- `Backup-FileIfExists` -- backs up a file before overwriting
- `Update-SessionPath` -- reloads PATH from the registry
- `Write-Summary` -- prints installed/skipped/failed summary

Every script dot-sources `Helpers.ps1` at the top: `. "$PSScriptRoot\Helpers.ps1"`

## Running scripts on a fresh machine

1. Clone the repository
2. Place `.ssh.zip` in the repo root (see README.md for creation instructions)
3. Open PowerShell 7 as Administrator
4. Run `.\Setup-DevEnvironment.ps1`
5. Optionally run `.\Setup-DevEnvironment.ps1 -IncludeOptional` for VS Code settings and profile

## Architectural decisions

- **`profile.ps1` is the single source of truth** for the PowerShell profile. `Apply-PowerShellProfile.ps1` copies it to `$PROFILE`. There is no embedded here-string.
- **`Helpers.ps1` eliminates duplication.** All shared functions live in one file, dot-sourced by every script.
- **Configuration is inline, not in a separate data file.** Tool lists, extension IDs, and git settings are defined in the functions that use them. This keeps each function self-contained at the cost of requiring manual updates when adding tools.
