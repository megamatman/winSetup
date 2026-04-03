# Project Setup -- Cookiecutter, Pre-commit, and Templates

How to scaffold a Python project using the winSetup templates and configure pre-commit hooks.

> **Path convention**: `$env:WINSETUP` is set automatically by the setup script. If not set, define it: `$env:WINSETUP = "path\to\winSetup"`

## Setup

- **cookiecutter**: Installed globally via `pipx install cookiecutter` by the setup script.
- **pre-commit**: Installed globally via `pipx install pre-commit` by the setup script.
- **Templates**: Bundled in the `winSetup\templates\` directory:
  - `python-project/` -- A cookiecutter template for new Python projects (includes `pyproject.toml` and a starter file).
  - `pre-commit-config.yaml` -- A ready-to-use pre-commit configuration with hooks for formatting, linting, type checking, and security scanning.

---

## Cookiecutter -- Project Templating

Cookiecutter takes a template directory (local or remote) and generates a new project by prompting you for variable values (project name, author, etc.) and filling them into the template files.

### Using the bundled Python project template

```powershell
cookiecutter $WINSETUP\templates\python-project
```

Cookiecutter prompts you for the template variables and creates a new directory with the project scaffolded. The bundled template includes:

- `pyproject.toml` with ruff, mypy, and bandit configurations.
- A starter Python file.

### Using community templates

Cookiecutter can pull templates directly from GitHub:

```powershell
cookiecutter gh:audreyfeldroy/cookiecutter-pypackage
```

Popular Python templates:

```powershell
cookiecutter gh:audreyfeldroy/cookiecutter-pypackage    # Full Python package with docs, CI, PyPI
cookiecutter gh:drivendataorg/cookiecutter-data-science  # Data science project structure
cookiecutter gh:tiangolo/full-stack-fastapi-template     # FastAPI full-stack app
```

### Listing previously used templates

Cookiecutter caches templates you've used before. Replay them with:

```powershell
cookiecutter --replay $WINSETUP\templates\python-project
```

This reuses your previous answers without prompting.

### Using default values without prompting

```powershell
cookiecutter --no-input $WINSETUP\templates\python-project
```

Accepts all default values. Useful for scripting.

### Overriding specific values on the command line

```powershell
cookiecutter $WINSETUP\templates\python-project project_name="my-api"
```

---

## Pre-commit -- Automated Quality Checks

Pre-commit is a framework for managing git hooks. It runs a set of checks every time you run `git commit`. If any check fails, the commit is blocked until you fix the issue. This catches formatting problems, lint errors, type errors, and security issues before they ever reach your repository.

### Installing hooks in a project

```powershell
cd ~\Projects\my-api
pre-commit install
```

This installs the git hooks into `.git/hooks/`. After this, every `git commit` in this repository automatically runs the checks defined in `.pre-commit-config.yaml`.

### The bundled configuration

The template at `winSetup\templates\pre-commit-config.yaml` includes these hooks:

**From `pre-commit-hooks` (general quality):**

| Hook | What it does |
|------|-------------|
| `trailing-whitespace` | Strips trailing whitespace from all files. |
| `end-of-file-fixer` | Ensures every file ends with a newline. |
| `check-yaml` | Validates YAML files for syntax errors. |
| `check-added-large-files` | Prevents accidentally committing large files (binaries, data dumps). |
| `detect-private-key` | Blocks commits that contain private keys (RSA, DSA, EC, etc.). |

**From `ruff-pre-commit` (linting and formatting):**

| Hook | What it does |
|------|-------------|
| `ruff-format` | Auto-formats Python code to Ruff/Black-compatible style. |
| `ruff` | Runs the ruff linter with `--fix` to auto-correct import ordering and style issues. |

**From `mirrors-mypy` (type checking):**

| Hook | What it does |
|------|-------------|
| `mypy` | Runs static type checking on changed Python files. |

**From `bandit` (security):**

| Hook | What it does |
|------|-------------|
| `bandit` | Scans for security issues (hardcoded passwords, insecure functions, etc.). Uses `pyproject.toml` for config. |

### Running hooks manually

Run all hooks against all files (not just staged ones):

```powershell
pre-commit run --all-files
```

Run a specific hook:

```powershell
pre-commit run ruff-format --all-files
pre-commit run ruff --all-files
pre-commit run mypy --all-files
```

Run hooks only against staged files (same as what happens on commit):

```powershell
pre-commit run
```

### What happens when a hook fails

When you run `gc "Add feature"` and a hook fails:

1. The commit is **blocked** -- nothing is committed.
2. Pre-commit prints which hook failed and what the error was.
3. Some hooks (ruff-format, ruff, trailing-whitespace, end-of-file-fixer) auto-fix the files. The fixed files are left as unstaged changes.
4. You stage the fixes with `ga .` and commit again.

Example flow:

```powershell
ga src/main.py
gc "Add user endpoint"
# ruff-format reformats src/main.py -- commit blocked
# ruff fixes an import ordering issue -- commit blocked

ga src/main.py                     # Stage the auto-fixed file
gc "Add user endpoint"             # Now it passes
```

### Updating hook versions

Hook versions are pinned in `.pre-commit-config.yaml` (e.g., `rev: v4.5.0`). To update all hooks to their latest versions:

```powershell
pre-commit autoupdate
```

This modifies `.pre-commit-config.yaml` with the new version tags. Review the changes and commit:

```powershell
gs                                  # See the modified config
ga .pre-commit-config.yaml
gc "Update pre-commit hooks"
```

### Skipping hooks temporarily

If you need to commit without running hooks (e.g., a work-in-progress commit):

```powershell
git commit --no-verify -m "WIP: partial implementation"
```

Use this sparingly -- the hooks exist to catch problems early.

---

## The Bundled Templates

### `templates/python-project/`

A cookiecutter template that generates a basic Python project structure. Contains:

- `pyproject.toml` -- Configured for ruff (88-char lines, E, F, I rules, formatting), mypy (non-strict), and bandit (excludes tests).
- `scratch.py` -- A starter file.

### `templates/pre-commit-config.yaml`

A ready-to-copy pre-commit configuration. Copy it into any project:

```powershell
Copy-Item $WINSETUP\templates\pre-commit-config.yaml .\.pre-commit-config.yaml
pre-commit install
```

---

For the full project creation sequence, see the [README New Project Quickstart](../README.md#new-project-quickstart).

---

## How Pre-commit Integrates with Existing Tools

Pre-commit runs the same tools you already have installed via pipx, but in isolated environments managed by pre-commit itself. This means:

- **No version conflicts**: Pre-commit downloads its own copies of ruff, mypy, and bandit at the versions pinned in `.pre-commit-config.yaml`. These are independent of your pipx-installed versions.
- **Same configuration**: The hooks read the same `pyproject.toml` for settings (line length, enabled rules, etc.). You configure once and both the terminal commands and the pre-commit hooks use the same rules.
- **Two ways to run checks**: You can run `ruff format --check src/` or `ruff check src/` manually from the terminal (using your pipx versions), and pre-commit runs them automatically on commit (using its own versions). The results should be identical because they share the `pyproject.toml` config.
- **bandit configuration**: The pre-commit hook passes `-c pyproject.toml` to bandit, so it uses the `[tool.bandit]` section in your project's `pyproject.toml` (which excludes the `tests/` directory by default).

If you update your pipx tools with `pipx upgrade-all`, the pre-commit hook versions stay pinned. Run `pre-commit autoupdate` separately to update the hook versions. It's fine if they're slightly out of sync -- the important thing is that both use the same `pyproject.toml` settings.

---

## Real-World Workflows

### Adding pre-commit to an existing project

```powershell
cd ~\Projects\existing-api
Copy-Item $WINSETUP\templates\pre-commit-config.yaml .\.pre-commit-config.yaml
pre-commit install

# Run against all existing files to see what needs fixing
pre-commit run --all-files

# Fix issues (ruff auto-fixes most things)
ga .
gc "Add pre-commit hooks and fix formatting"
```

### Fixing a failed commit

```powershell
ga src/auth.py
gc "Add authentication"
# Output: ruff-format...Failed (reformatted src/auth.py)
# Output: ruff...Failed (fixed 2 import ordering issues)

# Files were auto-fixed by the hooks
ga src/auth.py                     # Stage the fixes
gc "Add authentication"            # Commit again -- passes this time
```

### Running a quick check without committing

```powershell
pre-commit run --all-files
```

This is useful before pushing or before creating a pull request, to catch issues across the entire project rather than just staged files.

### Using a community cookiecutter template with pre-commit

```powershell
cookiecutter gh:audreyfeldroy/cookiecutter-pypackage
cd my-package
Copy-Item $WINSETUP\templates\pre-commit-config.yaml .\.pre-commit-config.yaml
pre-commit install
pre-commit run --all-files
ga .
gc "Initial setup with pre-commit hooks"
```

---

## Tips and Gotchas

- **First run is slow**: The first time pre-commit runs (or after `pre-commit autoupdate`), it downloads and installs the hook environments. Subsequent runs are fast because the environments are cached.
- **Pre-commit cache location**: Hook environments are cached at `~\.cache\pre-commit\`. If hooks behave strangely, clear the cache with `pre-commit clean` and re-run.
- **`.pre-commit-config.yaml` goes in the repo root**: It must be at the top level of your git repository, alongside `.gitignore` and `pyproject.toml`.
- **Commit the config**: `.pre-commit-config.yaml` should be committed to git so every developer on the project gets the same hooks. But each developer needs to run `pre-commit install` once after cloning -- the hooks themselves are not stored in git.
- **Hook versions vs tool versions**: The `rev:` values in `.pre-commit-config.yaml` are git tags, not PyPI versions. They might look different from what `ruff --version` reports. `pre-commit autoupdate` handles this for you.
- **mypy hook and dependencies**: The mypy pre-commit hook runs in its own environment and may not have access to your project's dependencies. If mypy reports `Cannot find implementation or library stub for module`, you may need to add `additional_dependencies` to the mypy hook in `.pre-commit-config.yaml`.
- **Cookiecutter prompts**: If you're scripting project creation and don't want interactive prompts, use `--no-input` with default values or provide variables on the command line.
- **Template customisation**: You can modify the bundled templates in `winSetup\templates\` to match your preferences. Add more files, change the directory structure, or update the `pyproject.toml` settings. Cookiecutter uses Jinja2 templating, so you can add variables with `{{ cookiecutter.variable_name }}`.

---

## See Also

- [Python Environment](05-python-environment.md) -- pip, pipx, virtual environments, and linting tools
- [Security Hygiene](10-security-hygiene.md) -- global .gitignore, SSH signing, secrets scanning