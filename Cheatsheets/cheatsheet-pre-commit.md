# Pre-commit Cheatsheet

Git hook manager that runs linters and formatters on every commit.

## Commands

| Command | What it does |
|---|---|
| `pre-commit install` | Install hooks into current repo's `.git/hooks/` |
| `pre-commit run --all-files` | Run all hooks on every file (not just staged) |
| `pre-commit run <hook-id>` | Run a specific hook (e.g., `pre-commit run ruff-format`) |
| `pre-commit run` | Run hooks on staged files only |
| `pre-commit autoupdate` | Update all hooks to latest versions |
| `pre-commit uninstall` | Remove hooks from current repo |
| `pre-commit clean` | Clear cached hook environments |
| `git commit --no-verify` | Skip hooks for this commit (use sparingly) |

## Template Hooks (from templates/pre-commit-config.yaml)

| Hook | What it does |
|---|---|
| `trailing-whitespace` | Strips trailing whitespace |
| `end-of-file-fixer` | Ensures files end with newline |
| `check-yaml` | Validates YAML syntax |
| `check-added-large-files` | Prevents committing large files |
| `detect-private-key` | Catches accidentally committed keys |
| `ruff-format` | Auto-formats Python code |
| `ruff` | Lints and auto-fixes Python |
| `mypy` | Type-checks Python |
| `bandit` | Security scans Python |

## Tips

- Hooks run automatically on `git commit`. They only check staged files by default.
- If a hook modifies a file (e.g., ruff-format reformats), the commit is aborted. Re-stage and recommit.
- Use `--no-verify` only for emergencies. The hooks exist for a reason.
- Copy the template: `Copy-Item $WINSETUP\templates\pre-commit-config.yaml .\.pre-commit-config.yaml`. Set `$WINSETUP` to your scripts directory -- see [09-project-setup.md](../HowTo-Guides/09-project-setup.md).

---

## See Also

- [Python](cheatsheet-python.md) -- pip, pipx, linting tools
- [Security](cheatsheet-security.md) -- bandit, secrets scanning, global gitignore
