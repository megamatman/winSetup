# VS Code CLI Cheatsheet

Open files, diffs, and projects from the terminal using the `code` command.

## Opening Files and Folders

| Command | What it does |
|---|---|
| `code .` | Open current directory as workspace |
| `code <file>` | Open a file |
| `code <file1> <file2>` | Open multiple files as tabs |
| `code --goto <file>:<line>` | Open file at specific line |
| `code --goto <file>:<line>:<col>` | Open file at line and column |
| `code -n <folder>` | Open folder in new window |
| `code -r <folder>` | Open folder, reuse current window |

## Diffing

| Command | What it does |
|---|---|
| `code --diff <file1> <file2>` | Side-by-side diff of two files |
| `<cmd> \| code -` | Pipe output into a new VS Code tab |

## Extensions

| Command | What it does |
|---|---|
| `code --list-extensions` | List installed extensions |
| `code --install-extension <id>` | Install an extension |
| `code --uninstall-extension <id>` | Remove an extension |
| `code --disable-extensions .` | Open with all extensions disabled |

## Other

| Command | What it does |
|---|---|
| `code --version` | Show VS Code version |
| `code --help` | Show all CLI flags |
| `code "$env:APPDATA\Code\User\settings.json"` | Open your settings file |
| `code --remote ssh-remote+<user>@<host> /path` | Open a remote folder via SSH |

## Combinations

| Command | What it does |
|---|---|
| `fd -e py \| fzf \| ForEach-Object { code $_ }` | Fuzzy pick a file and open it |
| `rg -l "TODO" \| ForEach-Object { code $_ }` | Open all files containing TODOs |
| `rg "TODO" \| code -` | Pipe search results into VS Code |
| `z myproject && code .` | Jump to project and open it |

## Tips

- `code .` is the fastest way to start working on a project. Pair it with `z` for instant project switching.
- Use `code --goto` to jump from terminal linter/test output directly to the offending line.
- The `-` flag reads from stdin. Useful for reviewing `rg`, `git diff`, or `gl` output in the editor.
- If `code` isn't found, run `refreshenv` or restart your terminal.
- The integrated terminal uses Hack Nerd Font (configured in settings) so Oh My Posh renders correctly.

---

## See Also

- [Navigation and Search](cheatsheet-navigation-search.md) -- fd, ripgrep, bat for finding files
- [fzf](cheatsheet-fzf.md) -- fuzzy finder for interactive file selection
