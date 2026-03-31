# Tutorial 2: Navigating Smarter

## What you will learn

- Using `fd` to find files by name, extension, and type
- Using `bat` to read files with syntax highlighting
- Using `zoxide` (`z`) to jump to directories without typing full paths
- Combining `fd`, `bat`, and `fzf` for interactive file selection

## Prerequisites

- Completed Tutorial 1 (Getting Oriented)
- Comfortable with basic terminal navigation (`cd`, `ls`)

---

## Step 1: Find files with fd

`fd` is a fast, user-friendly replacement for recursive file searching. Navigate to a project directory (the winSetup repo works fine):

```powershell
cd $env:WINSETUP
```

Find all files containing "setup" in their name:

```powershell
fd setup
```

Unlike `Get-ChildItem -Recurse -Filter`, you don't need wildcards. `fd` searches by substring, is case-insensitive by default, and skips `.git` directories and anything in `.gitignore`.

### Filter by type

Find only files (not directories):

```powershell
fd --type f
```

Find only directories:

```powershell
fd --type d
```

### Filter by extension

Find all Markdown files:

```powershell
fd -e md
```

Find all PowerShell scripts:

```powershell
fd -e ps1
```

### Limit depth

See only the top level (no recursion):

```powershell
fd --max-depth 1
```

## Step 2: Read files with bat

Now that you've found a file, read it. `bat` replaces the plain `cat`/`Get-Content` with syntax highlighting, line numbers, and git change markers.

```powershell
bat README.md
```

You'll see the file with Markdown syntax highlighting, line numbers on the left, and a header showing the filename.

### Read specific lines

When you know the area you need (e.g., from a linter error pointing to line 42):

```powershell
bat --line-range 1:20 Setup-DevEnvironment.ps1
```

Shows only lines 1-20.

### Plain output

If you just want the text without decoration (useful for piping):

```powershell
bat --plain README.md
```

### Find, then read

Combine `fd` and `bat` in a natural workflow:

```powershell
fd -e md
# See the list of Markdown files, pick one:
bat HowTo-Guides/01-chocolatey.md
```

This two-step pattern -- find the file, then view it -- is something you'll do dozens of times a day.

## Step 3: Jump directories with zoxide

`zoxide` replaces `cd` with a smarter command that learns from your habits. Every time you visit a directory (with `cd` or `z`), zoxide records it. Over time, it builds a frequency/recency database.

### Teach zoxide your directories

If this is a fresh setup, zoxide's database is empty. Start by visiting your key directories:

```powershell
cd $env:WINSETUP
cd ~\OneDrive\Documents\Code
cd ~\OneDrive\Documents
cd ~
```

Each `cd` command trains zoxide. After visiting directories a few times, you can jump to them with fragments:

### Jump with z

```powershell
z winsetup
```

This jumps to your winSetup directory because that's the highest-ranked directory matching "winsetup". You don't need the full path, the correct case, or even a contiguous match.

> **If this fails:** `z` jumps to the wrong directory or does nothing -- zoxide's database is empty or the wrong entry has a higher score. Fix: `zoxide add $PWD` to manually seed the directory, or use `zi <keyword>` to interactively select.

### Use multiple keywords

```powershell
z code winsetup
```

Matches directories containing both "code" and "winsetup" in their path, in that order.

### Interactive selection with zi

When multiple directories match, use `zi` to pick:

```powershell
zi code
```

This opens fzf with all matching directories. Arrow to the one you want and press Enter.

### See what zoxide knows

```powershell
zoxide query --list
```

Shows all tracked directories with their scores.

## Step 4: Combine tools with fzf

The real power comes from combining these tools interactively with `fzf` (the fuzzy finder).

### Interactive file picker with preview

```powershell
fd --type f | fzf --preview "bat --color=always {}"
```

This:
1. `fd --type f` lists all files recursively
2. Pipes the list to `fzf`, which shows an interactive fuzzy finder
3. `--preview "bat --color=always {}"` shows a syntax-highlighted preview of each file as you scroll

Type to filter, arrow keys to navigate, Enter to select. The selected file path is printed to stdout.

### Open the result in VS Code

```powershell
fd --type f | fzf --preview "bat --color=always {}" | ForEach-Object { code $_ }
```

This chains the selection into opening the file. But you don't need to type this -- your profile has it wired to **Ctrl+F**.

### Try Ctrl+F now

Press `Ctrl+F` at an empty prompt. The same interactive picker appears. Select a file and its path is inserted at your cursor. You can then prepend `code ` or `bat ` or whatever command you need.

### Find only specific file types interactively

```powershell
fd -e py --type f | fzf --preview "bat --color=always {}"
```

Now the picker only shows Python files.

## Step 5: Build a navigation habit

Here's the workflow that replaces clicking through File Explorer:

1. **Jump to a project**: `z myproject`
2. **Find a file**: `fd config` or press `Ctrl+F`
3. **Read it**: `bat filename` or use the fzf preview
4. **Open it**: `code filename` or `code --goto filename:42`

Practice this cycle a few times.

---

## Exercise

1. Navigate to your Code directory: `cd ~\OneDrive\Documents\Code`
2. Use `fd -e md` to find all Markdown files in the winSetup project
3. Pick one and read it with `bat`
4. Navigate to at least three different directories using `cd` (this trains zoxide)
5. Now use `z` to jump back to winSetup from wherever you are
6. Press `Ctrl+F`, type "choco", and select the Chocolatey how-to guide. Note the path that gets inserted
7. Use `zi` to interactively jump to a directory

---

## What comes next

You can now find files and jump between directories quickly. **Tutorial 3** teaches you how to search *inside* files using ripgrep -- finding function definitions, TODO comments, configuration values, and anything else across your entire codebase.
