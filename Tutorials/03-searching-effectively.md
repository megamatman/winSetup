# Tutorial 3: Searching Effectively

## What you will learn

- Using `rg` (ripgrep) to search file contents across a codebase
- Filtering results by file type, context lines, and match mode
- Combining `rg` with `fzf` for interactive exploration
- Using `Ctrl+F` for quick file-level search with preview
- A practical workflow for exploring unfamiliar code

## Prerequisites

- Completed Tutorial 2 (Navigating Smarter)
- Familiar with `fd`, `bat`, and `fzf` basics

---

## Step 1: Search for text with ripgrep

`rg` (ripgrep) searches the *contents* of files, not just their names. It's what you reach for when you know *what* you're looking for but not *where* it is.

Navigate to the winSetup project:

```powershell
z winsetup
```

Search for every occurrence of "Chocolatey":

```powershell
rg "Chocolatey"
```

You'll see output like:

```
Setup-DevEnvironment.ps1:86:    if (Get-Command choco -ErrorAction SilentlyContinue) {
Setup-DevEnvironment.ps1:87:        Write-Skip "Chocolatey is already installed"
HowTo-Guides/01-chocolatey.md:3:Chocolatey is a command-line package manager...
```

Each result shows **filename:line number:matching line**. Colours highlight the match within each line.

### Why ripgrep instead of Select-String

PowerShell's `Select-String` works, but `rg` is dramatically faster on large codebases, respects `.gitignore` by default, and has better output formatting. On a project with thousands of files, the speed difference is seconds vs minutes.

## Step 2: Refine your searches

### Case-insensitive search

```powershell
rg -i "todo"
```

Finds `TODO`, `Todo`, `todo`, and any other case variation.

### Search specific file types

ripgrep uses its own type names -- use `rg --type-list` to see all available types and their associated extensions. For PowerShell files, the type is `ps` (not `ps1`):

```powershell
rg "function" --type ps
```

For Markdown:

```powershell
rg "setup" --type md
```

### Show context around matches

Sometimes one matching line isn't enough. Show 3 lines before and after:

```powershell
rg -C 3 "Install-Chocolatey"
```

Or just lines after (useful for seeing function bodies):

```powershell
rg -A 10 "function Install-Chocolatey"
```

This shows the function signature plus the next 10 lines.

### Match whole words only

```powershell
rg -w "bat"
```

Matches `bat` but not `batch` or `combat`. Essential when searching for short terms.

### List only filenames

When you just need to know *which files* contain something:

```powershell
rg -l "fzf"
```

Output is one filename per line -- no line content, no line numbers. Clean and easy to pipe.

### Count matches per file

```powershell
rg -c "Write-Host"
```

Shows each file and how many matches it has. Useful for understanding where something is concentrated.

## Step 3: Search and explore interactively

The real power of `rg` emerges when you combine it with `fzf` for interactive exploration.

### Pipe ripgrep results into fzf

```powershell
rg "function" --type ps | fzf
```

This shows every function definition in a fuzzy-searchable list. Type to filter -- for example, type "install" to narrow down to install-related functions.

### Add file preview

```powershell
rg -l "choco" | fzf --preview "bat --color=always {}"
```

This:
1. Finds files containing "choco"
2. Opens fzf with those filenames
3. Shows a full syntax-highlighted preview of each file as you scroll

### Open the selected file

```powershell
rg -l "choco" | fzf --preview "bat --color=always {}" | ForEach-Object { code $_ }
```

Select a file in fzf, press Enter, and it opens in VS Code.

## Step 4: Use Ctrl+F for quick file search

Your profile binds `Ctrl+F` to an interactive file finder with bat preview. This is different from `Ctrl+T` (which just inserts a path):

- **Ctrl+T**: File list from `fd`, no preview. Fast, minimal.
- **Ctrl+F**: File list from `fd`, with bat preview pane. Slightly slower, but you can see file contents before selecting.

Try both now. Press `Ctrl+T` at an empty prompt, pick a file, and see the path inserted. Then try `Ctrl+F` and notice the preview pane on the right.

Use `Ctrl+F` when you need to *identify* the right file. Use `Ctrl+T` when you already know which file you want and just need the path.

## Step 5: Real-world search workflow

Here's a scenario: you've joined a new project and need to understand how authentication works. You don't know the file structure yet.

### Step 5a: Find where auth lives

```powershell
rg -l "authenticate\|auth\|login" --type py
```

This lists every Python file mentioning authentication. Now you know which files to look at.

### Step 5b: See the function signatures

```powershell
rg "def.*auth" --type py
```

Shows every function with "auth" in its name, with filenames and line numbers.

### Step 5c: Read the code around a specific function

```powershell
rg -A 20 "def authenticate_user" --type py
```

Shows the function definition and its first 20 lines.

### Step 5d: Check what calls it

```powershell
rg "authenticate_user\(" --type py
```

The `\(` ensures you find function calls, not just the definition.

### Step 5e: Open the key file

```powershell
code --goto src/auth/service.py:42
```

Jump directly to the line you found interesting.

This five-step pattern -- find files, find functions, read context, find callers, open in editor -- is how experienced developers navigate unfamiliar codebases. With `rg`, `bat`, and `code`, each step takes seconds.

## Step 6: Search patterns worth memorising

These cover the searches you'll do most often:

```powershell
# Find all TODO/FIXME comments
rg "TODO|FIXME|HACK|XXX"

# Find all imports of a specific module
rg "^import requests|^from requests"

# Find environment variable usage
rg "os\.environ|os\.getenv" --type py

# Find all API endpoints in a Flask/FastAPI app
rg "@app\.(get|post|put|delete|patch)" --type py

# Find config files that reference a specific port
rg "8080" -g "*.json" -g "*.yaml" -g "*.toml" -g "*.env"

# Find files that were recently changed (combine with fd)
fd --type f --changed-within 1d
```

---

## Exercise

1. Navigate to the winSetup project
2. Use `rg` to find every file that mentions "Python" (case-insensitive): `rg -i "python"`
3. Narrow it down to just Markdown files: `rg -i "python" --type md`
4. Count how many matches are in each file: `rg -c -i "python" --type md`
5. Find every function definition in the PowerShell script: `rg "function " --type ps`
6. Show the function body for `Install-SSHKeys`: `rg -A 15 "function Install-SSHKeys"`
7. Pipe the function list into fzf: `rg "function " --type ps | fzf`
8. Use `Ctrl+F` to find and preview the git how-to guide without typing its full path

---

## What comes next

You can now find files by name and search their contents efficiently. **Tutorial 4** shows you how to become a terminal power user -- using PSReadLine's autosuggestions, history search, and the full set of fzf keybindings to work faster at the command line itself.
