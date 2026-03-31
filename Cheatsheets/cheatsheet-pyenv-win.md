# pyenv-win Cheatsheet

Manage multiple Python versions on Windows.

## Commands

| Command | What it does |
|---|---|
| `pyenv install --list` | List all available Python versions |
| `pyenv install <version>` | Install a Python version |
| `pyenv uninstall <version>` | Remove a Python version |
| `pyenv versions` | List installed versions (active marked with *) |
| `pyenv version` | Show current active version |
| `pyenv global <version>` | Set default Python version |
| `pyenv local <version>` | Set Python version for current directory (creates `.python-version`) |
| `pyenv shell <version>` | Set Python version for current session only |
| `pyenv rehash` | Rebuild shims (run after installing new Python) |
| `pyenv which python` | Show path to active Python binary |

## Tips

- `pyenv local` creates a `.python-version` file -- commit it to share with your team.
- Run `pyenv rehash` after installing a new version.
- Profile adds `$env:PYENV\bin` and `$env:PYENV\shims` to PATH automatically.
- pipx tools use the global Python. Venvs use whichever version is active when created.

---

## See Also

- [Python](cheatsheet-python.md) -- pip, pipx, venv, and linting tools
- [Pre-commit](cheatsheet-pre-commit.md) -- automated hooks for Python projects
