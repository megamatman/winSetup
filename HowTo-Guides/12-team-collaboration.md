# Team Collaboration -- PRs, Code Review, Conflicts, and Branch Management

Task reference for team git workflows: PRs, code review, conflicts, and branch management.

---

## How to Review a PR from the Terminal

List open PRs, check one out locally, run the project's linters and tests, then submit your review -- all without opening a browser.

```powershell
gh pr list                            # See what's open
gh pr checkout 42                     # Check out PR #42 locally
pre-commit run --all-files            # Run linters against the PR's code
python -m pytest                      # Run tests
git diff main..HEAD                   # Review the full diff (delta-formatted)
gh pr review 42 --approve --body "LGTM. Tests pass."
```

To request changes instead of approving:

```powershell
gh pr review 42 --request-changes --body "Off-by-one error in pagination -- see src/paginate.py line 31."
```

**Failure note:** If `gh pr checkout` fails with "could not determine base repo," you're not inside a cloned GitHub repo. Run `git remote -v` to verify the remote is set. See [cheatsheet-git.md](../Cheatsheets/cheatsheet-git.md) for remote configuration.

---

## How to Handle a Rejected Push

A push can be rejected because the remote has commits you don't have locally. This happens when a teammate pushed to the same branch, or when `main` has moved forward.

```powershell
git push
# ! [rejected] feature/xyz -> feature/xyz (non-fast-forward)

git pull --rebase                     # Replay your commits on top of the remote's
git push                              # Push again -- should succeed now
```

If the rebase encounters conflicts, resolve them (see "How to Resolve Conflicts in Lazygit" below), then continue:

```powershell
git rebase --continue
git push
```

**Failure note:** If you rebased a branch that was already pushed, `git push` will be rejected because the history diverged. Use `git push --force-with-lease` -- this is safe because it checks that no one else has pushed since your last fetch. Never use bare `--force` on a shared branch. See [cheatsheet-git.md](../Cheatsheets/cheatsheet-git.md) for push options.

---

## How to Rebase a Feature Branch on Updated Main

When `main` has moved forward and you want your feature branch to include those changes with a linear history:

```powershell
git checkout feature/my-feature
git fetch origin                      # Download latest remote state
git rebase origin/main                # Replay your commits on top of updated main
```

If there are no conflicts, the rebase completes and your branch is now based on the latest `main`. If you'd already pushed the branch:

```powershell
git push --force-with-lease           # Required because rebase rewrites commit hashes
```

To abort a rebase that's gone wrong:

```powershell
git rebase --abort                    # Returns your branch to its pre-rebase state
```

**Failure note:** If the rebase produces many conflicts across multiple commits, consider `git merge origin/main` instead -- it resolves all conflicts in one step rather than commit-by-commit. Neither approach is inherently better; follow your team's convention. See [cheatsheet-git.md](../Cheatsheets/cheatsheet-git.md) for rebase and merge options.

---

## How to Resolve Conflicts in Lazygit

Lazygit provides a visual conflict resolution workflow that replaces manual editing of conflict markers.

```powershell
# Start a merge or rebase that produces conflicts, then:
lg                                    # Open lazygit
```

1. In the **Files** panel, conflicted files show a conflict icon.
2. Press **Enter** on a conflicted file to open the resolution view.
3. Navigate between conflict blocks with arrow keys.
4. Press **Space** to pick a version: ours, theirs, or both.
5. Press **Escape** when all conflicts in the file are resolved.
6. Press **Space** in the Files panel to stage the resolved file.
7. Press **c** to commit the merge, or if rebasing, press **m** to continue the rebase.

To abort instead:

```powershell
git merge --abort     # If merging
git rebase --abort    # If rebasing
```

**Failure note:** If lazygit shows "this file has no inline merge conflicts" but git still reports the file as conflicted, the conflict may be a file-level conflict (e.g., deleted in one branch, modified in another). Use `gs` to see the conflict type, then resolve with `git add` (keep the file) or `git rm` (delete it). See [cheatsheet-lazygit.md](../Cheatsheets/cheatsheet-lazygit.md) for all lazygit shortcuts.

---

## How to Configure Branch Protection to Require Signed Commits

Branch protection rules are set on GitHub, not locally. This requires admin or maintainer access to the repository.

```powershell
# Open the repo settings in the browser
gh browse --settings
```

Then navigate to **Settings > Rules > Rulesets** (or **Branches** for classic protection rules):

1. Click **New ruleset** (or edit an existing branch protection rule for `main`).
2. Under **Require signed commits**, toggle it on.
3. Save the ruleset.

After this, any push to the protected branch with unsigned commits is rejected:

```
remote: error: GH009: Commit is not signed.
```

To verify your own commits are signed before pushing:

```powershell
git log --show-signature -5
```

Every commit should show `Good "git" signature for your-email@example.com`.

**Failure note:** If a teammate's commits are rejected, they need to configure SSH signing (see [10-security-hygiene.md](10-security-hygiene.md#ssh-commit-signing----proving-authorship)) and then re-sign their commits with `git rebase --exec "git commit --amend --no-edit -S" main`. See [cheatsheet-security.md](../Cheatsheets/cheatsheet-security.md) for signing commands.

---

## How to Diagnose a Teammate's Failed Pre-commit Run

When a PR has formatting errors, trailing whitespace, or type-check failures, the author likely hasn't installed pre-commit hooks locally.

**Confirm the diagnosis:**

```powershell
gh pr checkout 55
pre-commit run --all-files
```

If hooks fail on the PR's code, the author didn't run them.

**Common symptoms and their hooks:**

| Symptom | Missing hook |
|---------|-------------|
| Inconsistent formatting | `ruff-format` |
| Trailing whitespace | `trailing-whitespace` |
| Unsorted imports | `ruff` (isort rules) |
| Type errors in signatures | `mypy` |

**The fix -- ask the author to run:**

```powershell
pre-commit install                    # Install hooks for future commits
pre-commit run --all-files            # Fix existing issues
ga .
gc "Fix linting issues from pre-commit"
gp
```

**Preventing this in CI:** Add a GitHub Actions workflow that runs `pre-commit` on every PR so issues are caught even when local hooks are skipped:

```yaml
# .github/workflows/lint.yml
- uses: pre-commit/action@v3.0.1
```

**Failure note:** If `pre-commit run --all-files` itself fails to run (not just reports issues), the author may be missing tool dependencies (ruff, mypy, bandit). Check that the project's `requirements.txt` or `pyproject.toml` includes dev dependencies, and that the venv is activated. See [cheatsheet-pre-commit.md](../Cheatsheets/cheatsheet-pre-commit.md) for hook troubleshooting.

---

## See Also

- [Git](04-git.md) -- everyday git commands and profile aliases
- [Git Advanced](07-git-advanced.md) -- delta, lazygit, and commit signing workflows
- [Security Hygiene](10-security-hygiene.md) -- global .gitignore, SSH signing, secrets scanning
