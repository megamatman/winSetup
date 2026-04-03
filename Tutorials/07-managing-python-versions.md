# Tutorial 7: Managing Python Versions

## What you will learn

- Using pyenv-win to install and switch between Python versions
- Understanding why version management matters for real projects
- Resolving a real package compatibility conflict with per-project versions
- How pyenv interacts with virtual environments

## Prerequisites

- Completed Tutorials 1-5
- Comfortable with virtual environments and pip

---

## Step 1: Check your current Python

Before managing multiple versions, see what you have now:

```powershell
python --version
```

This shows the Python your system currently uses. Now check what pyenv knows about:

```powershell
pyenv versions
```

You'll see a list of installed versions with an asterisk next to the active one. If you've only installed one version, there will be a single entry.

## Step 2: See available versions

```powershell
pyenv install --list
```

This prints every Python version pyenv-win can install. The list is Windows-specific -- it only includes versions that have official Windows installers or builds. You'll see entries like `3.11.9`, `3.12.4`, `3.13.0`, etc.

Scroll through to find the version you need. For this tutorial, we'll use `3.11.9` as the second version.

## Step 3: Install a second Python version

```powershell
pyenv install 3.11.9
```

This downloads and installs Python 3.11.9 alongside your existing version. Neither version is affected by the other -- they live in separate directories under `~/.pyenv/pyenv-win/versions/`.

Verify both are now available:

```powershell
pyenv versions
```

You should see both your original version and `3.11.9` listed.

## Step 4: Switch globally

The global version is the default Python used everywhere on your system:

```powershell
pyenv global 3.11.9
```

Now verify:

```powershell
python --version
# Python 3.11.9
```

Every terminal session, every directory, every new project will use 3.11.9 until you change it.

Switch back to your primary version -- use whichever version you had active before this tutorial:

> **Tip**: Check which version that is with `pyenv versions` before switching away from it.

```powershell
pyenv global <your-version>
python --version
```

Use `pyenv global` when you want to change the default for everything. This is a system-wide setting.

## Step 5: Set a per-project version

This is where pyenv becomes truly useful. Different projects can use different Python versions:

```powershell
mkdir ~\Projects\legacy-project
cd ~\Projects\legacy-project

pyenv local 3.11.9
```

This creates a `.python-version` file in the directory:

```powershell
cat .python-version
# 3.11.9
```

> **If this fails:** `python --version` still shows the wrong version -- pyenv shims are not first on PATH. Fix: check `$env:PATH -split ";"` and verify `.pyenv\pyenv-win\shims` appears early. Reload profile: `. $PROFILE`.

Now whenever you `cd` into this directory (or any subdirectory), pyenv automatically switches to Python 3.11.9. Step out of the directory and your global version takes over again:

```powershell
python --version
# 3.11.9

cd ..
python --version
# 3.12.4
```

The `.python-version` file should be committed to git so everyone on the team uses the same Python version for that project.

## Step 6: How shims work

You might wonder: how does typing `python` sometimes give you 3.12 and sometimes 3.11?

pyenv uses **shims** -- small wrapper scripts that sit in your PATH ahead of the real Python executables. When you run `python`, you're actually running pyenv's shim, which:

1. Checks the current directory for a `.python-version` file
2. If not found, checks parent directories (walking up to the root)
3. If still not found, uses the global version from `~/.pyenv/pyenv-win/version`
4. Launches the correct Python executable

This is why the pyenv shims directory must be early in your PATH. Your setup script already configures this. You can see the shim in action:

```powershell
pyenv which python
```

This shows the actual path to the Python executable that would run.

## Step 7: Resolve a package compatibility conflict

Here's a real scenario. You want to use a package that requires Python 3.11 (it doesn't support 3.12 yet), but your global Python is 3.12.

```powershell
# Your global is 3.12
python --version
# Python 3.12.4

# Create the project
mkdir ~\Projects\ml-experiment
cd ~\Projects\ml-experiment

# Pin this project to 3.11
pyenv local 3.11.9
python --version
# Python 3.11.9

# Now create a venv with 3.11
python -m venv .venv
.venv\Scripts\Activate.ps1

# Install the package that needs 3.11
pip install some-package

# Everything works because both the base Python and the venv are 3.11
python --version
# Python 3.11.9
```

Without pyenv, you'd have to manually manage multiple Python installations, edit PATH variables, and hope nothing breaks. With pyenv, it's two commands: `pyenv local` and `python -m venv`.

## Step 8: Interaction with virtual environments

Understanding how pyenv and venvs work together is important:

1. **pyenv local** sets which Python interpreter is used in a directory
2. **python -m venv .venv** creates a virtual environment using that interpreter
3. The venv "locks in" the Python version it was created with

This means:

- Changing `pyenv local` after creating a venv does NOT change the venv's Python
- If you need a venv with a different Python, delete the old venv and create a new one
- The `.python-version` file and `.venv` directory work together: the file ensures `python -m venv` uses the right version when creating or recreating the environment

A typical project setup:

```powershell
cd ~\Projects\my-project
pyenv local 3.11.9          # Set the Python version
python -m venv .venv         # Create venv with that version
.venv\Scripts\Activate.ps1   # Activate it
pip install -r requirements.txt
```

---

## Exercise

1. Install a second Python version using `pyenv install` (pick one you don't have)
2. Create a new project directory under `~\Projects\`
3. Set the project to use the new version with `pyenv local`
4. Verify `python --version` shows the correct version inside the directory
5. Create a virtual environment with `python -m venv .venv`
6. Activate it and verify `python --version` still shows the correct version
7. Step out of the directory and confirm your global version is unchanged

---

## What comes next

You can manage any number of Python versions side by side. When a project's README says "requires Python 3.11", you now know exactly what to do: `pyenv install`, `pyenv local`, `python -m venv`.

In Tutorial 8, you'll level up your git workflow with lazygit's visual interface, delta's improved diffs, and commit signing verification.
