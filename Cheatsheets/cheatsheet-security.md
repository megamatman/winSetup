# Security Cheatsheet

Global gitignore, commit signing, bandit scanning, secrets detection, and SSH agent.

## Global .gitignore

| Command | What it does |
|---|---|
| `git config --global core.excludesfile` | Show path to global gitignore |
| `git check-ignore -v <file>` | Check why a file is being ignored |
| `code ~\.gitignore_global` | Edit global gitignore |

## Commit Signing

| Command | What it does |
|---|---|
| `git log --show-signature -5` | Check last 5 commits for signatures |
| `git verify-commit <hash>` | Verify a specific commit |
| `git commit --no-gpg-sign -m "msg"` | Commit without signing (one-off override) |

## Bandit (Python Security Scanner)

| Command | What it does |
|---|---|
| `bandit <file>` | Scan a file |
| `bandit -r <dir>/` | Scan recursively |
| `bandit -r <dir>/ -ll` | High severity only |
| `bandit -r <dir>/ -f json -o report.json` | JSON report |

## Secrets Audit

| Command | What it does |
|---|---|
| `rg --hidden --no-ignore "API_KEY\|SECRET\|PASSWORD"` | Search all files for secret patterns |
| `git grep -i "password\|secret" -- "*.py" "*.json"` | Search tracked files only |
| `pre-commit run detect-private-key --all-files` | Run key detection hook manually |

## SSH Agent

| Command | What it does |
|---|---|
| `ssh-add -l` | List loaded keys |
| `ssh-add ~\.ssh\id_ed25519` | Load key manually |
| `ssh -T git@github.com` | Test GitHub SSH connection |

## Tips

- Global gitignore protects against accidental commits of `.env`, `*.key`, `*.pem`, and private keys.
- Commits are signed automatically via SSH (configured by the setup script). Look for the "Verified" badge on GitHub.
- Run `bandit -r src/ -ll` before merging to catch high-severity issues.
- Use `.env` for secrets, commit `.env.example` as a template with placeholder values.

---

## See Also

- [Git](cheatsheet-git.md) -- everyday git commands and commit signing
- [Pre-commit](cheatsheet-pre-commit.md) -- automated hooks including detect-private-key
- [Python](cheatsheet-python.md) -- bandit and other code quality tools
