# Git Advanced -- Delta, Lazygit, and Commit Signing

This guide covers delta, lazygit, and SSH commit signing -- the three tools that extend the basic git workflow. For signing reference see [10-security-hygiene.md](10-security-hygiene.md).

## Setup

- **delta**: Installed via `choco install delta`. The setup script configures git to use delta as its pager (`core.pager = delta`) with side-by-side view, line numbers, and navigate mode. The environment variable `DELTA_FEATURES` is set in your profile.
- **lazygit**: Installed via `choco install lazygit`. Your profile defines `Set-Alias lg lazygit` so you can launch it with `lg`.
- **SSH signing**: Configured by the setup script using your existing `~/.ssh/id_ed25519.pub` key. Git is set to `gpg.format=ssh`, `commit.gpgsign=true`, and `user.signingkey` points to your public key.

---

## Delta -- Better Diffs

Delta replaces git's default diff pager. Instead of raw `+`/`-` lines with no colour, you get syntax-highlighted code, side-by-side comparison, line numbers, and file-level navigation. You don't call delta directly -- it hooks into every git command that shows diffs.

### How it works

The setup script runs these git config commands:

```
git config --global core.pager "delta"
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.light false
git config --global delta.side-by-side true
git config --global merge.conflictstyle "diff3"
git config --global diff.colorMoved "default"
```

Once configured, every `git diff`, `git log -p`, `git show`, and `git stash show -p` command automatically uses delta.

### Viewing unstaged changes

```powershell
git diff
```

Delta shows a two-column layout: the old version on the left, the new version on the right. Added lines are highlighted in green, removed lines in red, and changed words within a line are underlined.

### Viewing staged changes

```powershell
git diff --staged
```

Same side-by-side view, but only for files you've already staged with `ga`.

### Viewing a specific commit

```powershell
git show abc1234
```

Shows the commit message, metadata, and full diff of that commit, all formatted by delta.

### Browsing commit history with diffs

```powershell
git log -p
```

Walks through each commit in reverse chronological order, showing the full diff for each one. Delta highlights every diff.

### Comparing branches

```powershell
git diff main..feature/auth
```

Shows all differences between two branches in the side-by-side format.

### Navigating between files

When delta shows a diff with multiple files, press `n` to jump to the next file and `N` to jump to the previous file. This is enabled by `delta.navigate = true`. Press `q` to quit the pager.

> **If delta is not rendering:** your terminal does not support 24-bit colour. Fix: verify Windows Terminal colour scheme is set. As a fallback: `git -c core.pager=less diff`.

### Viewing moved code

The `diff.colorMoved = default` setting means git detects blocks of code that moved from one location to another and colours them differently from added/removed code. Delta renders this clearly.

---

## Lazygit -- Terminal Git UI

Lazygit is a terminal user interface for git. Instead of remembering flags and typing commands, you navigate panels with arrow keys and perform operations with single-key shortcuts. It's especially useful for interactive rebasing, resolving merge conflicts, and reviewing complex diffs.

### Launching lazygit

```powershell
lg
```

The `lg` alias is defined in your PowerShell profile. Run it from any git repository.

### Panel layout

Lazygit opens with five panels:

1. **Status** (top-left): Current branch, repo name, upstream status.
2. **Files** (left): Unstaged and staged changes. Similar to `git status`.
3. **Branches** (second column): Local and remote branches.
4. **Commits** (third column): Commit history for the current branch.
5. **Stash** (bottom): Stashed changes.

Use `Tab` or the number keys (`1`-`5`) to switch between panels. Use arrow keys or `j`/`k` to navigate within a panel.

### Staging and unstaging files

In the **Files** panel:

- **Space**: Toggle a file between staged and unstaged.
- **a**: Stage or unstage all files.
- **Enter**: Open the file diff to stage individual hunks or lines.

When you press Enter on a file, you see the diff. Press **Space** on a hunk to stage just that hunk, or navigate to individual lines and press **Space** to stage a single line. This replaces `git add -p`.

### Committing

With files staged:

- **c**: Open the commit message editor. Type your message, then press `Enter` to commit.
- **C**: Commit with the editor (for multi-line messages).
- **A**: Amend the last commit (adds staged changes to the previous commit).

### Pushing and pulling

- **P** (capital): Push to the remote.
- **p** (lowercase): Pull from the remote.
- **f**: Fetch from the remote without merging.

### Branch operations

In the **Branches** panel:

- **n**: Create a new branch from the current HEAD.
- **Space**: Check out the selected branch.
- **d**: Delete the selected branch.
- **M**: Merge the selected branch into the current branch.
- **r**: Rebase the current branch onto the selected branch.

### Interactive rebase

In the **Commits** panel, navigate to the commit you want to start from and press **e** to begin an interactive rebase. Then for each commit:

- **p**: Pick (keep the commit as-is).
- **s**: Squash into the previous commit.
- **r**: Reword the commit message.
- **d**: Drop (delete) the commit.
- **e**: Edit the commit (pause the rebase so you can modify it).
- **Ctrl+j** / **Ctrl+k**: Move a commit up or down in the history.

Press **m** to continue the rebase after making your selections. This replaces `git rebase -i` entirely, and you can see the commit diffs while deciding what to do.

### Resolving merge conflicts

When a merge or rebase encounters conflicts, lazygit shows the conflicted files in the Files panel with a conflict icon. Press **Enter** on a conflicted file to open the conflict resolution view:

- You see the conflicting sections highlighted.
- Use arrow keys to navigate between conflicts.
- Press **Space** to pick the version you want (ours, theirs, or both).
- After resolving all conflicts in a file, press **Space** in the Files panel to mark it as resolved.
- Press **m** to continue the merge or rebase.

### Other useful shortcuts

- **?**: Open the keybindings cheat sheet (context-sensitive to the current panel).
- **x**: Open the menu of all available actions for the current panel.
- **+** / **-**: Expand or collapse the diff view.
- **{** / **}**: Navigate between diff hunks.
- **Esc**: Go back or close a dialog.
- **q**: Quit lazygit.

---

## SSH Commit Signing

SSH commit signing is configured by the setup script. For the full reference including GitHub key upload and signature verification, see [10-security-hygiene.md -- SSH Commit Signing](10-security-hygiene.md#ssh-commit-signing----proving-authorship).

---

## Git Aliases in Context

Your profile defines five git aliases. Here's how they interact with delta, lazygit, and signing:

| Alias | Command                              | Delta? | Signed? |
|-------|--------------------------------------|--------|---------|
| `gs`  | `git status`                         | No     | N/A     |
| `ga`  | `git add`                            | No     | N/A     |
| `gc`  | `git commit -m`                      | No     | Yes     |
| `gp`  | `git push`                           | No     | N/A     |
| `gl`  | `git log --oneline --graph --decorate` | No (oneline has no diff) | N/A |

- `gc` automatically signs because `commit.gpgsign = true`.
- `gl` doesn't trigger delta because `--oneline` doesn't include diffs. Use `git log -p` to see delta-formatted diffs in the log.
- `git diff`, `git show`, and `git log -p` all automatically use delta.
- Lazygit (`lg`) uses its own diff rendering but respects your git config for signing.

---

## Real-World Workflows

### Reviewing a pull request locally

```powershell
gh pr checkout 42
git log -p main..HEAD              # Delta-formatted diffs for every commit
git diff main..HEAD                # Delta-formatted summary of all changes
```

### Interactive cleanup before pushing

```powershell
lg                                 # Open lazygit
# Navigate to Commits panel
# Press 'e' on the oldest commit to start interactive rebase
# Squash fixup commits, reword messages
# Push with 'P'
```

### Debugging a regression

```powershell
git log -p --follow src/auth.py    # See every change to this file, formatted by delta
git show abc1234                   # Inspect the suspicious commit
```

### Staging only part of a file

```powershell
lg                                 # Open lazygit
# In Files panel, press Enter on the file
# Navigate to the hunk you want
# Press Space to stage just that hunk
# Press c to commit only the staged changes
```

### Verifying a release

```powershell
git log --show-signature -5        # Check that the last 5 commits are signed
git tag -s v2.1.0 -m "Release 2.1.0"
gp
git push --tags
```

---

## Tips and Gotchas

- **Delta is a pager, not a command**: You never run `delta` directly for git operations. It hooks in via `core.pager`. If you want to use delta outside of git (e.g., diffing two arbitrary files), run `delta file1.py file2.py`.
- **Side-by-side needs terminal width**: Delta's side-by-side mode works best in a wide terminal. If your terminal is narrow, the columns get cramped. Resize your terminal or temporarily disable side-by-side with `git -c delta.side-by-side=false diff`.
- **Lazygit config file**: Lazygit stores its config at `%APPDATA%\lazygit\config.yml`. You can customise keybindings, colours, and behaviour there. The defaults work well out of the box.
- **Lazygit vs aliases**: Use aliases (`gs`, `gc`, `gp`) for quick, one-step operations. Use lazygit (`lg`) for anything involving multiple steps, visual review, interactive rebase, or conflict resolution. They complement each other.
- **SSH agent must be running for signing**: If the SSH agent isn't running, commits will fail because git can't access your signing key. Your profile auto-starts the agent, but if you see signing errors, check with `ssh-add -l`. If it shows no identities, run `ssh-add ~/.ssh/id_ed25519`.
- **Signing key vs authentication key on GitHub**: GitHub treats signing keys and authentication keys separately, even if they use the same public key. You need to upload `id_ed25519.pub` twice: once as an Authentication key and once as a Signing key.
- **Delta and less**: Delta uses `less` as its underlying pager. Standard less keybindings work: `/` to search, `n`/`N` to navigate search results, `q` to quit, `g` to go to the top, `G` to go to the bottom.
- **Disabling signing temporarily**: If you need to commit without signing (e.g., on a machine without your key), use `git commit --no-gpg-sign -m "message"`. This overrides the global config for that one commit.
- **`git add -p` with delta**: Interactive patch mode can conflict with delta as the pager. This is mitigated by the `interactive.diffFilter = "delta --color-only"` setting configured by the setup script. If interactive staging behaves unexpectedly, use lazygit's hunk staging as an alternative.

---

## See Also

- [Git](04-git.md) -- everyday git commands and profile aliases
- [Security Hygiene](10-security-hygiene.md) -- global .gitignore, SSH signing, secrets scanning