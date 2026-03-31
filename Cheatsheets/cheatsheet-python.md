# Python Cheatsheet

Python, pip, pipx, virtual environments, and code quality tools.

## Python and pip

| Command | What it does |
|---|---|
| `python --version` | Show Python version |
| `python <file>` | Run a script |
| `python -m venv .venv` | Create a virtual environment |
| `.venv\Scripts\Activate.ps1` | Activate venv (Windows) |
| `deactivate` | Deactivate venv |
| `pip install <pkg>` | Install a package |
| `pip install -r requirements.txt` | Install from requirements file |
| `pip freeze > requirements.txt` | Export installed packages |
| `pip list` | List installed packages |
| `pip show <pkg>` | Show package details |
| `pip uninstall <pkg>` | Remove a package |

## pipx (Global Tools)

| Command | What it does |
|---|---|
| `pipx list` | List installed tools |
| `pipx install <tool>` | Install a CLI tool globally |
| `pipx upgrade <tool>` | Upgrade a tool |
| `pipx upgrade-all` | Upgrade all tools |
| `pipx uninstall <tool>` | Remove a tool |
| `pipx run <tool>` | Run a tool without installing |
| `pipx ensurepath` | Add pipx bin directory to PATH |
| `Setup-PythonTools` | Check/install all configured tools |

## ruff (Linter and Formatter)

| Command | What it does |
|---|---|
| `ruff check <file>` | Lint a file |
| `ruff check <dir>/` | Lint a directory |
| `ruff check --fix <file>` | Auto-fix issues |
| `ruff rule <code>` | Explain a specific rule |
| `ruff format <file>` | Format a file |
| `ruff format <dir>/` | Format all Python files in directory |
| `ruff format --check <file>` | Check if formatting is needed (no changes) |
| `ruff format --diff <file>` | Show what would change |

## pylint (Analysis)

| Command | What it does |
|---|---|
| `pylint <file>` | Analyse a file (score out of 10) |
| `pylint <dir>/` | Analyse a directory |
| `pylint --disable=C0114 <file>` | Suppress a specific warning |
| `pylint --generate-rcfile > .pylintrc` | Generate config file |

## mypy (Type Checking)

| Command | What it does |
|---|---|
| `mypy <file>` | Type-check a file |
| `mypy <dir>/` | Type-check a directory |
| `mypy --strict <file>` | Strict mode (all checks enabled) |
| `mypy --ignore-missing-imports <file>` | Skip untyped third-party libraries |

## bandit (Security)

| Command | What it does |
|---|---|
| `bandit <file>` | Scan a file for security issues |
| `bandit -r <dir>/` | Scan recursively |
| `bandit -r <dir>/ -ll` | High severity only |
| `bandit -r <dir>/ -s B101` | Skip a specific rule |

## Pre-Commit Quality Check

Run in order before committing:

```powershell
ruff format src/
ruff check --fix src/
ruff check src/
pylint src/
mypy src/
bandit -r src/
```

## pyenv-win

For pyenv-win commands see [cheatsheet-pyenv-win.md](cheatsheet-pyenv-win.md).

## pre-commit

For pre-commit commands see [cheatsheet-pre-commit.md](cheatsheet-pre-commit.md).

## Tips

- **pip vs pipx**: `pip install` for project dependencies (inside a venv). `pipx install` for CLI tools (global).
- Windows uses `.venv\Scripts\Activate.ps1` (not `source .venv/bin/activate` like Linux/macOS).
- `python` on Windows (not `python3`). The `py` launcher also works: `py -3.12 script.py`.
- Add `.venv/` and `__pycache__/` to `.gitignore`.
- VS Code runs Ruff on save and shows Ruff/Pylint/Mypy errors inline automatically.

---

## See Also

- [pyenv-win](cheatsheet-pyenv-win.md) -- Python version management
- [Pre-commit](cheatsheet-pre-commit.md) -- automated linting on commit
- [Security](cheatsheet-security.md) -- bandit, secrets scanning, .env conventions
