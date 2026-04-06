# Quick Reference

## I'm new here

| I want to... | Go to |
|---|---|
| Set up a fresh machine | [README.md: Quick Start](README.md#quick-start) |
| Understand what's installed | [README.md: What Gets Installed](README.md#what-gets-installed) |
| Learn the tools | [Tutorials/01-getting-oriented.md](Tutorials/01-getting-oriented.md) |
| Check everything is working | Run `Show-DevEnvironment` |
| Verify my profile is complete | Run `Test-ProfileHealth` |

## Daily development

| I want to... | Go to |
|---|---|
| Start a new Python project | [Tutorials/09-new-project-from-scratch.md](Tutorials/09-new-project-from-scratch.md) |
| Jump to a directory | [Cheatsheets/cheatsheet-navigation-search.md](Cheatsheets/cheatsheet-navigation-search.md) (zoxide) |
| Find a file by name | [Cheatsheets/cheatsheet-navigation-search.md](Cheatsheets/cheatsheet-navigation-search.md) (fd) |
| Search inside files | [Cheatsheets/cheatsheet-navigation-search.md](Cheatsheets/cheatsheet-navigation-search.md) (rg) |
| View a file with syntax highlighting | `bat <file>` |
| Stage and commit changes | [Cheatsheets/cheatsheet-git.md](Cheatsheets/cheatsheet-git.md) |
| Review diffs visually | `lg` (lazygit) or `git diff` (delta) |
| Run linting and formatting | `ruff check --fix .` and `ruff format .` |
| Switch Python versions | [Cheatsheets/cheatsheet-pyenv-win.md](Cheatsheets/cheatsheet-pyenv-win.md) |
| Add pre-commit hooks to a project | [HowTo-Guides/09-project-setup.md](HowTo-Guides/09-project-setup.md) |
| Open a project in VS Code | `z myproject && code .` |

## Something went wrong

| I want to... | Go to |
|---|---|
| Diagnose a setup problem | [TROUBLESHOOTING.md: Setup](TROUBLESHOOTING.md#setup) |
| Fix a terminal or profile issue | [TROUBLESHOOTING.md: Terminal](TROUBLESHOOTING.md#terminal-and-profile) |
| Fix a Python tooling issue | [TROUBLESHOOTING.md: Python](TROUBLESHOOTING.md#python-and-tooling) |
| Fix a git or signing issue | [TROUBLESHOOTING.md: Git](TROUBLESHOOTING.md#git-and-signing) |
| Fix a VS Code issue | [TROUBLESHOOTING.md: VS Code](TROUBLESHOOTING.md#vs-code-integration) |

## Maintenance

| I want to... | Go to |
|---|---|
| Update all tools | Run `Invoke-DevUpdate` or `.\Update-DevEnvironment.ps1` |
| Update pre-commit hooks in a project | `cd <project> && pre-commit autoupdate` |
| Redeploy VS Code settings | Run `.\Apply-VSCodeSettings.ps1` |
| Redeploy the PowerShell profile | Run `.\Apply-PowerShellProfile.ps1` |
| Add a new tool to the setup | [CONTRIBUTING.md](CONTRIBUTING.md) |

## Team collaboration

| I want to... | Go to |
|---|---|
| Learn the team workflow | [Tutorials/11-working-in-a-team.md](Tutorials/11-working-in-a-team.md) |
| Open a pull request from the terminal | [HowTo-Guides/12-team-collaboration.md](HowTo-Guides/12-team-collaboration.md) |
| Review a colleague's PR locally | [HowTo-Guides/12-team-collaboration.md](HowTo-Guides/12-team-collaboration.md) |
| Resolve a merge conflict | [HowTo-Guides/12-team-collaboration.md](HowTo-Guides/12-team-collaboration.md) |
| Handle a rejected push | [TROUBLESHOOTING.md: Git](TROUBLESHOOTING.md#git-and-signing) |
| Understand signed commit requirements | [HowTo-Guides/10-security-hygiene.md](HowTo-Guides/10-security-hygiene.md) |

## I want to learn

| I want to... | Go to |
|---|---|
| Learn to navigate faster | [Tutorials/02-navigating-smarter.md](Tutorials/02-navigating-smarter.md) |
| Learn to search codebases | [Tutorials/03-searching-effectively.md](Tutorials/03-searching-effectively.md) |
| Learn terminal shortcuts | [Tutorials/04-terminal-power-user.md](Tutorials/04-terminal-power-user.md) |
| Learn the Python workflow | [Tutorials/05-python-workflow.md](Tutorials/05-python-workflow.md) |
| Learn to use git professionally | [Tutorials/08-git-like-a-pro.md](Tutorials/08-git-like-a-pro.md) |
| Get a quick-reference for any tool | [Cheatsheets/](Cheatsheets/) directory |

## Terminal commands available after setup

| Command | What it does |
|---|---|
| `Show-DevEnvironment` | Print all tool versions and environment status |
| `Test-ProfileHealth` | Check profile has all expected sections |
| `Invoke-DevSetup` | Run setup script from anywhere |
| `Invoke-DevUpdate` | Run update script from anywhere |
| `z <keyword>` | Jump to a directory |
| `lg` | Launch lazygit |
| `gs` / `ga` / `gc` / `gp` / `gl` | Git aliases |
| `cat <file>` | View file with bat |
