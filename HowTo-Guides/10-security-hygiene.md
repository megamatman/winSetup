# Security Hygiene -- Secrets, Signing, and Scanning

How to manage secrets, sign commits, scan for vulnerabilities, and audit repositories before sharing them.

## Setup

- **Global .gitignore**: Created by the setup script at `~\.gitignore_global` and registered with `git config --global core.excludesfile`.
- **SSH commit signing**: Configured by the setup script using your `~/.ssh/id_ed25519.pub` key. All commits are signed automatically.
- **bandit**: Installed globally via `pipx install bandit`.
- **pre-commit**: Installed globally via `pipx install pre-commit`. The template config includes the `detect-private-key` hook and bandit.
- **cookiecutter templates**: The bundled `pyproject.toml` template configures bandit to exclude the `tests/` directory.

---

## Global .gitignore -- First Line of Defence

The global .gitignore prevents certain files from being tracked by git in any repository on your machine. It's your safety net -- even if you forget to add entries to a project's `.gitignore`, the global one catches the most dangerous files.

### What it catches

The setup script creates `~\.gitignore_global` with these patterns:

```gitignore
# Secrets and keys
.env
.env.*
!.env.example
*.key
*.pem
*.p12
*.pfx
id_rsa
id_ed25519
*.secret

# Python
__pycache__/
*.py[cod]
.venv/
venv/
*.egg-info/
.mypy_cache/
.ruff_cache/

# Tools
.pytest_cache/
.pre-commit-config-cache/

# OS
.DS_Store
Thumbs.db
desktop.ini

# Editors
.vscode/settings.json
*.swp
*.swo
```

### Where it lives

```powershell
# View the global gitignore path
git config --global core.excludesfile
# Output: ~\.gitignore_global

# View its contents
bat ~/.gitignore_global
```

### How it works with project .gitignore

The global .gitignore and per-project `.gitignore` files are additive. Git ignores a file if it matches any ignore pattern from either source. The global file protects every repo; the project file adds project-specific patterns.

This means:

- `.env` is ignored everywhere (global).
- `node_modules/` might be ignored in a specific project (project `.gitignore`).
- `!.env.example` overrides the `.env.*` pattern, allowing `.env.example` to be committed.

### Customising the global .gitignore

Edit the file directly:

```powershell
code ~/.gitignore_global
```

Add patterns for tools or frameworks you use. For example:

```gitignore
# Terraform
*.tfstate
*.tfstate.backup
.terraform/

# Node
node_modules/
.npm/
```

After editing, git picks up the changes immediately -- no restart needed.

### Verifying a file is ignored

```powershell
git check-ignore -v .env
```

This shows which gitignore rule is causing the file to be ignored and which file the rule comes from:

```
~\.gitignore_global:2:.env    .env
```

---

## SSH Commit Signing -- Proving Authorship

Without signing, git commits are trivially forgeable. Anyone can set `user.name` and `user.email` to your identity and push commits that appear to be from you. SSH commit signing attaches a cryptographic signature to each commit, and GitHub verifies it against your uploaded public key.

### How it's configured

The setup script runs:

```
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
```

Every commit is signed automatically. You don't need to remember any flags.

### Setting up the GitHub "Verified" badge

For signed commits to show as "Verified" on GitHub:

1. Go to **GitHub > Settings > SSH and GPG keys**.
2. Click **New SSH key**.
3. Set **Key type** to **Signing Key** (not Authentication Key).
4. Paste the contents of `~/.ssh/id_ed25519.pub`:
   ```powershell
   bat ~/.ssh/id_ed25519.pub | clip
   ```
5. Save the key.

You need to upload the same key twice on GitHub: once as an Authentication Key (for pushing/pulling) and once as a Signing Key (for commit verification). They can be the same public key file.

> **If signed commits show as "Unverified" on GitHub:** your key is uploaded as Authentication but not as Signing. Fix: upload the same public key again with type "Signing Key" in GitHub Settings.

### Automated key upload via the setup script

If the GitHub CLI (`gh`) is installed and authenticated, the setup script uploads your SSH key automatically as both an Authentication Key and a Signing Key. If automated upload was skipped (e.g., `gh` wasn't authenticated), you can do it manually:

```powershell
gh auth login
gh ssh-key add ~/.ssh/id_ed25519.pub --title "my-machine" --type authentication
gh ssh-key add ~/.ssh/id_ed25519.pub --title "my-machine (signing)" --type signing
```

Verify both keys are uploaded:

```powershell
gh ssh-key list
```

### Verifying signatures locally

Check whether recent commits are signed:

```powershell
git log --show-signature -5
```

Verify a specific commit:

```powershell
git verify-commit abc1234
```

### Why signing matters

- **Supply chain security**: In a team or open-source project, signed commits let you verify that code actually came from who it claims to come from.
- **Compliance**: Some organisations require signed commits as part of their security policy.
- **GitHub protection**: Repository rules can require signed commits, blocking unsigned pushes.

---

## Bandit -- Python Security Scanning

Bandit scans Python source code for common security issues. It's not a replacement for a security review, but it catches the low-hanging fruit: hardcoded passwords, insecure use of `subprocess`, SQL injection patterns, insecure hash functions, and more.

### Scanning a file

```powershell
bandit src/main.py
```

### Scanning an entire project

```powershell
bandit -r src/
```

The `-r` flag means recursive. Without it, bandit only scans the files you explicitly list.

### Filtering by severity

Show only high-severity issues:

```powershell
bandit -r src/ -ll
```

Show only high-severity and high-confidence issues:

```powershell
bandit -r src/ -ll -ii
```

### Common issues bandit catches

| Code | What it flags |
|------|--------------|
| B105 | Hardcoded password strings (`password = "secret123"`) |
| B106 | Hardcoded password as a function argument |
| B108 | Hardcoded temporary directory (`/tmp`) |
| B301 | Use of `pickle` (can execute arbitrary code on deserialisation) |
| B303 | Use of insecure hash functions (MD5, SHA1) for security purposes |
| B602 | Use of `subprocess` with `shell=True` |
| B608 | SQL injection via string formatting |

### Excluding directories

Your `pyproject.toml` template excludes the test directory:

```toml
[tool.bandit]
exclude_dirs = ["tests"]
```

Test code often contains intentional security anti-patterns (hardcoded test credentials, mock data). Excluding `tests/` reduces false positives.

### Suppressing false positives

If bandit flags something that's intentional, suppress it inline:

```python
password_hash = hashlib.md5(data).hexdigest()  # nosec B303 -- not used for security
```

The `# nosec` comment tells bandit to skip that line. Always include the rule code and a justification.

### Generating reports

```powershell
bandit -r src/ -f json -o bandit-report.json   # JSON report
bandit -r src/ -f html -o bandit-report.html   # HTML report
```

---

## Pre-commit Security Hooks

The bundled pre-commit configuration includes two security-focused hooks that run automatically on every commit.

### `detect-private-key`

This hook scans staged files for patterns that look like private keys (RSA, DSA, EC, PGP private key headers). If you accidentally stage a file containing a private key, the commit is blocked.

What it catches:

```
-----BEGIN RSA PRIVATE KEY-----
-----BEGIN DSA PRIVATE KEY-----
-----BEGIN EC PRIVATE KEY-----
-----BEGIN OPENSSH PRIVATE KEY-----
-----BEGIN PGP PRIVATE KEY BLOCK-----
```

This is a last-resort safety net. The global .gitignore should prevent key files from being staged in the first place, but `detect-private-key` catches cases where a key is embedded inside another file (e.g., pasted into a config file or a script).

### `bandit` hook

The bandit pre-commit hook runs the same security scan described above, but only on files being committed. It uses the `pyproject.toml` configuration (`-c pyproject.toml`), so it respects your `exclude_dirs` and other settings.

If bandit finds issues, the commit is blocked and you see the full bandit output with issue codes, severity, confidence, and the offending lines.

---

## .env File Conventions

Environment variables and secrets should never be hardcoded in your source code. The standard convention is to use `.env` files for local development and environment variables in production.

### The pattern

- **`.env`**: Contains actual secrets. Never committed. Ignored by the global .gitignore.
- **`.env.example`**: Contains the same variable names with placeholder values. Committed to git as documentation of what variables the project needs.

Example `.env`:

```ini
DATABASE_URL=postgresql://user:actualpassword@localhost:5432/mydb
SECRET_KEY=a9f2k3j4h5g6f7d8s9a0
API_KEY=sk-live-abc123def456
```

Example `.env.example`:

```ini
DATABASE_URL=postgresql://user:password@localhost:5432/mydb
SECRET_KEY=generate-a-random-string
API_KEY=your-api-key-here
```

### Creating the .env.example

When you add a new secret to `.env`, immediately add a placeholder entry to `.env.example`:

```powershell
# After adding STRIPE_KEY to .env:
echo 'STRIPE_KEY=your-stripe-key-here' >> .env.example
ga .env.example
gc "Add STRIPE_KEY to env example"
```

### Why `.env.example` is allowed in git

The global .gitignore has this rule:

```gitignore
.env
.env.*
!.env.example
```

The `!` prefix means "do not ignore this file." So `.env`, `.env.local`, `.env.production` are all ignored, but `.env.example` is explicitly allowed through.

### Loading .env files in Python

Use the `python-dotenv` package:

```python
from dotenv import load_dotenv
import os

load_dotenv()  # Reads .env file into environment variables
database_url = os.environ["DATABASE_URL"]
```

Install it in your project:

```powershell
pip install python-dotenv
```

### Loading .env files in PowerShell

For local development scripts:

```powershell
Get-Content .env | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process")
    }
}
```

---

## Best Practices for Handling Secrets on Windows

### Use Windows Credential Manager for persistent secrets

For secrets that multiple projects share (database passwords, API keys for external services), store them in Windows Credential Manager rather than dotfiles:

```powershell
# Store a credential
cmdkey /add:MyService /user:apikey /pass:sk-live-abc123

# Retrieve in a script
$cred = cmdkey /list:MyService
```

For more complex needs, use the `Microsoft.PowerShell.SecretManagement` module:

```powershell
Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser
Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser

# Register a vault
Register-SecretVault -Name LocalVault -ModuleName Microsoft.PowerShell.SecretStore

# Store a secret
Set-Secret -Name "DatabasePassword" -Secret "actual-password"

# Retrieve it
$password = Get-Secret -Name "DatabasePassword" -AsPlainText
```

### Never hardcode secrets in scripts

Instead of:

```python
# BAD -- bandit will catch this
API_KEY = "sk-live-abc123def456"
```

Do:

```python
# GOOD -- reads from environment
import os
API_KEY = os.environ["API_KEY"]
```

### Keep SSH keys protected

Your setup deploys SSH keys with owner-only permissions. Verify this:

```powershell
icacls $env:USERPROFILE\.ssh\id_ed25519
```

The output should show only your user account with `(F)` (Full Control). If other users have access, the setup script's ACL configuration may need to be re-run.

### Audit what git is tracking

Periodically check that no secrets have slipped through:

```powershell
# Search tracked files for common secret patterns
git grep -i "password\s*=" -- "*.py" "*.json" "*.yaml" "*.toml"
git grep -i "secret_key\s*=" -- "*.py" "*.json" "*.yaml" "*.toml"
git grep "sk-live-\|sk-test-\|AKIA" -- "*.py" "*.json" "*.yaml" "*.toml"
```

If you find a committed secret, removing it from the current commit isn't enough -- it's still in git history. You need to rewrite history with `git filter-repo` or rotate the credential (preferred).

### Rotate, don't scrub

If a secret is committed to git, assume it's compromised. Rotate the credential (generate a new API key, change the password) rather than trying to remove it from git history. History rewriting is complex and error-prone; rotation is immediate and certain.

---

## Real-World Workflows

### Setting up a new project with all security layers

```powershell
mkdir my-api && cd my-api
git init

# Configure pre-commit
Copy-Item $WINSETUP\templates\pre-commit-config.yaml .\.pre-commit-config.yaml
pre-commit install

# Create .env files
@"
DATABASE_URL=postgresql://user:devpassword@localhost:5432/myapi
SECRET_KEY=$(python -c "import secrets; print(secrets.token_hex(32))")
"@ | Set-Content .env

@"
DATABASE_URL=postgresql://user:password@localhost:5432/myapi
SECRET_KEY=generate-with-python-secrets-module
"@ | Set-Content .env.example

# Verify .env is ignored
git check-ignore .env              # Should print ".env"

# Initial commit
ga .pre-commit-config.yaml .env.example
gc "Initial setup with pre-commit and env template"
```

### Responding to a "secret leaked" alert

GitHub and other services detect committed secrets and send alerts. When you receive one:

```powershell
# 1. Rotate the credential immediately
# (Generate a new API key in the service's dashboard)

# 2. Update your .env with the new credential
code .env

# 3. Verify the old credential is in git history
git log --all -p -S "sk-live-old-key" -- "*.py" "*.env"

# 4. If it's in a recent, unpushed commit, you can amend
# If it's in pushed history, rotation is the fix -- don't bother rewriting
```

### Auditing a project before open-sourcing

Before making a private repo public, run a thorough check:

```powershell
# Check for secrets in tracked files
git grep -i "password\|secret\|api.key\|token" -- "*.py" "*.json" "*.yaml" "*.toml" "*.cfg"

# Run bandit across the entire codebase
bandit -r src/ -ll

# Run all pre-commit hooks
pre-commit run --all-files

# Check for private keys
pre-commit run detect-private-key --all-files
```

### Weekly security maintenance

```powershell
# Update pre-commit hooks to get latest security patches
pre-commit autoupdate
pre-commit run --all-files

# Update bandit to catch newly-added rules
pipx upgrade bandit

# Run a full scan
bandit -r src/ -f json -o bandit-report.json
```

---

## Tips and Gotchas

- **Global .gitignore is per-machine, not per-repo**: It only protects you on machines where the setup script has run. Team members need their own global .gitignore, or (better) the project `.gitignore` should include the same secret patterns.
- **`.env` files with dots**: The global gitignore pattern `.env.*` catches `.env.local`, `.env.production`, `.env.staging`, etc. If you need to commit one of these (e.g., `.env.test` with non-secret test values), add `!.env.test` to the project `.gitignore`.
- **Pre-commit and large repos**: The first `pre-commit run --all-files` on a large project can be slow because mypy and bandit need to analyse every file. Subsequent commits are fast because hooks only check staged files.
- **Bandit and tests**: The template excludes `tests/` from bandit scans. If you want to scan test code too, remove the `exclude_dirs` setting from `pyproject.toml`. Expect more false positives from test fixtures and mock data.
- **SSH agent and signing**: If the SSH agent isn't running, `git commit` will fail because it can't access the signing key. Your profile auto-starts the agent, but in edge cases (e.g., running scripts as a different user), you may need to start it manually: `Start-Service ssh-agent; ssh-add ~/.ssh/id_ed25519`.
- **Windows Defender and .env files**: Windows Defender sometimes flags `.env` files as suspicious. This is a false positive. You can add an exclusion for your project directories if the scans are slow.
- **Git filter-repo for history rewriting**: If you must remove a secret from git history (e.g., before open-sourcing), use `git filter-repo` (install via `pip install git-filter-repo`). It's the modern replacement for `git filter-branch` and BFG Cleaner. But always rotate the credential first -- history rewriting is a supplement, not a substitute.
- **Signing key passphrase**: If your SSH key has a passphrase, the SSH agent caches it after the first use in each terminal session. If commits hang or prompt for a passphrase, make sure `ssh-add` has loaded your key: `ssh-add -l`.

---

## See Also

- [Git Advanced](07-git-advanced.md) -- delta, lazygit, and commit signing workflows
- [Project Setup](09-project-setup.md) -- pre-commit hooks for automated security scanning
- [Python Environment](05-python-environment.md) -- bandit and other code quality tools