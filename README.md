# Windows Dev Environment Setup

One script to set up a complete Windows 11 development environment. Safe to re-run: skips anything already installed.

> **Looking for the terminal UI?** [winTerface](https://github.com/megamatman/winTerface) provides a keyboard-driven TUI for managing your winSetup environment: install, update, and remove tools, check profile health, and run updates without memorising commands.

## One-line install

Open PowerShell 7 and run:

```powershell
irm "https://raw.githubusercontent.com/megamatman/winSetup/refs/tags/v1.1.0/bootstrap.ps1" | iex
```

The script prompts for confirmation before taking any action. It installs git if needed, clones the repo, and walks you through setup. `bootstrap.ps1` runs without admin rights; `Setup-DevEnvironment.ps1` requests elevation when it runs. [Review the script](https://github.com/megamatman/winSetup/blob/main/bootstrap.ps1) before running. For the manual path, see [Prerequisites](#prerequisites) below.

## Prerequisites

- Windows 11
- PowerShell 7+ (download from https://aka.ms/powershell if needed)
- Administrator access (right-click Terminal > Run as Administrator)
- `Hack.zip` in the repo directory (included in the repo)
- `.ssh.zip` in the repo directory (you create this; see [SSH Keys](#ssh-keys))

## Quick Start

**Step 1:** Open Terminal as Administrator.

**Step 2:** Navigate to this repository and run:

```powershell
cd "path\to\winSetup"
.\Setup-DevEnvironment.ps1
```

**Step 3:** There is no step 3. The script handles everything.

> **Already signed into GitHub and OneDrive?** VS Code settings, extensions, and your PowerShell profile sync automatically. The script skips those by default. If sync hasn't kicked in on a fresh machine, add `-IncludeOptional` to deploy them manually.

## What Gets Installed

### Always installed

| Tool | Purpose | Skips if |
|---|---|---|
| Chocolatey | Windows package manager | `choco` command exists |
| VS Code | Code editor | `code` command exists |
| Python | Python runtime (not the Store stub) | `python` exists and is not the Store alias |
| Oh My Posh | Themed terminal prompt (Gruvbox theme) | `oh-my-posh` command exists |
| GitHub CLI | GitHub operations from the terminal | `gh` command exists |
| fzf | Fuzzy finder | `fzf` command exists |
| fd | Fast file finder | `fd` command exists |
| PSFzf | PowerShell fzf integration module | Module already installed |
| zoxide | Smart directory jumper | `zoxide` command exists |
| bat | Syntax-highlighted file viewer | `bat` command exists |
| ripgrep | Fast content search | `rg` command exists |
| delta | Side-by-side git diff viewer | `delta` command exists |
| lazygit | Terminal git UI | `lazygit` command exists |
| pyenv-win | Python version manager | `~\.pyenv` directory exists |
| Hack Nerd Font | Terminal font with icons | Font files in `C:\Windows\Fonts` |
| SSH keys | Deployed from `.ssh.zip` | `~\.ssh\id_ed25519` exists |
| GitHub SSH key upload | Uploads key via `gh` (auth + signing) | Key already on GitHub |
| Windows Terminal font | Sets Hack Nerd Font in terminal config | Already set |
| Python tools (pipx) | pylint, mypy, ruff, bandit, pre-commit, cookiecutter | Each checked individually |
| Global .gitignore | Blocks secrets, caches, OS files from commits | `~\.gitignore_global` exists |
| Git commit signing | SSH-based commit signatures | `gpg.format` already set to `ssh` |
| Delta git config | Sets delta as the git pager | `core.pager` already set to `delta` |
| Git identity check | Detects missing `user.name`/`user.email` | Already configured |
| Profile health check | Validates the PowerShell profile has all sections | Informational only |

### Installed with `-IncludeOptional`

These are normally handled by VS Code Settings Sync (via GitHub) and OneDrive. Use `-IncludeOptional` on a fresh machine where sync hasn't run yet.

| Item | What it does |
|---|---|
| VS Code `settings.json` | Full replacement with standard config (backs up existing) |
| VS Code extensions | Installs 15 extensions (Python, linting, Git, formatting) |
| PowerShell profile | Full replacement (backs up existing) |
| Windows Defender exclusions | Excludes `~\Code`, `~\.pyenv`, `~\.local`, `~\.venv` from scanning |

## Scripts Reference

| Script | Purpose | Key flags |
|---|---|---|
| `bootstrap.ps1` | One-line install for fresh machines (no admin needed) | `-InstallPath`, `-RunSetup` |
| `Setup-DevEnvironment.ps1` | Full environment setup (requires Admin) | `-IncludeOptional`, `-CheckProfileOnly`, `-ScaffoldPyproject`, `-TemplateName`, `-WhatIf` |
| `Apply-VSCodeSettings.ps1` | VS Code settings and extensions | `-SettingsOnly`, `-ExtensionsOnly` |
| `Apply-PowerShellProfile.ps1` | Deploys `profile.ps1` to `$PROFILE` | none |
| `Update-DevEnvironment.ps1` | Update all tools to latest versions | requires Admin for Chocolatey |
| `Uninstall-Tool.ps1` | Remove a tool from the machine and from winSetup management | `-Tool <name>`, `-KeepFiles` |
| `profile.ps1` | Canonical PowerShell profile source (single source of truth) | -- |
| `Helpers.ps1` | Shared helper functions (dot-sourced by all scripts) | -- |

```powershell
# Full setup (fresh machine):
.\Setup-DevEnvironment.ps1

# Full setup including optional sync-fallback steps:
.\Setup-DevEnvironment.ps1 -IncludeOptional

# Check profile completeness without making changes:
.\Setup-DevEnvironment.ps1 -CheckProfileOnly

# Preview what setup would do without making changes:
.\Setup-DevEnvironment.ps1 -WhatIf

# Scaffold a pyproject.toml into a project:
.\Setup-DevEnvironment.ps1 -ScaffoldPyproject "~\Projects\my-app"

# Deploy VS Code settings and extensions:
.\Apply-VSCodeSettings.ps1

# Deploy VS Code settings only (skip extensions):
.\Apply-VSCodeSettings.ps1 -SettingsOnly

# Deploy PowerShell profile:
.\Apply-PowerShellProfile.ps1

# Update all tools:
.\Update-DevEnvironment.ps1
```

## Terminal Commands

After setup, these commands are available in any terminal session.

### Environment management

| Command | What it does |
|---|---|
| `Show-DevEnvironment` | Print all tool versions and environment status |
| `Test-ProfileHealth` | Check that your profile has all expected sections |
| `Setup-PythonTools` | Verify and install Python tools via pipx |
| `Invoke-DevSetup` | Run `Setup-DevEnvironment.ps1` from anywhere |
| `Invoke-DevUpdate` | Run `Update-DevEnvironment.ps1` from anywhere |

### Daily shortcuts

| Command | What it does |
|---|---|
| `z <keyword>` | Jump to a directory via zoxide |
| `zi <keyword>` | Interactive directory jump via zoxide + fzf |
| `lg` | Launch lazygit |
| `gs` | `git status` |
| `ga <files>` | `git add` |
| `gc "message"` | `git commit -m` |
| `gp` | `git push` |
| `gl` | `git log --oneline --graph --decorate` |
| `cat <file>` | View file with bat (syntax highlighting) |

## New Project Quickstart

`$env:WINSETUP` is set automatically by your profile. If it's not set, define it first:

```powershell
$env:WINSETUP = "path\to\winSetup"
```

### 1. Create the project directory

```powershell
mkdir $env:USERPROFILE\Projects\my-new-project
cd $env:USERPROFILE\Projects\my-new-project
```

### 2. Initialise git and create a virtual environment

```powershell
git init
python -m venv .venv
.venv\Scripts\Activate.ps1
```

### 3. Copy template files and pre-commit config

```powershell
Copy-Item "$env:WINSETUP\templates\python-project\*" . -Recurse
Copy-Item "$env:WINSETUP\templates\pre-commit-config.yaml" .\.pre-commit-config.yaml
```

### 4. Install hooks and make the first commit

```powershell
pre-commit install
ga .
gc "Initial project setup"
```

Your project now has git, a virtual environment, linting config, pre-commit hooks, and a first signed commit.

## Maintenance

### Recommended cadence

| When | What to do |
|---|---|
| Weekly | Nothing: hooks run automatically on every commit |
| Monthly | Run `.\Update-DevEnvironment.ps1` (as Admin for Chocolatey) |
| Per new project | Copy pre-commit config and run `pre-commit install` |
| When joining a repo | Run `pre-commit install` after cloning |

### Updating tools

```powershell
.\Update-DevEnvironment.ps1
```

This updates Chocolatey packages, winget packages, pipx tools, PSFzf, and pyenv-win in one pass. Run as Administrator to include Chocolatey updates.

Close VS Code before running updates. The Ruff and Pylint extensions hold Python tool executables open, which causes pipx upgrades to fail. The update script detects this and waits automatically.

### Updating pre-commit hooks (per-project)

```powershell
cd ~\Projects\my-project
pre-commit autoupdate
ga .pre-commit-config.yaml
gc "Update pre-commit hooks"
```

## SSH Keys

The setup script deploys SSH keys from `.ssh.zip` and uploads them to GitHub automatically if `gh` is authenticated.

### I already have SSH keys

Zip your `~\.ssh` folder contents into this directory:

```powershell
Compress-Archive -Path "$env:USERPROFILE\.ssh\*" -DestinationPath ".ssh.zip"
```

### I need to generate new keys

1. Open a terminal (does not need to be Admin):

   ```powershell
   ssh-keygen -t ed25519 -C "your-email@example.com"
   ```

   Press Enter to accept the default location (`~\.ssh\id_ed25519`). Add a passphrase if you want.

2. Add the public key to GitHub. Copy the output and paste it at https://github.com/settings/ssh/new:

   ```powershell
   Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"
   ```

3. Zip the keys into this directory:

   ```powershell
   Compress-Archive -Path "$env:USERPROFILE\.ssh\*" -DestinationPath ".ssh.zip"
   ```

### I used a different key type

The script defaults to `id_ed25519`. If you used a different type (e.g. `id_rsa`), update these two lines in `Setup-DevEnvironment.ps1`:

| Line | What to change |
|---|---|
| `$keyPath = Join-Path $sshDir "id_ed25519"` (in `Install-SSHKeys`) | Change `"id_ed25519"` to your key filename |
| `$keyPath = Join-Path $env:USERPROFILE ".ssh\id_ed25519"` (in `profile.ps1`) | Change `"id_ed25519"` to your key filename |

## Verifying files

SHA256 checksums for all source and config files are published in `checksums.sha256`. To verify a file before running it:

```powershell
(Get-FileHash bootstrap.ps1 -Algorithm SHA256).Hash
```

Compare the output against the corresponding entry in `checksums.sha256`.

## Documentation

**Not sure where to start? See [QUICK-REFERENCE.md](QUICK-REFERENCE.md).**

| Document | Contents |
|---|---|
| [QUICK-REFERENCE.md](QUICK-REFERENCE.md) | Single-page task navigator: "I want to do X, where do I go?" |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Symptom-first problem solving (40+ entries) |
| `HowTo-Guides/` | Reference guides for every tool: what it does, how to use it, real examples |
| `Tutorials/` | Progressive tutorials from first terminal open to security hygiene |
| `Cheatsheets/` | One-page quick-reference tables for every tool and capability |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to add tools, edit the profile, and contribute to this repo |

## Interface Contract

winSetup exposes a stable interface for consumers such as [winTerface](https://github.com/megamatman/winTerface). The full specification is in [INTERFACE.md](INTERFACE.md).

**Current contract version: 2** (defined as `$script:ContractVersion` in `Setup-DevEnvironment.ps1`).

The contract covers: `$PackageRegistry` format, `Install-*` function naming, `$CoreSteps` semantics, profile section comment patterns, and the `-InstallTool` parameter dispatch. See INTERFACE.md for what constitutes a breaking vs non-breaking change.

### Where Things Live

| What | Where |
|---|---|
| PowerShell profile | `$PROFILE` (typically `~\OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`) |
| VS Code settings | `$env:APPDATA\Code\User\settings.json` |
| Tools | Installed via Chocolatey, winget, pipx, and pip to their standard locations |
| Templates | `$env:WINSETUP\templates\` |
| SSH keys | `~\.ssh\` |
| pyenv versions | `~\.pyenv\pyenv-win\versions\` |
| Global .gitignore | `~\.gitignore_global` |

**New to this setup?** Start with `Tutorials/01-getting-oriented.md`.

**Something broken?** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
