# Navigation and Search -- fd, zoxide, ripgrep, bat

These four tools replace slower, less ergonomic built-in alternatives. `fd` replaces `Get-ChildItem` for finding files, `ripgrep` replaces `Select-String` for searching file contents, `bat` replaces `Get-Content`/`cat` for reading files, and `zoxide` replaces `Set-Location`/`cd` for navigating directories. They're designed to work together -- your profile uses `fd` as fzf's file source and `bat` as fzf's previewer.

## Setup

All four are installed by `Setup-DevEnvironment.ps1`:
- **fd** -- `choco install fd`
- **ripgrep** -- `choco install ripgrep`
- **bat** -- `choco install bat`
- **zoxide** -- `choco install zoxide`

Your profile adds:
- `Set-Alias cat bat` -- so `cat` uses bat with syntax highlighting
- `Invoke-Expression (& { (zoxide init powershell | Out-String) })` -- enables the `z` command
- `$env:FZF_DEFAULT_COMMAND = 'fd --type f'` -- fzf uses fd to list files

---

## fd -- Find Files Fast

`fd` is a simpler, faster alternative to `find` (or `Get-ChildItem -Recurse`). It respects `.gitignore` by default, uses regex patterns, and has coloured output.

### Find files by name

```powershell
fd config
```

Finds all files and directories containing "config" in their name, recursively from the current directory. No need for wildcards -- `fd` searches by substring.

### Find only files (not directories)

```powershell
fd --type f readme
```

### Find only directories

```powershell
fd --type d test
```

### Find by extension

```powershell
fd --extension py
fd -e ts -e tsx
```

The first finds all `.py` files. The second finds all `.ts` and `.tsx` files.

### Find in a specific directory

```powershell
fd controller src/api
```

Searches only within `src/api`.

### Include hidden and ignored files

By default, `fd` skips hidden files and anything in `.gitignore`. To include everything:

```powershell
fd --hidden --no-ignore .env
```

### Execute a command on results

```powershell
fd --extension log --exec Remove-Item
```

Deletes every `.log` file found recursively.

### Real-world examples

Find all Dockerfiles in a monorepo:

```powershell
fd Dockerfile
```

Find all test files:

```powershell
fd --type f test -e py
```

Find large files that shouldn't be in the repo:

```powershell
fd --type f --size +10m
```

---

## ripgrep (rg) -- Search File Contents

`ripgrep` searches the contents of files using regex, similar to `grep` but much faster. It respects `.gitignore`, searches recursively by default, and shows results with line numbers and syntax context.

### Search for a string

```powershell
rg "database_url"
```

Searches all files recursively for "database_url" and shows matching lines with filenames and line numbers.

### Case-insensitive search

```powershell
rg -i "todo"
```

### Search specific file types

```powershell
rg "import" --type py
rg "fetch" --type ts
```

ripgrep knows file types by extension. Use `rg --type-list` to see all supported types.

### Search with context (lines around matches)

```powershell
rg -C 3 "def process_payment"
```

Shows 3 lines before and after each match. Use `-B` for before-only or `-A` for after-only.

### Search for a whole word

```powershell
rg -w "user"
```

Matches `user` but not `username` or `users`.

### List only filenames (no line content)

```powershell
rg -l "API_KEY"
```

Useful when you just need to know which files contain something.

### Count matches per file

```powershell
rg -c "TODO"
```

Shows each file and how many TODOs it contains.

### Search and replace (preview)

```powershell
rg "old_function_name" --replace "new_function_name"
```

This prints what the output would look like with replacements but doesn't modify files. Useful for previewing a rename before committing to it.

### Include hidden/ignored files

```powershell
rg --hidden --no-ignore "SECRET_KEY"
```

Useful for auditing `.env` files that are normally gitignored.

### Real-world examples

Find everywhere a function is called:

```powershell
rg "authenticate_user\("
```

Find all TODO comments in Python files:

```powershell
rg "TODO|FIXME|HACK" --type py
```

Find which config files reference a specific port:

```powershell
rg "8080" -g "*.json" -g "*.yaml" -g "*.toml"
```

The `-g` flag filters by glob pattern when `--type` doesn't cover your case.

---

## bat -- Better File Viewing

`bat` is a replacement for `cat`/`Get-Content` with syntax highlighting, line numbers, and git integration. Your profile aliases `cat` to `bat`, so it's the default for viewing files.

### View a file

```powershell
bat src/main.py
```

Shows the file with syntax highlighting, line numbers, and a header showing the filename.

### View specific lines

```powershell
bat --line-range 20:40 src/main.py
```

Shows only lines 20-40. Useful for large files when you know the area you need.

### View without decorations

```powershell
bat --plain config.json
```

Strips line numbers and headers. Useful when piping output or when you just want clean text.

### Compare with git changes

```powershell
bat --diff src/main.py
```

Highlights lines that have changed since the last git commit (added, modified, removed).

### View multiple files

```powershell
bat src/*.py
```

Shows all Python files in `src/` concatenated, with headers separating each file.

### Use as a pager for other commands

```powershell
rg "TODO" | bat --language log
```

Pipes ripgrep output through bat with syntax highlighting applied.

### Available themes

```powershell
bat --list-themes
bat --theme="Dracula" src/main.py
```

### Real-world examples

Quickly review a config file with context:

```powershell
bat docker-compose.yml
```

Check what a script does before running it:

```powershell
bat deploy.sh
```

View a log file with syntax highlighting:

```powershell
bat --language log /var/log/app.log
```

---

## zoxide -- Smarter Directory Navigation

`zoxide` is a smarter `cd` that learns which directories you visit and lets you jump to them by typing a fragment of the path. The more you visit a directory, the higher it ranks.

> **Note**: zoxide requires its prompt hook to fire after each directory change. On this setup, Oh My Posh replaces the default prompt function, so the profile explicitly wires zoxide's hook into the Oh My Posh prompt. If zoxide stops recording directories after a profile change, check that the zoxide section still appears **after** the Oh My Posh init line in your profile.

> **If `z` does not record directories:** Oh My Posh may have replaced the prompt before zoxide's hook registered. Verify the zoxide section in `profile.ps1` appears after Oh My Posh init. Reload: `. $PROFILE`.

### Jump to a directory

```powershell
z projects
```

Jumps to the highest-ranked directory matching "projects" -- probably `~\OneDrive\Documents\Code` or wherever you spend the most time. You don't need the full path.

### Jump with multiple keywords

```powershell
z code winsetup
```

Matches directories containing both "code" and "winsetup" in order. This would match your winSetup directory.

### Interactive selection

```powershell
zi projects
```

`zi` opens fzf with all matching directories so you can pick the right one when multiple match.

### See the database

```powershell
zoxide query --list
```

Shows all directories zoxide has learned, sorted by frequency/recency score.

### Add a directory manually

```powershell
zoxide add "C:\Work\ImportantProject"
```

### Remove a stale directory

```powershell
zoxide remove "C:\Old\DeletedProject"
```

### Real-world examples

Jump to your project from anywhere:

```powershell
# Instead of:
cd "$env:WINSETUP"

# Just type:
z winsetup
```

Switch between two projects you're working on:

```powershell
z frontend    # jumps to your frontend project
# do some work...
z api         # jumps to your API project
```

Navigate to a test directory deep in a project:

```powershell
z tests unit
```

Matches something like `C:\Projects\myapp\src\tests\unit`.

---

## Combining These Tools

These tools are most powerful when used together.

### Find a file, preview it, then open it

```powershell
fd --type f --extension py | fzf --preview "bat --color=always {}" | ForEach-Object { code $_ }
```

Or just press `Ctrl+F` in your terminal -- your profile has this wired up as a keybinding.

### Search for a pattern, then open matching files in VS Code

```powershell
rg -l "database" | fzf --preview "bat --color=always {}" | ForEach-Object { code $_ }
```

### Find all large files in a project

```powershell
fd --type f --size +1m | ForEach-Object { bat --line-range 1:1 $_ }
```

### Quick project audit

```powershell
rg -c "TODO" --type py | bat --language csv
```

## Tips and Gotchas

- **`.gitignore` is respected by default**: `fd`, `rg`, and `bat` all skip files listed in `.gitignore`. This is usually what you want, but when searching for `.env` files or `node_modules` contents, add `--no-ignore`.
- **Hidden files are skipped by default**: `fd` and `rg` skip dotfiles. Use `--hidden` to include them.
- **`bat` as `cat`**: Your profile aliases `cat` to `bat`. If you need the original PowerShell `Get-Content` behaviour (e.g., for piping raw bytes), use `Get-Content` explicitly.
- **zoxide needs time to learn**: On a fresh machine, `z` won't know any directories yet. Use `cd` normally for the first few sessions -- zoxide watches and builds its database. After a day of use, it starts being useful.
- **`rg` vs `Select-String`**: PowerShell's `Select-String` works on objects and integrates with the pipeline. `rg` is faster for searching across many files but outputs plain text. Use whichever fits the situation.
- **Windows paths**: All four tools handle Windows backslash paths correctly. `fd` and `rg` output forward slashes by default, which PowerShell handles fine.

---

## See Also

- [PowerShell Terminal](02-powershell-terminal.md) -- PSFzf keybindings and fzf integration