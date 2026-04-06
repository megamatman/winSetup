# Tutorial 5: Python Workflow

## What you will learn

- Creating and activating virtual environments
- The difference between pip (project packages) and pipx (global tools)
- Running pylint, ruff, mypy, and bandit against real code
- A pre-commit quality check workflow
- How these tools integrate with VS Code

## Prerequisites

- Completed Tutorials 1-4
- Familiar with the terminal, fzf keybindings, and git aliases

---

## Step 1: Create a project with a virtual environment

Every Python project should have its own virtual environment. This keeps dependencies isolated -- what you install for project A doesn't affect project B.

```powershell
# Create and enter a new project directory
mkdir ~\Projects\python-demo
cd ~\Projects\python-demo

# Initialize git
git init

# Create a virtual environment
python -m venv .venv
```

The `.venv` folder now contains a private copy of Python and pip for this project.

### Activate the virtual environment

```powershell
.venv\Scripts\Activate.ps1
```

Your prompt changes to show `(.venv)` -- Oh My Posh displays this alongside the directory and git info. Every `pip install` and `python` command now operates inside this isolated environment.

> **If this fails:** "cannot be loaded because running scripts is disabled" -- execution policy blocks the activation script. Fix: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

### Create a .gitignore

The virtual environment shouldn't be committed:

```powershell
@"
.venv/
__pycache__/
*.pyc
"@ | Set-Content .gitignore
```

### Scaffold a pyproject.toml

Use the setup script's built-in scaffolding:

```powershell
& "$env:WINSETUP\Setup-DevEnvironment.ps1" -ScaffoldPyproject "."
```

This creates a `pyproject.toml` with Ruff and Mypy configuration.

## Step 2: Write some code to lint

Create a Python file with intentional issues so you can see each tool in action:

```powershell
code main.py
```

Paste this into `main.py` (it has problems on purpose):

```python
import os
import json
import sys

def  calculate_total(items, tax_rate):
    total = 0
    for item in items:
        total = total + item["price"] * item["quantity"]
    total = total * (1 + tax_rate)
    return total

def get_user( name ):
    password = "admin123"
    connection_string = "postgresql://user:pass@localhost/db"
    return {"name": name, "role": "user"}

class userManager:
    def __init__(self):
        self.users = []

    def add_user(self, name):
        user = get_user(name)
        self.users.append(user)
        return user

    def find_user(self, name):
        for u in self.users:
            if u["name"] == name:
                return u
        return None

result = calculate_total([{"price": 10, "quantity": 2}], 0.08)
print(f"Total: {result}")
```

This file has: unused imports, hardcoded credentials, inconsistent spacing, no type annotations, and naming convention issues. Perfect for testing all five tools.

## Step 3: Run Ruff format -- Auto-format

Ruff includes a built-in formatter that produces Black-compatible output. Check what it would change first:

```powershell
ruff format --diff main.py
```

You'll see a diff showing formatting fixes. Apply the fixes:

```powershell
ruff format main.py
```

Run it again to confirm the file is now clean:

```powershell
ruff format --check main.py
```

**Key insight**: Ruff handles both linting (`ruff check`) and formatting (`ruff format`). One tool for everything.

## Step 4: Run Ruff -- Fast linting

Ruff catches style issues, unused imports, and common bugs:

```powershell
ruff check main.py
```

You'll see errors like:

```
main.py:1:8: F401 `os` imported but unused
main.py:2:8: F401 `json` imported but unused
main.py:3:8: F401 `sys` imported but unused
```

The `F401` codes are rule identifiers. Your `pyproject.toml` enables `E` (pycodestyle), `F` (pyflakes), and `I` (isort).

Auto-fix what Ruff can:

```powershell
ruff check --fix main.py
```

The unused imports are removed automatically. Run `ruff check main.py` again -- those errors are gone.

> **If this fails:** ruff reports errors it cannot auto-fix -- these require manual intervention. The error code tells you the rule (e.g., `F841` unused variable). Fix each manually, then re-run.

**Key insight**: Ruff is extremely fast (written in Rust) and replaces several older tools (flake8, isort, pyflakes) in one. It's the first linter you should run because it catches the most common issues and auto-fixes many of them.

## Step 5: Run Pylint -- Deep analysis

Pylint does more thorough analysis than Ruff, including code complexity, naming conventions, and design suggestions:

```powershell
pylint main.py
```

You'll see output with different categories:

- **C** (Convention): Naming issues, missing docstrings
- **W** (Warning): Unused variables, unreachable code
- **E** (Error): Actual bugs
- **R** (Refactor): Code smell suggestions

Pylint gives a score out of 10. Don't aim for 10/10 on every file -- focus on E and W categories first.

**Key insight**: Pylint is opinionated and slower than Ruff. It's most valuable for catching design issues that simpler linters miss. Use Ruff for fast feedback, Pylint for thorough review.

## Step 6: Run Mypy -- Type checking

Mypy checks type annotations. Since our example has no annotations, Mypy won't find much:

```powershell
mypy main.py
```

Now add type annotations to `calculate_total`:

```python
def calculate_total(items: list[dict], tax_rate: float) -> float:
```

Run Mypy again. It now validates that the function is called correctly. Try adding a deliberate error to see Mypy catch it -- change the call to:

```python
result = calculate_total("not a list", 0.08)
```

```powershell
mypy main.py
# error: Argument 1 to "calculate_total" has incompatible type "str"; expected "list[dict[...]]"
```

Fix it and move on. The point is: Mypy catches bugs that only appear at runtime, before you ever run the code.

> **If this fails:** mypy reports "Cannot find implementation or library stub for module" -- the module lacks type stubs. Fix: `pip install types-<package>` or add `# type: ignore` to the import.

**Key insight**: Mypy's value scales with the amount of type annotations in your code. Start by annotating function signatures -- that's where the biggest return on investment is.

## Step 7: Run Bandit -- Security scanning

Bandit catches security anti-patterns:

```powershell
bandit main.py
```

It should flag:

- `password = "admin123"` -- possible hardcoded password
- `connection_string = "postgresql://..."` -- possible hardcoded connection string

These are real issues that could end up in a git repo and leak credentials. Bandit's job is to catch them before that happens.

**Key insight**: Run Bandit before committing, especially on code that handles authentication, database connections, or API keys. It catches things that other linters don't look for.

## Step 8: The pre-commit quality check

Before committing, run all the tools in sequence:

```powershell
# Auto-fix formatting and imports
ruff format main.py
ruff check --fix main.py

# Check for remaining issues
ruff check main.py
pylint main.py
mypy main.py
bandit main.py
```

If everything passes, commit:

```powershell
ga main.py pyproject.toml .gitignore
gc "Add initial project with quality checks passing"
```

## Step 9: Understanding pip vs pipx

You now have two ways to install Python packages:

### pip -- Project dependencies

```powershell
# Inside an activated venv:
pip install flask
pip install -r requirements.txt
pip freeze > requirements.txt
```

pip installs packages into the current virtual environment. These are your project's dependencies -- the libraries your code imports.

### pipx -- Global tools

```powershell
pipx install httpie
pipx list
pipx upgrade-all
```

pipx installs command-line tools (like pylint, ruff, mypy) into isolated global environments. These are tools you *run*, not libraries you *import*. They're available from any directory without activating a venv.

**The rule**: If your code does `import something`, install it with pip inside a venv. If you type `something` as a command in the terminal, install it with pipx.

## VS Code integration

Your VS Code settings automatically run these tools as you edit:

- **Ruff**: Formats on save and lint errors appear as yellow/red squiggles
- **Pylint**: Additional lint errors inline
- **Mypy**: Type errors appear inline
- **Pylance**: Language server for autocomplete, go-to-definition, and type inference
- **ErrorLens**: Shows error messages at the end of the offending line, not just in the Problems panel

Open `main.py` in VS Code and you'll see these working immediately -- no configuration needed beyond what the setup script already deployed.

---

## Exercise

1. Create a new project in `~\Projects\lint-exercise`
2. Create a virtual environment and activate it
3. Scaffold a `pyproject.toml` with the setup script
4. Create a Python file with at least one unused import, one function without type annotations, and one hardcoded string that looks like a password
5. Run each tool in order: `ruff format`, `ruff check --fix`, `ruff check`, `pylint`, `mypy`, `bandit`
6. Fix all the issues the tools find
7. Commit the clean code using the git aliases: `ga .`, `gc "Clean project with all checks passing"`
8. Deactivate the venv: `deactivate`

---

## What comes next

You've got a complete Python workflow from project creation to quality-checked commit. **Tutorial 6** shows you how to bridge the terminal and VS Code -- using `code` CLI flags, navigating between terminal linting output and editor markers, and choosing when to use the integrated terminal vs Windows Terminal.
