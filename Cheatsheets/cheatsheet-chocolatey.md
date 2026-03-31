# Chocolatey Cheatsheet

Command-line package manager for Windows. Requires elevated (Administrator) terminal.

## Commands

| Command | What it does |
|---|---|
| `choco search <name>` | Search for a package |
| `choco install <name> -y` | Install a package (auto-confirm) |
| `choco install <name> --version=<ver> -y` | Install a specific version |
| `choco list` | List installed packages |
| `choco outdated` | Show packages with available updates |
| `choco upgrade <name> -y` | Update a single package |
| `choco upgrade all -y` | Update all packages |
| `choco uninstall <name> -y` | Remove a package |
| `choco pin add --name <name>` | Pin a package (skip during `upgrade all`) |
| `choco pin remove --name <name>` | Unpin a package |
| `choco pin list` | Show pinned packages |
| `refreshenv` | Reload PATH without restarting terminal |

## Tips

- Always run in an **Administrator** terminal.
- Run `refreshenv` after installing something so the new command is immediately available.
- Don't install the same tool from both Chocolatey and winget -- pick one.
- `choco upgrade all -y` is safe to run periodically as a maintenance step.
