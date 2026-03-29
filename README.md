# Windows Dev Environment Setup

One script to set up a fresh Windows 11 machine for development. Safe to re-run — it skips anything already installed.

## Quick Start (ELI5)

You just got a new Windows PC (or reinstalled Windows) and need all your dev tools back. Instead of spending an hour manually installing things one by one, you run one command and it does everything for you.

**Step 1:** Right-click the Start menu and pick **Terminal (Admin)**.

**Step 2:** Navigate to this folder:

```powershell
cd "$env:USERPROFILE\OneDrive\Documents\Code\winSetup"
```

**Step 3:** Run the script:

```powershell
.\Setup-DevEnvironment.ps1
```

That's it. Go get a coffee. When you come back, your machine will have Chocolatey, VS Code, Python, Oh My Posh, Hack Nerd Font, your SSH keys, and all your Python linting tools installed.

> **Already signed into GitHub and OneDrive?** Your VS Code settings, extensions, and PowerShell profile will sync automatically — the script skips those by default. If sync hasn't kicked in yet, add `-IncludeOptional` to install them manually as a fallback.

## What It Installs

| Tool | How | Skips if |
|---|---|---|
| Chocolatey | Official bootstrap script | `choco` command exists |
| VS Code | `choco install vscode` | `code` command exists |
| Python | `choco install python` | `python` exists (ignores the Windows Store stub) |
| Oh My Posh | `winget install` | `oh-my-posh` command exists |
| Hack Nerd Font | Extracts bundled `Hack.zip` | Font files already in `C:\Windows\Fonts` |
| SSH keys | Extracts bundled `.ssh.zip` | `~\.ssh\id_ed25519` exists |
| Windows Terminal font | Surgical JSON edit | Already set to Hack Nerd Font |
| Python tools | pipx (pylint, black, mypy, ruff, bandit) | Each tool checked individually |

### Optional (sync fallback)

These are normally handled by VS Code Settings Sync and OneDrive. Pass `-IncludeOptional` to apply them manually:

| Item | What it does |
|---|---|
| VS Code `settings.json` | Full replacement with standard config |
| VS Code extensions | Installs 15 extensions (Python, linting, Git, formatting) |
| PowerShell profile | Full replacement with SSH agent, Oh My Posh, and Python tools setup |

## Usage

```powershell
# Standard setup:
.\Setup-DevEnvironment.ps1

# Include optional sync-fallback steps:
.\Setup-DevEnvironment.ps1 -IncludeOptional

# Scaffold a pyproject.toml into a project:
.\Setup-DevEnvironment.ps1 -ScaffoldPyproject "C:\Projects\my-app"
```

## Requirements

- Windows 11
- PowerShell 7+
- Run as Administrator
- `Hack.zip` and `.ssh.zip` in the same directory as the script

## Bundled Files

| File | Contents |
|---|---|
| `Hack.zip` | Hack Nerd Font TTF files |
| `.ssh.zip` | SSH keys (`id_ed25519` + related files) |

These must be placed alongside `Setup-DevEnvironment.ps1` before running.
