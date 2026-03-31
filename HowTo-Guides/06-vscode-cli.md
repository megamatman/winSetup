# VS Code CLI -- Using `code` from the Terminal

VS Code ships with a `code` command-line tool that lets you open files, folders, diffs, and more directly from your PowerShell terminal. Combined with your other tools (fzf, fd, ripgrep), it makes the terminal the fastest way to get into the right file at the right place.

## Setup

Installed via `choco install vscode`. The Chocolatey package adds `code` to your system PATH automatically. The setup script also optionally deploys:
- `settings.json` with your editor preferences
- 15 extensions covering Python, linting, Git, formatting, and theming

## Core Usage

### Open the current directory as a workspace

```powershell
code .
```

This is the most common usage. It opens VS Code with the current folder as the workspace root, including the file explorer, source control, and terminal.

### Open a specific file

```powershell
code src/main.py
```

Opens the file in an existing VS Code window if one is running, or starts a new one.

### Open a file at a specific line

```powershell
code --goto src/main.py:42
```

Opens the file and places your cursor on line 42. Useful when a linter or test output tells you the exact line number:

```powershell
# Pylint says: src/main.py:42: Missing docstring
code --goto src/main.py:42
```

### Open a file at a specific line and column

```powershell
code --goto src/main.py:42:10
```

### Open multiple files

```powershell
code src/main.py src/utils.py tests/test_main.py
```

Opens all three files as tabs in the same window.

### Open a folder in a new window

```powershell
code --new-window C:\Projects\other-project
```

By default, `code .` reuses the current window. `--new-window` (or `-n`) forces a separate window.

### Open a folder and reuse the current window

```powershell
code --reuse-window C:\Projects\other-project
```

Replaces the current workspace without opening a new window.

## Diffing Files

### Compare two files

```powershell
code --diff file-old.py file-new.py
```

Opens a side-by-side diff view in VS Code. Changes are highlighted with green (added) and red (removed).

### Compare a file with its git version

You'll typically do this in VS Code's Source Control panel (GitLens makes this easy), but from the terminal:

```powershell
git diff src/main.py | code --diff -
```

### Compare with clipboard

Useful for comparing snippets:

```powershell
code --diff config-dev.json config-prod.json
```

## Managing Extensions

### List installed extensions

```powershell
code --list-extensions
```

### Install an extension

```powershell
code --install-extension ms-python.python
```

### Uninstall an extension

```powershell
code --uninstall-extension ms-python.python
```

### Install extensions from a list

Export your extensions on one machine:

```powershell
code --list-extensions > extensions.txt
```

Install them on another:

```powershell
Get-Content extensions.txt | ForEach-Object { code --install-extension $_ }
```

This is what the setup script does with its built-in extension list, but it's useful for project-specific extensions too.

## Piping Content to VS Code

### Open stdin in VS Code

```powershell
rg "TODO" --type py | code -
```

The `-` flag tells VS Code to read from stdin. This opens a new untitled file with the piped content. Useful for reviewing search results, log output, or command output.

### Open a process list

```powershell
Get-Process | Out-String | code -
```

### Pipe a git diff for review

```powershell
git diff HEAD~5..HEAD | code -
```

## Real-World Workflows

### Quick edit from search results

Find a file with fzf and open it:

```powershell
fd --type f | fzf --preview "bat --color=always {}" | ForEach-Object { code $_ }
```

Or just press `Ctrl+F`, select the file, then type `code ` before the path.

### Jump to an error from the terminal

Your test output shows `FAILED tests/test_auth.py:87`:

```powershell
code --goto tests/test_auth.py:87
```

### Open a project you were working on yesterday

```powershell
z my-project    # zoxide jumps to the directory
code .          # Open it in VS Code
```

### Compare configuration between environments

```powershell
code --diff config/dev.json config/prod.json
```

### Review all Python files that reference a function

```powershell
rg -l "process_payment" --type py | ForEach-Object { code $_ }
```

This opens every file containing "process_payment" as separate tabs.

### Start a new project from scratch

```powershell
mkdir my-api && cd my-api
git init
python -m venv .venv
code .
```

VS Code detects the virtual environment and offers to select it as your Python interpreter.

## Useful Settings Flags

### Open VS Code in portable mode (no extensions)

```powershell
code --disable-extensions .
```

Useful for debugging whether an extension is causing issues.

### Verbose logging for troubleshooting

```powershell
code --verbose --log debug
```

### Check VS Code version

```powershell
code --version
```

### Open user settings in the editor

```powershell
code "$env:APPDATA\Code\User\settings.json"
```

Or just press `Ctrl+,` inside VS Code.

## Tips and Gotchas

- **`code .` is your entry point**: Get in the habit of navigating to a project directory in your terminal and typing `code .`. It's faster than File > Open Folder and keeps your hands on the keyboard.
- **Reuse vs new window**: By default, `code` reuses the most recent window. If you want to keep your current workspace open and view something else, use `code -n other-folder`. If you find the default behaviour annoying, add `"window.openFoldersInNewWindow": "on"` to your settings.
- **`code` not found**: If `code` isn't recognised after installing VS Code via Chocolatey, run `refreshenv` or restart your terminal. The Chocolatey package adds it to PATH, but the current session might not have picked it up yet.
- **Windows Terminal integration**: Your VS Code settings include `"terminal.integrated.fontFamily": "'Hack Nerd Font'"` so the integrated terminal renders Oh My Posh glyphs correctly. If the integrated terminal looks different from Windows Terminal, check that the font matches.
- **Remote development**: `code` can open remote folders via SSH. Install the "Remote - SSH" extension, then:
  ```powershell
  code --remote ssh-remote+user@host /path/to/project
  ```
- **Settings Sync**: Your setup relies on VS Code Settings Sync (via GitHub) for settings and extensions on established machines. The `-IncludeOptional` flag is a fallback for fresh machines where sync hasn't kicked in yet.

---

## See Also

- [Navigation and Search](03-navigation-and-search.md) -- fd, ripgrep, and bat for finding and previewing files
- [Git](04-git.md) -- git workflows that complement VS Code