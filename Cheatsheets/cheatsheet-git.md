# Git Cheatsheet

Version control. Profile aliases for common operations.

## Profile Aliases

| Alias | Expands to |
|---|---|
| `gs` | `git status` |
| `ga <files>` | `git add <files>` |
| `gc "message"` | `git commit -m "message"` |
| `gp` | `git push` |
| `gl` | `git log --oneline --graph --decorate` |
| `lg` | Launch lazygit (terminal git UI) |

## Everyday Commands

| Command | What it does |
|---|---|
| `git init` | Create a new repo in current directory |
| `git clone git@github.com:user/repo.git` | Clone a repo via SSH |
| `gs` | Show staged, unstaged, and untracked files |
| `ga <file>` | Stage a file |
| `ga .` | Stage everything |
| `gc "message"` | Commit staged changes |
| `gp` | Push to remote |
| `git pull` | Fetch and merge remote changes |
| `gl` | Compact graphical log |

## Branching

| Command | What it does |
|---|---|
| `git checkout -b <name>` | Create and switch to new branch |
| `git checkout <name>` | Switch to existing branch |
| `git branch` | List local branches |
| `git branch -d <name>` | Delete a merged branch |
| `git push -u origin <name>` | Push new branch and set upstream |
| `git merge <branch>` | Merge branch into current |

## Undoing Things

| Command | What it does |
|---|---|
| `git restore --staged <file>` | Unstage a file (keep changes) |
| `git restore <file>` | Discard unstaged changes (destructive) |
| `git commit --amend -m "new msg"` | Fix the last commit message |
| `git stash` | Temporarily save uncommitted changes |
| `git stash pop` | Restore stashed changes |
| `git reset HEAD~1` | Undo last commit (keep changes) |

## Inspecting

| Command | What it does |
|---|---|
| `git diff` | Show unstaged changes |
| `git diff --staged` | Show staged changes |
| `git diff main..feature` | Compare two branches |
| `git log --oneline -10` | Last 10 commits (compact) |
| `git blame <file>` | Who changed each line |
| `git show <hash>` | View a specific commit |

## GitHub CLI (gh)

| Command | What it does |
|---|---|
| `gh repo clone user/repo` | Clone a repo |
| `gh pr create --title "..."` | Create a pull request |
| `gh pr list` | List open PRs |
| `gh pr checkout <num>` | Check out a PR locally |
| `gh issue list` | List open issues |
| `gh repo view --web` | Open repo in browser |

## Delta and Lazygit

| Command | What it does |
|---|---|
| `lg` | Launch lazygit (terminal git UI) |
| `git diff` | Side-by-side diff via delta (automatic) |
| `git log -p` | Commit diffs via delta |
| `n` / `N` | Navigate files in delta output |

## Commit Signing

| Command | What it does |
|---|---|
| `git log --show-signature -5` | Verify last 5 commit signatures |
| `git verify-commit <hash>` | Verify a specific commit |
| `git tag -s <tag> -m "msg"` | Create a signed tag |

## Tips

- `gc` overrides PowerShell's `Get-Content` alias. Use `Get-Content` or `bat` to read files.
- First push on a new branch needs `git push -u origin <name>`. After that, `gp` works.
- Use `git branch | fzf | ForEach-Object { git checkout $_.Trim() }` to fuzzy-switch branches.
- SSH agent auto-loads your key on terminal start. If auth fails, check `ssh-add -l`.

---

## See Also

- [Lazygit](cheatsheet-lazygit.md) -- terminal git UI keybindings
- [Delta](cheatsheet-delta.md) -- diff viewer configuration and navigation
- [Security](cheatsheet-security.md) -- commit signing, secrets scanning, global gitignore
