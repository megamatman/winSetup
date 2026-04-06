# Tutorial 9: New Project from Scratch

## What you will learn

- End-to-end project scaffolding using the winSetup templates
- Setting up pre-commit hooks and understanding what each hook does
- Making your first commit with hooks running automatically
- Fixing a linting failure and recommitting
- The complete workflow from empty directory to production-ready project

## Prerequisites

- Completed Tutorials 1-8
- Familiar with venvs, git aliases, lazygit, pyenv, and pre-commit hooks

---

## Before you start

Complete the [New Project Quickstart](../README.md#new-project-quickstart) steps to scaffold a project directory with git, a venv, templates, and pre-commit hooks installed. Then return here.

## Step 1: Create a Python file with intentional issues

Let's write some code that will trigger the hooks. Create `src/main.py`:

```python
import os
import sys
import json
import os  # duplicate import

def greet(name):
    message = "Hello, " + name
    return message

def add_numbers(a: int, b: int) -> str:
    return a + b  # type error: returns int, not str

if __name__ == "__main__":
    greet("World")
```

This file has several problems:

- Duplicate `import os`
- Trailing whitespace after the `message` line
- Type annotation says `-> str` but the function returns an `int`
- Unused imports (`sys`, `json`)

## Step 2: Stage and commit -- watch the hooks

```powershell
ga .
gc "Initial commit"
```

The hooks run in order. You'll see output like:

```
Trim Trailing Whitespace.................................................Failed
Fix End of Files.........................................................Passed
Check Yaml...............................................................Passed
Check for added large files..............................................Passed
Detect Private Key.......................................................Passed
ruff-format..............................................................Failed
ruff.....................................................................Failed
mypy.....................................................................Failed
```

The commit is **blocked** because hooks failed. This is exactly what you want -- problems are caught before they enter the repository.

> **If this fails:** hooks run and the commit is blocked -- this is expected, not an error. Read which hooks failed, stage any auto-fixed files with `ga .`, and commit again.

## Step 3: Review the auto-fixed files

Some hooks fix problems automatically rather than just reporting them:

- **trailing-whitespace** removed the trailing spaces
- **ruff-format** reformatted the code to its standard style

Check what changed:

```powershell
git diff
```

delta shows you the exact fixes. The auto-fixable issues are already resolved in your working copy.

## Step 4: Fix remaining issues and recommit

The auto-fixes handle formatting, but you need to manually fix:

- Remove the duplicate `import os`
- Remove unused imports (`sys`, `json`)
- Fix the type annotation (change `-> str` to `-> int`, or change the return value)

Edit the file, then stage and commit again:

```powershell
ga .
gc "Initial commit"
```

This time all hooks pass, and the commit goes through. Your first commit is clean, formatted, type-checked, and signed.

## Step 5: Run hooks on all files manually

You can run hooks without committing -- useful for checking the whole project:

```powershell
pre-commit run --all-files
```

This runs every hook against every tracked file, not just staged changes. Use this when you've updated hook versions or want a full project health check.

## Step 6: Update hooks to latest versions

Hook repositories release updates with new rules and bug fixes:

```powershell
pre-commit autoupdate
```

This updates the version pins in `.pre-commit-config.yaml` to the latest releases. Review the changes with `git diff`, then commit the updated config.

## Step 7: Open in VS Code

```powershell
code .
```

VS Code picks up the project's `.venv`, `.pre-commit-config.yaml`, and `pyproject.toml` automatically. The linting extensions (Ruff, Pylint, Mypy) run in real-time as you edit, so most issues are caught before you even try to commit.

---

## Exercise

Scaffold a second project from scratch **without looking at this tutorial**. Time yourself. Here's the checklist:

1. Create the project directory
2. Initialize git
3. Set a Python version with pyenv (if needed)
4. Create and activate a virtual environment
5. Copy template files
6. Copy the pre-commit config
7. Install hooks
8. Create a Python file
9. Make your first commit (let hooks catch and fix issues)
10. Fix any remaining issues and recommit
11. Open in VS Code

Repeat this process without referring to the tutorial. Each time you do it, it will feel more natural.

---

## What comes next

You've scaffolded a project with all the quality tools in place. **Tutorial 10** covers the security side -- verifying your global .gitignore works, scanning for secrets, and responding when one leaks. **Tutorial 11** covers team collaboration -- branches, PRs, code review, and conflict resolution.
