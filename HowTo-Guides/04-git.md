# Git -- Version Control and Profile Aliases

Git is the version control system behind GitHub, GitLab, and most modern software development. Your setup includes Git itself (ships with Windows or via Chocolatey), a set of PowerShell aliases for common operations, SSH key deployment for GitHub authentication, and GitLens in VS Code for visual blame and history.

## Git Identity

Before you can commit, git needs to know who you are. The setup script checks for this and prints the commands if they're missing. Set them once:

```powershell
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

These are separate from SSH authentication (which proves you can push to GitHub) and commit signing (which proves you authored a commit). All three are configured by the setup script, but identity must be set manually since only you know your name and email.

## Setup

- **SSH keys**: Deployed from `.ssh.zip` by the setup script. Your profile auto-starts `ssh-agent` and loads `id_ed25519` on every terminal session.
- **Aliases**: Defined in your PowerShell profile:

```powershell
function gs { git status }
function ga { git add $args }
function gc { git commit -m $args }
function gp { git push }
function gl { git log --oneline --graph --decorate }
Set-Alias lg lazygit
```

- **GitLens**: Installed as a VS Code extension, providing inline blame annotations and history exploration.

## Profile Aliases

### `gs` -- Quick status check

```powershell
gs
```

Equivalent to `git status`. Shows staged, unstaged, and untracked files. Run this constantly -- before committing, after switching branches, whenever you're unsure of your working tree state.

### `ga` -- Stage files

```powershell
ga src/main.py                  # Stage a single file
ga src/main.py src/utils.py     # Stage multiple files
ga .                            # Stage everything in current directory
```

Equivalent to `git add`. Moves files from "unstaged" to "staged" so they'll be included in your next commit.

### `gc` -- Commit with a message

```powershell
gc "Add user authentication endpoint"
```

Equivalent to `git commit -m`. Creates a commit with all currently staged changes.

### `gp` -- Push to remote

```powershell
gp
```

Equivalent to `git push`. Pushes your local commits to the remote (usually GitHub).

### `gl` -- Visual log

```powershell
gl
```

Equivalent to `git log --oneline --graph --decorate`. Shows commit history as a compact ASCII graph with branch names and tags. Much easier to read than the default `git log`.

## Core Git Usage

### Creating a new repository

```powershell
mkdir my-project
cd my-project
git init
```

### Cloning an existing repository

```powershell
git clone git@github.com:<your-github-username>/winSetup.git
cd winSetup
```

Uses SSH (not HTTPS) because your setup deploys SSH keys and configures the agent.

### The basic workflow

The daily git cycle is: check status, stage changes, commit, push.

```powershell
gs                              # See what's changed
ga src/feature.py tests/        # Stage the files you want to commit
gs                              # Confirm what's staged
gc "Implement search feature"   # Commit
gp                              # Push to GitHub
```

### Creating and switching branches

```powershell
git checkout -b feature/search      # Create and switch to new branch
# ... do work ...
gc "Add search functionality"
gp                                  # First push will prompt to set upstream
git push -u origin feature/search   # Set upstream explicitly
```

After the first push with `-u`, subsequent `gp` calls work without specifying the remote.

### Switching between branches

```powershell
git checkout main
git checkout feature/search
```

With fzf, you can fuzzy-select branches:

```powershell
git branch | fzf | ForEach-Object { git checkout $_.Trim() }
```

### Pulling changes

```powershell
git pull
```

Fetches and merges remote changes into your current branch. Do this before starting new work.

### Viewing what changed

```powershell
git diff                    # Unstaged changes
git diff --staged           # Staged changes (what will be committed)
git diff main..feature      # Difference between two branches
```

### Undoing things

Unstage a file (keep the changes, just remove from staging):

```powershell
git restore --staged src/main.py
```

Discard all unstaged changes in a file (destructive -- resets to last commit):

```powershell
git restore src/main.py
```

Amend the last commit message:

```powershell
git commit --amend -m "Better commit message"
```

### Stashing work

Save your current changes temporarily without committing:

```powershell
git stash
git checkout main           # Do something on main
git checkout feature
git stash pop               # Restore your changes
```

### Viewing file history

```powershell
git log --oneline src/main.py       # Commits that touched this file
git blame src/main.py               # Who changed each line and when
```

## Real-World Workflows

### Starting a new feature

```powershell
git checkout main
git pull                            # Get latest changes
git checkout -b feature/user-auth   # Branch from up-to-date main
# ... write code ...
ga .
gc "Add user authentication"
gp
git push -u origin feature/user-auth
# Create PR on GitHub
```

### Reviewing what you've done today

```powershell
git log --oneline --since="8 hours ago"
```

Or with the alias for a graphical view:

```powershell
gl
```

### Resolving a merge conflict

```powershell
git checkout main
git pull
git checkout feature/my-branch
git merge main                      # Conflict!
# Open conflicted files in VS Code -- GitLens highlights conflicts
code .
# Fix conflicts, then:
ga .
gc "Resolve merge conflicts with main"
```

### Quick commit of a single file fix

```powershell
ga src/bugfix.py
gc "Fix null check in user validation"
gp
```

### Checking what a colleague changed

```powershell
git log --oneline --author="colleague" --since="1 week ago"
git show abc1234                    # View a specific commit
```

## GitHub CLI Integration

The setup script installs `gh` (GitHub CLI). Useful commands:

```powershell
gh repo clone owner/repo            # Clone a repo
gh pr create --title "Add feature"  # Create a pull request
gh pr list                          # List open PRs
gh pr checkout 42                   # Check out PR #42 locally
gh issue list                       # List open issues
gh repo view --web                  # Open the repo in your browser
```

## GitLens in VS Code

GitLens is installed as a VS Code extension and adds:

- **Inline blame**: See who last changed each line, with commit message and timestamp, as a faded annotation at the end of the line.
- **File history**: Right-click a file > "Open File History" to see every commit that touched it.
- **Line history**: Right-click a line > "Open Line History" for the history of that specific line.
- **Compare**: Click the GitLens icon in the sidebar to compare branches, commits, or files.

## Delta -- Better Diffs

Delta replaces the default git diff pager with syntax-highlighted, side-by-side diffs. The setup script configures it automatically -- every `git diff`, `git log -p`, and `git show` command renders through delta without extra flags. Press `n`/`N` to navigate between files in multi-file diffs.

For full documentation -- configuration, navigation keys, and temporary overrides -- see [Git Advanced](07-git-advanced.md).

---

## Lazygit -- Terminal Git UI

Lazygit is a terminal UI for git that makes complex operations visual and keyboard-driven. Launch it with the `lg` alias. It's especially useful for staging individual hunks, interactive rebasing, and resolving merge conflicts.

For a full walkthrough -- panel layout, keybindings, rebase workflow, and conflict resolution -- see [Git Advanced](07-git-advanced.md).

---

## Tips and Gotchas

- **SSH vs HTTPS**: Your setup uses SSH for GitHub. Clone URLs should start with `git@github.com:`, not `https://github.com/`. If you accidentally clone via HTTPS, switch with:
  ```powershell
  git remote set-url origin git@github.com:user/repo.git
  ```
- **`gc` conflicts with PowerShell**: PowerShell has a built-in alias `gc` for `Get-Content`. Your profile overrides this with the git commit function. If you need `Get-Content`, use the full cmdlet name. Since `cat` is aliased to `bat`, you'll rarely need `Get-Content` directly.
- **Line endings on Windows**: Git on Windows defaults to converting line endings (`core.autocrlf=true`). This means files are stored as LF in the repo but checked out as CRLF on your machine. You'll see `LF will be replaced by CRLF` warnings -- these are normal and harmless.
- **SSH agent auto-start**: Your profile starts `ssh-agent` and loads your key automatically. If you see "Permission denied (publickey)" errors, check that the agent is running with `ssh-add -l`. If it shows no identities, run `ssh-add ~/.ssh/id_ed25519` manually.
- **First push on a new branch**: The first `gp` on a new branch will fail because there's no upstream tracking branch. Use `git push -u origin branch-name` once, then `gp` works for subsequent pushes.
- **`gc` alias collision**: `gc` conflicts with PowerShell's built-in `Get-Content` alias. The profile removes the built-in alias explicitly so the git commit function works. If you ever see `gc` behaving as `Get-Content`, the alias removal line may be missing from your profile -- run `. $PROFILE` to reload.
- **`git add -p` with delta**: Interactive staging (`git add -p`) can behave strangely with delta configured as the pager. The `interactive.diffFilter = "delta --color-only"` setting in `.gitconfig` mitigates this. If you see issues, use lazygit's hunk staging instead, which doesn't go through the pager.

---

## See Also

- [Git Advanced](07-git-advanced.md) -- delta, lazygit, and commit signing in depth
- [Security Hygiene](10-security-hygiene.md) -- global .gitignore, SSH signing, secrets scanning