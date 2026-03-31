# Delta Cheatsheet

Syntax-highlighting pager for git diffs. Configured automatically as git's pager.

## Usage

| Command | What it does |
|---|---|
| `git diff` | Side-by-side diff with syntax highlighting |
| `git diff --staged` | Staged changes with delta |
| `git log -p` | Commit history with delta diffs |
| `git show <hash>` | Single commit diff with delta |
| `n` / `N` | Navigate to next/previous file (in delta output) |
| `q` | Quit pager |

## Configuration (set by setup script)

| Setting | Value |
|---|---|
| `core.pager` | `delta` |
| `delta.side-by-side` | `true` |
| `delta.navigate` | `true` |
| `delta.light` | `false` |
| `merge.conflictstyle` | `diff3` |
| `diff.colorMoved` | `default` |

## Profile Variable

`$env:DELTA_FEATURES = "side-by-side line-numbers"`

## Tips

- All git diff commands use delta automatically. Press `n`/`N` to jump between files.
- delta also works with `diff` command outside git: `delta file1.py file2.py`.
- For plain diffs (e.g., piping to another tool): `git -c core.pager=cat diff`.

---

## See Also

- [Git](cheatsheet-git.md) -- everyday git commands and aliases
- [Lazygit](cheatsheet-lazygit.md) -- terminal git UI
