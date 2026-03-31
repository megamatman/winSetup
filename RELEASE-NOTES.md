# Release Notes -- v1.0.0

Released: 2026-03-31

## What this is

winSetup is a Windows 11 development environment setup tool for teams. One
script installs and configures a complete Python and general development
environment. Safe to re-run -- every step checks before acting.

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
| `Setup-DevEnvironment.ps1` | Full environment setup |
| `Apply-VSCodeSettings.ps1` | VS Code settings and extensions |
| `Apply-PowerShellProfile.ps1` | PowerShell profile deployment |
| `Update-DevEnvironment.ps1` | Keep all tools up to date |
| `Helpers.ps1` | Shared helper functions (dot-sourced by all scripts) |
| `profile.ps1` | Canonical PowerShell profile source |
| `Hack.zip` | Hack Nerd Font (bundled) |
| `templates/` | Pre-commit config and Python project template |

## Documentation

| Directory | Contents |
|---|---|
| `HowTo-Guides/` | Reference guides for every installed tool |
| `Tutorials/` | Eleven progressive tutorials from first terminal open to team workflow |
| `Cheatsheets/` | Quick-reference command tables for every tool |
| `TROUBLESHOOTING.md` | Symptom-first troubleshooting for 40+ common problems |
| `QUICK-REFERENCE.md` | Single-page task navigator |

## Requirements

- Windows 11
- PowerShell 7+
- Administrator access to run `Setup-DevEnvironment.ps1`
- `Hack.zip` in the repository directory (included)
- `.ssh.zip` in the repository directory (you create this -- see README)

## Known limitations

- Corporate machines with restricted GPO or proxy settings may block
  Chocolatey bootstrap or winget. No automated fallback exists for these.
- `Setup-PythonTools` runs on every terminal open (with a daily check).
  On machines without Python this produces a warning until setup is run.
- The step counter in `Setup-DevEnvironment.ps1` is a hardcoded constant
  that must be manually updated if steps are added or removed.

## Quick start

See `README.md`.
