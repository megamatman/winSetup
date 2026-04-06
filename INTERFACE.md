# winSetup Interface Contract

This document defines the stable interfaces that consumers of winSetup
(primarily winTerface) depend on. Changes to any item documented here must
be coordinated across both projects.

**Contract version: 1**

Check the version programmatically via `$script:ContractVersion` defined
near the top of `Setup-DevEnvironment.ps1`.

---

## $PackageRegistry format

Defined in `Update-DevEnvironment.ps1`. A PowerShell hashtable mapping
friendly tool names to their update method.

### Structure

```powershell
$PackageRegistry = @{
    "<key>" = @{ Manager = "<manager>"; Id = "<package-id>" }
}
```

### Fields

| Field | Required | Description |
|-------|----------|-------------|
| Key (outer) | Yes | Lowercase friendly name used in CLI commands (e.g. `ruff`, `fzf`). |
| `Manager` | Yes | Package manager identifier. See allowed values below. |
| `Id` | Yes | Package identifier passed to the manager's install/upgrade command. |

### Allowed Manager values

| Value | Package manager | Install command pattern |
|-------|----------------|----------------------|
| `choco` | Chocolatey | `choco upgrade <Id> -y` |
| `winget` | Windows Package Manager | `winget upgrade --id <Id> --exact --silent` |
| `pipx` | pipx (Python CLI tools) | `pipx upgrade <Id>` |
| `module` | PowerShell Gallery | `Install-Module <Id> -Force -Scope CurrentUser` |
| `pyenv` | pyenv-win (pip) | `pip install <Id> --upgrade --target ...` |

### Example entry

```powershell
"ruff" = @{ Manager = "pipx"; Id = "ruff" }
```

### Parsing convention

Consumers that need to read `$PackageRegistry` without executing the file
should use regex extraction matching this pattern:

```
"([^"]+)"\s*=\s*@\{\s*Manager\s*=\s*"([^"]+)";\s*Id\s*=\s*"([^"]+)"\s*\}
```

This is the pattern used by `Uninstall-Tool.ps1`.

---

## Install-* function naming convention

Each managed tool has a corresponding install function in
`Setup-DevEnvironment.ps1` following this pattern:

```
Install-<PascalCaseName>
```

Where `<PascalCaseName>` is the display name with all non-alphanumeric
characters stripped. Examples:

| Display name | Function name |
|-------------|---------------|
| Chocolatey | `Install-Chocolatey` |
| ruff | `Install-ruff` |
| Oh My Posh | `Install-OhMyPosh` |

### Requirements

- The function must be defined in `Setup-DevEnvironment.ps1`.
- It must contain exactly one `Write-Step` call.
- winTerface's `-InstallTool` dispatch and `Uninstall-Tool.ps1` Step 2
  both depend on this naming convention.

---

## $CoreSteps variable

Defined in `Setup-DevEnvironment.ps1`:

```powershell
$CoreSteps = 18
```

### Semantics

- Must equal the number of `Write-Step` calls in the core execution path
  (between `Assert-Administrator` and the `if ($IncludeOptional)` block).
- `$OptionalSteps = 4` covers the optional block.
- `Uninstall-Tool.ps1` decrements `$CoreSteps` by 1 when removing a tool.
- winTerface validates the count via the existing Pester regression test.

---

## Profile section comment patterns

`profile.ps1` uses a consistent comment block to delimit each managed
section:

```powershell
# ==============================================================================
# <Section Name>
# ==============================================================================
```

The three-line pattern is: a line of `=` characters, the section name, and
another line of `=` characters. The section name appears on the middle line
preceded by `# `.

### How sections are identified

`Uninstall-Tool.ps1` Step 4 identifies lines belonging to a tool using
word-boundary matching on the tool name and `Set-Alias` pattern matching.
It does **not** parse the comment headers directly. Comment lines
(`^\s*#`) are excluded from removal to avoid accidentally deleting section
headers for other tools.

`Test-ProfileHealth` in `Setup-DevEnvironment.ps1` uses regex patterns to
verify section presence. The expected patterns are defined in the
`$expectedSections` hashtable within that function.

### Adding a new section

New profile sections must follow the same three-line comment header format
so that `Test-ProfileHealth` can detect them and `Uninstall-Tool.ps1` can
safely remove tool-specific lines beneath them.

---

## -InstallTool parameter

`Setup-DevEnvironment.ps1` accepts a `-InstallTool <string>` parameter
that installs a single named tool without running the full setup.

### Dispatch rules

1. Look up the name in a hardcoded `$toolFunctions` table mapping friendly
   names to `Install-*` function names.
2. If not found, sanitise the name (strip non-alphanumeric characters) and
   check for an `Install-<SanitisedName>` function via
   `Get-Command -CommandType Function`.
3. If still not found, list available tools and exit.

### Consumer usage

winTerface calls this parameter to install tools from the Tools screen and
after the Add Tool wizard completes. The fallback in step 2 allows
wizard-added tools (not in the hardcoded table) to be installed.

---

## Breaking vs non-breaking changes

### Breaking changes (increment contract version)

- Renaming or removing a `$PackageRegistry` key.
- Changing the `Manager` or `Id` field names in `$PackageRegistry`.
- Adding a new required field to `$PackageRegistry` entries.
- Changing the `Install-*` function naming convention.
- Changing the profile section comment header format.
- Removing or renaming the `-InstallTool` parameter.
- Changing the `$CoreSteps` variable name or its decrement contract.

### Non-breaking changes (no version increment needed)

- Adding a new entry to `$PackageRegistry`.
- Adding a new `Install-*` function.
- Adding a new allowed `Manager` value (consumers should handle unknown
  values gracefully).
- Adding a new optional field to `$PackageRegistry` entries.
- Changing the implementation of an existing `Install-*` function without
  renaming it.
- Adding new profile sections following the existing comment format.
- Adding new parameters to `Setup-DevEnvironment.ps1` that do not affect
  existing parameters.

---

## Version history

| Version | Date | Changes |
|---------|------|---------|
| 1 | 2026-04-06 | Initial contract. Documents $PackageRegistry, Install-* naming, $CoreSteps, profile patterns, -InstallTool dispatch. |
