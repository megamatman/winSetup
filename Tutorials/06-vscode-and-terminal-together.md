# Tutorial 6: VS Code and Terminal Together

## What you will learn

- Opening projects, files, and specific lines from the terminal with `code`
- Diffing files from the command line
- Navigating between terminal linting output and VS Code error markers
- When to use the VS Code integrated terminal vs Windows Terminal
- A combined daily workflow using everything from Tutorials 1-5

## Prerequisites

- Completed Tutorials 1-5
- Comfortable with all terminal tools and the Python quality workflow

---

## Step 1: Launch VS Code from the terminal

The fastest way to start working on a project is:

```powershell
z myproject
code .
```

`code .` opens the current directory as a VS Code workspace. The file explorer, source control panel, and terminal are all scoped to this folder.

This is faster than launching VS Code and using File > Open Folder because:
- `z` gets you to the directory in one command (Tutorial 2)
- `code .` opens the workspace immediately
- You're already in the terminal, so no context switch

### Open a specific file

```powershell
code src/main.py
```

This opens the file in your existing VS Code window (if one is running) or starts a new one.

### Open at a specific line

When a linter or test tells you the exact line number:

```powershell
pylint main.py
# Output: main.py:14:4: C0116: Missing function or method docstring
code --goto main.py:14
```

Your cursor lands on line 14, ready to add that docstring. This is the bridge between terminal output and editor action.

### Open at a line and column

```powershell
code --goto main.py:14:5
```

Useful when Mypy or Ruff gives you an exact column position.

## Step 2: Diff files from the terminal

### Compare two files

```powershell
code --diff config-dev.json config-prod.json
```

Opens a side-by-side diff in VS Code. Differences are highlighted in green (added) and red (removed). This is useful for:
- Comparing config files across environments
- Reviewing changes before committing
- Understanding what changed between two versions of a file

### Review git changes visually

```powershell
# See a summary of what changed
gs

# Open the diff in VS Code for a specific file
git diff src/main.py | code -
```

The `-` flag reads from stdin, so the diff appears in a new VS Code tab. For a nicer experience, use VS Code's Source Control panel (Ctrl+Shift+G), which shows all changes with inline diffs.

## Step 3: Pipe output into VS Code

The `-` flag lets you send any terminal output into VS Code for review:

```powershell
# Send ripgrep results to VS Code
rg "TODO" --type py | code -

# Send a process list
Get-Process | Out-String | code -

# Send git log
gl | code -
```

This is useful when output is long and you want to search, scroll, or copy from it in a proper editor rather than the terminal.

## Step 4: Navigate between terminal and editor

The real productivity comes from using the terminal and VS Code as complementary tools, not alternatives.

### Scenario: Fix linting errors

Run your linters in the terminal:

```powershell
ruff check src/
```

Output:

```
src/api/routes.py:12:1: F401 `os` imported but unused
src/api/routes.py:45:5: E711 Comparison to `None` using `==`
src/models/user.py:8:1: I001 Import block is un-sorted or un-formatted
```

Now you have three options:

**Option A -- Auto-fix from terminal**:

```powershell
ruff check --fix src/
```

Ruff fixes what it can automatically. Check what's left.

**Option B -- Jump to each error**:

```powershell
code --goto src/api/routes.py:12
# Fix the error, save
code --goto src/api/routes.py:45
# Fix the error, save
```

**Option C -- Let VS Code show you** (usually the best):

VS Code already runs Ruff, Pylint, and Mypy in real-time. Open the file and look for:
- Red/yellow squiggles under problematic code
- ErrorLens messages at the end of each offending line
- The Problems panel (Ctrl+Shift+M) for a full list

The terminal is best for running checks across the entire project. VS Code is best for fixing individual files interactively. Use both.

### Scenario: Explore unfamiliar code

Combine the search techniques from Tutorial 3 with VS Code:

```powershell
# Terminal: find where payment logic lives
rg -l "process_payment" --type py

# Terminal: see the function signature and context
rg -A 5 "def process_payment" --type py

# Editor: open the file at that line for full context
code --goto src/billing/service.py:42

# Editor: use Ctrl+Click on function calls to jump to definitions
# Editor: use GitLens blame to see who wrote each line and when
```

## Step 5: Integrated terminal vs Windows Terminal

VS Code has a built-in terminal panel (Ctrl+\`). Your setup configures it with Hack Nerd Font so Oh My Posh renders correctly. But you also have Windows Terminal as a separate app. When should you use which?

### Use the VS Code integrated terminal when:

- Running commands related to the file you're editing (linters, tests, build)
- You want to stay in one window without Alt-Tabbing
- You need side-by-side code and terminal
- Running `code --goto` to jump to a line (it opens in the same window)

### Use Windows Terminal when:

- Managing multiple projects simultaneously (one tab per project)
- Running long-lived processes (dev servers, database, Docker)
- You want more screen space for terminal output
- Running system administration tasks (Chocolatey upgrades, SSH)

### Practical setup

Keep Windows Terminal open on one side of your screen for navigation and broad searches. Keep VS Code open for editing and project-scoped commands. The workflow:

1. **Windows Terminal**: `z project`, `rg "bug"`, `gs`
2. **VS Code**: `code .` from Windows Terminal, then use the integrated terminal for file-specific commands
3. **Switch between them**: Alt+Tab, or use Windows 11's Snap layouts to tile them

## Step 6: The complete daily workflow

Here's everything from all six tutorials in a realistic morning workflow:

```powershell
# -- Windows Terminal --

# Jump to your project (Tutorial 2: zoxide)
z myapi

# Pull latest changes (Tutorial 4: git aliases)
git pull

# Check what your teammate changed (Tutorial 3: ripgrep)
rg -l "auth" --type py
gl

# Open the project in VS Code (this tutorial)
code .

# -- VS Code integrated terminal --

# Activate your virtual environment (Tutorial 5)
.venv\Scripts\Activate.ps1

# Run tests
python -m pytest

# A test fails at tests/test_auth.py:87
# Click the file:line link in the terminal output, or:
code --goto tests/test_auth.py:87

# Fix the issue in the editor
# Save -- Ruff auto-formats, Pylint shows any remaining issues

# -- Windows Terminal --

# Run full quality check (Tutorial 5)
ruff format --check src/
ruff check src/
mypy src/

# Everything passes. Commit and push (Tutorial 4: aliases)
gs
ga src/auth/service.py tests/test_auth.py
gc "Fix auth token validation"
gp

# Find that config file you need next (Tutorial 2: Ctrl+F)
# Press Ctrl+F, type "docker", preview with bat, select

# Recall that deployment command from last week (Tutorial 4: Ctrl+R)
# Press Ctrl+R, type "deploy prod"
```

Every step uses a tool or keybinding from your setup. No manual file browsing, no slow searching, no retyping long commands.

## Full Workflow: Scaffold to Signed Commit

The complete flow from empty directory to verified commit uses every tool in this series: `mkdir` and `cd`, venv creation, template copying, `pre-commit install`, `code .` for editing, `git diff` through delta, committing with aliases or lazygit, and automatic SSH signing.

Tutorial 9 walks through this end-to-end. For now, the key point is that every step in that workflow uses a terminal command or tool you've learned in Tutorials 1-6.

---

## Exercise

1. Navigate to the winSetup project from anywhere: `z winsetup`
2. Open it in VS Code: `code .`
3. Use `rg` in the terminal to find a specific function in the script, note the line number
4. Open that line in VS Code: `code --goto Setup-DevEnvironment.ps1:<line>`
5. Create two small text files and diff them: `code --diff file1.txt file2.txt`
6. Run `rg "function" --type ps | code -` to send search results into VS Code
7. Open the VS Code integrated terminal (Ctrl+\`) and run `gs` -- confirm the aliases work there too
8. Practice Alt-Tabbing between Windows Terminal and VS Code while working

---

## What comes next

You've now bridged the terminal and VS Code into a unified workflow. In Tutorial 7, you'll learn to manage multiple Python versions with pyenv-win -- essential when different projects require different Python versions.
