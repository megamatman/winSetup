# Maintenance Cheatsheet

Keeping your dev environment tools up to date.

## Update Script

| Command | What it does |
|---|---|
| `.\Update-DevEnvironment.ps1` | Update all tools (run as Admin for Chocolatey) |

## Manual Updates

| Command | What it does |
|---|---|
| `choco upgrade all -y` | Update all Chocolatey packages |
| `winget upgrade --all` | Update all winget packages |
| `pipx upgrade-all` | Update all pipx tools |
| `Update-Module PSFzf -Force` | Update PSFzf module |
| `pyenv update` | Update pyenv available version list |
| `pre-commit autoupdate` | Update hooks in current repo (run per-project) |

## Check Before Updating

| Command | What it does |
|---|---|
| `choco outdated` | List outdated Chocolatey packages |
| `winget upgrade --list` | List available winget updates |
| `pipx list` | Show installed pipx tools and versions |
| `pyenv versions` | Show installed Python versions |

## Git Identity

| Command | What it does |
|---|---|
| `git config --global user.name "Name"` | Set commit author name |
| `git config --global user.email "email"` | Set commit author email |
| `git config --global user.name` | Check current name |
| `git config --global user.email` | Check current email |

## GitHub SSH Keys

| Command | What it does |
|---|---|
| `gh auth login` | Authenticate GitHub CLI |
| `gh ssh-key list` | List keys uploaded to GitHub |
| `gh ssh-key add ~\.ssh\id_ed25519.pub --type authentication` | Upload auth key |
| `gh ssh-key add ~\.ssh\id_ed25519.pub --type signing` | Upload signing key |

## Terminal Commands

| Command | What it does |
|---|---|
| `Show-DevEnvironment` | Show all tool versions and status |
| `Test-ProfileHealth` | Check profile completeness |
| `Invoke-DevSetup` | Re-run setup from anywhere |
| `Invoke-DevUpdate` | Run updates from anywhere |
| `.\Apply-VSCodeSettings.ps1` | Redeploy VS Code settings and extensions |
| `.\Apply-VSCodeSettings.ps1 -SettingsOnly` | Redeploy settings only |
| `.\Apply-PowerShellProfile.ps1` | Redeploy PowerShell profile |

## Tips

- Run `Update-DevEnvironment.ps1` as Administrator to include Chocolatey updates.
- `pre-commit autoupdate` is per-repo -- run it in each project that uses pre-commit.
- After updating pyenv with `pyenv update`, run `pyenv install --list` to see newly available Python versions.

---

## See Also

- [Python](cheatsheet-python.md) -- pip, pipx, linting tools
- [Git](cheatsheet-git.md) -- everyday git commands and aliases
- [Chocolatey](cheatsheet-chocolatey.md) -- package management
