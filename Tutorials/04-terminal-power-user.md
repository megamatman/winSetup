# Tutorial 4: Terminal Power User

## What you will learn

- How PSReadLine autosuggestions and ListView mode work in practice
- Using `Ctrl+R` to search and reuse commands from your history
- Using `Ctrl+T` to insert file paths without typing them
- Fuzzy Tab completion for commands, paths, and arguments
- Putting git aliases (`gs`, `ga`, `gc`, `gp`, `gl`) into a real workflow

## Prerequisites

- Completed Tutorials 1-3
- Comfortable with `fd`, `rg`, `bat`, `fzf`, and `zoxide`

---

## Step 1: Autosuggestions in action

Start typing a command you've run before. For example, type `git`:

```
> git
```

Two things happen:

1. **Inline suggestion**: A faded ghost-text suggestion appears, showing the most recent matching command (e.g., `git push`). Press `Right Arrow` to accept the full suggestion, or keep typing to narrow it.

2. **ListView dropdown**: A list of predictions appears below your cursor, showing several matching commands ranked by frequency. Use `Up/Down` arrows to highlight one, then press `Enter` to accept.

### Try it

Type `rg` and pause. The dropdown shows your recent ripgrep commands. Arrow down to the one you want, press Enter, and it runs. No retyping.

This works because your profile sets:

```powershell
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView
```

### Dismiss the dropdown

Press `Escape` to close the dropdown and keep what you've typed. The next keystroke brings it back.

## Step 2: Ctrl+R -- History search

`Ctrl+R` opens a full-screen fuzzy search over your entire command history. This is your most important keybinding for productivity.

### Basic usage

1. Press `Ctrl+R`
2. A fzf overlay appears with your command history (newest first)
3. Type fragments of the command you're looking for -- they don't need to be contiguous
4. Press `Enter` to paste the selected command onto your prompt
5. Edit it if needed, then press `Enter` again to run

### Example scenario

You ran a complex Docker command three days ago:

```powershell
docker run -d -p 5432:5432 -e POSTGRES_PASSWORD=secret --name dev-db postgres:15
```

You don't remember the exact flags. Press `Ctrl+R`, type `docker postgres`, and fzf finds it instantly. Press Enter and the full command is on your prompt, ready to run or edit.

### Why this matters

Your command history persists across sessions (stored in `$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt`). `Ctrl+R` can find commands from weeks or months ago. Combined with ListView autosuggestions, you rarely need to type long commands from scratch.

## Step 3: Ctrl+T -- File path picker

`Ctrl+T` inserts a file path at your cursor position using fzf.

### Example

You want to open a file but don't want to type the path:

1. Type `code ` (with a trailing space)
2. Press `Ctrl+T`
3. The fzf file picker appears (powered by `fd`)
4. Type fragments to filter (e.g., "readme")
5. Press `Enter`
6. The full file path is inserted after `code `
7. Press `Enter` to run the command

### Works mid-command

`Ctrl+T` inserts at the cursor, so it works anywhere in a command:

```
> bat [Ctrl+T selects a file] --line-range 1:20
```

It also works with multiple files:

```
> code [Ctrl+T] [Ctrl+T] [Ctrl+T]
```

Each `Ctrl+T` adds another file path.

## Step 4: Tab -- Fuzzy completion

Pressing `Tab` activates fzf-powered completion instead of PowerShell's default cycling behaviour.

### Complete commands

Type `cho` then press `Tab`:

```
> cho[Tab]
```

fzf shows matching commands: `choco`, `chmod` (if available), etc. Select one and press Enter.

### Complete file paths

```
> bat How[Tab]
```

fzf shows directories and files matching "How": `HowTo-Guides/`. Select it, and Tab again to go deeper.

### Complete git branches

```
> git checkout [Tab]
```

fzf lists your local branches. Type a fragment to filter, select, and press Enter.

### Complete parameters

```
> rg --[Tab]
```

fzf shows all available ripgrep flags. Type "type" to filter to `--type`, `--type-list`, etc.

### Why this beats default Tab

Default PowerShell Tab cycles through completions one at a time. With 20 possible completions, you'd press Tab 19 times to get the last one. Fuzzy Tab shows all options at once and lets you type to filter. It's faster for everything.

## Step 5: Arrow key history search

Your profile configures `Up/Down` arrows for prefix-based history search:

```powershell
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
```

### How it works

1. Type the beginning of a command: `git commit`
2. Press `Up Arrow`
3. Instead of showing your most recent command (regardless of what it was), it shows the most recent command that *started with* `git commit`
4. Press `Up` again to go further back through matching commands

### When to use this vs Ctrl+R

- **Arrow keys**: When you remember the start of the command. Fastest for "I just ran something like `git commit...` a few commands ago."
- **Ctrl+R**: When you remember fragments from the middle or end. Better for "I ran something with `postgres` in it last week."

## Step 6: Git aliases in practice

Your profile defines five aliases that cover 90% of daily git operations:

```powershell
function gs { git status }       # What's changed?
function ga { git add $args }    # Stage changes
function gc { git commit -m $args }  # Commit
function gp { git push }         # Push to remote
function gl { git log --oneline --graph --decorate }  # View history
```

### The daily workflow

Here's a complete feature cycle using the aliases:

```powershell
# 1. Check what's changed
gs

# 2. Stage specific files
ga src/feature.py tests/test_feature.py

# 3. Check what's staged (confirm before committing)
gs

# 4. Commit
gc "Add user search feature"

# 5. Push
gp

# 6. Review the log
gl
```

### Combine with fzf for file staging

Instead of typing file paths for `ga`, use `Ctrl+T`:

```
> ga [Ctrl+T]
# Select the file you want to stage
# Repeat for more files
```

Or use `gs` output to decide what to stage, then stage it:

```powershell
gs                          # See the list of modified files
ga src/main.py              # Stage just the one you want
gc "Fix null check"
gp
```

### Review history with gl

```powershell
gl
```

Shows a compact graph of recent commits:

```
* a1b2c3d (HEAD -> main, origin/main) Add fzf config
* d4e5f6g Fix step counter
* h7i8j9k Initial commit
```

Your profile also defines `lg` as an alias for lazygit, a full terminal UI for git. Tutorial 8 covers this in depth -- for now, know that `lg` exists and is there when you need more than the aliases provide.

---

## Putting it all together

Here's a realistic 5-minute workflow combining everything from Tutorials 1-4:

```powershell
# Jump to your project
z myproject

# Check git status
gs

# Find the file you need to edit
# (Ctrl+F for preview, or rg to search contents)
rg -l "process_payment" --type py

# Open it at the relevant line
code --goto src/billing/service.py:87

# ... edit in VS Code ...

# Back in the terminal, check what changed
gs

# Stage the changed files
ga src/billing/service.py

# Commit
gc "Fix payment processing timeout"

# Push
gp

# Recall that Docker command from last week
# (Ctrl+R, type "docker compose")
```

---

## Exercise

1. Press `Ctrl+R` and search for a command you ran earlier today. Select it and edit it before running.
2. Type `bat ` then press `Ctrl+T`. Select a file and view it.
3. Type `cd ` then press `Tab`. Navigate into a directory using fuzzy completion.
4. Type `rg` then press `Up Arrow` multiple times -- watch it cycle through only your previous ripgrep commands.
5. Practice the git alias workflow:
   - Create a test file: `"test" | Set-Content test.txt`
   - `gs` to see it as untracked
   - `ga test.txt` to stage it
   - `gs` to see it staged
   - `git restore --staged test.txt` to unstage it
   - `Remove-Item test.txt` to clean up
6. Run `gl` in the winSetup repo and read the commit graph

---

## What comes next

You're now fluent with the terminal itself. **Tutorial 5** takes you into a real Python development workflow -- creating virtual environments, writing code, and running the linting tools (pylint, mypy, ruff, bandit) that catch bugs before they reach production.
