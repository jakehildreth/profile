# DollarSignPROFILE.ps1
# Version 2026.5.72053
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
    $GitBranch = & { $ErrorActionPreference = 'SilentlyContinue'; git branch --show-current 2>&1 } | Where-Object { $_ -is [string] }
    if ($LASTEXITCODE -eq 0 -and $GitBranch) {
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

function gai {
    param(
        [switch]$Personal,
        [switch]$PowerShell,
        [switch]$Pester
    )

    $usePersonal = $Personal.IsPresent
    $usePowerShell = $PowerShell.IsPresent
    $usePester = $Pester.IsPresent

    if (-not ($usePersonal -or $usePowerShell -or $usePester)) {
        $usePersonal = $true
        $usePowerShell = $true
        $usePester = $true
    }

    $instructions = ''

    if ($usePersonal) {
        $instructions += @'
Please read and follow my personal instructions:
https://raw.githubusercontent.com/jakehildreth/jakehildreth/refs/heads/main/.github/copilot-instructions.md

'@
    }

    if ($usePowerShell) {
        $instructions += @'
Read and follow PowerShell best practices:
https://raw.githubusercontent.com/github/awesome-copilot/refs/heads/main/instructions/powershell.instructions.md

'@
    }

    if ($usePester) {
        $instructions += @'
Read and follow Pester testing best practices:
https://raw.githubusercontent.com/github/awesome-copilot/refs/heads/main/instructions/powershell-pester-5.instructions.md

'@
    }
    
    $instructions | Set-Clipboard
}

function dcc {
    @'
Compare the current state of this project against its most recent commit.
Using the diff, draft a conventional commit following my standards, and present it to me for approval.
If I approve the commit message, commit the changes & push them.
If the current branch is not main, ask me if I want to do a PR.
If I say yes, draft a pull request title and description, then return the title and description as separate copy-pastable blocks.
If I say no, tell me you're ready for the next task. In a robot style.
'@ | Set-Clipboard
}
