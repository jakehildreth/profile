# DollarSignPROFILE.ps1
# Version 2026.10.262245
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

function Install-AgentContent {
    <#
    .SYNOPSIS
        Installs Jake's global agent instructions, agents, skills, and hooks.

    .DESCRIPTION
        Fetches instructions, agents, skills, and Copilot CLI hooks from their upstream repositories
        into ~/.agents, then copies them into each agent harness directory that already exists
        (~/.claude, ~/.omp/agent, ~/.copilot). Instructions are also written into a managed block in
        ~/AGENTS.md and in each existing harness's own AGENTS.md or CLAUDE.md.

        Each source is fetched into a temporary directory and applied only if every download
        succeeded, so one failing source never blocks the others. A file whose content would change
        is first copied to <name>.bak.<yyyyMMddHHmmss>. Nothing is ever deleted.

    .EXAMPLE
        Install-AgentContent

        Installs or updates everything and returns one result object per source.

    .EXAMPLE
        gai -WhatIf

        Lists every file that would be written without changing anything. Sources are still
        downloaded to a temporary directory, and the harness copy step reads the current
        ~/.agents rather than the pending update.

    .OUTPUTS
        System.Management.Automation.PSCustomObject

        One object per source with Source, Status, FilesWritten, and Message properties.

    .NOTES
        Requires network access to github.com and raw.githubusercontent.com. Unauthenticated GitHub
        API calls are limited to 60 per hour per IP.
    #>
    [Alias('gai')]
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param()

    # Progress rendering makes Invoke-WebRequest very slow in Windows PowerShell 5.1.
    $ProgressPreference = 'SilentlyContinue'
    $runState = @{ FilesWritten = 0; Timestamp = (Get-Date -Format 'yyyyMMddHHmmss') }
    $agentsPath = Join-Path -Path $HOME -ChildPath '.agents'
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)

    function Save-RemoteFile {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$Uri,

            [Parameter(Mandatory)]
            [string]$Path
        )

        $null = New-Item -ItemType Directory -Path (Split-Path -Path $Path -Parent) -Force -WhatIf:$false -ErrorAction Stop
        Invoke-WebRequest -Uri $Uri -OutFile $Path -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
    }

    # Downloads an instruction file and strips its YAML frontmatter.
    function Save-InstructionFile {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$Uri,

            [Parameter(Mandatory)]
            [string]$Path
        )

        $downloadPath = [System.IO.Path]::GetTempFileName()
        try {
            Save-RemoteFile -Uri $Uri -Path $downloadPath
            $lines = [System.IO.File]::ReadAllLines($downloadPath)
            $bodyStart = 0
            if ($lines.Count -gt 0 -and $lines[0] -match '^---\s*$') {
                $bodyStart = 1
                while ($bodyStart -lt $lines.Count -and $lines[$bodyStart] -notmatch '^---\s*$') {
                    $bodyStart++
                }
                $bodyStart++
            }
            $body = ''
            if ($bodyStart -lt $lines.Count) {
                $body = ($lines[$bodyStart..($lines.Count - 1)] -join "`n") + "`n"
            }
            $null = New-Item -ItemType Directory -Path (Split-Path -Path $Path -Parent) -Force -WhatIf:$false -ErrorAction Stop
            [System.IO.File]::WriteAllText($Path, $body, $utf8NoBom)
        } finally {
            Remove-Item -LiteralPath $downloadPath -Force -WhatIf:$false -ErrorAction SilentlyContinue
        }
    }

    # Copies Source over Destination, backing Destination up first when its content would change.
    function Copy-FileIfChanged {
        [CmdletBinding(SupportsShouldProcess)]
        param(
            [Parameter(Mandatory)]
            [string]$Source,

            [Parameter(Mandatory)]
            [string]$Destination
        )

        $destinationExists = Test-Path -LiteralPath $Destination
        if ($destinationExists -and (Get-FileHash -LiteralPath $Source -ErrorAction Stop).Hash -eq (Get-FileHash -LiteralPath $Destination -ErrorAction Stop).Hash) {
            return
        }
        if (-not $PSCmdlet.ShouldProcess($Destination, 'Write file')) {
            return
        }
        $null = New-Item -ItemType Directory -Path (Split-Path -Path $Destination -Parent) -Force -ErrorAction Stop
        if ($destinationExists) {
            Copy-Item -LiteralPath $Destination -Destination "$Destination.bak.$($runState.Timestamp)" -ErrorAction Stop
        }
        Copy-Item -LiteralPath $Source -Destination $Destination -ErrorAction Stop
        if ($Destination -like '*.sh' -and $PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) {
            chmod +x $Destination
        }
        $runState.FilesWritten++
    }

    # shortcut: Get-ChildItem -Recurse does not follow directory symlinks in Windows PowerShell 5.1; upgrade if a source tree ever contains one.
    function Copy-FileTree {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$SourceDirectory,

            [Parameter(Mandatory)]
            [string]$DestinationDirectory
        )

        if (-not (Test-Path -LiteralPath $SourceDirectory -PathType Container)) {
            return
        }
        $rootPath = (Resolve-Path -LiteralPath $SourceDirectory -ErrorAction Stop).ProviderPath.TrimEnd('\', '/')
        Get-ChildItem -LiteralPath $rootPath -Recurse -File -Force -ErrorAction Stop |
            Where-Object -FilterScript { $_.Name -notlike '*.bak.*' -and $_.Name -ne '.DS_Store' } |
            ForEach-Object -Process {
                $relativePath = $_.FullName.Substring($rootPath.Length).TrimStart('\', '/')
                Copy-FileIfChanged -Source $_.FullName -Destination (Join-Path -Path $DestinationDirectory -ChildPath $relativePath)
            }
    }

    # Replaces (or appends) the managed block in a shared markdown file.
    function Write-ManagedBlock {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$Path,

            [Parameter(Mandatory)]
            [string]$Body
        )

        $block = "<!-- BEGIN gai (managed block; edits here are overwritten) -->`n$Body`n<!-- END gai -->`n"
        if (Test-Path -LiteralPath $Path) {
            $existing = [System.IO.File]::ReadAllText($Path)
            $blockStart = $existing.IndexOf('<!-- BEGIN gai')
            if ($blockStart -ge 0) {
                $blockEnd = $existing.IndexOf('<!-- END gai -->', $blockStart)
                $lineEnd = if ($blockEnd -ge 0) { $existing.IndexOf("`n", $blockEnd) } else { -1 }
                $tail = if ($lineEnd -ge 0) { $existing.Substring($lineEnd + 1) } else { '' }
                $newContent = $existing.Substring(0, $blockStart) + $block + $tail
            } else {
                $newContent = $existing + "`n" + $block
            }
        } else {
            $newContent = $block
        }
        $stagedPath = [System.IO.Path]::GetTempFileName()
        try {
            [System.IO.File]::WriteAllText($stagedPath, $newContent, $utf8NoBom)
            Copy-FileIfChanged -Source $stagedPath -Destination $Path
        } finally {
            Remove-Item -LiteralPath $stagedPath -Force -WhatIf:$false -ErrorAction SilentlyContinue
        }
    }

    # shortcut: a truncated tree fails the source instead of being paged through; upgrade if a source repo outgrows one API response.
    function Save-RepositoryFile {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$Repository,

            [Parameter(Mandatory)]
            [scriptblock]$Select,

            [Parameter(Mandatory)]
            [string]$DestinationDirectory
        )

        $tree = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/git/trees/HEAD?recursive=1" -Headers @{ Accept = 'application/vnd.github+json' } -ErrorAction Stop
        if ($tree.truncated -ne $false) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new("The $Repository tree is truncated."),
                'TreeTruncated',
                [System.Management.Automation.ErrorCategory]::InvalidResult,
                $Repository
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
        $selected = @($tree.tree |
            Where-Object -Property type -EQ -Value 'blob' |
            ForEach-Object -Process { & $Select $_.path } |
            Where-Object -FilterScript { $_ })
        if ($selected.Count -eq 0) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new("No files matched in $Repository."),
                'NoFilesMatched',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $Repository
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
        foreach ($file in $selected) {
            Save-RemoteFile -Uri "https://raw.githubusercontent.com/$Repository/HEAD/$($file.SourcePath)" -Path (Join-Path -Path $DestinationDirectory -ChildPath $file.RelativePath)
        }
    }

    # Fetches a source into a temporary directory and writes it to ~/.agents only if every download worked.
    function Install-Source {
        [CmdletBinding()]
        [OutputType([pscustomobject])]
        param(
            [Parameter(Mandatory)]
            [string]$Name,

            [Parameter(Mandatory)]
            [scriptblock]$Fetch
        )

        $stagingPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([guid]::NewGuid().ToString())
        $writtenBefore = $runState.FilesWritten
        $status = 'Failed'
        $message = ''
        try {
            $null = & $Fetch $stagingPath
            Copy-FileTree -SourceDirectory $stagingPath -DestinationDirectory $agentsPath
            $status = if ($WhatIfPreference) { 'WhatIf' } else { 'Installed' }
        } catch {
            $message = $_.Exception.Message
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                $_.Exception,
                'SourceInstallFailed',
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $Name
            )
            $PSCmdlet.WriteError($errorRecord)
        } finally {
            Remove-Item -LiteralPath $stagingPath -Recurse -Force -WhatIf:$false -ErrorAction SilentlyContinue
        }
        [pscustomobject]@{
            Source       = $Name
            Status       = $status
            FilesWritten = $runState.FilesWritten - $writtenBefore
            Message      = $message
        }
    }

    $ownBaseUri = 'https://raw.githubusercontent.com/jakehildreth/jakehildreth/HEAD'
    $awesomeBaseUri = 'https://raw.githubusercontent.com/github/awesome-copilot/HEAD'

    Install-Source -Name 'jakehildreth: instructions, hooks, skills' -Fetch {
        param($StagingPath)
        Save-InstructionFile -Uri "$ownBaseUri/.github/copilot-instructions.md" -Path (Join-Path -Path $StagingPath -ChildPath 'instructions/personal.md')
        foreach ($hookFile in 'no-ai-attribution.json', 'no-ai-attribution.sh', 'no-ai-attribution.ps1', 'no-squash-merge.json', 'no-squash-merge.sh', 'no-squash-merge.ps1') {
            Save-RemoteFile -Uri "$ownBaseUri/hooks/$hookFile" -Path (Join-Path -Path $StagingPath -ChildPath "hooks/$hookFile")
        }
        Save-RepositoryFile -Repository 'jakehildreth/jakehildreth' -DestinationDirectory (Join-Path -Path $StagingPath -ChildPath 'skills') -Select {
            param($RepositoryPath)
            if ($RepositoryPath -cmatch '^skills/(conference-talk-summary|new-linkedin-post|talk-developer|writing-voice)/') {
                @{ SourcePath = $RepositoryPath; RelativePath = $RepositoryPath.Substring(7) }
            }
        }
    }

    Install-Source -Name 'awesome-copilot: instructions, agents, skills' -Fetch {
        param($StagingPath)
        Save-InstructionFile -Uri "$awesomeBaseUri/instructions/powershell.instructions.md" -Path (Join-Path -Path $StagingPath -ChildPath 'instructions/powershell.md')
        Save-InstructionFile -Uri "$awesomeBaseUri/instructions/powershell-pester-6.instructions.md" -Path (Join-Path -Path $StagingPath -ChildPath 'instructions/pester.md')
        Save-InstructionFile -Uri "$awesomeBaseUri/instructions/csharp.instructions.md" -Path (Join-Path -Path $StagingPath -ChildPath 'instructions/csharp.md')
        foreach ($agentFile in 'CSharpExpert.agent.md', 'csharp-dotnet-janitor.agent.md') {
            Save-RemoteFile -Uri "$awesomeBaseUri/agents/$agentFile" -Path (Join-Path -Path $StagingPath -ChildPath "agents/$agentFile")
        }
        foreach ($skillFile in 'pester-migration/SKILL.md', 'pester-migration/references/v3-to-v4.md', 'pester-migration/references/v4-to-v5.md', 'pester-migration/references/v5-to-v6.md', 'csharp-docs/SKILL.md') {
            Save-RemoteFile -Uri "$awesomeBaseUri/skills/$skillFile" -Path (Join-Path -Path $StagingPath -ChildPath "skills/$skillFile")
        }
    }

    Install-Source -Name 'mattpocock/skills' -Fetch {
        param($StagingPath)
        Save-RepositoryFile -Repository 'mattpocock/skills' -DestinationDirectory (Join-Path -Path $StagingPath -ChildPath 'skills') -Select {
            param($RepositoryPath)
            if ($RepositoryPath -cmatch '^skills/(?:engineering|productivity)/([^/]+/.+)$') {
                @{ SourcePath = $RepositoryPath; RelativePath = $Matches[1] }
            }
        }
    }

    Install-Source -Name 'DietrichGebert/ponytail' -Fetch {
        param($StagingPath)
        Save-RepositoryFile -Repository 'DietrichGebert/ponytail' -DestinationDirectory (Join-Path -Path $StagingPath -ChildPath 'skills') -Select {
            param($RepositoryPath)
            if ($RepositoryPath -cmatch '^skills/([^/]+/SKILL\.md)$') {
                @{ SourcePath = $RepositoryPath; RelativePath = $Matches[1] }
            }
        }
    }

    # Copy from ~/.agents into each harness directory that already exists.
    $distributeWrittenBefore = $runState.FilesWritten
    $distributeStatus = 'Failed'
    $distributeMessage = ''
    try {
        $instructionsPath = Join-Path -Path $agentsPath -ChildPath 'instructions'
        $claudePath = Join-Path -Path $HOME -ChildPath '.claude'
        $ompPath = Join-Path -Path $HOME -ChildPath '.omp/agent'
        $copilotPath = Join-Path -Path $HOME -ChildPath '.copilot'
        $claudeExists = Test-Path -LiteralPath $claudePath -PathType Container
        $ompExists = Test-Path -LiteralPath $ompPath -PathType Container
        $copilotExists = Test-Path -LiteralPath $copilotPath -PathType Container

        foreach ($harnessPath in $claudePath, $ompPath, $copilotPath) {
            if (Test-Path -LiteralPath $harnessPath -PathType Container) {
                Copy-FileTree -SourceDirectory (Join-Path -Path $agentsPath -ChildPath 'skills') -DestinationDirectory (Join-Path -Path $harnessPath -ChildPath 'skills')
            }
        }
        if ($claudeExists) {
            Copy-FileTree -SourceDirectory (Join-Path -Path $agentsPath -ChildPath 'agents') -DestinationDirectory (Join-Path -Path $claudePath -ChildPath 'agents')
        }
        if ($copilotExists) {
            Copy-FileTree -SourceDirectory (Join-Path -Path $agentsPath -ChildPath 'hooks') -DestinationDirectory (Join-Path -Path $copilotPath -ChildPath 'hooks')
        }

        $instructionNames = 'personal', 'powershell', 'pester', 'csharp'
        $instructionParts = foreach ($instructionName in $instructionNames) {
            $instructionPath = Join-Path -Path $instructionsPath -ChildPath "$instructionName.md"
            if (Test-Path -LiteralPath $instructionPath) {
                [System.IO.File]::ReadAllText($instructionPath) + "`n"
            }
        }
        $instructionBody = $instructionParts -join ''
        if ($instructionBody) {
            Write-ManagedBlock -Path (Join-Path -Path $HOME -ChildPath 'AGENTS.md') -Body $instructionBody
            if ($claudeExists) {
                Write-ManagedBlock -Path (Join-Path -Path $claudePath -ChildPath 'CLAUDE.md') -Body $instructionBody
            }
            if ($ompExists) {
                Write-ManagedBlock -Path (Join-Path -Path $ompPath -ChildPath 'AGENTS.md') -Body $instructionBody
            }
        }

        if ($copilotExists) {
            $applyTo = @{ personal = '**/*'; powershell = '**/*.ps1,**/*.psm1'; pester = '**/*.Tests.ps1'; csharp = '**/*.cs' }
            foreach ($instructionName in $instructionNames) {
                $instructionPath = Join-Path -Path $instructionsPath -ChildPath "$instructionName.md"
                if (-not (Test-Path -LiteralPath $instructionPath)) {
                    continue
                }
                $stagedPath = [System.IO.Path]::GetTempFileName()
                try {
                    $content = "---`napplyTo: '$($applyTo[$instructionName])'`n---`n`n" + [System.IO.File]::ReadAllText($instructionPath)
                    [System.IO.File]::WriteAllText($stagedPath, $content, $utf8NoBom)
                    Copy-FileIfChanged -Source $stagedPath -Destination (Join-Path -Path $copilotPath -ChildPath "instructions/$instructionName.instructions.md")
                } finally {
                    Remove-Item -LiteralPath $stagedPath -Force -WhatIf:$false -ErrorAction SilentlyContinue
                }
            }
        }
        $distributeStatus = if ($WhatIfPreference) { 'WhatIf' } else { 'Installed' }
    } catch {
        $distributeMessage = $_.Exception.Message
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            $_.Exception,
            'DistributeFailed',
            [System.Management.Automation.ErrorCategory]::NotSpecified,
            $HOME
        )
        $PSCmdlet.WriteError($errorRecord)
    }
    [pscustomobject]@{
        Source       = 'Harness directories and AGENTS.md'
        Status       = $distributeStatus
        FilesWritten = $runState.FilesWritten - $distributeWrittenBefore
        Message      = $distributeMessage
    }
    Write-Verbose -Message "Replaced files are kept as *.bak.$($runState.Timestamp)"
}

