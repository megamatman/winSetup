# Tutorial 11: Working in a Team

## What you will learn

- Cloning a shared repository and setting up your local environment to match the team
- Creating feature branches and pushing them for review
- Reviewing a teammate's pull request from the terminal
- Resolving merge conflicts visually in lazygit
- Keeping your feature branch current with `git pull --rebase`
- Diagnosing environment mismatches when a teammate's commits break the rules

## Prerequisites

- Completed Tutorials 1-10
- A GitHub account with SSH authentication and commit signing configured (Tutorial 10)
- The `gh` CLI authenticated (`gh auth status` shows "Logged in")

---

## Section 1: Joining an Existing Project

### Step 1: Clone the repository

When you join a project, the first thing you do is clone it. Use SSH (not HTTPS) so your existing SSH key handles authentication and signing:

```powershell
cd ~/Code
gh repo clone your-org/team-project
cd team-project
```

`gh repo clone` automatically uses the SSH URL when your `gh` is configured for SSH. You can also use the full URL:

```powershell
git clone git@github.com:your-org/team-project.git
```

Verify the remote:

```powershell
git remote -v
```

Expected output:

```
origin  git@github.com:your-org/team-project.git (fetch)
origin  git@github.com:your-org/team-project.git (push)
```

### Step 2: Set up the local environment

Most Python projects have three things to configure: the Python version, the virtual environment, and pre-commit hooks.

**Check the Python version:**

```powershell
bat .python-version
```

If the file exists, it specifies the version the team uses. Make sure you have it installed:

```powershell
pyenv versions
```

If it's missing, install it:

```powershell
pyenv install 3.12.4    # Whatever version .python-version specifies
```

pyenv-win reads `.python-version` automatically, so once installed, `python --version` will match.

**Create the virtual environment and install dependencies:**

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Some projects use `pyproject.toml` instead of `requirements.txt`:

```powershell
pip install -e ".[dev]"
```

**Install pre-commit hooks:**

```powershell
pre-commit install
```

This is easy to forget and causes problems later -- if you skip it, your commits won't be checked locally, and you'll only find out when CI fails or a reviewer flags issues.

**Verify everything works:**

```powershell
python --version          # Should match .python-version
pre-commit run --all-files  # All hooks should pass
gs                        # Should show a clean working tree
```

If `pre-commit run --all-files` fails on a freshly cloned repo, that's a problem the team needs to fix -- not something you should work around.

---

## Section 2: Feature Branch Workflow

### Step 3: Create a branch from up-to-date main

Never work directly on `main`. Always create a feature branch:

```powershell
git checkout main
git pull                  # Get the latest changes
git checkout -b feature/add-user-export
```

Branch naming convention varies by team, but `feature/`, `fix/`, and `chore/` prefixes are common. Ask your team if they have a standard.

Verify you're on the new branch:

```powershell
gs
```

Expected output:

```
On branch feature/add-user-export
nothing to commit, working tree clean
```

### Step 4: Make commits on your branch

Work normally -- edit files, stage, commit:

```powershell
# Edit files...
ga src/export.py
gc "Add CSV export for user data"

# More work...
ga src/export.py tests/test_export.py
gc "Add tests for user export"
```

Each commit is automatically signed (Tutorial 10 configured this). Keep commits focused -- one logical change per commit.

### Step 5: Push and open a pull request

Push your branch to the remote. The first push needs `-u` to set the upstream tracking branch:

```powershell
git push -u origin feature/add-user-export
```

After the first push, `gp` works for subsequent pushes.

Open a pull request with the GitHub CLI:

```powershell
gh pr create --title "Add CSV export for user data" --body "Adds an export endpoint and tests. Closes #42."
```

`gh pr create` opens against the default branch (usually `main`) automatically. You'll see output like:

```
Creating pull request for feature/add-user-export into main in your-org/team-project

https://github.com/your-org/team-project/pull/57
```

For a more interactive experience, omit the flags and `gh` will prompt you:

```powershell
gh pr create
```

You can also open the PR in the browser to add reviewers:

```powershell
gh pr view --web
```

---

## Section 3: Code Review from the Terminal

### Step 6: List and check out a teammate's PR

See what's open:

```powershell
gh pr list
```

Expected output:

```
Showing 3 of 3 open pull requests in your-org/team-project

#59  Fix pagination bug          fix/pagination     about 2 hours ago
#57  Add CSV export              feature/add-user-export  about 1 day ago
#55  Update dependencies         chore/deps         about 3 days ago
```

Check out a PR locally to review and test it:

```powershell
gh pr checkout 59
```

This creates a local branch tracking the PR and switches to it. Now you can run the code, run tests, and inspect the changes:

```powershell
python -m pytest                  # Run tests
pre-commit run --all-files        # Run linters
git log -p main..HEAD             # See all commits with diffs (delta-formatted)
git diff main..HEAD               # See the total diff against main
```

### Step 7: Submit your review

After inspecting the code, submit a review:

```powershell
# Approve
gh pr review 59 --approve --body "Looks good. Tests pass locally."

# Request changes
gh pr review 59 --request-changes --body "The pagination offset is off by one -- see line 42 in src/pagination.py."

# Comment without approving or rejecting
gh pr review 59 --comment --body "Nit: consider renaming 'data' to 'user_records' for clarity."
```

After reviewing, switch back to your own branch:

```powershell
git checkout feature/add-user-export
```

---

## Section 4: Resolving Conflicts

### Step 8: Handle merge conflicts

Conflicts happen when two branches change the same lines. You'll encounter them when merging or rebasing.

**What conflict output looks like:**

```powershell
git merge main
```

If there are conflicts, git tells you:

```
Auto-merging src/export.py
CONFLICT (content): Merge conflict in src/export.py
Automatic merge failed; fix conflicts and then commit the result.
```

The file now contains conflict markers:

```python
<<<<<<< HEAD
def export_users(format="csv"):
=======
def export_users(fmt="csv"):
>>>>>>> main
```

Everything between `<<<<<<< HEAD` and `=======` is your version. Everything between `=======` and `>>>>>>> main` is the incoming version.

**Resolve visually in lazygit:**

```powershell
lg
```

In the Files panel, conflicted files have a conflict icon. Press **Enter** on the conflicted file to open the conflict resolution view:

1. You see the conflicting sections highlighted with "ours" and "theirs" labels.
2. Use arrow keys to navigate between conflict blocks.
3. Press **Space** to pick the version you want. You can choose ours, theirs, or both (to keep both versions).
4. After resolving all conflicts in the file, press **Escape** to go back to the Files panel.
5. Press **Space** to stage the resolved file.
6. Press **c** to commit the merge.

If you started a merge and want to abort:

```powershell
git merge --abort
```

---

## Section 5: Keeping Your Branch Current

### Step 9: Rebase vs merge

When `main` has moved forward while you were working on your feature branch, you need to incorporate those changes. There are two approaches:

**`git merge main` (merge commit):**

```powershell
git checkout feature/add-user-export
git fetch origin
git merge origin/main
```

This creates a merge commit that ties the histories together. The branch history shows exactly when you merged. Some teams prefer this because it preserves the true timeline.

**`git pull --rebase` / `git rebase main` (linear history):**

```powershell
git checkout feature/add-user-export
git fetch origin
git rebase origin/main
```

This replays your commits on top of the latest `main`, producing a linear history with no merge commits. Many teams prefer this for feature branches because the PR diff stays clean.

After rebasing, your local branch has diverged from the remote (because the commits have new hashes). You need a force push:

```powershell
git push --force-with-lease
```

`--force-with-lease` is safer than `--force` -- it refuses to push if someone else has pushed to your branch since your last fetch.

**Which to use?** Follow your team's convention. If there's no convention, rebase for feature branches and merge for long-lived branches. The important thing is consistency.

**Keeping current with `git pull --rebase`:**

If you and a teammate are both pushing to the same branch (e.g., during pair programming), use:

```powershell
git pull --rebase
```

This fetches the remote changes and replays your local commits on top. It avoids the unnecessary merge commits that `git pull` (without `--rebase`) creates.

---

## Section 6: When a Teammate Hasn't Set Up Their Environment

### Step 10: Diagnose environment mismatches

You'll eventually see a PR where the commits aren't signed, the formatting is wrong, or linting errors are present. This usually means the author hasn't run the setup properly.

**Unsigned commits in a PR:**

On GitHub, unsigned commits show "Unverified" or no badge at all. From the terminal:

```powershell
gh pr checkout 61
git log --show-signature -5
```

If you see `No signature` instead of `Good "git" signature`, the author hasn't configured SSH signing.

**Branch protection requiring signatures:**

If the repository has branch protection rules requiring signed commits, an unsigned push to `main` is blocked entirely. GitHub shows:

```
remote: error: GH009: Commit is not signed.
```

The author needs to follow Tutorial 10 to configure signing, then either amend their commits to re-sign them or recreate the branch with signed commits:

```powershell
# The teammate runs this on their branch after configuring signing:
git rebase --exec "git commit --amend --no-edit -S" main
git push --force-with-lease
```

**The pre-commit contract:**

Pre-commit hooks only run if the developer installs them (`pre-commit install`). If someone skips this step, they can commit code that violates the project's standards.

Signs a teammate hasn't installed pre-commit:

- Formatting doesn't match (ruff-format would have fixed it)
- Trailing whitespace in diffs
- Type errors that mypy would have caught
- Import sorting is wrong

The fix: ask them to run:

```powershell
pre-commit install
pre-commit run --all-files
```

Then fix any issues the hooks flag and amend or add a fixup commit.

To prevent this entirely, some teams add CI checks that run the same pre-commit hooks. That way, even if a developer skips local hooks, the PR pipeline catches the problems:

```yaml
# .github/workflows/lint.yml
name: Lint
on: [pull_request]
jobs:
  pre-commit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
      - uses: pre-commit/action@v3.0.1
```

---

## Exercise

Practice the full team workflow using the winSetup repo itself:

1. Clone the winSetup repo (or use your existing local copy): `gh repo clone your-username/winSetup`
2. Run `pre-commit install` (if a `.pre-commit-config.yaml` exists)
3. Create a feature branch: `git checkout -b feature/my-test-change`
4. Create a new file: `"# Test" | Set-Content test-file.md`
5. Stage and commit: `ga test-file.md && gc "Add test file"`
6. Verify the commit is signed: `git log --show-signature -1`
7. Push and open a PR: `git push -u origin feature/my-test-change && gh pr create --title "Test PR" --body "Testing the team workflow."`
8. View your PR: `gh pr view --web`
9. Close the PR without merging: `gh pr close`
10. Clean up: `git checkout main && git branch -d feature/my-test-change`

---

## What comes next

You've completed all eleven tutorials. You can now:

- **Navigate** with zoxide, fd, and fzf (Tutorials 1-2)
- **Search** with ripgrep and interactive filtering (Tutorial 3)
- **Work fast** with PSReadLine, history search, and fuzzy completion (Tutorial 4)
- **Write quality Python** with venvs, linters, and formatters (Tutorial 5)
- **Bridge terminal and editor** with VS Code CLI integration (Tutorial 6)
- **Manage Python versions** with pyenv-win (Tutorial 7)
- **Use git professionally** with lazygit, delta, and signed commits (Tutorial 8)
- **Scaffold projects** with templates and pre-commit hooks (Tutorial 9)
- **Maintain security hygiene** with global .gitignore, bandit, and signing verification (Tutorial 10)
- **Collaborate with a team** using branches, PRs, code review, and conflict resolution (Tutorial 11)

The [HowTo-Guides](../HowTo-Guides/) cover each tool in more depth. The [Cheatsheets](../Cheatsheets/) give you quick-reference tables. And every tool has `--help` when you need specifics.
