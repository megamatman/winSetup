# Python Version Management -- pyenv-win

pyenv-win lets you install and switch between multiple Python versions on the same Windows machine. Instead of uninstalling Python 3.12 to test against 3.11, or juggling Chocolatey pins and Windows Store stubs, pyenv-win manages separate Python installations side-by-side and swaps between them instantly using shims. You can set a global default version for everyday use and pin specific versions to individual projects with a `.python-version` file.

## Setup

- **Installation**: The setup script installs pyenv-win via `pip install pyenv-win --target "$env:USERPROFILE\.pyenv\pyenv-win"`.
- **PATH**: Your PowerShell profile adds pyenv's `bin` and `shims` directories to PATH:
  ```powershell
  $env:PYENV = "$env:USERPROFILE\.pyenv\pyenv-win"
  if (Test-Path $env:PYENV) {
      $env:PATH = "$env:PYENV\bin;$env:PYENV\shims;$env:PATH"
  }
  ```
- **Location**: pyenv-win lives at `~\.pyenv\pyenv-win\`. All installed Python versions are stored under `~\.pyenv\pyenv-win\versions\`.

---

## How Shims Work

When you run `python`, your shell finds the first `python.exe` on PATH. pyenv-win places its `shims` directory at the front of PATH. The shim is a lightweight executable that intercepts the call, checks which Python version should be active (based on the current directory, the `.python-version` file, or the global default), and then delegates to the real Python binary in the correct `versions/` subdirectory.

This means you never need to modify PATH yourself when switching versions. The shim does the routing transparently.

```
python (your command)
  -> shims/python.exe (pyenv intercepts)
    -> checks .python-version in current dir (if present)
    -> checks pyenv global setting
    -> delegates to versions/3.12.4/python.exe (the real Python)
```

---

## Core Commands

### List all versions available to install

```powershell
pyenv install --list
```

This shows every Python version pyenv-win can install. The list is long -- pipe it to `fzf` or filter it:

```powershell
pyenv install --list | Select-String "3\.12"
```

### Install a Python version

```powershell
pyenv install 3.12.4
```

Downloads and installs Python 3.12.4 into `~\.pyenv\pyenv-win\versions\3.12.4\`. This doesn't affect your current Python -- it just makes the version available.

Install multiple versions:

```powershell
pyenv install 3.11.9
pyenv install 3.10.14
```

### Set the global default version

```powershell
pyenv global 3.12.4
```

This sets the Python version used everywhere unless overridden by a local `.python-version` file. The setting is stored in `~\.pyenv\pyenv-win\version`.

### Set a project-local version

```powershell
cd ~\Code\legacy-app
pyenv local 3.11.9
```

This creates a `.python-version` file in the current directory containing `3.11.9`. Whenever you're in this directory (or any subdirectory), `python` resolves to 3.11.9 instead of the global default.

### Check the active version

```powershell
pyenv version
```

Shows the currently active Python version and where the setting comes from:

```
3.12.4 (set by ~\.pyenv\pyenv-win\version)
```

Or if a local version is active:

```
3.11.9 (set by ~\Code\legacy-app\.python-version)
```

### List all installed versions

```powershell
pyenv versions
```

Shows every Python version you've installed, with an asterisk next to the active one:

```
  3.10.14
  3.11.9
* 3.12.4 (set by ~\.pyenv\pyenv-win\version)
```

### Uninstall a version

```powershell
pyenv uninstall 3.10.14
```

Removes the Python installation from the versions directory.

### Rehash after installing

```powershell
pyenv rehash
```

Regenerates the shim executables. Run this after installing a new Python version or after installing a package that provides a command-line script (though pyenv-win usually handles this automatically).

---

## Per-Project Python Versions

The `.python-version` file is the key to per-project version management. It's a plain text file containing just the version number.

### Creating it

```powershell
cd ~\Code\my-api
pyenv local 3.12.4
```

This creates `.python-version` with the content `3.12.4`.

### Committing it to your repo

The `.python-version` file should be committed to git. It tells other developers (and CI) which Python version the project expects:

```powershell
ga .python-version
gc "Pin Python version to 3.12.4"
```

### How it's resolved

When you run `python`, pyenv checks these locations in order:

1. The `PYENV_VERSION` environment variable (if set).
2. A `.python-version` file in the current directory.
3. A `.python-version` file in any parent directory (walks up the tree).
4. The global version set by `pyenv global`.

This means a `.python-version` in your project root automatically applies to all subdirectories within that project.

---

## Real-World Workflows

### Setting up a new project with a specific Python version

```powershell
mkdir my-api && cd my-api
pyenv local 3.12.4
python --version                    # Confirms 3.12.4
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install flask pytest
pip freeze > requirements.txt
git init
ga .python-version .gitignore requirements.txt
gc "Initial project setup with Python 3.12.4"
```

### Testing against multiple Python versions

```powershell
cd ~\Code\my-library

pyenv local 3.12.4
python -m venv .venv-312
.venv-312\Scripts\Activate.ps1
pip install -r requirements.txt
pytest
deactivate

pyenv local 3.11.9
python -m venv .venv-311
.venv-311\Scripts\Activate.ps1
pip install -r requirements.txt
pytest
deactivate

pyenv local 3.12.4              # Set it back to the default
```

### Working on a legacy project

Your global Python is 3.12.4 but a legacy project needs 3.10:

```powershell
pyenv install 3.10.14              # One-time install
cd ~\Code\legacy-app
pyenv local 3.10.14
python --version                    # 3.10.14
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt     # Install deps for this version
```

When you `cd` out of the project, your global 3.12.4 takes over again automatically.

### Upgrading a project to a newer Python

```powershell
cd ~\Code\my-api
pyenv install 3.13.1               # Install the new version
pyenv local 3.13.1                 # Switch the project
rm -r .venv                        # Delete old venv (it's tied to the old Python)
python -m venv .venv               # Create a new venv with 3.13.1
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
pytest                              # Run tests to check compatibility
gc "Upgrade Python to 3.13.1"
```

---

## pyenv-win and pipx

pipx installs global command-line tools (ruff, mypy, pylint, etc.) using the Python version that was active when pipx was installed. These tools live in their own virtual environments under `~\.local\pipx\venvs\` and are not affected by `pyenv local` or `pyenv global` changes.

This means:

- **pipx tools always work**: Changing your pyenv version doesn't break ruff, mypy, or other pipx-installed tools. They use the Python they were installed with.
- **Virtual environments use the local Python**: When you run `python -m venv .venv`, the venv is created using whichever Python pyenv currently resolves to. This is the version that matters for your project dependencies.
- **No conflict**: pipx global tools and per-project venvs are completely independent. You can have pyenv set to 3.11.9 for a project while your pipx tools run on 3.12.4.

If you reinstall Python entirely (e.g., uninstall via Chocolatey and reinstall), you may need to reinstall pipx and its tools. This doesn't happen when switching versions via pyenv.

---

## The scratch.py Convention

The project template (in `templates/python-project/`) scaffolds a `scratch.py` file that is listed in `.gitignore`. This is a dedicated space for quick experiments, API tests, and throwaway code without polluting your codebase.

Use it for:
- Testing a new library before integrating it into your project
- Prototyping a function before writing the real implementation
- Running quick data transformations or API calls

This pairs well with VS Code's `# %%` cell execution. Add `# %%` comments to divide `scratch.py` into cells, then press `Ctrl+Enter` to run individual cells interactively -- like a lightweight Jupyter notebook without the `.ipynb` overhead.

```python
# %%
import requests
response = requests.get("https://api.example.com/data")
print(response.json())

# %%
# Try a different approach
data = [x ** 2 for x in range(10)]
print(data)
```

Since `scratch.py` is gitignored, you never need to worry about accidentally committing experimental code.

---

## Tips and Gotchas

- **Rehash after installing**: If a newly installed Python version isn't being picked up, run `pyenv rehash` to regenerate the shims.
- **Windows-specific: no build from source**: Unlike pyenv on macOS/Linux, pyenv-win downloads prebuilt Python binaries. You don't need a C compiler or build tools. Installation is just a download and extract.
- **Chocolatey Python and pyenv can coexist**: The Chocolatey-installed Python is your "system" Python. pyenv manages additional versions alongside it. Because pyenv's shims are earlier on PATH (set by your profile), pyenv's version takes priority. If you remove pyenv from PATH, the Chocolatey Python is used.
- **The Windows Store stub**: If `python --version` opens the Microsoft Store even with pyenv configured, the Windows Store app alias is intercepting the call. Disable it: Settings > Apps > Advanced app settings > App execution aliases > turn off "python.exe" and "python3.exe".
- **`py` launcher vs pyenv**: Windows has a built-in `py` launcher (`py -3.11 script.py`) that also manages versions. pyenv-win is more powerful because it supports `.python-version` files and per-directory switching, but `py` still works for one-off version selection. They don't interfere with each other.
- **PATH order matters**: Your profile puts pyenv's shims before everything else on PATH. If `python --version` isn't showing the expected version, check PATH order with `$env:PATH -split ";"` and make sure `~\.pyenv\pyenv-win\shims` appears before `C:\Python312\` or similar.
- **Virtual environments are version-specific**: A venv created with Python 3.12 won't work if you switch to 3.11. If you change a project's Python version, delete and recreate the venv.

---

## See Also

- [Python Environment](05-python-environment.md) -- pip, pipx, virtual environments, and linting tools
- [Project Setup](09-project-setup.md) -- cookiecutter and pre-commit for new projects