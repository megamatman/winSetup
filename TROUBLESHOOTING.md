# Troubleshooting

Find your symptom below. Each entry gives the cause in one sentence and the fix as a command. If the fix does not resolve the issue, follow the link to the relevant HowTo-Guide for deeper investigation.

## Setup

### `python` opens the Microsoft Store

**Cause:** Windows 11 ships a stub that redirects to the Store instead of running Python.

**Fix:** Settings > Apps > Advanced app settings > App execution aliases > turn off `python.exe` and `python3.exe`. Then:
```powershell
refreshenv
```

### A tool shows as installed but the command is not found

**Cause:** PATH was not updated after installation.

**Fix:**
```powershell
refreshenv
```
**If that does not work:** Close and reopen your terminal. If still missing, re-run `.\Setup-DevEnvironment.ps1`.

### Setup script fails at a specific step with a red error

**Cause:** The script continues after failures and logs everything. Re-run it -- idempotency checks skip what already succeeded.

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

**Cause:** The summary tracks what was attempted but may not catch every failure mode.

**Fix:**
```powershell
Show-DevEnvironment
.\Setup-DevEnvironment.ps1
```
**If that does not work:** Check `logs/setup-*.txt` for the specific error.

## Terminal and profile

### My prompt shows broken squares instead of icons

**Cause:** The terminal is not using Hack Nerd Font.

**Fix:** In Windows Terminal: Settings > Profiles > Defaults > Font face > set to "Hack Nerd Font". In VS Code: check that `terminal.integrated.fontFamily` is set to `'Hack Nerd Font'`.

### `z` does not jump to the expected directory

**Cause:** zoxide ranks directories by frequency and recency. A directory visited once ranks lower.

**Fix:**
```powershell
zoxide add "$env:USERPROFILE\Projects\my-project"
```

### `z` database is empty

**Cause:** zoxide's prompt hook was not firing because Oh My Posh replaced the prompt function.

**Fix:** Ensure the zoxide section appears **after** Oh My Posh in `profile.ps1`, then redeploy:
```powershell
.\Apply-PowerShellProfile.ps1
```

### `Ctrl+R` shows no history

**Cause:** PSReadLine history file does not exist yet, or fzf is not on PATH.

**Fix:**
```powershell
fzf --version
```
**If that does not work:** Restart your terminal or run `refreshenv`.

### The `gc` alias behaves like `Get-Content`

**Cause:** The `Remove-Alias -Name gc` line is missing from your profile.

**Fix:**
```powershell
. $PROFILE
```
**If that does not work:** Redeploy the profile: `.\Apply-PowerShellProfile.ps1`

### `Test-ProfileHealth` reports missing sections

**Cause:** The deployed profile is out of date.

**Fix:**
```powershell
.\Apply-PowerShellProfile.ps1
. $PROFILE
```

### Profile takes more than 2 seconds to load

**Cause:** `Setup-PythonTools -Silent` runs on first terminal open each day.

**Fix:** The daily stamp at `$env:TEMP\winsetup-pythontools-stamp` prevents repeated runs. To suppress entirely, comment out the auto-run block in `profile.ps1`.

### `$env:WINSETUP` is empty

**Cause:** The setup script has not been run, and the profile fallback did not find the repo.

**Fix:**
```powershell
$env:WINSETUP = "path\to\winSetup"
```
**If that does not work:** Re-run `.\Setup-DevEnvironment.ps1` which persists WINSETUP to User environment.

## Python and tooling

### A pipx tool is not found after install

**Cause:** pipx's bin directory is not on PATH.

**Fix:**
```powershell
pipx ensurepath
```
Then restart your terminal.

### `pre-commit` hooks run but do nothing

**Cause:** Hooks only check staged files by default.

**Fix:**
```powershell
pre-commit run --all-files
```

### `mypy` reports no errors on obviously wrong code

**Cause:** mypy only checks files with type annotations. Unannotated code is ignored.

**Fix:** Add type annotations to function signatures, then re-run `mypy`.

### `bandit` flags a false positive

**Cause:** bandit flags patterns that could be insecure, not only those that are.

**Fix:**
```python
x = "not_a_real_secret"  # nosec B105
```

### Virtual environment activation is blocked by execution policy

**Cause:** PowerShell's execution policy blocks `.ps1` script execution.

**Fix:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### `pyenv local` sets a version but `python --version` shows the wrong one

**Cause:** pyenv's shims directory is not first on PATH, or the Windows Store stub is intercepting.

**Fix:**
```powershell
pyenv rehash
$env:PATH -split ";" | Select-String "pyenv"
```

### pre-commit hooks are not running even though I ran `pre-commit install`

**Cause:** `pre-commit install` is per-repository. Cloning a repo does not install hooks automatically.

**Fix:**
```powershell
cd <project-root>
pre-commit install
```

## Git and signing

### Commits show as "Unverified" on GitHub

**Cause:** The SSH key is uploaded as an Authentication Key but not as a Signing Key.

**Fix:**
```powershell
gh ssh-key add ~\.ssh\id_ed25519.pub --type signing --title "signing"
```

### `git commit` hangs or asks for a passphrase repeatedly

**Cause:** The SSH agent does not have the key loaded.

**Fix:**
```powershell
ssh-add -l
ssh-add ~\.ssh\id_ed25519
```

### `git tag -v` shows "gpg.ssh.allowedSignersFile needs to be configured"

**Cause:** Git cannot verify SSH signatures without a local list of trusted public keys.

**Fix:**
```powershell
$key = Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"
$email = git config --global user.email
"$email $key" | Set-Content "$env:USERPROFILE\.ssh\allowed_signers"
git config --global gpg.ssh.allowedSignersFile "$env:USERPROFILE\.ssh\allowed_signers"
```

### `git add -p` is not working correctly with delta

**Cause:** Delta's colour output can interfere with interactive patch mode.

**Fix:** Use lazygit's hunk staging instead: `lg`, then `Enter` on a file, `Space` on individual hunks.

### `git push` rejected with "Updates were rejected because the remote contains work"

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
Start-Service ssh-agent
ssh-add ~\.ssh\id_ed25519
```

### Delta is not rendering -- output looks like plain text

**Cause:** The terminal does not support the colour depth delta needs, or delta is not configured.

**Fix:**
```powershell
delta --version
git config --global core.pager
```
**If that does not work:** Use `git -c core.pager=less diff` as a fallback.

### My teammate's commits show as "Unverified" in our PR

**Cause:** They have not uploaded their SSH key as a Signing Key on GitHub.

**Fix:** They need to go to GitHub > Settings > SSH keys > add the same key with type "Signing Key".

### A merge conflict is blocking my commit

**Cause:** Two branches changed the same lines.

**Fix:** Open `lg` (lazygit), navigate to the conflicted file, resolve visually. Or open the file in VS Code where conflict markers are highlighted.

## VS Code integration

### Ruff is not showing errors inline

**Cause:** The Ruff extension is not installed or is disabled.

**Fix:**
```powershell
code --install-extension charliermarsh.ruff
```

### The Python interpreter is not being detected

**Cause:** VS Code needs to be told which venv to use.

**Fix:** Command Palette (`Ctrl+Shift+P`) > "Python: Select Interpreter" > choose the `.venv` in your project.

### `code .` opens a new window instead of reusing existing

**Cause:** VS Code defaults to opening in a new window.

**Fix:** Add `"window.openFoldersInNewWindow": "off"` to your VS Code settings, or use `code -r .` to reuse the current window.

### The integrated terminal looks different from Windows Terminal

**Cause:** The font is not set in VS Code settings.

**Fix:** Check that `terminal.integrated.fontFamily` is set to `'Hack Nerd Font'` in VS Code settings.

## Navigation and search

### `fd` is returning files that should be gitignored

**Cause:** `fd` respects `.gitignore` only inside a git repository. Outside a repo, it shows everything.

**Fix:**
```powershell
fd --type f    # Inside a git repo, .gitignore is respected automatically
```

### `rg` is not finding something you know is in the codebase

**Cause:** The file is gitignored or hidden.

**Fix:**
```powershell
rg --hidden --no-ignore "your search term"
```

### `Ctrl+F` preview is empty or showing an error

**Cause:** `bat` is not installed, or the file type is not recognised.

**Fix:**
```powershell
bat --version
fd --type f | fzf --preview "bat --color=always {}"
```

## Updates and maintenance

### `pipx upgrade` fails with "Access is denied" on a `.exe` file

**Cause:** VS Code extensions (Ruff, Pylint, Mypy) hold Python tool executables open during upgrades.

**Fix:** Close VS Code, then re-run `.\Update-DevEnvironment.ps1`. The update script detects running VS Code and waits automatically.

### pipx warnings show "File exists at X and points to X, not Y" for all tools

**Cause:** pipx shims are corrupted, usually from an interrupted upgrade.

**Fix:**
```powershell
pipx reinstall-all
```
**If that does not work:** Delete the contents of `~\.local\bin` manually, then run `pipx reinstall-all`.

### `pyenv update` produces "htmlfile: This command is not supported"

**Cause:** pyenv's built-in update uses a VBScript with an ActiveX component unavailable on modern Windows 11.

**Fix:** Use `Invoke-DevUpdate` or `.\Update-DevEnvironment.ps1` instead -- these use pip to update pyenv-win reliably. Do not run `pyenv update` directly.

### pipx warns "Found a space in the pipx home path"

**Symptom:** pipx warns "Found a space in the pipx home path" on every tool update, and some `.exe` files are not updated ("File exists at ... Not modifying").

**Cause:** Windows username contains a space (e.g. "Matt Lawrence"), causing `PIPX_HOME` to default to a path containing a space. pipx does not support spaces in `PIPX_HOME` on Windows.

**Fix:** Migrate pipx to a path without spaces. Run the following steps in a PS7 session:

**Step 1** -- Set new pipx locations:
```powershell
[System.Environment]::SetEnvironmentVariable('PIPX_HOME', 'C:\pipx', 'User')
[System.Environment]::SetEnvironmentVariable('PIPX_BIN_DIR', 'C:\pipx\bin', 'User')
```

**Step 2** -- Add `C:\pipx\bin` to User PATH before `.local\bin`:
```powershell
$current = [System.Environment]::GetEnvironmentVariable('PATH', 'User') -split ';'
$cleaned = $current | Where-Object { $_ -ne 'C:\pipx\bin' }
$reordered = @('C:\pipx\bin') + $cleaned
[System.Environment]::SetEnvironmentVariable('PATH', ($reordered -join ';'), 'User')
```

**Step 3** -- Restart your shell to pick up the new environment variables.

**Step 4** -- Reinstall all pipx packages into the new location:
```powershell
@('ruff','mypy','pylint','bandit','pre-commit','cookiecutter') |
    ForEach-Object { pipx install $_ }
```

**Step 5** -- Remove old stubs from `.local\bin`:
```powershell
@('ruff','mypy','dmypy','mypyc','stubgen','stubtest','pylint',
  'pylint-config','pyreverse','symilar','bandit','bandit-baseline',
  'bandit-config-generator','pre-commit','cookiecutter') |
    ForEach-Object {
        Remove-Item "$env:USERPROFILE\.local\bin\$_.exe" -ErrorAction SilentlyContinue
    }
Remove-Item "$env:USERPROFILE\.local\share\man\man1\bandit.1" -ErrorAction SilentlyContinue
```

**Step 6** -- Restart your shell and run `.\Update-DevEnvironment.ps1` to confirm no pipx warnings appear.

**Note:** The warning "Your profile path contains a space" from winSetup is a pre-flight check that will continue to appear -- this is informational and cannot be resolved without renaming your Windows user account. The pipx migration above resolves the functional issues it causes.
