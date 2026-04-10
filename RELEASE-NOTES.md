# Release Notes: v1.1.0

Released: 2026-04-10

## Fixes

- `Install-PythonTools` now uses `Invoke-Pipx` instead of calling pipx
  directly. On some Windows configurations, pipx.exe is a Python launcher
  script and fails with StandardOutputEncoding errors when called with
  output redirection. `Invoke-Pipx` retries via `python -m pipx` when
  the direct call throws. 3 call sites replaced.
- `Uninstall-Tool.ps1` Step 2 uses the PowerShell AST parser to locate
  `Install-*` function boundaries for removal. Replaces the previous
  brace-counting approach, which miscounted braces inside string literals
  and here-strings.
- `Wait-VSCodeClosed` timeout now prompts with Y/N instead of hanging
  indefinitely.
- `-InstallTool` dispatch adds `-CommandType Function` to `Get-Command`
  to avoid matching external executables.
- `Setup-PythonTools` checks `$LASTEXITCODE` after each `pipx install`
  and reports failures individually.

## Features

- `-WhatIf` dry-run mode on `Setup-DevEnvironment.ps1`. Previews all 18
  core steps (plus 4 optional with `-IncludeOptional`) without making
  changes. Each step uses the same detection logic as the real install.
- `bootstrap.ps1` for one-line first-time installation. Handles PS7
  check, git install via winget, repo clone, WINSETUP env var setup,
  and optional hand-off to `Setup-DevEnvironment.ps1`. Runs without
  admin. Security notice displayed before any action.
- Custom project templates via `~/.wintemplates` with `-TemplateName`
  parameter on `-ScaffoldPyproject`. Falls back to built-in template
  when no custom template exists.
- SHA256 checksums for all source and config files via
  `New-Checksums.ps1`. `checksums.sha256` published as a release asset.

## Refactoring

- Per-manager update helpers (`Invoke-ChocoUpdate`, `Invoke-WingetUpdate`,
  `Invoke-PipxUpdate`) extracted from `Update-SinglePackage` and
  `Update-All` in `Update-DevEnvironment.ps1`.
- VS Code settings moved from an embedded here-string in
  `Apply-VSCodeSettings.ps1` to `configs/vscode-settings.json`.
- `ScaffoldPyproject` template uses `os.environ.get()` patterns for
  environment variable access. `load_dotenv` retained as commented-out
  code for local development.

## Documentation

- `INTERFACE.md` introduced: versioned interface contract for consumers
  (contract version 2 current). Covers `$PackageRegistry` format,
  `Install-*` naming, `$CoreSteps` semantics, profile section comment
  patterns, `-InstallTool` dispatch, and `$PROFILE` managed section
  boundary with consumer extension contract.
- README: "One-line install" section with `bootstrap.ps1` one-liner and
  security notice. "Verifying files" section with `Get-FileHash`
  instructions.
- `QUICK-REFERENCE.md` updated with bootstrap, `-WhatIf`,
  `-TemplateName`, and file verification entries.
- `CONTRIBUTING.md` updated: `$PackageRegistry` step added to "adding a
  new tool" guide, `Helpers.ps1` function list completed.
- 12 HowTo-Guides, 11 Tutorials, 13 Cheatsheets published.

## Tests

166 Pester v5 tests across 9 files (up from 94 at v1.0.0):

| File | Tests | Coverage |
|------|------:|---------|
| Setup-DevEnvironment.Tests.ps1 | 26 | $CoreSteps regression, -InstallTool dispatch, Assert-Administrator, Invoke-Pipx fallback, ScaffoldPyproject template, custom templates, profile health patterns |
| Update-DevEnvironment.Tests.ps1 | 31 | Choco/winget/pipx output parsing, PSFzf module update, $PackageRegistry structure |
| Uninstall-Tool.Tests.ps1 | 20 | AST function removal, $PackageRegistry regex parsing, profile line removal, backup, braces-in-strings |
| Helpers.Tests.ps1 | 27 | Write-* functions, Backup-FileIfExists, Remove-OldBackups, Update-SessionPath merge |
| Apply-PowerShellProfile.Tests.ps1 | 8 | Profile deployment, backup, theme verification |
| Apply-VSCodeSettings.Tests.ps1 | 18 | Settings deployment, extension install, parameter switches, config file read |
| Profile.Tests.ps1 | 13 | Setup-PythonTools pipx install/$LASTEXITCODE, Show-DevEnvironment |
| Bootstrap.Tests.ps1 | 13 | Pre-flight checks, security notice, structure |
| New-Checksums.Tests.ps1 | 10 | Output format, entry count, hash verification, exclusions |

---

# Release Notes: v1.0.0

Released: 2026-04-06

## What this is

winSetup is a Windows 11 development environment setup tool for teams. One
script installs and configures a complete Python and general development
environment. Safe to re-run: every step checks before acting.

## What is installed

**Package managers:** Chocolatey, winget (built into Windows 11)

**Development tools:** VS Code, Git, GitHub CLI, Python (via Chocolatey),
pyenv-win (Python version management)

**Terminal:** Oh My Posh (Gruvbox theme), Hack Nerd Font, Windows Terminal
font configuration, PowerShell 7 profile with fzf, PSFzf, fd, bat,
ripgrep, zoxide, delta, lazygit

**Python tooling:** pipx, pylint, mypy, ruff (linting and formatting),
bandit, pre-commit, cookiecutter

**Git configuration:** delta as diff pager, SSH commit signing, global
.gitignore, git identity check, GitHub SSH key upload

**Security:** SSH key deployment with correct permissions, global
.gitignore covering secrets and keys, pre-commit template with
detect-private-key hook

## What is included

| File | Purpose |
|---|---|
| `Setup-DevEnvironment.ps1` | Full environment setup (`-WhatIf` for dry run, `-InstallTool` for single tools) |
| `Update-DevEnvironment.ps1` | Keep all tools up to date (per-package or full update) |
| `Uninstall-Tool.ps1` | Remove a tool from the machine and from winSetup management |
| `Apply-VSCodeSettings.ps1` | VS Code settings and extensions |
| `Apply-PowerShellProfile.ps1` | PowerShell profile deployment |
| `Helpers.ps1` | Shared helper functions (dot-sourced by all scripts) |
| `profile.ps1` | Canonical PowerShell profile source |
| `Hack.zip` | Hack Nerd Font (bundled) |
| `configs/` | Oh My Posh theme and VS Code settings (single source of truth) |
| `templates/` | Pre-commit config and Python project template |
| `tests/` | Pester test suite (7 files, 131 tests) |
| `INTERFACE.md` | Versioned interface contract for consumers (e.g. winTerface) |

## Documentation

| Document | Contents |
|---|---|
| `HowTo-Guides/` | Reference guides for every installed tool |
| `Tutorials/` | Eleven progressive tutorials from first terminal open to team workflow |
| `Cheatsheets/` | Quick-reference command tables for every tool |
| `TROUBLESHOOTING.md` | Symptom-first troubleshooting for 40+ common problems |
| `QUICK-REFERENCE.md` | Single-page task navigator |
| `CONTRIBUTING.md` | How to add tools, edit the profile, and contribute |
| `INTERFACE.md` | Stable interface contract for consumers (contract version 1) |

## Requirements

- Windows 11
- PowerShell 7+
- Administrator access to run `Setup-DevEnvironment.ps1`
- `Hack.zip` in the repository directory (included)
- `.ssh.zip` in the repository directory (you create this; see README)

## Known limitations

- Corporate machines with restricted GPO or proxy settings may block
  Chocolatey bootstrap or winget. No automated fallback exists for these.
- `Setup-PythonTools` runs on every terminal open (with a daily check).
  On machines without Python this produces a warning until setup is run.
- The step counter (`$CoreSteps`) in `Setup-DevEnvironment.ps1` is a
  hardcoded constant that must be manually updated if steps are added or
  removed. A Pester regression test validates the count, and
  `Uninstall-Tool.ps1` decrements it automatically via AST parsing.

## Quick start

See `README.md`.
