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
