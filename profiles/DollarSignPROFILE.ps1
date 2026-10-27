# DollarSignPROFILE.ps1
# Version 2026.10.262227
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
    <#
    .SYNOPSIS
        Install Jake's global agent instructions, agents, skills, and hooks.
    #>
    [Alias('gai')]
    param()

    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $state = @{ Changed = 0; Failed = $false; Ts = (Get-Date -Format 'yyyyMMddHHmmss') }
    $agents = Join-Path $HOME '.agents'
    $utf8 = New-Object Text.UTF8Encoding $false

    function Save-Remote($url, $dest) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -TimeoutSec 30
    }

    # Fetch an instruction file and strip its YAML frontmatter.
    function Save-Instruction($url, $dest) {
        $tmp = [IO.Path]::GetTempFileName()
        try {
            Save-Remote $url $tmp
            $lines = [IO.File]::ReadAllLines($tmp)
            $i = 0
            if ($lines.Count -gt 0 -and $lines[0] -match '^---\s*$') {
                $i = 1
                while ($i -lt $lines.Count -and $lines[$i] -notmatch '^---\s*$') { $i++ }
                $i++
            }
            $text = if ($i -lt $lines.Count) { ($lines[$i..($lines.Count - 1)] -join "`n") + "`n" } else { '' }
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
            [IO.File]::WriteAllText($dest, $text, $utf8)
        } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }

    # Copy src to dst; back dst up first when its content would change.
    function Copy-IfChanged($src, $dst) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
        if (Test-Path -LiteralPath $dst) {
            if ((Get-FileHash -LiteralPath $src).Hash -eq (Get-FileHash -LiteralPath $dst).Hash) { return }
            Copy-Item -LiteralPath $dst -Destination "$dst.bak.$($state.Ts)"
        }
        Copy-Item -LiteralPath $src -Destination $dst
        if ($dst -like '*.sh' -and $PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) { chmod +x $dst }
        $state.Changed++
    }

    # shortcut: Get-ChildItem -Recurse does not follow directory symlinks on Windows PowerShell 5.1.
    function Copy-Tree($srcDir, $dstDir) {
        if (-not (Test-Path -LiteralPath $srcDir -PathType Container)) { return }
        $root = (Resolve-Path -LiteralPath $srcDir).ProviderPath.TrimEnd('\', '/')
        Get-ChildItem -LiteralPath $root -Recurse -File -Force |
            Where-Object { $_.Name -notlike '*.bak.*' -and $_.Name -ne '.DS_Store' } |
            ForEach-Object { Copy-IfChanged $_.FullName (Join-Path $dstDir $_.FullName.Substring($root.Length).TrimStart('\', '/')) }
    }

    # Replace (or append) the managed block in a shared markdown file.
    function Set-Block($target, $body) {
        $block = "<!-- BEGIN gai (managed block; edits here are overwritten) -->`n$body`n<!-- END gai -->`n"
        $existing = if (Test-Path -LiteralPath $target) { [IO.File]::ReadAllText($target) } else { $null }
        if ($null -eq $existing) {
            $new = $block
        } else {
            $b = $existing.IndexOf('<!-- BEGIN gai')
            if ($b -ge 0) {
                $e = $existing.IndexOf('<!-- END gai -->', $b)
                $eol = if ($e -ge 0) { $existing.IndexOf("`n", $e) } else { -1 }
                $tail = if ($e -ge 0 -and $eol -ge 0) { $existing.Substring($eol + 1) } else { '' }
                $new = $existing.Substring(0, $b) + $block + $tail
            } else {
                $new = $existing + "`n" + $block
            }
        }
        $tmp = [IO.Path]::GetTempFileName()
        try {
            [IO.File]::WriteAllText($tmp, $new, $utf8)
            Copy-IfChanged $tmp $target
        } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }

    # shortcut: a truncated tree fails the source instead of being paged through.
    function Save-Listed($repo, [scriptblock]$map, $dest) {
        $tree = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/git/trees/HEAD?recursive=1" -Headers @{ Accept = 'application/vnd.github+json' }
        if ($tree.truncated -ne $false) { throw "$repo tree is truncated" }
        $pairs = @($tree.tree | Where-Object type -eq 'blob' | ForEach-Object { & $map $_.path } | Where-Object { $_ })
        if ($pairs.Count -eq 0) { throw "nothing matched in $repo" }
        foreach ($p in $pairs) { Save-Remote "https://raw.githubusercontent.com/$repo/HEAD/$($p.Src)" (Join-Path $dest $p.Rel) }
    }

    # Fetch a source into a temp dir; write it to ~/.agents only if every fetch worked.
    function Invoke-Source($name, [scriptblock]$fetch) {
        $stage = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        try {
            & $fetch $stage
            Copy-Tree $stage $agents
            Write-Host "[+] $name"
        } catch {
            Write-Host "[x] $name failed; skipped: $($_.Exception.Message)" -ForegroundColor Red
            $state.Failed = $true
        } finally { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
    }

    $own = 'https://raw.githubusercontent.com/jakehildreth/jakehildreth/HEAD'
    $awesome = 'https://raw.githubusercontent.com/github/awesome-copilot/HEAD'

    Invoke-Source 'jakehildreth: instructions, hooks, skills' {
        param($s)
        Save-Instruction "$own/.github/copilot-instructions.md" (Join-Path $s 'instructions/personal.md')
        foreach ($f in 'no-ai-attribution.json', 'no-ai-attribution.sh', 'no-ai-attribution.ps1', 'no-squash-merge.json', 'no-squash-merge.sh', 'no-squash-merge.ps1') {
            Save-Remote "$own/hooks/$f" (Join-Path $s "hooks/$f")
        }
        Save-Listed 'jakehildreth/jakehildreth' {
            param($p)
            if ($p -cmatch '^skills/(conference-talk-summary|new-linkedin-post|talk-developer|writing-voice)/') { @{ Src = $p; Rel = $p.Substring(7) } }
        } (Join-Path $s 'skills')
    }

    Invoke-Source 'awesome-copilot: instructions, agents, skills' {
        param($s)
        Save-Instruction "$awesome/instructions/powershell.instructions.md" (Join-Path $s 'instructions/powershell.md')
        Save-Instruction "$awesome/instructions/powershell-pester-6.instructions.md" (Join-Path $s 'instructions/pester.md')
        Save-Instruction "$awesome/instructions/csharp.instructions.md" (Join-Path $s 'instructions/csharp.md')
        foreach ($f in 'CSharpExpert.agent.md', 'csharp-dotnet-janitor.agent.md') {
            Save-Remote "$awesome/agents/$f" (Join-Path $s "agents/$f")
        }
        foreach ($f in 'pester-migration/SKILL.md', 'pester-migration/references/v3-to-v4.md', 'pester-migration/references/v4-to-v5.md', 'pester-migration/references/v5-to-v6.md', 'csharp-docs/SKILL.md') {
            Save-Remote "$awesome/skills/$f" (Join-Path $s "skills/$f")
        }
    }

    Invoke-Source 'mattpocock/skills' {
        param($s)
        Save-Listed 'mattpocock/skills' {
            param($p)
            if ($p -cmatch '^skills/(?:engineering|productivity)/([^/]+/.+)$') { @{ Src = $p; Rel = $Matches[1] } }
        } (Join-Path $s 'skills')
    }

    Invoke-Source 'DietrichGebert/ponytail' {
        param($s)
        Save-Listed 'DietrichGebert/ponytail' {
            param($p)
            if ($p -cmatch '^skills/([^/]+/SKILL\.md)$') { @{ Src = $p; Rel = $Matches[1] } }
        } (Join-Path $s 'skills')
    }

    # Copy from ~/.agents into each harness directory that already exists.
    try {
        $inst = Join-Path $agents 'instructions'
        $claude = Join-Path $HOME '.claude'
        $omp = Join-Path $HOME '.omp/agent'
        $copilot = Join-Path $HOME '.copilot'
        foreach ($h in $claude, $omp, $copilot) {
            if (Test-Path -LiteralPath $h -PathType Container) { Copy-Tree (Join-Path $agents 'skills') (Join-Path $h 'skills') }
        }
        if (Test-Path -LiteralPath $claude -PathType Container) { Copy-Tree (Join-Path $agents 'agents') (Join-Path $claude 'agents') }
        if (Test-Path -LiteralPath $copilot -PathType Container) { Copy-Tree (Join-Path $agents 'hooks') (Join-Path $copilot 'hooks') }

        $names = 'personal', 'powershell', 'pester', 'csharp'
        $body = ''
        foreach ($n in $names) {
            $f = Join-Path $inst "$n.md"
            if (Test-Path -LiteralPath $f) { $body += [IO.File]::ReadAllText($f) + "`n" }
        }
        Set-Block (Join-Path $HOME 'AGENTS.md') $body
        if (Test-Path -LiteralPath $claude -PathType Container) { Set-Block (Join-Path $claude 'CLAUDE.md') $body }
        if (Test-Path -LiteralPath $omp -PathType Container) { Set-Block (Join-Path $omp 'AGENTS.md') $body }

        if (Test-Path -LiteralPath $copilot -PathType Container) {
            $apply = @{ personal = '**/*'; powershell = '**/*.ps1,**/*.psm1'; pester = '**/*.Tests.ps1'; csharp = '**/*.cs' }
            foreach ($n in $names) {
                $f = Join-Path $inst "$n.md"
                if (-not (Test-Path -LiteralPath $f)) { continue }
                $tmp = [IO.Path]::GetTempFileName()
                try {
                    [IO.File]::WriteAllText($tmp, "---`napplyTo: '$($apply[$n])'`n---`n`n" + [IO.File]::ReadAllText($f), $utf8)
                    Copy-IfChanged $tmp (Join-Path $copilot "instructions/$n.instructions.md")
                } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
            }
        }
    } catch {
        Write-Host "[x] distribute failed: $($_.Exception.Message)" -ForegroundColor Red
        $state.Failed = $true
    }

    Write-Host "[i] $($state.Changed) file(s) written; replaced files are kept as *.bak.$($state.Ts)"
    if ($state.Failed) { $global:LASTEXITCODE = 1 }
}

