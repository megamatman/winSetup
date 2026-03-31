# Lazygit Cheatsheet

Terminal UI for git. Launch with `lg` alias.

## Navigation

| Key | What it does |
|---|---|
| `1`-`5` | Switch panels (status, files, branches, commits, stash) |
| `Tab` | Switch to next panel |
| `h`/`l` | Scroll left/right panels |
| `j`/`k` | Move up/down in current panel |
| `Enter` | Expand/view selected item |
| `q` | Quit lazygit |
| `?` | Show all keybindings |

## File Operations

| Key | What it does |
|---|---|
| `space` | Stage/unstage file |
| `a` | Stage/unstage all |
| `d` | Discard changes to file |
| `Enter` | Open file diff (stage individual hunks with `space`) |

## Commit Operations

| Key | What it does |
|---|---|
| `c` | Commit with message |
| `C` | Commit with multi-line message (opens editor) |
| `A` | Amend last commit |
| `e` | Edit a commit (during rebase) |

## Branch Operations

| Key | What it does |
|---|---|
| `n` | New branch |
| `space` | Checkout branch |
| `M` | Merge selected into current |
| `r` | Rebase current onto selected |

## Remote

| Key | What it does |
|---|---|
| `P` | Push |
| `p` | Pull |
| `f` | Fetch |

## Interactive Rebase

| Key | What it does |
|---|---|
| `e` (Commits panel) | Start interactive rebase from selected commit |
| `p` | Pick commit |
| `s` | Squash into previous |
| `r` | Reword commit message |
| `d` | Drop commit |
| `Ctrl+j` / `Ctrl+k` | Move commit up/down |
| `m` | Continue rebase |

## Conflict Resolution

| Key | What it does |
|---|---|
| `Enter` on conflicted file | Open resolution view |
| `space` | Pick ours/theirs |
| `m` | Continue merge/rebase after resolving |

## Stash Operations

| Key | What it does |
|---|---|
| `s` (Stash panel) | Stash current changes |
| `space` | Apply stash |
| `d` | Drop stash |

## Tips

- `lg` is defined as an alias in your profile. Use lazygit for complex operations; git aliases for quick one-liners.
- Press `?` in any panel to see all available keybindings for that context.
- Config lives at `%APPDATA%\lazygit\config.yml` if you want to customise.

---

## See Also

- [Git](cheatsheet-git.md) -- everyday git commands and profile aliases
- [Delta](cheatsheet-delta.md) -- diff viewer configured alongside lazygit
