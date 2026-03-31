# Python Environment

Task reference for Python virtual environments, package management, and code quality tools. For command reference see [cheatsheet-python.md](../Cheatsheets/cheatsheet-python.md).

## How to set up a project virtual environment

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt    # if the project has one
```

Add `.venv/` to your `.gitignore`. The venv is not committed -- only `requirements.txt` is.

> **If this fails:** "cannot be loaded because running scripts is disabled" -- execution policy is blocking activation. Fix: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

## How to decide: pip or pipx?

**pip** installs packages into a virtual environment. Use it for project dependencies -- libraries your code imports (`flask`, `requests`, `sqlalchemy`).

**pipx** installs command-line tools in isolated global environments. Use it for tools you run from the terminal (`ruff`, `pylint`, `mypy`, `bandit`, `pre-commit`).

The rule: if your code does `import X`, install with pip inside a venv. If you type `X` as a terminal command, install with pipx.

> **If a pipx tool is not found after install:** pipx's bin directory is not on PATH. Fix: `pipx ensurepath`, then restart your terminal.

## How to run linters on a project

Run all checks in this order before committing:

```powershell
ruff format --check src/       # Check formatting (no changes)
ruff check src/                # Lint for errors
mypy src/                      # Type checking
pylint src/                    # Deep analysis
bandit -r src/                 # Security scan
```

To auto-fix formatting and lint issues:

```powershell
ruff format src/               # Fix formatting
ruff check --fix src/          # Fix lint issues
```

If pre-commit is installed, these checks run automatically on every commit.

## How to interpret linter output

**ruff**: error codes like `F401` (unused import), `E501` (line too long), `I001` (unsorted imports). Most are auto-fixable with `--fix`.

**pylint**: scores files out of 10. Categories: **C** (convention), **W** (warning), **E** (error), **R** (refactor). Focus on E and W first. Suppress inline: `# pylint: disable=invalid-name`.

**mypy**: reports type mismatches between annotations and usage. Only checks files with type annotations -- unannotated code is silently ignored. Start by annotating function signatures.

> **If mypy reports "Cannot find implementation or library stub":** the module has no type stubs. Fix: `pip install types-<package>` or add `# type: ignore` to the import.

**bandit**: flags security anti-patterns with severity ratings (Low/Medium/High). Not every finding is a real bug -- bandit is conservative. Suppress false positives: `# nosec B105`.

## How to configure linters for a project

All tools read from `pyproject.toml`:

```toml
[tool.ruff]
line-length = 88

[tool.ruff.lint]
select = ["E", "F", "I"]

[tool.ruff.format]
quote-style = "double"
indent-style = "space"

[tool.mypy]
strict = false

[tool.bandit]
exclude_dirs = ["tests"]
```

Scaffold this file with: `.\Setup-DevEnvironment.ps1 -ScaffoldPyproject "."`

## How to integrate linters with VS Code

Your VS Code settings (deployed by `Apply-VSCodeSettings.ps1`) enable:

- **Ruff**: default Python formatter, runs on save, auto-fixes lint issues via `source.fixAll.ruff`
- **Pylint**: additional analysis, errors shown inline
- **Mypy**: type checking, errors shown inline
- **Pylance**: language server for autocomplete and go-to-definition
- **ErrorLens**: shows error messages at the end of the offending line

No additional configuration is needed beyond what the setup script deploys.

## Version management and pre-commit

- For managing multiple Python versions, see [08-python-version-management.md](08-python-version-management.md)
- For pre-commit hooks and project templates, see [09-project-setup.md](09-project-setup.md)

> **Note**: pipx tools use whichever Python was active when installed, not the current pyenv version. Switching `pyenv global` does not affect existing pipx tools. Reinstall with `pipx reinstall <tool>` after switching.

---

## See Also

- [Python Version Management](08-python-version-management.md) -- pyenv-win
- [Project Setup](09-project-setup.md) -- cookiecutter, pre-commit, templates
- [Security Hygiene](10-security-hygiene.md) -- bandit, secrets detection
- [cheatsheet-python.md](../Cheatsheets/cheatsheet-python.md) -- command reference
