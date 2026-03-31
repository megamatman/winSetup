# Navigation and Search Cheatsheet

fd (find files), zoxide (jump directories), ripgrep (search contents), bat (view files).

## fd -- Find Files

| Command | What it does |
|---|---|
| `fd <pattern>` | Find files/dirs matching pattern (recursive) |
| `fd --type f` | Files only |
| `fd --type d` | Directories only |
| `fd -e py` | Filter by extension |
| `fd -e ts -e tsx` | Multiple extensions |
| `fd --max-depth 1` | Current directory only (no recursion) |
| `fd --hidden --no-ignore` | Include hidden and gitignored files |
| `fd --size +10m` | Files larger than 10MB |
| `fd --changed-within 1d` | Modified in the last day |
| `fd <pattern> <dir>` | Search in a specific directory |
| `fd --exec <cmd>` | Run a command on each result |

## zoxide -- Jump Directories

| Command | What it does |
|---|---|
| `z <keyword>` | Jump to best-matching directory |
| `z <kw1> <kw2>` | Jump using multiple keywords |
| `zi <keyword>` | Interactive selection with fzf |
| `zoxide query --list` | Show all tracked directories |
| `zoxide add <path>` | Manually add a directory |
| `zoxide remove <path>` | Remove a directory from database |

## ripgrep (rg) -- Search File Contents

| Command | What it does |
|---|---|
| `rg "pattern"` | Search recursively for pattern |
| `rg -i "pattern"` | Case-insensitive search |
| `rg -w "word"` | Whole word match |
| `rg "pattern" --type py` | Search only Python files |
| `rg -l "pattern"` | List filenames only (no content) |
| `rg -c "pattern"` | Count matches per file |
| `rg -C 3 "pattern"` | Show 3 lines of context around matches |
| `rg -A 10 "pattern"` | Show 10 lines after each match |
| `rg -B 2 "pattern"` | Show 2 lines before each match |
| `rg --hidden --no-ignore` | Include hidden and gitignored files |
| `rg "pattern" -g "*.json"` | Filter by glob |
| `rg --type-list` | Show all known file types |

## bat -- View Files

| Command | What it does |
|---|---|
| `bat <file>` | View file with syntax highlighting |
| `bat --line-range 20:40 <file>` | View specific lines |
| `bat --plain <file>` | No line numbers or headers |
| `bat --diff <file>` | Highlight git changes |
| `bat --list-themes` | Show available colour themes |
| `bat --language log <file>` | Force a specific syntax |

## Combinations

| Command | What it does |
|---|---|
| `fd -e py \| fzf` | Fuzzy-select from Python files |
| `fd --type f \| fzf --preview "bat --color=always {}"` | File picker with preview |
| `rg -l "TODO" \| fzf --preview "bat --color=always {}"` | Search, then fuzzy-select results |
| `rg -l "pattern" \| ForEach-Object { code $_ }` | Open all matching files in VS Code |

## Tips

- All four tools respect `.gitignore` by default. Use `--no-ignore` to include everything.
- `fd` and `rg` skip hidden files by default. Use `--hidden` to include dotfiles.
- `cat` is aliased to `bat` in your profile. Use `Get-Content` for raw PowerShell behaviour.
- `z` learns from your `cd` usage. It gets smarter over time.

---

## See Also

- [fzf](cheatsheet-fzf.md) -- fuzzy finder flags, keybindings, and combinations
