# Maintenance -- Keeping Your Environment Current

Your dev environment includes tools from five different sources: Chocolatey, winget, pipx, PowerShell Gallery, and pyenv-win. Each has its own update mechanism. The `Update-DevEnvironment.ps1` script runs them all in one pass, but you can also update individual tools as needed.

## Setup

- **Update script**: `Update-DevEnvironment.ps1` is included in the winSetup repository alongside the setup script.
- **No scheduled automation**: The update script is run manually. There's no background service or scheduled task.

---

## Running the Update Script

```powershell
cd $env:WINSETUP
.\Update-DevEnvironment.ps1
```

This updates:
- **Chocolatey packages** (requires Administrator -- skipped if not elevated)
- **winget packages** (Oh My Posh, fzf, GitHub CLI)
- **pipx tools** (pylint, mypy, ruff, bandit, pre-commit, cookiecutter)
- **PSFzf module**
- **pyenv-win** available version list

Run as Administrator to include Chocolatey updates. Without elevation, only winget, pipx, PSFzf, and pyenv updates run.

**Close VS Code before running.** VS Code extensions (Ruff, Pylint, Mypy) hold Python tool executables open, causing pipx upgrades to fail with "Access is denied". The update script detects running VS Code and waits automatically until it is closed.

**PSFzf** updates run in a child PowerShell process automatically, so you do not need to close your terminal.

**pyenv-win** is updated via `pip install --upgrade` rather than `pyenv update`, which uses a VBScript that fails on modern Windows 11.

---

## Checking for Updates Without Installing

Preview what's outdated before committing to an update:

```powershell
# Chocolatey
choco outdated

# winget
winget upgrade --list

# pipx
pipx list

# Installed Python versions
pyenv versions
```

---

## Per-Package Manager Updates

### Chocolatey (requires Administrator)

```powershell
choco upgrade all -y           # Update everything
choco upgrade vscode -y        # Update a single package
choco pin add --name python    # Pin a package to skip during upgrades
```

### winget

```powershell
winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
winget upgrade JanDeDobbeleer.OhMyPosh    # Update a single package
```

### pipx

```powershell
pipx upgrade-all               # Update all tools
pipx upgrade ruff              # Update a single tool
pipx reinstall-all             # Reinstall everything (e.g., after Python upgrade)
```

### PSFzf module

The update script handles PSFzf updates in a child process automatically. To update manually:

```powershell
pwsh -NoProfile -Command "Update-Module PSFzf -Force"
```

### pyenv-win

Do not run `pyenv update` directly -- it uses a VBScript that fails on modern Windows 11. The update script uses pip instead:

```powershell
pip install pyenv-win --upgrade --target "$env:USERPROFILE\.pyenv\pyenv-win"
pyenv install --list           # See newly available versions
```

---

## Pre-commit Hooks (Per-Project)

Pre-commit hook versions are pinned in each project's `.pre-commit-config.yaml`. The update script does not touch these -- you update them per-project:

```powershell
cd ~\Code\my-project
pre-commit autoupdate          # Update hooks to latest versions
gs                             # See the modified config
ga .pre-commit-config.yaml
gc "Update pre-commit hooks"
```

Run this periodically in each project that uses pre-commit.

---

## Windows Defender Exclusions

The `-IncludeOptional` flag adds Defender exclusions for common development directories (`~\Code`, `~\.pyenv`, `~\.local`, `~\.venv`). This reduces real-time scanning overhead when building, running tests, or installing packages.

To add exclusions manually:

```powershell
# Requires Administrator
Add-MpPreference -ExclusionPath "$env:USERPROFILE\Code"
```

To see current exclusions:

```powershell
(Get-MpPreference).ExclusionPath
```

Only exclude directories you trust. Don't exclude download folders or temp directories.

---

## Real-World Workflows

### Monthly maintenance

```powershell
# Run as Administrator
cd $env:WINSETUP
.\Update-DevEnvironment.ps1

# Then update pre-commit in active projects
z my-api
pre-commit autoupdate
ga .pre-commit-config.yaml
gc "Update pre-commit hooks"
```

### After a Python version upgrade

If you install a new Python version via pyenv and want your pipx tools to use it:

```powershell
pyenv global 3.13.1
pipx reinstall-all             # Rebuilds all pipx tool environments with the new Python
```

### Checking if a tool needs updating before a demo

```powershell
choco outdated | rg "vscode\|python"
winget upgrade --list | rg "OhMyPosh\|fzf"
```

---

## Tips and Gotchas

- **Chocolatey needs elevation**: `choco upgrade` fails without Administrator. The update script detects this and skips Chocolatey updates gracefully.
- **winget and Chocolatey don't conflict**: They manage separate package databases. A tool installed via winget (fzf) won't be touched by `choco upgrade all`, and vice versa.
- **pipx tools are independent of pyenv**: pipx tools use the Python version that was active when they were installed. Changing `pyenv global` doesn't affect them. Use `pipx reinstall-all` after changing the global Python if you want them on the new version.
- **Pre-commit autoupdate changes the config file**: `pre-commit autoupdate` modifies `.pre-commit-config.yaml` in place. Always review the changes with `git diff` before committing.
- **PSFzf updates are transparent**: The update script runs PSFzf updates in a child process, so the module is never locked. No terminal restart needed.

---

## See Also

- [Chocolatey](01-chocolatey.md) -- package management basics
- [Python Environment](05-python-environment.md) -- pipx and Python tools
- [Python Version Management](08-python-version-management.md) -- pyenv-win
- [Project Setup](09-project-setup.md) -- pre-commit configuration
