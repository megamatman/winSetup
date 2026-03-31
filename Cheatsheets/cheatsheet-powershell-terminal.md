# PowerShell Terminal Cheatsheet

PSReadLine autosuggestions, PSFzf keybindings, and Oh My Posh prompt.

## Keybindings

| Key | What it does | Source |
|---|---|---|
| `Ctrl+R` | Fuzzy search command history | PSFzf |
| `Ctrl+T` | Fuzzy find a file, insert path at cursor | PSFzf |
| `Ctrl+F` | Find a file with bat preview, insert path | Custom |
| `Tab` | Fuzzy tab completion (commands, paths, args) | PSFzf |
| `Up Arrow` | Previous command matching current input | PSReadLine |
| `Down Arrow` | Next command matching current input | PSReadLine |
| `Right Arrow` | Accept inline autosuggestion | PSReadLine |
| `Escape` | Dismiss prediction dropdown | PSReadLine |

## PSReadLine Features

| Feature | Behaviour |
|---|---|
| ListView predictions | Dropdown of matching commands appears as you type |
| History autosuggestion | Ghost text shows most recent matching command |
| Prefix history search | Up/Down arrow filters history by what you've typed |
| History persistence | Commands saved across sessions in `ConsoleHost_history.txt` |

## Oh My Posh

| Command | What it does |
|---|---|
| `Get-PoshThemes` | Preview all available themes |
| `oh-my-posh --version` | Show version |

Change theme by editing the config path in `$PROFILE`:

```powershell
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\<theme>.omp.json" | Invoke-Expression
```

## Profile Aliases

| Alias | Expands to |
|---|---|
| `gs` | `git status` |
| `ga` | `git add` |
| `gc "msg"` | `git commit -m "msg"` |
| `gp` | `git push` |
| `gl` | `git log --oneline --graph --decorate` |
| `lg` | `lazygit` (terminal git UI) |
| `cat` | `bat` (syntax-highlighted file viewer) |
| `z <keyword>` | Jump to directory via zoxide |
| `zi <keyword>` | Interactive directory jump via zoxide + fzf |

## Tips

- `Ctrl+R` is the single most useful keybinding -- use it constantly.
- Type a prefix then `Up Arrow` for quick recall; `Ctrl+R` for fuzzy deep search.
- Prompt shows git branch/status, Python venv name, and execution time.
- If prompt glyphs look broken, ensure your terminal font is set to Hack Nerd Font.
- `gc` and `gl` are removed from PowerShell's built-in aliases in the profile to avoid conflicts with the git commit and git log functions.
- If Tab fuzzy completion conflicts with a module's argument completer (e.g. posh-git), remove the PSFzf Tab binding from your profile and use `Ctrl+T` for file picking instead.

---

## See Also

- [fzf](cheatsheet-fzf.md) -- fuzzy finder flags and combinations
- [Navigation and Search](cheatsheet-navigation-search.md) -- fd, zoxide, ripgrep, bat
