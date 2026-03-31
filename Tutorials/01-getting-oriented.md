# Tutorial 1: Getting Oriented

## What you will learn

- What happens when you open your terminal for the first time after setup
- How to read the Oh My Posh prompt and what each segment means
- Basic directory navigation with `cd` and `ls`
- What your PowerShell profile does and where it lives
- How to run `Setup-PythonTools` manually

## Prerequisites

- The setup script (`Setup-DevEnvironment.ps1`) has been run successfully
- Windows Terminal is open with PowerShell 7

---

## Step 1: Open your terminal

Right-click the Start menu and choose **Terminal**. You don't need Administrator for everyday work -- only the setup script requires elevation.

When the terminal opens, your PowerShell profile runs automatically. Behind the scenes, it:

1. Starts the SSH agent and loads your key (so git operations work without password prompts)
2. Loads the Chocolatey profile (gives you `refreshenv`)
3. Runs `Setup-PythonTools -Silent` (ensures your Python linting tools are installed)
4. Configures fzf, zoxide, bat, PSReadLine, and Oh My Posh

You won't see any output from these steps unless something is wrong. A clean startup means everything loaded successfully.

## Step 2: Read the prompt

Instead of the default `PS C:\Users\<you>>`, you'll see a styled prompt from Oh My Posh using the gruvbox theme. Here's what the segments mean:

```
 ~\winSetup   main
```

- **Directory path** (`~\winSetup`): Your current location. `~` is shorthand for your home folder (`$env:USERPROFILE`).
- **Git branch** (`main`): Shown when you're inside a git repository. The icon and colour change based on status:
  - Clean (no changes): typically green/neutral
  - Dirty (uncommitted changes): shows a modified indicator
  - Ahead/behind remote: shows arrow indicators
- **Python venv**: When a virtual environment is active, its name appears in the prompt (e.g., `.venv`).
- **Execution time**: After a slow command (several seconds or more), the prompt shows how long it took.

Try it: navigate into a git repo and make a change to see the prompt update.

## Step 3: Basic navigation

You already know `cd`, but let's confirm the essentials:

```powershell
# Go to your home directory
cd ~

# Go to a specific folder
cd "$env:USERPROFILE\OneDrive\Documents\Code"

# Go up one level
cd ..

# Go back to the previous directory
cd -
```

List the contents of a directory:

```powershell
ls
```

PowerShell's `ls` is an alias for `Get-ChildItem`. It shows files and folders with their mode, last write time, size, and name.

For a cleaner file listing, you can also use `fd` (which you'll learn in Tutorial 2):

```powershell
fd --max-depth 1
```

## Step 4: Understand your profile

Your profile is a PowerShell script that runs every time you open a terminal. View it:

```powershell
bat $PROFILE
```

This shows the file with syntax highlighting (because `cat` is aliased to `bat`). You'll see sections for SSH Agent, Chocolatey, Python Tools, fzf, zoxide, bat, PSReadLine, git aliases, and Oh My Posh -- each clearly separated by header comments.

The profile lives at:

```
~\OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
```

Because it's in your OneDrive folder, it syncs automatically to other machines where you sign into OneDrive.

**Important**: Don't edit the profile while a terminal is open expecting instant changes. Profile changes take effect in new terminal sessions. To reload in the current session:

```powershell
. $PROFILE
```

The leading dot (`. `) means "dot-source" -- it runs the script in the current session scope rather than a child scope.

## Step 5: Check your Python tools

Your profile runs `Setup-PythonTools -Silent` on every startup. To see the full status with output, run it without the `-Silent` flag:

```powershell
Setup-PythonTools
```

You'll see output like:

```
=== Python Tools Setup ===
Python: Python 3.12.4
pip: found
pipx: found
pylint : already installed
mypy : already installed
ruff : already installed
bandit : already installed
PATH: already configured

=== Setup complete ===
```

If any tool is missing, it gets installed automatically. This is what "idempotent" means in practice -- safe to run repeatedly, only acts when something is missing.

## Step 6: Verify your tools are working

The quickest way to check everything is the `Show-DevEnvironment` command, which is defined in your profile:

```powershell
Show-DevEnvironment
```

This prints every tool's version (or "not found" in red) plus your `$env:WINSETUP` and `$PROFILE` paths. If anything shows as missing, the setup script may need to be re-run, or you may need to restart your terminal for PATH changes to take effect.

You can also check individual tools manually:

```powershell
python --version
git --version
ssh -T git@github.com
$env:WINSETUP    # Should print the path to your winSetup repository
```

If `$env:WINSETUP` is empty, the variable isn't set in your profile -- check that the winSetup section is present in `$PROFILE`.

You can also run `Test-ProfileHealth` to check that your profile has all expected sections:

```powershell
Test-ProfileHealth
```

---

## Exercise

1. Open a new terminal window
2. Run `Show-DevEnvironment` and verify all tools show green
3. Run `Test-ProfileHealth` and confirm no sections are missing
4. Navigate to the winSetup repo directory (use `z winsetup` or `cd $env:WINSETUP`)
5. Run `bat $PROFILE` and read through the sections -- identify what each block does
6. Run `Setup-PythonTools` (without `-Silent`) and confirm all tools are present
7. Check your git connection: `ssh -T git@github.com` -- you should see "Hi <your-username>!"
8. Run `gl` (the git log alias) inside the winSetup directory and read the commit history

---

## What comes next

Now that you understand what's running and where things live, **Tutorial 2** teaches you how to navigate your filesystem faster using zoxide, fd, and bat -- replacing slow manual navigation with intelligent, fuzzy-matched jumps.
