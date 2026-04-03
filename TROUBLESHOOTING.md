# Troubleshooting

Find your symptom below. Each entry gives the cause and the fix.

## Setup

### `python` opens the Microsoft Store

**Cause:** Windows 11 ships a stub that redirects to the Store instead of running Python.
**Fix:**
```powershell
# Settings > Apps > Advanced app settings > App execution aliases
# Turn off python.exe and python3.exe, then:
refreshenv
```

### A tool shows as installed but the command is not found

**Cause:** PATH was not updated after installation. The current terminal session has stale PATH.
**Fix:**
```powershell
refreshenv
# Or close and reopen your terminal
```

### Setup script fails at a specific step with a red error

**Cause:** The script continues after failures. Re-run it -- idempotency checks skip what already succeeded.
**Fix:**
```powershell
.\Setup-DevEnvironment.ps1
```
**If that does not work:** Check the log in `logs/setup-*.txt` for the full error.

### SSH agent fails to start

**Cause:** The `ssh-agent` service is disabled by default on some machines.
**Fix:**
```powershell
Set-Service ssh-agent -StartupType Manual
Start-Service ssh-agent
```

### GitHub SSH key upload was skipped

**Cause:** `gh` is not authenticated, or the required API scopes are missing.
**Fix:**
```powershell
gh auth login
# Or if already logged in but missing scopes:
gh auth refresh -h github.com -s admin:public_key,admin:ssh_signing_key
```

### Git commits fail with "Author identity unknown"

**Cause:** `user.name` and `user.email` are not configured in git.
**Fix:**
```powershell
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

### The setup summary shows "All steps completed" but a tool is missing

**Cause:** Check the transcript log for the actual error -- the summary may have missed it if the step's tracking was incomplete.
**Fix:**
```powershell
Show-DevEnvironment    # Check which tools are red
.\Setup-DevEnvironment.ps1    # Re-run to fix missing tools
```

## Terminal and profile

### My prompt shows broken squares instead of icons

**Cause:** The terminal is not using Hack Nerd Font.
**Fix:** In Windows Terminal: Settings > Profiles > Defaults > Font face > set to "Hack Nerd Font". In VS Code: check that `terminal.integrated.fontFamily` is set to `'Hack Nerd Font'`.

### `z` does not jump to the expected directory

**Cause:** zoxide ranks directories by frequency and recency. A directory visited once ranks lower than one visited daily.
**Fix:**
```powershell
zoxide add "$env:USERPROFILE\Code\my-project"    # Seed it manually
```

### `z` database is empty

**Cause:** zoxide's prompt hook was not firing (Oh My Posh replaced the prompt function before zoxide wired its hook).
**Fix:** Ensure the zoxide section appears **after** Oh My Posh in `profile.ps1`. Redeploy with `.\Apply-PowerShellProfile.ps1`.

### `Ctrl+R` shows no history

**Cause:** PSReadLine history file does not exist yet or fzf is not on PATH.
**Fix:**
```powershell
fzf --version    # If not found, restart terminal or run refreshenv
```

### Tab completion shows file paths instead of command options

**Cause:** PSFzf's Tab override is replacing the module-specific completer.
**Fix:** Remove the Tab binding from `profile.ps1` and use `Ctrl+T` for file picking instead.

### The `gc` alias behaves like `Get-Content`

**Cause:** The `Remove-Alias -Name gc` line is missing from your profile.
**Fix:**
```powershell
. $PROFILE    # Reload profile
# If still broken, redeploy: .\Apply-PowerShellProfile.ps1
```

### `Test-ProfileHealth` reports missing sections

**Cause:** The deployed profile is out of date.
**Fix:**
```powershell
.\Apply-PowerShellProfile.ps1
. $PROFILE
```

### Profile takes more than 2 seconds to load

**Cause:** `Setup-PythonTools -Silent` runs on first terminal open each day. If Python or pipx is slow to respond, this delays startup.
**Fix:** The daily stamp at `$env:TEMP\winsetup-pythontools-stamp` prevents repeated runs. If startup is consistently slow, comment out the auto-run block in `profile.ps1`.

### `$env:WINSETUP` is empty

**Cause:** The setup script has not been run (it persists WINSETUP to User environment), and the profile fallback did not find the repo.
**Fix:**
```powershell
$env:WINSETUP = "path\to\winSetup"
# Or re-run: .\Setup-DevEnvironment.ps1
```

## Python and tooling

### `ruff` is not found after `pipx install`

**Cause:** pipx's bin directory is not on PATH.
**Fix:**
```powershell
pipx ensurepath
# Then restart your terminal
```

### `pre-commit` hooks run but do nothing

**Cause:** Hooks only check staged files by default. If nothing is staged, they report success.
**Fix:**
```powershell
pre-commit run --all-files    # Run against all files
```

### `mypy` reports no errors on obviously wrong code

**Cause:** mypy only checks files with type annotations. Unannotated code is ignored by default.
**Fix:** Add type annotations to function signatures, then re-run `mypy`.

### `bandit` flags a false positive

**Cause:** bandit is conservative -- it flags patterns that could be insecure, not only those that definitely are.
**Fix:**
```python
x = "not_a_real_secret"  # nosec B105
```
The `# nosec` comment suppresses the specific rule for that line.

### Virtual environment activation is blocked by execution policy

**Cause:** PowerShell's execution policy blocks `.ps1` script execution.
**Fix:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### `pipx upgrade` fails with "Access is denied" on an `.exe` file

**Cause:** VS Code extensions (Ruff, Pylint, Mypy) hold Python tool executables open, preventing pipx from replacing them during upgrades.
**Fix:** Close VS Code, then re-run `.\Update-DevEnvironment.ps1`. The update script now detects running VS Code and waits automatically.

### `pipx upgrade` warnings show "File exists at X and points to X, not Y" for all tools

**Cause:** pipx shims are corrupted, usually from an interrupted upgrade.
**Fix:**
```powershell
pipx reinstall-all
```
**If that does not work:** Delete the contents of `~\.local\bin` manually, then run `pipx reinstall-all`.

### `pyenv update` produces "htmlfile: This command is not supported"

**Cause:** pyenv's built-in update command uses a VBScript with an ActiveX component unavailable on modern Windows 11.
**Fix:** This is handled automatically by `.\Update-DevEnvironment.ps1`, which uses pip to update pyenv-win instead. Do not run `pyenv update` directly.

### `pyenv local` sets a version but `python --version` shows the wrong one

**Cause:** pyenv's shims directory is not first on PATH, or the Windows Store stub is intercepting.
**Fix:**
```powershell
pyenv rehash
# Check PATH order:
$env:PATH -split ";" | Select-String "pyenv"
```

## Git and signing

### Commits show as "Unverified" on GitHub

**Cause:** The SSH key is uploaded as an Authentication Key but not as a Signing Key. Both are required.
**Fix:**
```powershell
gh ssh-key add ~\.ssh\id_ed25519.pub --type signing --title "signing"
```

### `git commit` hangs or asks for a passphrase repeatedly

**Cause:** The SSH agent does not have the key loaded.
**Fix:**
```powershell
ssh-add -l    # Check loaded keys
ssh-add ~\.ssh\id_ed25519    # Load if missing
```

### `git add -p` is not working correctly with delta

**Cause:** Delta's colour output can interfere with interactive patch mode.
**Fix:** Use lazygit's hunk staging instead (`lg`, then `Enter` on a file, `Space` on individual hunks).

### `git tag -v` shows "gpg.ssh.allowedSignersFile needs to be configured"

**Cause:** Git cannot verify SSH signatures without a local list of trusted public keys.
**Fix:**
```powershell
$key = Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"
$email = git config --global user.email
"$email $key" | Set-Content "$env:USERPROFILE\.ssh\allowed_signers"
git config --global gpg.ssh.allowedSignersFile "$env:USERPROFILE\.ssh\allowed_signers"
```
**If that does not work:** Verify `user.email` is set with `git config --global user.email`. The allowed signers file entry must use the same email address as your git identity.

### Delta is not rendering -- output looks like plain text

**Cause:** The terminal does not support the colour depth delta needs, or delta is not installed.
**Fix:**
```powershell
delta --version    # Check installed
git config --global core.pager    # Should say "delta"
```
**If that does not work:** Use `git -c core.pager=less diff` as a fallback. Set `TERM=xterm-256color` for SSH sessions.

### `git push` was rejected with "Updates were rejected because the remote contains work"

**Cause:** A teammate has pushed to the branch since you last pulled.
**Fix:**
```powershell
git pull --rebase
git push
```

### `ssh -T git@github.com` returns "Permission denied (publickey)"

**Cause:** SSH agent is not running or the key is not loaded.
**Fix:**
```powershell
ssh-add -l    # Check loaded keys
ssh-add ~\.ssh\id_ed25519    # Load key
Start-Service ssh-agent    # If agent not running
```

### My teammate's commits show as "Unverified" in our PR

**Cause:** They have not uploaded their SSH key as a Signing Key on GitHub (only as Authentication).
**Fix:** They need to go to GitHub > Settings > SSH keys > add the same key with type "Signing Key".

### pre-commit hooks are not running even though I ran `pre-commit install`

**Cause:** `pre-commit install` is per-repository. Cloning a repo does not automatically install hooks.
**Fix:**
```powershell
cd <project-root>
pre-commit install
```

### A merge conflict is blocking my commit

**Cause:** Two branches changed the same lines. Git cannot auto-merge.
**Fix:** Open `lg` (lazygit), navigate to the conflicted file, resolve visually. Or open the file in VS Code -- conflict markers are highlighted.

## VS Code integration

### Ruff is not showing errors inline

**Cause:** The Ruff extension is not installed or is disabled.
**Fix:**
```powershell
code --install-extension charliermarsh.ruff
```

### The Python interpreter is not being detected

**Cause:** VS Code needs to be told which venv to use.
**Fix:** Open the Command Palette (`Ctrl+Shift+P`) > "Python: Select Interpreter" > choose the `.venv` in your project.

### The integrated terminal looks different from Windows Terminal

**Cause:** The font is not set in VS Code settings.
**Fix:** Check that `terminal.integrated.fontFamily` is set to `'Hack Nerd Font'` in VS Code settings (`Ctrl+,`).

## Navigation and search

### `fd` is returning files that should be gitignored

**Cause:** `fd` respects `.gitignore` by default, but only inside a git repository. Outside a repo, it shows everything.
**Fix:**
```powershell
fd --no-ignore    # Explicitly include ignored files
fd --type f       # Inside a git repo, .gitignore is respected automatically
```

### `rg` is not finding something you know is in the codebase

**Cause:** The file is gitignored or hidden. `rg` skips both by default.
**Fix:**
```powershell
rg --hidden --no-ignore "your search term"
```

### `Ctrl+F` preview is empty or showing an error

**Cause:** `bat` is not installed, or the file type is not recognised.
**Fix:**
```powershell
bat --version    # Check installed
fd --type f | fzf --preview "bat --color=always {}"    # Test manually
```
