# PowerShell Terminal -- PSReadLine, PSFzf, Oh My Posh

Your PowerShell profile configures the terminal into a productive, modern shell with fuzzy-search keybindings, intelligent autosuggestions, and a clean prompt. This guide covers the keybindings and features that are active in every terminal session.

## Setup

All configuration is handled by the PowerShell profile (`$PROFILE`), which is deployed by `Setup-DevEnvironment.ps1 -IncludeOptional` or synced via OneDrive. The tools themselves (fzf, PSFzf, Oh My Posh) are installed by the setup script.

## Keybinding Reference

| Key | What it does | Provided by |
|---|---|---|
| `Ctrl+R` | Fuzzy search through command history | PSFzf |
| `Ctrl+T` | Fuzzy find a file and insert its path | PSFzf |
| `Ctrl+F` | Find a file with bat preview, insert path | Custom PSReadLine |
| `Tab` | Fuzzy tab completion for commands and paths | PSFzf |
| `Up Arrow` | Search history backwards matching current input | PSReadLine |
| `Down Arrow` | Search history forwards matching current input | PSReadLine |

## PSReadLine -- Autosuggestions and History

PSReadLine is built into PowerShell 7 and handles line editing, history, and predictions. Your profile configures it for a zsh-like experience.

### Autosuggestions (ListView mode)

As you type, a dropdown list of predictions appears below your cursor -- sourced from your command history and any installed prediction plugins. This is the `ListView` prediction style:

```powershell
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView
```

Start typing a command and the list appears automatically. Use `Up`/`Down` arrows to select a suggestion, then press `Enter` to accept it.

**Example**: Type `git` and you'll see a dropdown of your most recent git commands. Arrow down to `git push origin main` and press Enter.

### History search with arrow keys

The arrow keys are bound to search history based on what you've already typed:

```powershell
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
```

**Example**: Type `docker` then press `Up Arrow`. Instead of cycling through your entire history, it only shows commands that started with `docker`. Each press of `Up` goes further back. The cursor moves to the end of the line so you can edit immediately.

### Practical difference from default behaviour

By default, `Up Arrow` cycles through *all* history regardless of what you've typed. With this configuration, it becomes a targeted search -- type a prefix, then arrow through matching commands. This is dramatically faster when you're looking for a specific command from hours ago.

## PSFzf -- Fuzzy Finding in the Terminal

PSFzf integrates fzf (a fuzzy finder) directly into your PowerShell workflow via keybindings.

### Ctrl+R -- Fuzzy history search

Press `Ctrl+R` at any prompt. A fuzzy search overlay appears with your entire command history. Type fragments of the command you're looking for -- they don't need to be contiguous.

**Example**: You ran a long Docker compose command two days ago. Press `Ctrl+R`, type `compose up`, and it narrows down to matching commands instantly. Press `Enter` to paste it onto your command line.

This is faster than pressing `Up Arrow` repeatedly, especially when you only remember part of the command.

### Ctrl+T -- Fuzzy file finder

Press `Ctrl+T` at any prompt. A fuzzy search overlay lists every file in and below your current directory (using `fd` under the hood). Type to filter, press `Enter`, and the selected file path is inserted at your cursor position.

**Example**: You need to open a deeply nested config file but can't remember the exact path:

```
> code [Ctrl+T]
# Type "tsconfig" in the fuzzy finder
# Select src/frontend/tsconfig.json
# Result: code src/frontend/tsconfig.json
```

### Ctrl+F -- File finder with bat preview

Press `Ctrl+F` at any prompt. Similar to `Ctrl+T`, but the fzf window shows a live preview of each file's contents (syntax-highlighted by bat) as you scroll through results.

**Example**: You're looking for a file that contains database configuration but can't remember the filename. Press `Ctrl+F`, type `config`, and scan the preview pane on the right to find the one with your connection string.

### Tab -- Fuzzy tab completion

Press `Tab` while typing a command, path, or argument. Instead of PowerShell's default completion cycling, fzf takes over with a fuzzy match against all possible completions.

**Example**:

```
> cd Do[Tab]
# Shows: Documents, Downloads, Docker
# Type "cu" to narrow to Documents
# Press Enter
```

This works for commands, parameters, file paths, and git branches -- anything PowerShell can complete.

## Oh My Posh -- Prompt Customisation

Oh My Posh replaces the default `PS C:\>` prompt with a themed, information-rich prompt. Your profile uses a managed copy of the `gruvbox` theme from the winSetup configs directory:

```powershell
$ompTheme = if ($env:WINSETUP) { "$env:WINSETUP\configs\gruvbox.omp.json" } else { $null }
if (-not $ompTheme -or -not (Test-Path $ompTheme)) {
    $ompTheme = "$env:POSH_THEMES_PATH\gruvbox.omp.json"
}
oh-my-posh init pwsh --config $ompTheme | Invoke-Expression
```

The primary path is `$env:WINSETUP\configs\gruvbox.omp.json`. If `$env:WINSETUP` is not set (e.g. before the setup script has been run), the profile falls back to the built-in Oh My Posh theme at `$env:POSH_THEMES_PATH`. To customise the theme, edit `configs/gruvbox.omp.json` in the winSetup repo.

The prompt shows:
- Current directory
- Git branch and status (dirty/clean, ahead/behind)
- Command execution time for long-running commands
- Python virtual environment name when active

### Changing the theme

Browse available themes:

```powershell
Get-PoshThemes
```

This renders every built-in theme in your terminal so you can preview them. To switch, change the config path in your profile:

```powershell
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json" | Invoke-Expression
```

### Checking your current config

```powershell
oh-my-posh config export --output ~/current-theme.json
```

## Real-World Workflows

### Recalling a complex command

You ran a specific `curl` command with headers and a JSON body last week:

1. Press `Ctrl+R`
2. Type `curl json`
3. The fuzzy matcher finds it even though "json" appeared in the middle of the command
4. Press `Enter` -- it's on your command line, ready to edit and re-run

### Opening a file you can't quite remember

You're in a monorepo and need to edit the ESLint config:

1. Press `Ctrl+F`
2. Type `eslint`
3. The preview pane shows each matching file's contents
4. Select the one in `packages/frontend/.eslintrc.js`
5. It's inserted at your cursor -- prepend `code ` and press Enter

### Navigating to a directory quickly

You're deep in `src/components/auth/` and need to jump to `tests/`:

1. Type `cd `
2. Press `Tab`
3. Type `tests` in the fuzzy finder
4. Select the right directory and press Enter

## Known Conflicts and Workarounds

### fzf preview and non-file inputs

The `FZF_DEFAULT_OPTS` environment variable intentionally does **not** include `--preview`. Adding a global preview causes `bat` to run on non-file inputs (such as command history items from `Ctrl+R`), producing errors. Preview is applied explicitly in `Ctrl+F` and `fd` pipelines where the input is always file paths.

### gc and gl alias collisions

PowerShell 7 defines built-in aliases `gc` (Get-Content) and `gl` (Get-Location) that conflict with the git commit and git log functions in your profile. The profile removes both explicitly:

```powershell
Remove-Alias -Name gl -Force -ErrorAction SilentlyContinue
Remove-Alias -Name gc -Force -ErrorAction SilentlyContinue
```

If `gc` starts behaving as `Get-Content`, the alias removal line may be missing -- run `. $PROFILE` to reload.

### PSFzf Tab completion and module argument completers

The PSFzf `Tab` override replaces PowerShell's default tab completion with fzf-powered fuzzy matching. If other modules register their own argument completers (e.g., posh-git for branch names, Az for Azure resources), the PSFzf `Tab` binding may override them. If you experience this, remove the Tab binding from your profile and rely on `Ctrl+T` for file picking instead:

```powershell
# Remove this line from your profile if Tab conflicts with module completers:
# Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
```

### Oh My Posh multiline prompt rendering

The Gruvbox theme used in this setup is single-line, so this doesn't apply. However, switching to a multiline Oh My Posh theme may cause cursor rendering issues with PSReadLine's ListView predictions. If you switch themes and see visual glitches, try disabling ListView temporarily:

```powershell
Set-PSReadLineOption -PredictionViewStyle InlineView
```

## Tips and Gotchas

- **Predictions blocking your view**: If the ListView dropdown is annoying in certain contexts, press `Escape` to dismiss it temporarily. It reappears when you start typing again.
- **History file location**: PSReadLine stores your history at `$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt`. This file persists across sessions -- that's how `Ctrl+R` can find commands from weeks ago.
- **fzf environment variables**: Your profile sets `FZF_DEFAULT_COMMAND` to `fd --type f` and `FZF_DEFAULT_OPTS` with reverse layout and inline info. Preview is not in the global opts (it causes errors with `Ctrl+R` history items) -- it's applied explicitly in `Ctrl+F` only.
- **Oh My Posh requires a Nerd Font**: The prompt uses special glyphs (git icons, segment separators) that only render correctly with a Nerd Font installed. The setup script installs Hack Nerd Font and configures Windows Terminal to use it. If you see broken squares in your prompt, your terminal isn't using the right font.
- **PSFzf vs raw fzf**: PSFzf is a PowerShell wrapper around fzf that hooks into PSReadLine. You can still use `fzf` directly in pipelines (e.g., `Get-ChildItem | fzf`), but the keybindings (`Ctrl+T`, `Ctrl+R`, `Tab`) are provided by PSFzf.

---

## See Also

- [Navigation and Search](03-navigation-and-search.md) -- fd, zoxide, ripgrep, bat
- [Git](04-git.md) -- git aliases and workflows