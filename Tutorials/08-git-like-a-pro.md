# Tutorial 8: Git Like a Pro

## What you will learn

- Using lazygit for a real feature branch workflow
- Reviewing diffs with delta's side-by-side view and syntax highlighting
- Verifying that your commits are signed
- Interactive rebase to clean up commit history
- When to use lazygit vs git aliases

## Prerequisites

- Completed Tutorials 1-6
- Comfortable with git aliases (`gs`, `ga`, `gc`, `gp`, `gl`)
- A repo with at least a few commits to experiment with

---

## Step 1: See delta in action

delta replaces git's default diff output with something far more readable. Navigate to a repo with changes:

```powershell
z winsetup
```

Make a small change to any file (or just view existing diffs), then:

```powershell
git diff
```

Instead of the plain red/green diff you're used to, delta gives you:

- **Side-by-side view** -- old and new versions next to each other
- **Syntax highlighting** -- code is colored as your editor would color it
- **Line numbers** -- both old and new line numbers shown
- **Word-level highlighting** -- the specific characters that changed are emphasized

Your `.gitconfig` already configures delta as the default pager, so every `git diff`, `git show`, and `git log -p` uses it automatically.

## Step 2: Browse commit history with delta

```powershell
git log -p
```

This shows each commit with its full diff, rendered through delta. You can scroll through the output with the usual pager keys:

- `j`/`k` or arrow keys to scroll line by line
- `Space`/`b` to scroll page by page
- `/` to search within the output
- `q` to quit

For a more compact view:

```powershell
gl
```

This uses the `git log` alias with the graph format. When you need to inspect a specific commit's changes, `git show <hash>` renders through delta as well.

## Step 3: Launch lazygit

```powershell
lg
```

`lg` is defined as `Set-Alias lg lazygit` in your PowerShell profile. lazygit opens a full-screen terminal UI for git. It replaces the need to remember dozens of git commands with a visual, keyboard-driven interface.

## Step 4: Navigate the panels

lazygit has five main panels. Press the number keys to jump between them:

| Key | Panel | What it shows |
|-----|-------|---------------|
| `1` | Status | Current branch, repo name, recent activity |
| `2` | Files | Staged and unstaged changes (like `gs`) |
| `3` | Branches | Local and remote branches |
| `4` | Commits | Commit history for the current branch |
| `5` | Stash | Stashed changes |

Within each panel:

- `j`/`k` or arrow keys to move up and down
- `Enter` to expand or drill into an item
- `?` to see all keybindings for the current panel
- `h`/`l` to switch between sub-panels (e.g., staged vs unstaged files)

The right side of the screen shows a preview -- file diffs, commit details, or branch info depending on what's selected.

## Step 5: Stage, commit, and push

Here's the basic workflow in lazygit:

1. **Press `2`** to go to the Files panel
2. **Navigate to a changed file** with `j`/`k`
3. **Press `Space`** to stage it (or `a` to stage all files)
4. **Press `c`** to open the commit message editor
5. **Type your commit message** and press `Enter` to confirm
6. **Press `P`** (capital P) to push to the remote

> **If this fails:** "Updates were rejected because the remote contains work" -- a teammate pushed since you last pulled. Fix: `git pull --rebase` then push again.

That's the equivalent of `ga`, `gc`, `gp` -- but you can see exactly what you're staging and review the diff before committing.

### Partial staging

One of lazygit's best features: you can stage individual lines or hunks, not just whole files:

1. Select a file and press `Enter` to see its diff
2. Navigate to specific lines with `j`/`k`
3. Press `Space` to stage individual lines
4. Press `a` to stage an entire hunk
5. Press `Escape` to go back, then `c` to commit

This is much easier than `git add -p` in the terminal.

## Step 6: Verify commit signing

Your commits are signed automatically. To verify:

```powershell
git log --show-signature -1
```

For the full signing reference including GitHub key upload, see [10-security-hygiene.md](../HowTo-Guides/10-security-hygiene.md#ssh-commit-signing----proving-authorship).

## Step 7: Interactive rebase with lazygit

Interactive rebase lets you rewrite commit history: reorder, squash, edit messages, or drop commits. In lazygit, this is visual and safe.

1. **Press `4`** to go to the Commits panel
2. **Navigate to the oldest commit** you want to modify
3. **Press `e`** to start an interactive rebase from that commit

Now you can:

| Key | Action | Use when |
|-----|--------|----------|
| `s` | Squash into previous commit | Combining "WIP" commits into one clean commit |
| `r` | Reword commit message | Fixing a typo or making the message clearer |
| `d` | Drop commit | Removing an accidental commit |
| `Ctrl+j`/`Ctrl+k` | Move commit up/down | Reordering commits logically |

When you're done, the rebase applies automatically. If there are conflicts, lazygit shows them and lets you resolve them in the same interface.

**Important**: Only rebase commits that haven't been pushed to a shared branch. Rewriting public history causes problems for everyone on the team.

To check whether commits have been pushed, compare your local branch with the remote:

```powershell
git log origin/main..HEAD
```

This shows commits that exist locally but not on the remote. Only rebase commits that appear in this list.

## Step 8: When to use lazygit vs git aliases

Both are fast. Choose based on the situation:

### Use lazygit (`lg`) when:

- Staging specific lines or hunks from multiple files
- Doing interactive rebase (squash, reorder, reword)
- Resolving merge conflicts (visual diff makes it easier)
- Exploring commit history and file changes interactively
- You want to review everything before committing

### Use git aliases (`gs`, `ga`, `gc`, `gp`) when:

- Making a quick commit of all changed files
- Checking status or log with a glance
- Pushing or pulling as part of a scripted workflow
- You already know exactly what you want to do

In practice, most developers use aliases for routine commits and lazygit for anything involving judgment -- reviewing diffs, cleaning up history, resolving conflicts.

---

## Exercise

1. Navigate to a test repo (use winSetup or create a new one)
2. Create a new branch: `git checkout -b tutorial-test`
3. Open lazygit with `lg`
4. Make three separate changes to files, committing each one through lazygit (stage with `Space`, commit with `c`)
5. In the Commits panel (`4`), start an interactive rebase and squash all three into one commit
6. Exit lazygit and verify the signature: `git log --show-signature -1`
7. Push the branch: `gp` (or `P` inside lazygit)
8. If using GitHub, check for the "Verified" badge on the commit

---

## What comes next

You now have two complementary git workflows: aliases for speed and lazygit for precision. In Tutorial 9, you'll put everything together by scaffolding a brand-new project from scratch -- git init, venv, templates, pre-commit hooks, and a first signed commit.
