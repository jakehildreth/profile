<#
.SYNOPSIS
    Installs or updates DollarSignPROFILE to the current user's PowerShell profile.

.DESCRIPTION
    Downloads DollarSignPROFILE.ps1 from GitHub and writes it to $PROFILE,
    creating the parent directory if needed. Respects the AutoUpdate preference
    stored in $PROFILE (never/always). If a previous install is detected and the
    content differs, prompts the user before overwriting. Creates a timestamped
    backup before any write. Dot-sources the profile after a successful install.

.EXAMPLE
    iwr profile.jakehildreth.com | iex

.EXAMPLE
    Invoke-RestMethod -Uri https://profile.jakehildreth.com | Invoke-Expression

.OUTPUTS
    None

.NOTES
    Source: https://github.com/jakehildreth/profile
#>

$ErrorActionPreference = 'Stop'

function Write-Info ($msg) { Write-Host "[i] $msg" -ForegroundColor Cyan }
function Write-Ok   ($msg) { Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Ask  ($msg) { Write-Host "[?] $msg" -ForegroundColor Blue }

function Write-Fail {
    param(
        [string]$Message,
        [System.Management.Automation.ErrorCategory]$Category = [System.Management.Automation.ErrorCategory]::NotSpecified,
        [object]$TargetObject = $null
    )
    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
        [System.Exception]::new($Message),
        'DollarSignPROFILE.InstallError',
        $Category,
        $TargetObject
    )
    Write-Error -ErrorRecord $errorRecord -ErrorAction SilentlyContinue
}

Set-Variable -Name sourceUri -Value 'https://raw.githubusercontent.com/jakehildreth/profile/refs/heads/main/profiles/DollarSignPROFILE.ps1' -Option ReadOnly -Force

try {
    $remoteContent = (Invoke-WebRequest -Uri $sourceUri -UseBasicParsing -TimeoutSec 10).Content
} catch {
    Write-Fail -Message "Download failed ($sourceUri). Verify the URL is reachable and the file exists." -Category ConnectionError -TargetObject $sourceUri
    return
}

$profilePath = $PROFILE

# --- Existing profile ---
if (Test-Path -Path $profilePath) {
    $localContent = [System.IO.File]::ReadAllText($profilePath)

    $preference = $null
    if ($localContent -match '(?m)^# AutoUpdate=(\w+)') {
        $preference = $Matches[1]
    }

    if ($preference -eq 'never') {
        Write-Info 'New PowerShell profile available. Skipping.'
        Write-Info "To change this behavior, remove this line from your profile:"
        Write-Host "`n  # AutoUpdate=never`n"
        return
    }

    $localStripped  = ($localContent  -replace '(?m)^# AutoUpdate=\w+(\r?\n)?', '').Trim() -replace '\r\n', "`n"
    $remoteStripped = ($remoteContent -replace '(?m)^# AutoUpdate=\w+(\r?\n)?', '').Trim() -replace '\r\n', "`n"

    if ($localStripped -eq $remoteStripped) {
        return
    }

    $writeHeader = $null

    if ($preference -eq 'always') {
        $writeHeader = 'always'
    } else {
        $isDollarSign = $localContent -match 'DollarSignPROFILE'
        if ($isDollarSign) {
            Write-Ask "A new version of your $(Split-Path $profilePath -Leaf) is available. Update it?"
        } else {
            Write-Ask "$(Split-Path $profilePath -Leaf) already exists and does not appear to be a DollarSignPROFILE install. Overwrite it?"
        }

        $caption = ''
        $message = ''
        $choices = @(
            [System.Management.Automation.Host.ChoiceDescription]::new('Yes, &always',         'Always apply updates silently.')
            [System.Management.Automation.Host.ChoiceDescription]::new('&Yes, just this time', 'Apply this update; ask again next time.')
            [System.Management.Automation.Host.ChoiceDescription]::new('No, &not this time',   'Skip this update; ask again next time.')
            [System.Management.Automation.Host.ChoiceDescription]::new('No, ne&ver',           'Never check for or apply updates.')
            [System.Management.Automation.Host.ChoiceDescription]::new('&More details',        'Show a diff of the changes, then ask again.')
        )

        do {
            $result = $Host.UI.PromptForChoice($caption, $message, $choices, 1)
            if ($result -eq 4) {
                $localLines  = $localStripped  -split "`n"
                $remoteLines = $remoteStripped -split "`n"
                $diff = Compare-Object -ReferenceObject $localLines -DifferenceObject $remoteLines
                Write-Host ''
                if ($diff) {
                    foreach ($entry in $diff) {
                        if ($entry.SideIndicator -eq '<=') {
                            Write-Host "- $($entry.InputObject)" -ForegroundColor Red
                        } else {
                            Write-Host "+ $($entry.InputObject)" -ForegroundColor Green
                        }
                    }
                } else {
                    Write-Info 'No line-level differences detected.'
                }
                Write-Host ''
            }
        } while ($result -eq 4)

        switch ($result) {
            0 { $writeHeader = 'always' }
            1 { $writeHeader = $null }
            2 { Write-Info 'Installation skipped.'; return }
            3 {
                $stripped = $localContent -replace '(?m)^# AutoUpdate=\w+(\r?\n)?', ''
                Set-Content -Path $profilePath -Value ("# AutoUpdate=never`n" + $stripped) -Encoding UTF8
                Write-Info 'Installation skipped. You will not be prompted again.'
                return
            }
        }
    }

    Write-Info "Installing PowerShell profile → $profilePath"
    $backup = "$profilePath.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
    try {
        Copy-Item -Path $profilePath -Destination $backup
        Write-Info "Backup created: $backup"
    } catch {
        Write-Fail -Message "Could not create backup of $profilePath." -Category WriteError -TargetObject $profilePath
        return
    }

    $finalContent = if ($writeHeader) { "# AutoUpdate=$writeHeader`n$remoteContent" } else { $remoteContent }
    try {
        Set-Content -Path $profilePath -Value $finalContent -Encoding UTF8
    } catch {
        Write-Fail -Message "Could not write to $profilePath." -Category WriteError -TargetObject $profilePath
        return
    }

} else {
    # --- Fresh install ---
    Write-Info "Installing PowerShell profile → $profilePath"
    $profileDir = Split-Path -Path $profilePath -Parent
    if (-not (Test-Path -Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
    try {
        Set-Content -Path $profilePath -Value $remoteContent -Encoding UTF8
    } catch {
        Write-Fail -Message "Could not write to $profilePath." -Category WriteError -TargetObject $profilePath
        return
    }
}

Write-Ok 'PowerShell profile written.'
. $profilePath
Write-Ok '$PROFILE loaded.'
