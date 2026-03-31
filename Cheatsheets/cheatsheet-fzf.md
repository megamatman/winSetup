# fzf Cheatsheet

General-purpose fuzzy finder. Used standalone and via PSFzf keybindings.

## Profile Keybindings

| Key | What it does |
|---|---|
| `Ctrl+R` | Fuzzy search command history |
| `Ctrl+T` | Fuzzy find file, insert path |
| `Ctrl+F` | Find file with bat preview, insert path |
| `Tab` | Fuzzy tab completion |

## Environment Variables (set in profile)

| Variable | Value |
|---|---|
| `FZF_DEFAULT_COMMAND` | `fd --type f` |
| `FZF_DEFAULT_OPTS` | `--layout=reverse --inline-info --height=80%` |

## fzf Inside the Finder

| Key | What it does |
|---|---|
| Type text | Filter results (fuzzy match) |
| `Up` / `Down` | Move selection |
| `Enter` | Accept selection |
| `Escape` / `Ctrl+C` | Cancel |
| `Tab` | Mark item (multi-select mode) |
| `Shift+Tab` | Unmark item |

## Standalone Usage

| Command | What it does |
|---|---|
| `fzf` | Fuzzy pick from stdin (default: file list) |
| `<cmd> \| fzf` | Fuzzy pick from command output |
| `fzf --preview "<cmd> {}"` | Show preview for each item |
| `fzf --multi` | Allow selecting multiple items |
| `fzf --height=50%` | Use half the terminal height |
| `fzf --query "init"` | Start with a pre-filled query |
| `fzf --exact` | Exact match instead of fuzzy |

## Useful Flags

| Flag | What it does |
|---|---|
| `--preview "bat --color=always {}"` | Syntax-highlighted file preview |
| `--layout=reverse` | Results top-down instead of bottom-up |
| `--inline-info` | Show match count inline |
| `--height=80%` | Don't take the full terminal |
| `--border` | Draw a border around the finder |
| `--prompt "Files> "` | Custom prompt text |

## Common Combinations

| Command | What it does |
|---|---|
| `fd -e py \| fzf --preview "bat --color=always {}"` | Pick a Python file with preview |
| `rg -l "TODO" \| fzf` | Pick from files containing TODOs |
| `git branch \| fzf \| ForEach-Object { git checkout $_.Trim() }` | Fuzzy switch git branch |
| `Get-Process \| ForEach-Object { $_.Name } \| fzf` | Pick a process name |
| `choco list \| fzf` | Pick from installed Chocolatey packages |
| `code --list-extensions \| fzf` | Pick from installed VS Code extensions |

## Tips

- Your `FZF_DEFAULT_COMMAND` uses `fd`, so fzf respects `.gitignore` and skips hidden files.
- Fuzzy matching is token-based: `main py` matches `src/main.py`. Order matters.
- Prefix a token with `'` for exact match: `'main` only matches literal "main".
- Prefix with `^` for start-of-line: `^src` matches paths starting with "src".
- Suffix with `$` for end-of-line: `.py$` matches paths ending in ".py".
- Preview is not set globally -- it is applied explicitly in `Ctrl+F` and `fd` pipelines only. Setting it globally causes errors when `Ctrl+R` passes command strings to bat.

---

## See Also

- [Navigation and Search](cheatsheet-navigation-search.md) -- fd, zoxide, ripgrep, bat
- [PowerShell Terminal](cheatsheet-powershell-terminal.md) -- PSFzf keybindings and autosuggestions
