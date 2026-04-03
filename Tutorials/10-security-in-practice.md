# Tutorial 10: Security in Practice

## What you will learn

- Verifying the global .gitignore is protecting your secrets
- Setting up `.env` and `.env.example` conventions in a project
- Running a full bandit security scan and interpreting the output
- Auditing tracked files for secret patterns with ripgrep
- Verifying commit signatures locally and on GitHub
- Responding to a "secret leaked" scenario

## Prerequisites

- Completed Tutorials 1-9
- A project directory from Tutorial 9 (or any git repo with pre-commit configured)

---

## Step 1: Verify the global .gitignore

The setup script created `~\.gitignore_global` and configured git to use it. Every repo on your machine benefits from these rules -- they block `.env` files, private keys, and other secrets from being committed.

Test it:

```powershell
cd ~\Projects\tutorial-project    # Or any git repo

# Create a fake .env file
"API_KEY=sk-fake-12345" | Set-Content .env

# Check if git sees it
gs
```

The `.env` file should NOT appear in `git status`. It's being ignored globally. Verify why:

```powershell
git check-ignore -v .env
```

You'll see output like:

```
~\.gitignore_global:2:.env    .env
```

This confirms the rule, the file it comes from, and which pattern matched. Clean up:

```powershell
Remove-Item .env
```

## Step 2: Set up .env and .env.example

The convention is: `.env` holds real secrets (gitignored), `.env.example` holds placeholder values (committed). This way new developers know which environment variables the project needs without seeing the actual values.

Create both:

```powershell
# The real secrets file (gitignored)
@"
DATABASE_URL=postgresql://user:password@localhost:5432/mydb
API_KEY=sk-live-your-real-key-here
SECRET_KEY=your-django-secret
"@ | Set-Content .env

# The template file (committed)
@"
DATABASE_URL=postgresql://user:password@localhost:5432/mydb
API_KEY=sk-live-REPLACE-ME
SECRET_KEY=REPLACE-ME
"@ | Set-Content .env.example
```

Check that git handles them correctly:

```powershell
gs
# .env.example should appear as untracked
# .env should NOT appear (globally ignored)
```

Stage and commit the template:

```powershell
ga .env.example
gc "Add .env.example template"
```

## Step 3: Run a bandit security scan

Bandit scans Python code for common security issues. If your Tutorial 9 project has `main.py`, scan it:

```powershell
bandit main.py
```

For a broader scan:

```powershell
bandit -r . -ll
```

The `-ll` flag shows only medium and high severity issues. Typical findings include:

- **B105**: Hardcoded passwords (e.g., `password = "admin123"`)
- **B108**: Insecure temporary file creation
- **B301**: Use of `pickle` (potential code execution)
- **B602**: Subprocess with `shell=True`

Each finding includes the filename, line number, severity, and a brief explanation. Not every finding is a real bug -- bandit flags patterns that *could* be insecure. Use your judgment.

To generate a JSON report for tracking:

```powershell
bandit -r . -f json -o bandit-report.json
bat bandit-report.json
```

## Step 4: Audit for secret patterns with ripgrep

Even with `.gitignore`, it's worth scanning what's actually tracked:

```powershell
# Search tracked files for common secret patterns
git grep -i "password\|secret\|api.key\|token" -- "*.py" "*.json" "*.yaml" "*.toml"
```

For a broader search including ignored and hidden files:

```powershell
rg --hidden --no-ignore "API_KEY\|SECRET\|PASSWORD\|PRIVATE.KEY"
```

The `--hidden --no-ignore` flags override the defaults so nothing is skipped. Review every match -- some will be legitimate (config field names, documentation), others may be real secrets.

## Step 5: Verify SSH keys are uploaded to GitHub

The setup script uploads your SSH key as both an Authentication Key and a Signing Key automatically if `gh` is authenticated. Verify both are present:

```powershell
gh ssh-key list
```

You should see two entries for your machine -- one for authentication and one for signing. If either is missing, upload manually:

```powershell
gh ssh-key add ~/.ssh/id_ed25519.pub --type authentication --title "my-machine"
gh ssh-key add ~/.ssh/id_ed25519.pub --type signing --title "my-machine (signing)"
```

## Step 6: Verify commit signatures

Your setup configures SSH commit signing automatically. Verify it's working:

```powershell
git log --show-signature -3
```

You should see output like:

```
Good "git" signature for your-email@example.com
```

If you see "No signature" on a commit, it was made before signing was configured (or on a machine without it). That's normal for older commits.

To verify a specific commit:

```powershell
git verify-commit HEAD
```

On GitHub, signed commits show a "Verified" badge. Navigate to your repo's commit history and look for the green badge next to each commit message.

## Step 7: Respond to a leaked secret

Scenario: you accidentally committed a real API key. Here's the response workflow:

**1. Rotate the credential immediately.** Go to the service dashboard and generate a new key. The old key is compromised regardless of what you do in git.

**2. Update your .env with the new credential:**

```powershell
code .env
```

**3. Check how far the secret spread:**

```powershell
# Is it in recent, unpushed commits?
git log origin/main..HEAD -p -S "sk-live-old-key"
```

If the secret is only in unpushed commits, you can amend or rebase to remove it. If it's already pushed, rotation is the fix -- don't waste time rewriting public history.

**4. Add the pattern to your project .gitignore if it isn't already covered:**

```powershell
bat .gitignore
# Verify .env is listed
```

---

## Exercise

1. In your Tutorial 9 project, create a `.env` file with a fake secret: `"FAKE_KEY=sk-test-12345" | Set-Content .env`
2. Run `gs` and verify `.env` does NOT appear (global .gitignore blocks it)
3. Run `git check-ignore -v .env` to confirm which rule is catching it
4. Create a Python file that contains a hardcoded password: `"password = 'admin123'" | Set-Content bad_code.py`
5. Run `bandit bad_code.py` and see the B105 finding
6. Stage and try to commit: `ga bad_code.py && gc "Test commit"` -- the pre-commit `detect-private-key` hook won't catch this (it looks for key files, not passwords), but `bandit` hook will flag it
7. Force-add the `.env` file: `git add -f .env` then try to commit -- the `detect-private-key` hook should catch the fake key pattern
8. Unstage everything: `git restore --staged .env bad_code.py`
9. Verify your last real commit is signed: `git log --show-signature -1`
10. Clean up: `Remove-Item .env, bad_code.py`

---

## What comes next

You've completed all ten tutorials. You can now:

- **Navigate** with zoxide, fd, and fzf (Tutorials 1-2)
- **Search** with ripgrep and interactive filtering (Tutorial 3)
- **Work fast** with PSReadLine, history search, and fuzzy completion (Tutorial 4)
- **Write quality Python** with venvs, linters, and formatters (Tutorial 5)
- **Bridge terminal and editor** with VS Code CLI integration (Tutorial 6)
- **Manage Python versions** with pyenv-win (Tutorial 7)
- **Use git professionally** with lazygit, delta, and signed commits (Tutorial 8)
- **Scaffold projects** with templates and pre-commit hooks (Tutorial 9)
- **Maintain security hygiene** with global .gitignore, bandit, and signing verification (Tutorial 10)

The [HowTo-Guides](../HowTo-Guides/) cover each tool in more depth. The [Cheatsheets](../Cheatsheets/) give you quick-reference tables. And every tool has `--help` when you need specifics.
