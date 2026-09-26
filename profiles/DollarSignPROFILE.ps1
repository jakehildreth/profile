# DollarSignPROFILE.ps1
# Version 2026.9.260812
# https://github.com/jakehildreth/profile/profiles/DollarSignPROFILE.ps1

#region Self-Update
try {
    $__installerContent = (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/jakehildreth/profile/refs/heads/main/installers/Install-DollarSignPROFILE.ps1' -UseBasicParsing -TimeoutSec 3).Content
    Invoke-Expression $__installerContent
} catch {
    # Network unavailable or timeout — continue loading profile as-is
} finally {
    Remove-Variable -Name __installerContent -ErrorAction SilentlyContinue
}
#endregion Self-Update

[Console]::OutputEncoding = [Text.Encoding]::UTF8

# Enable Ctrl+U to clear line on Windows
Set-PSReadLineKeyHandler -Chord 'Ctrl+u' -Function BackwardDeleteLine

# Enable ESC to clear full comand on macOS
Set-PSReadLineKeyHandler -Chord 'Escape' -Function RevertLine

# Make Alt+Arrow and Ctrl+Arrow work the same on Mac+Windows
Set-PSReadLineKeyHandler -Chord 'Alt+LeftArrow'  -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Alt+RightArrow' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow'  -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord

# Make Ctrl+Backspace and Alt+Backspace work the same on Mac+Windows
Set-PSReadLineKeyHandler -Chord 'Ctrl+Backspace' -Function BackwardDeleteWord
Set-PSReadLineKeyHandler -Chord 'Alt+Backspace' -Function BackwardDeleteWord

# Make Ctrl+Delete and Alt+Delete work the same on Mac+Windows
Set-PSReadLineKeyHandler -Chord 'Ctrl+Delete' -Function DeleteWord
Set-PSReadLineKeyHandler -Chord 'Alt+Delete' -Function DeleteWord

function Get-CalVer {
    [Alias('calver')]
    param()
    (Get-Date -Format yyyy.M.dHHmm).ToString()
}

function New-Credential {
    param(
        [string]$User
    )

    Write-Host @"

PowerShell credential request
Enter your credentials.
"@
    if ($null -eq $User) { $User = Read-Host "User" }
    $Password = Read-Host "Password for user $User" -AsSecureString
    $Credential = [System.Management.Automation.PSCredential]::New($User, $Password)

    $Credential
}

function New-Function {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [ValidateScript({ (Get-Verb).Verb -contains $_ })]
        [string]$Verb,
        [Parameter(Mandatory, Position = 1)]
        [string]$Noun,
        [Parameter(Mandatory, Position = 2)]
        [string]$Path
    )

    #requires -Version 5

    $FunctionName = "$Verb-$Noun"
    $Path = Join-Path -Path $Path -ChildPath "$($FunctionName).ps1"
    $Framework = @"
function $FunctionName {
    <#
        .SYNOPSIS

        .DESCRIPTION

        .PARAMETER Parameter

        .INPUTS

        .OUTPUTS

        .EXAMPLE

        .LINK
    #>
    [CmdletBinding()]
    param (
    )

    #requires -Version 5.1

    begin {
    }

    process {
    }

    end {
    }
}
"@
    $Framework | Out-File -FilePath $Path
}

function prompt {
    Write-Host
    $CurrentLocation = $executionContext.SessionState.Path.CurrentLocation
    $GitBranch = & { $ErrorActionPreference = 'SilentlyContinue'; git rev-parse --abbrev-ref HEAD 2>&1 } | Where-Object { $_ -is [string] }
    if ($LASTEXITCODE -eq 0 -and $GitBranch -and $GitBranch -ne 'HEAD') {
        Write-Host "[$($Host.UI.RawUI.WindowSize.Width)x$($Host.UI.RawUI.WindowSize.Height)] $($CurrentLocation.ToString() -ireplace [regex]::escape($HOME),'~') [$GitBranch]"
    } else {
        Write-Host "[$($Host.UI.RawUI.WindowSize.Width)x$($Host.UI.RawUI.WindowSize.Height)] $($CurrentLocation.ToString() -ireplace [regex]::escape($HOME),'~')"
    }
    "PS$($PSVersionTable.PSVersion.Major)$('>' * ($nestedPromptLevel + 1)) "
}

$PSDefaultParameterValues = @{
    'Out-Default:OutVariable' = 'LastOutput' # Saves output of the last command to the variable $LastOutput
}

function Get-IPAddress {
    if (Test-Path -Path /bin/zsh) {
        'for i in $(ifconfig -l); do
        case $i in
        (lo0)
            ;;
        (*)
            set -- $(ifconfig $i | grep "inet [1-9]")
            if test $# -gt 1; then
                echo $i: $2
            fi
        esac
        done' | /bin/zsh
    } elseif (Get-Command -Name Get-NetIPAddress) {
        Get-NetIPAddress | Where-Object AddressFamily -EQ 'IPv4' | ForEach-Object {
            "$($_.InterfaceAlias): $($_.IPAddress)"
        }
    } else {
        Write-Warning 'No IP address retrieval method found.'
    }
}

function Get-AgentInstructions {
    [Alias('gai')]
    param()
    @'
---
description: "Install or update Jake's global user-level agent instructions, agents, and skills from raw URLs"
version: "2026.9.260812"
---

# Install Global Agent Instructions, Agents, and Skills

Create or update my user-level agent content so it applies automatically to every workspace,
regardless of which agent, harness, or model I am using, without me having to paste URLs at the
start of each chat.

## Instruction source URLs to fetch

1. **Personal instructions:** `https://raw.githubusercontent.com/jakehildreth/jakehildreth/refs/heads/main/.github/copilot-instructions.md`
2. **PowerShell best practices:** `https://raw.githubusercontent.com/github/awesome-copilot/refs/heads/main/instructions/powershell.instructions.md`
3. **Pester v6 best practices:** `https://raw.githubusercontent.com/github/awesome-copilot/refs/heads/main/instructions/powershell-pester-6.instructions.md`
4. **C# best practices:** `https://raw.githubusercontent.com/github/awesome-copilot/6c4d33b9cfca967a28bb2962ef4d55e4a384c88c/instructions/csharp.instructions.md`

## Agent source URLs to fetch

1. `https://raw.githubusercontent.com/github/awesome-copilot/6c4d33b9cfca967a28bb2962ef4d55e4a384c88c/agents/CSharpExpert.agent.md`
2. `https://raw.githubusercontent.com/github/awesome-copilot/6c4d33b9cfca967a28bb2962ef4d55e4a384c88c/agents/csharp-dotnet-janitor.agent.md`

## Skill source URLs to fetch

1. `https://raw.githubusercontent.com/github/awesome-copilot/main/skills/pester-migration/SKILL.md`
2. `https://raw.githubusercontent.com/github/awesome-copilot/main/skills/pester-migration/references/v3-to-v4.md`
3. `https://raw.githubusercontent.com/github/awesome-copilot/main/skills/pester-migration/references/v4-to-v5.md`
4. `https://raw.githubusercontent.com/github/awesome-copilot/main/skills/pester-migration/references/v5-to-v6.md`
5. `https://raw.githubusercontent.com/github/awesome-copilot/6c4d33b9cfca967a28bb2962ef4d55e4a384c88c/skills/csharp-docs/SKILL.md`

## Target location

Create the directory tree if it does not exist:

```
~/.agents/instructions/
~/.agents/agents/
~/.agents/skills/pester-migration/references/
~/.agents/skills/csharp-docs/
```

`~/.agents/` is the harness-agnostic canonical home for user-level agent content. The files below
are the single source of truth; per-harness locations (next section) point at them instead of
holding their own copies.

## Instruction files to create/update in `~/.agents/instructions/`

| File | Content |
|---|---|
| `personal.md` | Jake's interaction guidelines, dev standards, TDD, CalVer, conventional commits, no-emoji rule, git workflow, plus references to the other instruction files. |
| `powershell.md` | PowerShell cmdlet best practices: naming, parameter design, `[switch]` vs `[bool]`, pipeline/output, error handling, comment-based help, aliases. |
| `pester.md` | Pester v6 best practices: file structure, Describe/Context/It, assertions, mocking, data-driven tests, tags, skip, configuration. |
| `csharp.md` | C# development best practices. |

These are plain markdown with NO frontmatter. Harness-specific `applyTo` scoping lives only in the
per-harness pointer files, not here.

## Agent files to create/update in `~/.agents/agents/`

| File | Content |
|---|---|
| `CSharpExpert.agent.md` | C# Expert agent: expert C#/.NET development assistance. |
| `csharp-dotnet-janitor.agent.md` | C#/.NET Janitor agent: cleanup, modernization, and tech debt remediation for C#/.NET codebases. |

Write agent files verbatim from upstream, frontmatter included. Do NOT strip, add, or modify
anything.

## Per-harness pointer files

Wire each installed harness to the canonical files. Create a pointer ONLY for harnesses already
installed or configured on this machine; do not create directories for harnesses I do not use.
Prefer symlinks from the harness location to the `~/.agents/` files where the harness supports
them; otherwise create the small pointer files described below.

| Harness | Pointer location | Pointer content |
|---|---|---|
| omp | `~/.omp/agent/AGENTS.md` | Ensure it reads (or references) `~/AGENTS.md` first, then the four `~/.agents/instructions/` files (`personal.md`, `powershell.md`, `pester.md`, `csharp.md`). omp has no `applyTo` scoping; its global AGENTS.md is always in context. Do NOT overwrite existing content; merge around it. |
| omp | `~/.omp/agent/skills/` | Symlink (or copy) `pester-migration/` and `csharp-docs/` from `~/.agents/skills/`. |
| Claude Code | `~/.claude/CLAUDE.md` | Append (if not already present) `@~/.agents/instructions/personal.md`, `@~/.agents/instructions/powershell.md`, `@~/.agents/instructions/pester.md`, `@~/.agents/instructions/csharp.md` import lines. |
| Claude Code | `~/.claude/agents/` | Symlink (or copy) `CSharpExpert.agent.md` and `csharp-dotnet-janitor.agent.md` from `~/.agents/agents/`. |
| VS Code Copilot | `~/.copilot/instructions/*.instructions.md` | One file per source (`personal.instructions.md`, `powershell.instructions.md`, `pester.instructions.md`, `csharp.instructions.md`) with YAML frontmatter (`applyTo`: `**/*` for personal, `**/*.ps1,**/*.psm1` for powershell, `**/*.Tests.ps1` for pester, `**/*.cs` for csharp) and a body that references the matching `~/.agents/instructions/` file. |
| Any harness supporting `AGENTS.md` | `~/AGENTS.md` | Markdown that includes or references the four `~/.agents/instructions/` files. |

Do NOT overwrite existing non-pointer content in `~/.claude/CLAUDE.md` or `~/AGENTS.md`; merge or
append around it.

## Skills to install

Install into the canonical skills folder under `~/.agents/skills/`.

| Source file | Target path |
|---|---|
| `pester-migration/SKILL.md` | `~/.agents/skills/pester-migration/SKILL.md` |
| `pester-migration/references/v3-to-v4.md` | `~/.agents/skills/pester-migration/references/v3-to-v4.md` |
| `pester-migration/references/v4-to-v5.md` | `~/.agents/skills/pester-migration/references/v4-to-v5.md` |
| `pester-migration/references/v5-to-v6.md` | `~/.agents/skills/pester-migration/references/v5-to-v6.md` |
| `csharp-docs/SKILL.md` | `~/.agents/skills/csharp-docs/SKILL.md` |

Write skill files verbatim from upstream. Do NOT strip or add frontmatter; `SKILL.md`'s own
`name`/`description` frontmatter is how harnesses identify the skill, so it must survive the copy
unchanged.

For each installed harness with its own skills directory, symlink that directory's skill entries
to the matching `~/.agents/skills/` folder (or copy the files if the harness cannot follow
symlinks):

| Harness | Skills locations |
|---|---|
| omp | `~/.omp/agent/skills/pester-migration/`, `~/.omp/agent/skills/csharp-docs/` |
| Claude Code | `~/.claude/skills/pester-migration/`, `~/.claude/skills/csharp-docs/` |
| VS Code Copilot | `~/.copilot/skills/pester-migration/`, `~/.copilot/skills/csharp-docs/` |

## Requirements

- After fetching each INSTRUCTION source URL, strip its existing frontmatter (if any) before
  inserting the remaining body content into the canonical `~/.agents/instructions/` files.
- Agent files and skill files are copied verbatim; do not strip their frontmatter.
- If a target file already exists, merge new source content without overwriting project-specific
  priorities. The conflict resolution priority must remain: project-level instructions (a repo's
  own `AGENTS.md`/`CLAUDE.md`/`.instructions.md`) > these user-level files > externally
  referenced docs.
- After creating/updating the files, list them and confirm their paths.
- If the source URLs are unreachable, stop and report the error; do not create empty files.

'@ | Set-Clipboard
}

