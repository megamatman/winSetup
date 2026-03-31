# Chocolatey -- Windows Package Manager

This guide covers Chocolatey usage beyond the setup script: version pinning, package inspection, and maintenance. For command reference see [cheatsheet-chocolatey.md](../Cheatsheets/cheatsheet-chocolatey.md).

## Setup

Handled by `Setup-DevEnvironment.ps1`. Chocolatey is installed via the official bootstrap script and requires an elevated (Administrator) PowerShell session. The Chocolatey PowerShell profile module is loaded automatically in your profile via:

```powershell
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}
```

This gives you the `refreshenv` command, which reloads environment variables (like PATH) without restarting your terminal.

## Core Usage

### Search for a package

```powershell
choco search nodejs
```

This searches the Chocolatey community repository. You'll see package names, versions, and download counts.

### Install a package

```powershell
choco install nodejs -y
```

The `-y` flag auto-confirms prompts. Without it, Chocolatey asks you to confirm each install.

### Install a specific version

```powershell
choco install python --version=3.11.9 -y
```

### See what's installed

```powershell
choco list
```

This shows every package Chocolatey manages on your system, with version numbers.

### Update a single package

```powershell
choco upgrade nodejs -y
```

### Update everything

```powershell
choco upgrade all -y
```

This upgrades every Chocolatey-managed package to its latest version. Run this periodically to keep your tools current.

### Uninstall a package

```powershell
choco uninstall nodejs -y
```

### Check what's outdated

```powershell
choco outdated
```

Lists packages that have newer versions available, without installing anything.

## Real-World Workflows

### Setting up a new project that needs Node.js

You're starting a React project but don't have Node installed:

```powershell
choco install nodejs -y
refreshenv
node --version
npm init -y
```

`refreshenv` reloads your PATH so `node` and `npm` are available immediately without opening a new terminal.

### Weekend maintenance

Update all your dev tools in one command:

```powershell
# Run as Administrator
choco upgrade all -y
```

This catches updates for VS Code, Python, ripgrep, bat, and anything else you've installed through Chocolatey.

### Pinning a package version

If a project requires a specific Python version and you don't want `choco upgrade all` to bump it:

```powershell
choco pin add --name python --version 3.12.4
```

Now `choco upgrade all` will skip Python. Remove the pin later with:

```powershell
choco pin remove --name python
```

## Tips and Gotchas

- **Elevation required**: Most `choco install` and `choco upgrade` commands need an Administrator terminal. If you forget, you'll get a permissions error.
- **`refreshenv` is your friend**: After installing something, run `refreshenv` instead of closing and reopening your terminal. This is provided by the Chocolatey profile module loaded in your PowerShell profile.
- **Don't mix installers**: If you install Python via Chocolatey, don't also install it from python.org or the Microsoft Store. You'll end up with conflicting PATH entries and confusing version behaviour.
- **Chocolatey vs winget**: Both are package managers. This setup uses Chocolatey for most tools and winget for Oh My Posh, fzf, and GitHub CLI (because those packages are better maintained on winget). They coexist fine -- just don't install the same package from both.
- **Package source**: Chocolatey's community repository is at https://community.chocolatey.org/packages. You can browse it to check package names, maintainers, and version history before installing.

---

## See Also

- [PowerShell Terminal](02-powershell-terminal.md) -- keybindings, autosuggestions, and Oh My Posh
- [Python Environment](05-python-environment.md) -- pipx and Python tools installed via Chocolatey