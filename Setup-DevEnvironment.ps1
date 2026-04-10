<#
.SYNOPSIS
    Sets up a Windows 11 development environment consistently across machines.

.DESCRIPTION
    Idempotent utility that installs and configures: Chocolatey, VS Code, Python,
    Oh My Posh, GitHub CLI, fzf + PSFzf, Hack Nerd Font, SSH keys (with GitHub
    upload), Windows Terminal font, Python tools, delta, lazygit, pyenv-win,
    global gitignore, git commit signing, and git identity check.
    Optional: VS Code settings, extensions, PowerShell profile, Defender exclusions.
    Optional steps (VS Code settings, extensions, PowerShell profile) are skipped by
    default since they are normally handled by VS Code Settings Sync and OneDrive.

.PARAMETER IncludeOptional
    Enable optional steps: VS Code settings.json, VS Code extensions, PowerShell profile.
    These are normally applied automatically by VS Code Settings Sync and OneDrive.

.PARAMETER ScaffoldPyproject
    Path to a project directory where a pyproject.toml template should be created.
    When provided, the script only scaffolds the file and exits.

.PARAMETER CheckProfileOnly
    Run only the profile health check and exit. Useful for verifying your profile
    has all expected sections without running the full setup.

.PARAMETER WhatIf
    Preview all setup steps without making changes. Each step reports whether it
    would install/configure a tool or skip it (already present). No tools are
    installed, no files are modified.

.EXAMPLE
    .\Setup-DevEnvironment.ps1
    Run the standard setup (most common case).

.EXAMPLE
    .\Setup-DevEnvironment.ps1 -IncludeOptional
    Run the standard setup plus optional sync-fallback steps.

.EXAMPLE
    .\Setup-DevEnvironment.ps1 -WhatIf
    Preview what the standard setup would do without making changes.

.EXAMPLE
    .\Setup-DevEnvironment.ps1 -ScaffoldPyproject "C:\Projects\my-app"
    Scaffold a pyproject.toml into the specified directory.
#>

[CmdletBinding()]
param(
    [switch]$IncludeOptional,
    [switch]$CheckProfileOnly,
    [ValidateNotNullOrEmpty()]
    [string]$ScaffoldPyproject,

    # Install a single named tool without running full setup.
    # Example: .\Setup-DevEnvironment.ps1 -InstallTool ruff
    [string]$InstallTool,

    [switch]$WhatIf
)

Set-StrictMode -Version Latest
. "$PSScriptRoot\Helpers.ps1"

# Interface contract version for consumers (see INTERFACE.md).
# Increment when making breaking changes to $PackageRegistry format,
# Install-* naming, $CoreSteps semantics, or -InstallTool dispatch.
$script:ContractVersion = 2

# Must match the number of Write-Step calls in core/optional functions respectively.
# Update CoreSteps and OptionalSteps if functions are added or removed.
# Core (18): Test-ProfileHealth + Chocolatey + VSCode + Python + OhMyPosh +
#   GitHubCLI + Fzf + CLITools + HackNerdFont + SSHKeys + GitHubSSHKey +
#   WindowsTerminalFont + PythonTools + PyenvWin + GlobalGitIgnore +
#   GitIdentity + GitCommitSigning + DeltaGitConfig
# Optional (4): VSCodeSettings + VSCodeExtensions + Profile + Defender
$CoreSteps = 18
$OptionalSteps = 4
$TotalSteps = if ($IncludeOptional) { $CoreSteps + $OptionalSteps } else { $CoreSteps }
$script:CurrentStep = 0

function Assert-Winget {
    <#
    .SYNOPSIS
        Verifies that winget is available on the system.
    .DESCRIPTION
        Returns $true if winget is found on PATH, $false otherwise.
        Displays a remediation message when winget is missing.
    #>
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Issue "winget not found. Install App Installer from the Microsoft Store or update Windows."
        return $false
    }
    return $true
}

# =============================================================================
# Step Functions
# =============================================================================

function Assert-Administrator {
    <#
    .SYNOPSIS
        Ensures the script is running with Administrator privileges.
    .DESCRIPTION
        Checks the current Windows identity for the Administrator role and
        throws a terminating error if the session is not elevated.
    #>
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Issue "This script must be run as Administrator. Right-click PowerShell and select 'Run as Administrator'."
        throw "This script must be run as Administrator."
    }
}

function Install-Chocolatey {
    <#
    .SYNOPSIS
        Installs the Chocolatey package manager.
    .DESCRIPTION
        Downloads and runs the Chocolatey install script if choco is not
        already on PATH. Refreshes the session PATH after installation.
    #>
    Write-Step "Chocolatey"
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Verbose "Skipping Chocolatey -- already installed at $((Get-Command choco).Source)"
        Write-Skip "Chocolatey is already installed" -Track "Chocolatey"
        return
    }
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Update-SessionPath
        Write-Change "Chocolatey installed" -Track "Chocolatey"
    } catch {
        Write-Issue "Chocolatey install failed: $($_.Exception.Message)" -Track "Chocolatey"
    }
}

function Install-VSCode {
    <#
    .SYNOPSIS
        Installs Visual Studio Code via Chocolatey.
    .DESCRIPTION
        Skips if the 'code' command is already available. Installs using
        choco and refreshes the session PATH.
    #>
    Write-Step "VS Code"
    if (Get-Command code -ErrorAction SilentlyContinue) {
        Write-Verbose "Skipping VS Code -- already installed at $((Get-Command code).Source)"
        Write-Skip "VS Code is already installed" -Track "VS Code"
        return
    }
    try {
        choco install vscode -y
        if ($LASTEXITCODE -ne 0) { Write-Issue "VS Code install failed (choco exit code: $LASTEXITCODE)" -Track "VS Code"; return }
        Update-SessionPath
        if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
            Write-Host "  VS Code installed but 'code' not found on PATH. You may need to restart your terminal." -ForegroundColor Yellow
        } else {
            Write-Change "VS Code installed" -Track "VS Code"
        }
    } catch {
        Write-Issue "VS Code install failed: $($_.Exception.Message)" -Track "VS Code"
    }
}

function Install-Python {
    <#
    .SYNOPSIS
        Installs Python via Chocolatey.
    .DESCRIPTION
        Skips if a real Python (not the Windows Store stub) is already on PATH.
        Installs using choco and refreshes the session PATH.
    #>
    Write-Step "Python"
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    $isStoreStub = $pythonCmd -and $pythonCmd.Source -like "*WindowsApps*"
    if ($pythonCmd -and -not $isStoreStub) {
        Write-Verbose "Skipping Python -- already installed at $($pythonCmd.Source)"
        Write-Skip "Python is already installed" -Track "Python"
        return
    }
    try {
        choco install python -y
        if ($LASTEXITCODE -ne 0) { Write-Issue "Python install failed (choco exit code: $LASTEXITCODE)" -Track "Python"; return }
        Update-SessionPath
        if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
            Write-Host "  Python installed but 'python' not found on PATH. You may need to restart your terminal." -ForegroundColor Yellow
        } else {
            Write-Change "Python installed" -Track "Python"
        }
    } catch {
        Write-Issue "Python install failed: $($_.Exception.Message)" -Track "Python"
    }
}

function Install-OhMyPosh {
    <#
    .SYNOPSIS
        Installs Oh My Posh prompt engine via winget.
    .DESCRIPTION
        Skips if oh-my-posh is already on PATH. Requires winget.
    #>
    Write-Step "Oh My Posh"
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        Write-Verbose "Skipping Oh My Posh -- already installed at $((Get-Command oh-my-posh).Source)"
        Write-Skip "Oh My Posh is already installed" -Track "Oh My Posh"
        return
    }
    if (-not (Assert-Winget)) { return }
    try {
        winget install JanDeDobbeleer.OhMyPosh --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { Write-Issue "Oh My Posh install failed (winget exit code: $LASTEXITCODE)" -Track "Oh My Posh"; return }
        Update-SessionPath
        Write-Change "Oh My Posh installed" -Track "Oh My Posh"
    } catch {
        Write-Issue "Oh My Posh install failed: $($_.Exception.Message)" -Track "Oh My Posh"
    }
}

function Install-GitHubCLI {
    <#
    .SYNOPSIS
        Installs the GitHub CLI via winget.
    .DESCRIPTION
        Skips if 'gh' is already on PATH. Requires winget.
    #>
    Write-Step "GitHub CLI"
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Verbose "Skipping GitHub CLI -- already installed at $((Get-Command gh).Source)"
        Write-Skip "GitHub CLI is already installed" -Track "GitHub CLI"
        return
    }
    if (-not (Assert-Winget)) { return }
    try {
        winget install GitHub.cli --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { Write-Issue "GitHub CLI install failed (winget exit code: $LASTEXITCODE)" -Track "GitHub CLI"; return }
        Update-SessionPath
        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
            Write-Host "  GitHub CLI installed but 'gh' not found on PATH. You may need to restart your terminal." -ForegroundColor Yellow
        } else {
            Write-Change "GitHub CLI installed" -Track "GitHub CLI"
        }
    } catch {
        Write-Issue "GitHub CLI install failed: $($_.Exception.Message)" -Track "GitHub CLI"
    }
}

function Install-Fzf {
    <#
    .SYNOPSIS
        Installs fzf, fd, and the PSFzf PowerShell module.
    .DESCRIPTION
        Installs fzf via winget, fd via Chocolatey, and PSFzf from the
        PowerShell Gallery. Each component is skipped if already present.
    #>
    Write-Step "fzf + fd + PSFzf"

    # Install fzf binary via winget
    if (Get-Command fzf -ErrorAction SilentlyContinue) {
        Write-Verbose "Skipping fzf -- already installed at $((Get-Command fzf).Source)"
        Write-Skip "fzf is already installed" -Track "fzf"
    } else {
        if (-not (Assert-Winget)) { return }
        try {
            winget install junegunn.fzf --silent --accept-package-agreements --accept-source-agreements
            if ($LASTEXITCODE -ne 0) { Write-Issue "fzf install failed (winget exit code: $LASTEXITCODE)" -Track "fzf"; return }
            Update-SessionPath
            if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
                Write-Host "  fzf installed but not found on PATH. You may need to restart your terminal." -ForegroundColor Yellow
            } else {
                Write-Change "fzf installed" -Track "fzf"
            }
        } catch {
            Write-Issue "fzf install failed: $($_.Exception.Message)" -Track "fzf"
        }
    }

    # Install fd via Chocolatey
    if (Get-Command fd -ErrorAction SilentlyContinue) {
        Write-Verbose "Skipping fd -- already installed at $((Get-Command fd).Source)"
        Write-Skip "fd is already installed" -Track "fd"
    } else {
        try {
            choco install fd -y
            if ($LASTEXITCODE -ne 0) { Write-Issue "fd install failed (choco exit code: $LASTEXITCODE)" -Track "fd"; return }
            Update-SessionPath
            if (-not (Get-Command fd -ErrorAction SilentlyContinue)) {
                Write-Host "  fd installed but not found on PATH. You may need to restart your terminal." -ForegroundColor Yellow
            } else {
                Write-Change "fd installed" -Track "fd"
            }
        } catch {
            Write-Issue "fd install failed: $($_.Exception.Message)" -Track "fd"
        }
    }

    # Install PSFzf PowerShell module
    if (Get-Module -ListAvailable -Name PSFzf) {
        Write-Skip "PSFzf module is already installed" -Track "PSFzf"
    } else {
        try {
            Install-Module -Name PSFzf -Scope CurrentUser -Force -ErrorAction Stop
            Write-Change "PSFzf module installed" -Track "PSFzf"
        } catch {
            Write-Issue "PSFzf install failed: $($_.Exception.Message)" -Track "PSFzf"
        }
    }
}

function Install-CLITools {
    <#
    .SYNOPSIS
        Installs CLI productivity tools via Chocolatey.
    .DESCRIPTION
        Installs zoxide, bat, ripgrep, delta, and lazygit. Each tool is
        skipped individually if its command is already on PATH.
    #>
    Write-Step "CLI Tools (zoxide, bat, ripgrep, delta, lazygit)"

    $tools = @(
        @{ Name = "zoxide"; Command = "zoxide"; Package = "zoxide" }
        @{ Name = "bat"; Command = "bat"; Package = "bat" }
        @{ Name = "ripgrep"; Command = "rg"; Package = "ripgrep" }
        @{ Name = "delta"; Command = "delta"; Package = "delta" }
        @{ Name = "lazygit"; Command = "lazygit"; Package = "lazygit" }
    )

    foreach ($tool in $tools) {
        if (Get-Command $tool.Command -ErrorAction SilentlyContinue) {
            Write-Verbose "Skipping $($tool.Name) -- already installed at $((Get-Command $tool.Command).Source)"
            Write-Skip "$($tool.Name) is already installed" -Track $tool.Name
        } else {
            try {
                choco install $tool.Package -y
                if ($LASTEXITCODE -ne 0) { Write-Issue "$($tool.Name) install failed (choco exit code: $LASTEXITCODE)" -Track $tool.Name; continue }
                Update-SessionPath
                if (-not (Get-Command $tool.Command -ErrorAction SilentlyContinue)) {
                    Write-Host "  $($tool.Name) installed but not found on PATH. You may need to restart your terminal." -ForegroundColor Yellow
                } else {
                    Write-Change "$($tool.Name) installed" -Track $tool.Name
                }
            } catch {
                Write-Issue "$($tool.Name) install failed: $($_.Exception.Message)" -Track $tool.Name
            }
        }
    }
}

function Install-HackNerdFont {
    <#
    .SYNOPSIS
        Installs the Hack Nerd Font family from a bundled zip file.
    .DESCRIPTION
        Extracts Hack.zip from the script directory, copies .ttf files into
        C:\Windows\Fonts, and registers them in the Windows font registry.
        Skips if Hack fonts are already present.
    #>
    Write-Step "Hack Nerd Font"
    $fontsPath = "C:\Windows\Fonts"
    $alreadyInstalled = Get-ChildItem $fontsPath | Where-Object { $_.Name -like "Hack*" }
    if ($alreadyInstalled) {
        Write-Verbose "Skipping Hack Nerd Font -- already installed in $fontsPath"
        Write-Skip "Hack Nerd Font is already installed" -Track "Hack Nerd Font"
        return
    }

    $zipPath = Join-Path $PSScriptRoot "Hack.zip"
    if (-not (Test-Path $zipPath)) {
        Write-Issue "Hack.zip not found in $PSScriptRoot" -Track "Hack Nerd Font"
        return
    }

    try {
        $extractPath = Join-Path $env:TEMP "HackFont"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        $fonts = Get-ChildItem $extractPath -Recurse -Filter "*.ttf"
        foreach ($font in $fonts) {
            Copy-Item $font.FullName $fontsPath
            $regKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
            $fontDisplayName = $font.BaseName + " (TrueType)"
            Set-ItemProperty -Path $regKey -Name $fontDisplayName -Value $font.Name
        }
        Remove-Item $extractPath -Recurse -Force
        Write-Change "Hack Nerd Font installed ($($fonts.Count) files)" -Track "Hack Nerd Font"
    } catch {
        Write-Issue "Hack Nerd Font install failed: $($_.Exception.Message)" -Track "Hack Nerd Font"
    }
}

function Install-SSHKeys {
    <#
    .SYNOPSIS
        Deploys SSH keys from a bundled .ssh.zip archive.
    .DESCRIPTION
        Extracts .ssh.zip from the script directory into ~/.ssh and sets
        owner-only ACL permissions on the private key. Skips if
        id_ed25519 already exists.
    #>
    Write-Step "SSH Keys"
    $sshDir = Join-Path $env:USERPROFILE ".ssh"
    $keyPath = Join-Path $sshDir "id_ed25519"

    if (Test-Path $keyPath) {
        Write-Verbose "Skipping SSH keys -- $keyPath already exists"
        Write-Skip "SSH keys already present" -Track "SSH Keys"
        return
    }

    $zipPath = Join-Path $PSScriptRoot ".ssh.zip"
    if (-not (Test-Path $zipPath)) {
        Write-Issue ".ssh.zip not found in $PSScriptRoot" -Track "SSH Keys"
        return
    }

    try {
        if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir | Out-Null }
        Expand-Archive -Path $zipPath -DestinationPath $sshDir -Force

        if (-not (Test-Path $keyPath)) {
            Write-Issue "SSH key not found at $keyPath after extraction -- check that .ssh.zip contains id_ed25519 at its root, not inside a subdirectory" -Track "SSH Keys"
            return
        }

        # Set correct permissions on private key (owner-only access)
        $acl = Get-Acl $keyPath
        $acl.SetAccessRuleProtection($true, $false)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $env:USERNAME, "FullControl", "Allow"
        )
        $acl.SetAccessRule($rule)
        Set-Acl $keyPath $acl
        Write-Change "SSH keys deployed and permissions set" -Track "SSH Keys"
    } catch {
        Write-Issue "SSH keys install failed: $($_.Exception.Message)" -Track "SSH Keys"
    }
}

function Add-GitHubSSHKey {
    <#
    .SYNOPSIS
        Uploads the local SSH public key to GitHub.
    .DESCRIPTION
        Uses the GitHub CLI to add id_ed25519.pub as both an authentication
        and a signing key. Skips if the key is already registered on GitHub
        or if gh is not authenticated.
    #>
    Write-Step "GitHub SSH Key Upload"

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Skip "GitHub CLI not found -- skipping SSH key upload" -Track "GitHub SSH Key"
        return
    }

    $keyPath = Join-Path $env:USERPROFILE ".ssh\id_ed25519.pub"
    if (-not (Test-Path $keyPath)) {
        Write-Skip "SSH public key not found at $keyPath -- skipping" -Track "GitHub SSH Key"
        return
    }

    # Check if already authenticated with gh
    $null = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  GitHub CLI is not authenticated." -ForegroundColor Yellow
        Write-Host "  Run 'gh auth login' then re-run this script to upload your SSH key automatically." -ForegroundColor Yellow
        return
    }

    # Check if key is already uploaded
    $keyContent = Get-Content $keyPath
    $keyFragment = ($keyContent -split " ")[1].Substring(0, 20)
    $existingKeys = gh api user/keys --paginate 2>&1
    $existingSigningKeys = gh api user/ssh_signing_keys --paginate 2>&1
    if ($LASTEXITCODE -ne 0) {
        # API call failed -- likely missing scopes. Check with gh ssh-key list as fallback.
        $existingKeys = gh ssh-key list 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Cannot check existing SSH keys (missing API scopes)." -ForegroundColor Yellow
            Write-Host "  Run 'gh auth refresh -h github.com -s admin:public_key,admin:ssh_signing_key' then re-run." -ForegroundColor Yellow
            return
        }
    }
    $allKeys = "$existingKeys $existingSigningKeys"
    if ($allKeys -match [regex]::Escape($keyFragment)) {
        Write-Verbose "Skipping SSH key upload -- key already on GitHub"
        Write-Skip "SSH key is already uploaded to GitHub" -Track "GitHub SSH Key"
        return
    }

    $hostname = $env:COMPUTERNAME
    $date = Get-Date -Format 'yyyy-MM-dd'

    $null = gh ssh-key add $keyPath --title "$hostname - $date" --type authentication 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Issue "Failed to upload authentication key to GitHub" -Track "GitHub SSH Key"
        return
    }
    $null = gh ssh-key add $keyPath --title "$hostname - $date (signing)" --type signing 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Issue "Failed to upload signing key to GitHub" -Track "GitHub SSH Key"
        return
    }
    Write-Change "SSH key uploaded to GitHub (authentication + signing)" -Track "GitHub SSH Key"
}

function Set-WindowsTerminalFont {
    <#
    .SYNOPSIS
        Sets the default Windows Terminal font to Hack Nerd Font.
    .DESCRIPTION
        Patches the Windows Terminal settings.json to set
        profiles.defaults.font.face to "Hack Nerd Font". Skips if the
        font is already configured or settings.json is not found.
    #>
    Write-Step "Windows Terminal Font"
    $wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

    if (-not (Test-Path $wtSettingsPath)) {
        Write-Verbose "Skipping Windows Terminal font -- settings file not found at $wtSettingsPath"
        Write-Skip "Windows Terminal settings not found -- skipping" -Track "WT Font"
        return
    }

    try {
    $wtSettings = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json

    # Check if already set
    $currentFont = $null
    if ($wtSettings.profiles.defaults.PSObject.Properties['font']) {
        $currentFont = $wtSettings.profiles.defaults.font.face
    }
    if ($currentFont -eq "Hack Nerd Font") {
        Write-Skip "Windows Terminal font is already set to Hack Nerd Font" -Track "WT Font"
        return
    }

    # Surgical edit: only touch the font key
    if (-not $wtSettings.profiles.defaults.PSObject.Properties['font']) {
        $wtSettings.profiles.defaults | Add-Member -MemberType NoteProperty -Name "font" -Value ([PSCustomObject]@{ face = "Hack Nerd Font" })
    } elseif (-not $wtSettings.profiles.defaults.font.PSObject.Properties['face']) {
        $wtSettings.profiles.defaults.font | Add-Member -MemberType NoteProperty -Name "face" -Value "Hack Nerd Font"
    } else {
        $wtSettings.profiles.defaults.font.face = "Hack Nerd Font"
    }
    $wtSettings | ConvertTo-Json -Depth 10 | Set-Content $wtSettingsPath -Encoding UTF8
    Write-Change "Windows Terminal font set to Hack Nerd Font" -Track "WT Font"
    } catch {
        Write-Issue "Windows Terminal font config failed: $($_.Exception.Message)" -Track "WT Font"
    }
}

function Invoke-Pipx {
    <#
    .SYNOPSIS
        Calls pipx with fallback to python -m pipx.
    .DESCRIPTION
        On some Windows configurations pipx.exe is a Python launcher script
        rather than a native executable. Calling it with output redirection
        fails with "StandardOutputEncoding is only supported when standard
        output is redirected." This helper tries pipx directly first, then
        retries via python -m pipx if the direct call throws.
    #>
    try {
        $output = & pipx @args 2>&1
        return $output
    }
    catch {
        # Fallback: launcher script failure. Use python -m pipx instead.
        $output = & python -m pipx @args 2>&1
        return $output
    }
}

function Install-PythonTools {
    <#
    .SYNOPSIS
        Installs Python CLI tools via pipx.
    .DESCRIPTION
        Ensures pipx is installed, then installs pylint, mypy, ruff,
        bandit, pre-commit, and cookiecutter. Each tool is skipped if
        already present in the pipx package list.
    #>
    Write-Step "Python Tools (pipx)"

    $tools = @("pylint", "mypy", "ruff", "bandit", "pre-commit", "cookiecutter")

    # Check Python is available
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pythonCmd -or $pythonCmd.Source -like "*WindowsApps*") {
        Write-Issue "Python not found. Skipping Python tools." -Track "Python Tools"
        return
    }

    # Check pip is available
    if (-not (Get-Command pip -ErrorAction SilentlyContinue)) {
        Write-Issue "pip not found. Run 'python -m ensurepip' to install it." -Track "Python Tools"
        return
    }

    # Check pipx, install if missing
    if (-not (Get-Command pipx -ErrorAction SilentlyContinue)) {
        $null = pip install --user pipx 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Issue "pip install pipx failed. Check your Python/pip installation." -Track "pipx"
            return
        }
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + $env:PATH
        if (-not (Get-Command pipx -ErrorAction SilentlyContinue)) {
            Write-Issue "pipx installed but not on PATH. Run 'pipx ensurepath', restart your terminal, and re-run." -Track "pipx"
            return
        }
        Write-Change "pipx installed" -Track "pipx"
    } else {
        Write-Skip "pipx is already installed" -Track "pipx"
    }

    # Install missing tools (Invoke-Pipx handles launcher script fallback)
    $installedPackages = Invoke-Pipx list --short 2>$null | ForEach-Object { ($_ -split "\s+")[0].Trim().ToLower() }

    foreach ($tool in $tools) {
        if ($installedPackages -contains $tool.ToLower()) {
            Write-Skip "$tool is already installed" -Track $tool
        } else {
            $result = Invoke-Pipx install $tool 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Issue "$tool failed to install: $($result | Select-Object -Last 3 | Out-String)" -Track $tool
            } else {
                Write-Change "$tool installed" -Track $tool
            }
        }
    }

    # Ensure PATH
    $ensurepath = (Invoke-Pipx ensurepath 2>&1) -join " "
    if ($ensurepath -notmatch "already in PATH") {
        Write-Change "PATH updated -- restart your terminal for changes to take effect"
    }
}

function Install-PyenvWin {
    <#
    .SYNOPSIS
        Installs pyenv-win for Python version management.
    .DESCRIPTION
        Installs pyenv-win via pip into ~/.pyenv and adds its bin and
        shims directories to the session PATH. Skips if ~/.pyenv exists.
    #>
    Write-Step "pyenv-win"

    $pyenvDir = Join-Path $env:USERPROFILE ".pyenv"
    if (Test-Path $pyenvDir) {
        Write-Verbose "Skipping pyenv-win -- $pyenvDir already exists"
        Write-Skip "pyenv-win is already installed" -Track "pyenv-win"
    } else {
        try {
            $result = pip install pyenv-win --target "$pyenvDir\pyenv-win" 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Issue "pyenv-win install failed: $($result | Select-Object -Last 3 | Out-String)" -Track "pyenv-win"
            } else {
                Write-Change "pyenv-win installed" -Track "pyenv-win"
            }
        } catch {
            Write-Issue "pyenv-win install failed: $($_.Exception.Message)" -Track "pyenv-win"
        }
    }

    # Ensure pyenv is on PATH for this session
    $env:PYENV = "$pyenvDir\pyenv-win"
    $env:PATH = "$env:PYENV\bin;$env:PYENV\shims;$env:PATH"
}

function Set-GlobalGitIgnore {
    <#
    .SYNOPSIS
        Creates a global .gitignore and configures git to use it.
    .DESCRIPTION
        Writes a default .gitignore_global to the user profile covering
        secrets, Python artifacts, OS files, and editor noise, then sets
        git core.excludesfile. Skips if the file already exists.
    #>
    Write-Step "Global .gitignore"

    $globalGitIgnore = Join-Path $env:USERPROFILE ".gitignore_global"
    if (Test-Path $globalGitIgnore) {
        Write-Skip "Global .gitignore already exists" -Track "Global .gitignore"
    } else {
        try {
        @"
# Secrets and keys
.env
.env.*
!.env.example
*.key
*.pem
*.p12
*.pfx
id_rsa
id_ed25519
*.secret

# Python
__pycache__/
*.py[cod]
.venv/
venv/
*.egg-info/
.mypy_cache/
.ruff_cache/

# Tools
.pytest_cache/
.pre-commit-config-cache/

# OS
.DS_Store
Thumbs.db
desktop.ini

# Editors -- .vscode/settings.json is globally ignored by default.
# Teams who want to share workspace settings should remove this line
# from their project's .gitignore after setup.
.vscode/settings.json
*.swp
*.swo
"@ | Set-Content $globalGitIgnore
        git config --global core.excludesfile $globalGitIgnore
        Write-Change "Global .gitignore created and configured" -Track "Global .gitignore"
        } catch {
            Write-Issue "Global .gitignore setup failed: $($_.Exception.Message)" -Track "Global .gitignore"
        }
    }
}

function Set-GitCommitSigning {
    <#
    .SYNOPSIS
        Configures git to sign commits with the local SSH key.
    .DESCRIPTION
        Sets gpg.format to ssh, enables commit.gpgsign, and creates an
        allowed_signers file for local signature verification. Skips if
        SSH signing is already configured.
    #>
    Write-Step "Git Commit Signing (SSH)"

    $gpgFormat = git config --global gpg.format 2>$null
    if ($gpgFormat -eq "ssh") {
        Write-Skip "Git commit signing is already configured" -Track "Git Signing"
        return
    }

    $signingKey = Join-Path $env:USERPROFILE ".ssh\id_ed25519.pub"
    if (Test-Path $signingKey) {
        try {
            git config --global gpg.format ssh
            git config --global user.signingkey $signingKey
            git config --global commit.gpgsign true

            # Configure allowed signers file for local SSH signature verification
            $allowedSignersPath = Join-Path $env:USERPROFILE ".ssh\allowed_signers"
            $gitEmail = git config --global user.email 2>$null
            if ($gitEmail) {
                $pubKeyContent = Get-Content $signingKey
                "$gitEmail $pubKeyContent" | Set-Content $allowedSignersPath -Encoding UTF8
                git config --global gpg.ssh.allowedSignersFile $allowedSignersPath
                Write-Change "Git commit signing configured with allowed signers file" -Track "Git Signing"
            } else {
                Write-Host "  Git user.email not set -- skipping allowed signers file." -ForegroundColor Yellow
                Write-Host "  Run Set-GitIdentity first, then re-run this script." -ForegroundColor Yellow
                Write-Change "Git commit signing configured (allowed signers pending)" -Track "Git Signing"
            }
        } catch {
            Write-Issue "Git signing config failed: $($_.Exception.Message)" -Track "Git Signing"
        }
    } else {
        Write-Host "  SSH signing key not found at $signingKey -- skipping git signing setup" -ForegroundColor Yellow
    }
}

function Set-DeltaGitConfig {
    <#
    .SYNOPSIS
        Configures delta as the default git diff pager.
    .DESCRIPTION
        Sets core.pager, interactive.diffFilter, and delta options
        (navigate, side-by-side, dark mode) in the global git config.
        Skips if delta is already the configured pager.
    #>
    Write-Step "Delta Git Diff"

    $deltaConfigured = git config --global core.pager 2>$null
    if ($deltaConfigured -eq "delta") {
        Write-Skip "Delta is already configured as git pager" -Track "Delta Config"
        return
    }

    try {
        git config --global core.pager "delta"
        git config --global interactive.diffFilter "delta --color-only"
        git config --global delta.navigate true
        git config --global delta.light false
        git config --global delta.side-by-side true
        git config --global merge.conflictstyle "diff3"
        git config --global diff.colorMoved "default"
        Write-Change "Delta configured as git pager" -Track "Delta Config"
    } catch {
        Write-Issue "Delta git config failed: $($_.Exception.Message)" -Track "Delta Config"
    }
}

function Set-GitIdentity {
    <#
    .SYNOPSIS
        Checks that git user.name and user.email are configured.
    .DESCRIPTION
        Verifies global git identity is set. If either value is missing,
        displays the commands needed to configure them.
    #>
    Write-Step "Git Identity"

    $name = git config --global user.name 2>$null
    $email = git config --global user.email 2>$null

    if ($name -and $email) {
        Write-Verbose "Git identity: $name / $email"
        Write-Skip "Git identity already configured ($name / $email)" -Track "Git Identity"
        return
    }

    Write-Host "  Git user identity is not configured." -ForegroundColor Yellow
    Write-Host "  Commits will fail until you set these. Run the following:" -ForegroundColor Yellow
    Write-Host "    git config --global user.name 'Your Name'" -ForegroundColor Yellow
    Write-Host "    git config --global user.email 'you@example.com'" -ForegroundColor Yellow
}

function Set-DefenderExclusions {
    <#
    .SYNOPSIS
        Adds developer directories to Windows Defender exclusion paths.
    .DESCRIPTION
        Excludes Projects, .pyenv, .local, and .venv under the user
        profile from real-time scanning to reduce build/test overhead.
    #>
    Write-Step "Windows Defender Exclusions"

    if (-not (Get-Command Get-MpPreference -ErrorAction SilentlyContinue)) {
        Write-Skip "Windows Defender not found -- skipping" -Track "Defender"
        return
    }

    $exclusions = @(
        "$env:USERPROFILE\Projects",
        "$env:USERPROFILE\.pyenv",
        "$env:USERPROFILE\.local",
        "$env:USERPROFILE\.venv"
    )

    foreach ($path in $exclusions) {
        try {
            $existing = (Get-MpPreference).ExclusionPath
            if ($existing -contains $path) {
                Write-Skip "$path is already excluded" -Track "Defender"
            } else {
                Add-MpPreference -ExclusionPath $path
                Write-Change "Added exclusion: $path" -Track "Defender"
            }
        } catch {
            Write-Issue "Failed to add exclusion for $path -- $($_.Exception.Message)" -Track "Defender"
        }
    }
}

function Set-VSCodeSettings {
    <#
    .SYNOPSIS
        Deploys VS Code settings.json via Apply-VSCodeSettings.ps1.
    .DESCRIPTION
        Delegates to Apply-VSCodeSettings.ps1 -SettingsOnly to copy the
        canonical settings file into the VS Code user configuration directory.
    #>
    Write-Step "VS Code Settings"
    & "$PSScriptRoot\Apply-VSCodeSettings.ps1" -SettingsOnly
}

function Install-VSCodeExtensions {
    <#
    .SYNOPSIS
        Installs VS Code extensions via Apply-VSCodeSettings.ps1.
    .DESCRIPTION
        Delegates to Apply-VSCodeSettings.ps1 -ExtensionsOnly to install
        the standard set of VS Code extensions.
    #>
    Write-Step "VS Code Extensions"
    & "$PSScriptRoot\Apply-VSCodeSettings.ps1" -ExtensionsOnly
}

function Set-PowerShellProfile {
    <#
    .SYNOPSIS
        Deploys the canonical PowerShell profile to $PROFILE.
    .DESCRIPTION
        Delegates to Apply-PowerShellProfile.ps1 which backs up any
        existing profile and copies the repo's profile.ps1 into place.
    #>
    Write-Step "PowerShell Profile"
    & "$PSScriptRoot\Apply-PowerShellProfile.ps1"
}

function New-PyprojectToml {
    <#
    .SYNOPSIS
        Scaffolds a pyproject.toml with default ruff and mypy settings.
    .DESCRIPTION
        Creates a minimal pyproject.toml in the specified directory with
        ruff lint/format rules and mypy configuration. Skips if the file
        already exists.
    .PARAMETER Path
        Directory where the pyproject.toml should be created.
    #>
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Issue "Directory not found: $Path"
        return
    }

    $tomlPath = Join-Path $Path "pyproject.toml"
    if (Test-Path $tomlPath) {
        Write-Skip "pyproject.toml already exists in $Path"
        return
    }

    $content = @'
[tool.ruff]
line-length = 88

[tool.ruff.lint]
select = ["E", "F", "I"]

[tool.ruff.format]
quote-style = "double"
indent-style = "space"

[tool.mypy]
strict = false
'@

    Set-Content -Path $tomlPath -Value $content -Encoding UTF8
    Write-Change "pyproject.toml scaffolded in $Path"
}

function Test-ProfileHealth {
    <#
    .SYNOPSIS
        Validates that the PowerShell profile contains all expected sections.
    .DESCRIPTION
        Reads $PROFILE and checks for known markers (SSH agent, Chocolatey,
        fzf, Oh My Posh, etc.). Reports any missing sections and suggests
        redeploying the profile to fix them.
    #>
    Write-Step "Profile Health Check"

    if (-not (Test-Path $PROFILE)) {
        Write-Issue "No PowerShell profile found at $PROFILE"
        Write-Host "  Run '.\Setup-DevEnvironment.ps1 -IncludeOptional' or '.\Apply-PowerShellProfile.ps1' to deploy it." -ForegroundColor Yellow
        return
    }

    $content = Get-Content $PROFILE -Raw

    $expectedSections = @{
        "SSH Agent"         = "ssh-agent"
        "Chocolatey"        = "chocolateyProfile"
        "winSetup"          = "WINSETUP"
        "Python Tools"      = "Setup-PythonTools"
        "fzf"               = "FZF_DEFAULT_COMMAND"
        "PSFzf"             = "Import-Module PSFzf"
        "PSReadLine"        = "PredictionSource"
        "zoxide"            = "zoxide init"
        "zoxide OMP fix"    = "__zoxide_omp_prompt"
        "pyenv-win"         = "PYENV"
        "lazygit alias"     = "Set-Alias lg lazygit"
        "delta"             = "DELTA_FEATURES"
        "bat alias"         = "Set-Alias cat bat"
        "Ctrl+F binding"    = "Ctrl\+f"
        "Git aliases"       = "function gs"
        "gl alias fix"      = "Remove-Alias.*gl"
        "gc alias fix"      = "Remove-Alias.*gc"
        "Oh My Posh"        = "oh-my-posh init"
        "Test-ProfileHealth" = "function Test-ProfileHealth"
        "Invoke-DevSetup"   = "function Invoke-DevSetup"
        "Invoke-DevUpdate"  = "function Invoke-DevUpdate"
        "Show-DevEnvironment" = "function Show-DevEnvironment"
    }

    $missing = @()
    foreach ($section in $expectedSections.GetEnumerator()) {
        if ($content -notmatch $section.Value) {
            $missing += $section.Key
        }
    }

    if ($missing.Count -eq 0) {
        Write-Skip "Profile is complete -- all expected sections present"
    } else {
        Write-Host "  Profile is incomplete. Missing sections:" -ForegroundColor Yellow
        foreach ($m in $missing) {
            Write-Host "    - $m" -ForegroundColor Yellow
        }
        Write-Host "  Run '.\Apply-PowerShellProfile.ps1' to redeploy the full profile." -ForegroundColor Yellow
    }
}

# =============================================================================
# Main Execution
# =============================================================================

# Short-circuit: pyproject scaffold
if ($ScaffoldPyproject) {
    New-PyprojectToml -Path $ScaffoldPyproject
    return
}

# Short-circuit: profile health check only
if ($CheckProfileOnly) {
    $script:CurrentStep = 0
    $TotalSteps = 1
    Test-ProfileHealth
    return
}

# Short-circuit: dry-run preview
if ($WhatIf) {
    Write-Host "`n=== Dry Run -- no changes will be made ===" -ForegroundColor Cyan
    Write-Host "Previewing what Setup-DevEnvironment.ps1 would do.`n" -ForegroundColor DarkGray

    $script:CurrentStep = 0
    $TotalSteps = if ($IncludeOptional) { $CoreSteps + $OptionalSteps } else { $CoreSteps }
    $wouldRun  = 0
    $wouldSkip = 0

    # Detection table -- each entry mirrors the check from the corresponding
    # Install-*/Set-* function. Checks are read-only (Get-Command, Test-Path,
    # git config queries). No tools are installed or files modified.
    $dryRunSteps = @(
        @{ Name = 'Profile Health Check'; Present = { Test-Path $PROFILE } }
        @{ Name = 'Chocolatey';           Present = { [bool](Get-Command choco -ErrorAction SilentlyContinue) } }
        @{ Name = 'VS Code';              Present = { [bool](Get-Command code -ErrorAction SilentlyContinue) } }
        @{ Name = 'Python';               Present = {
            $p = Get-Command python -ErrorAction SilentlyContinue
            $p -and $p.Source -notlike '*WindowsApps*'
        } }
        @{ Name = 'Oh My Posh';           Present = { [bool](Get-Command oh-my-posh -ErrorAction SilentlyContinue) } }
        @{ Name = 'GitHub CLI';           Present = { [bool](Get-Command gh -ErrorAction SilentlyContinue) } }
        @{ Name = 'fzf + fd + PSFzf';     Present = {
            (Get-Command fzf -ErrorAction SilentlyContinue) -and
            (Get-Command fd -ErrorAction SilentlyContinue) -and
            (Get-Module PSFzf -ListAvailable)
        } }
        @{ Name = 'CLI Tools (zoxide, bat, ripgrep, delta, lazygit)'; Present = {
            (Get-Command zoxide -ErrorAction SilentlyContinue) -and
            (Get-Command bat -ErrorAction SilentlyContinue) -and
            (Get-Command rg -ErrorAction SilentlyContinue) -and
            (Get-Command delta -ErrorAction SilentlyContinue) -and
            (Get-Command lazygit -ErrorAction SilentlyContinue)
        } }
        @{ Name = 'Hack Nerd Font';       Present = {
            [bool](Get-ChildItem 'C:\Windows\Fonts' -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Hack*' })
        } }
        @{ Name = 'SSH Keys';             Present = { Test-Path (Join-Path $env:USERPROFILE '.ssh\id_ed25519') } }
        @{ Name = 'GitHub SSH Key Upload'; Present = {
            # Simplified: check that gh is available, key exists, and gh is authenticated
            (Get-Command gh -ErrorAction SilentlyContinue) -and
            (Test-Path (Join-Path $env:USERPROFILE '.ssh\id_ed25519.pub'))
        } }
        @{ Name = 'Windows Terminal Font'; Present = {
            $wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
            if (-not (Test-Path $wt)) { $false }
            else {
                try {
                    $s = Get-Content $wt -Raw | ConvertFrom-Json
                    $s.profiles.defaults.PSObject.Properties['font'] -and
                    $s.profiles.defaults.font.face -eq 'Hack Nerd Font'
                } catch { $false }
            }
        } }
        @{ Name = 'Python Tools (pipx)';  Present = {
            if (-not (Get-Command pipx -ErrorAction SilentlyContinue)) { $false }
            else {
                $installed = pipx list --short 2>$null | ForEach-Object { ($_ -split '\s+')[0].Trim().ToLower() }
                $needed = @('pylint','mypy','ruff','bandit','pre-commit','cookiecutter')
                -not ($needed | Where-Object { $installed -notcontains $_ })
            }
        } }
        @{ Name = 'pyenv-win';            Present = { Test-Path (Join-Path $env:USERPROFILE '.pyenv') } }
        @{ Name = 'Global .gitignore';    Present = { Test-Path (Join-Path $env:USERPROFILE '.gitignore_global') } }
        @{ Name = 'Git Identity';         Present = {
            $n = git config --global user.name 2>$null
            $e = git config --global user.email 2>$null
            $n -and $e
        } }
        @{ Name = 'Git Commit Signing (SSH)'; Present = { (git config --global gpg.format 2>$null) -eq 'ssh' } }
        @{ Name = 'Delta Git Diff';       Present = { (git config --global core.pager 2>$null) -eq 'delta' } }
    )

    if ($IncludeOptional) {
        $dryRunSteps += @(
            @{ Name = 'VS Code Settings';           Present = { $false } }  # always deploys
            @{ Name = 'VS Code Extensions';          Present = { $false } }  # always runs
            @{ Name = 'PowerShell Profile';          Present = { $false } }  # always deploys
            @{ Name = 'Windows Defender Exclusions';  Present = {
                if (-not (Get-Command Get-MpPreference -ErrorAction SilentlyContinue)) { $false }
                else {
                    $existing = (Get-MpPreference).ExclusionPath
                    $paths = @("$env:USERPROFILE\Projects","$env:USERPROFILE\.pyenv","$env:USERPROFILE\.local","$env:USERPROFILE\.venv")
                    -not ($paths | Where-Object { $existing -notcontains $_ })
                }
            } }
        )
    }

    foreach ($step in $dryRunSteps) {
        Write-Step $step.Name
        $present = try { & $step.Present } catch { $false }
        if ($present) {
            Write-Skip "$($step.Name) -- already present"
            $wouldSkip++
        } else {
            Write-Host "  Would install/configure: $($step.Name)" -ForegroundColor Yellow
            $wouldRun++
        }
    }

    Write-Host "`n=== Dry Run Summary ===" -ForegroundColor Cyan
    Write-Host "  Would run:  $wouldRun steps" -ForegroundColor Yellow
    Write-Host "  Would skip: $wouldSkip steps (already present)" -ForegroundColor DarkGray
    Write-Host "  Total:      $($wouldRun + $wouldSkip) steps" -ForegroundColor White
    Write-Host "`nRun without -WhatIf to apply changes.`n" -ForegroundColor DarkGray
    exit 0
}

# Short-circuit: install a single named tool
if ($InstallTool) {
    # Start transcript for install logging (mirrors Uninstall-Tool.ps1)
    $installLogDir = Join-Path $PSScriptRoot 'logs'
    if (-not (Test-Path $installLogDir)) { New-Item -ItemType Directory -Path $installLogDir | Out-Null }
    $installLogFile = Join-Path $installLogDir "install-$InstallTool-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    Start-Transcript -Path $installLogFile -Force

    # Map friendly names to install functions for built-in multi-tool functions.
    $toolFunctions = @{
        'chocolatey'  = 'Install-Chocolatey'
        'vscode'      = 'Install-VSCode'
        'python'      = 'Install-Python'
        'ohmyposh'    = 'Install-OhMyPosh'
        'gh'          = 'Install-GitHubCLI'
        'fzf'         = 'Install-Fzf'
        'ripgrep'     = 'Install-CLITools'
        'bat'         = 'Install-CLITools'
        'delta'       = 'Install-CLITools'
        'lazygit'     = 'Install-CLITools'
        'zoxide'      = 'Install-CLITools'
        'fd'          = 'Install-CLITools'
        'hacknerd'    = 'Install-HackNerdFont'
        'pythontools' = 'Install-PythonTools'
        'ruff'        = 'Install-PythonTools'
        'pylint'      = 'Install-PythonTools'
        'mypy'        = 'Install-PythonTools'
        'bandit'      = 'Install-PythonTools'
        'pre-commit'  = 'Install-PythonTools'
        'cookiecutter'= 'Install-PythonTools'
        'pyenv'       = 'Install-PyenvWin'
    }
    $key = $InstallTool.ToLower()
    $func = $toolFunctions[$key]

    # Fallback: tools added via the Add Tool wizard create Install-<Name>
    # functions that aren't in the hardcoded table. Try by convention.
    if (-not $func) {
        $safeName = $InstallTool -replace '[^a-zA-Z0-9]', ''
        $candidate = "Install-$safeName"
        if (Get-Command $candidate -CommandType Function -ErrorAction SilentlyContinue) {
            $func = $candidate
        }
    }

    if (-not $func) {
        Write-Host "Unknown tool: $InstallTool" -ForegroundColor Red
        Write-Host "`nAvailable tools:" -ForegroundColor Yellow
        $toolFunctions.Keys | Sort-Object | ForEach-Object { Write-Host "  $_" }
        # Also list wizard-added Install-* functions not in the table
        Get-Command 'Install-*' -CommandType Function -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin $toolFunctions.Values } |
            ForEach-Object { Write-Host "  $($_.Name -replace '^Install-', '')" }
        Stop-Transcript
        return
    }

    Write-Host "`n=== Installing: $InstallTool ===" -ForegroundColor Cyan
    $script:CurrentStep = 0
    $TotalSteps = 1
    $script:Installed = [System.Collections.Generic.List[string]]::new()
    $script:Skipped   = [System.Collections.Generic.List[string]]::new()
    $script:Failed    = [System.Collections.Generic.List[string]]::new()
    & $func
    Write-Summary
    Write-Host "Transcript: $installLogFile" -ForegroundColor DarkGray
    Stop-Transcript
    return
}

# PowerShell 7+ required
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7 or later. Current version: $($PSVersionTable.PSVersion)" -ForegroundColor Red
    Write-Host "Download PowerShell 7 from: https://aka.ms/powershell" -ForegroundColor Yellow
    exit 1
}

# Transcript logging
$logsDir = "$PSScriptRoot\logs"
if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }
$logPath = "$logsDir\setup-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
Start-Transcript -Path $logPath
Write-Host "Logging to: $logPath" -ForegroundColor DarkGray


# Outcome tracking
$script:Installed = [System.Collections.Generic.List[string]]::new()
$script:Skipped   = [System.Collections.Generic.List[string]]::new()
$script:Failed    = [System.Collections.Generic.List[string]]::new()

# Set WINSETUP to the directory this script lives in.
# This is reliable regardless of where the repo is cloned.
# Persisted to User environment so it survives terminal restarts.
$env:WINSETUP = $PSScriptRoot
[System.Environment]::SetEnvironmentVariable("WINSETUP", $PSScriptRoot, "User")
Write-Host "  WINSETUP set to: $env:WINSETUP" -ForegroundColor DarkGray

# Main setup
if ($env:USERPROFILE -match ' ') {
    Write-Host ""
    Write-Host "  Warning: Your profile path contains a space ('$env:USERPROFILE')." -ForegroundColor Yellow
    Write-Host "  If you have not already migrated pipx to C:\pipx, tools may not update" -ForegroundColor Yellow
    Write-Host "  correctly. See TROUBLESHOOTING.md -- 'pipx space in home path' for steps." -ForegroundColor Yellow
    Write-Host "  If you have already migrated pipx, this warning can be ignored." -ForegroundColor DarkGray
    Write-Host ""
}
Assert-Administrator

Test-ProfileHealth

Write-Verbose "Running as: $($env:USERNAME)"
Write-Verbose "Script root: $PSScriptRoot"
Write-Verbose "IncludeOptional: $IncludeOptional"
Write-Host "`n=== Dev Environment Setup ===" -ForegroundColor Cyan
Write-Host "Script root: $PSScriptRoot"

Install-Chocolatey
Install-VSCode
Install-Python
Install-OhMyPosh
Install-GitHubCLI
Install-Fzf
Install-CLITools
Install-HackNerdFont
Install-SSHKeys
Add-GitHubSSHKey
Set-WindowsTerminalFont
Install-PythonTools
Install-PyenvWin
Set-GlobalGitIgnore
Set-GitIdentity
Set-GitCommitSigning
Set-DeltaGitConfig

if ($IncludeOptional) {
    Set-VSCodeSettings
    Install-VSCodeExtensions
    Set-PowerShellProfile
    Set-DefenderExclusions
} else {
    Write-Host "`nSkipping optional steps (VS Code settings, extensions, profile, Defender exclusions)." -ForegroundColor DarkGray
    Write-Host "These are normally applied automatically by VS Code Settings Sync and OneDrive." -ForegroundColor DarkGray
    Write-Host "Pass -IncludeOptional to apply them manually as a fallback." -ForegroundColor DarkGray
}

Write-Summary
Write-Host "`n=== Setup complete ===`n" -ForegroundColor Cyan
Stop-Transcript
