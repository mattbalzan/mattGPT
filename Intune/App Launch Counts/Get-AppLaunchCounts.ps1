#Requires -Version 5.1
<#
.SYNOPSIS
    Intune **detection** script that reports how many times a curated list of
    applications has been launched by the logged-on user(s) on the device.

.DESCRIPTION
    Windows records, per user, how many times each program was started from
    Windows Explorer (Start menu, taskbar, double-click, etc.) in the
    **UserAssist** registry keys:

        HKEY_USERS\<SID>\Software\Microsoft\Windows\CurrentVersion\
            Explorer\UserAssist\{CEBFF5CD-ACE2-4F4F-9178-9926F41749EA}\Count

    The value *names* are ROT13-encoded full paths to the executable, the
    run count is stored as a DWORD at byte offset 4 of each value's binary data,
    and (on Windows 7+) the last-execution time is stored as an 8-byte FILETIME
    at byte offset 60.

    This script:
      1. Resolves every interactive user hive to inspect. When Intune runs the
         script as SYSTEM (the default), it enumerates the loaded user hives in
         HKEY_USERS (SIDs starting S-1-5-21-). When run in the logged-on user's
         context, the current user's hive is used. Counts are summed across all
         matched users so the value reflects total launches on the device.
      2. ROT13-decodes each UserAssist entry, extracts the executable file name,
         its run count and its last-execution time.
      3. Matches the executable name against the curated $SelectApps list and
         tallies the launch count per app (multiple executables can roll up to
         a single friendly app name), keeping the most recent last-launch time
         seen across all matched executables and users. If $SelectApps is left
         empty, EVERY executable found in UserAssist is reported instead, keyed
         by its file name and ordered by launch count (highest first).
      4. Writes a single comma-separated line to STDOUT in the form:

             <AppName>|<Count>|<LastLaunch>,<AppName>|<Count>|<LastLaunch>,...

         where <LastLaunch> is the most recent launch in local device time,
         formatted yyyy-MM-dd HH:mm:ss (empty when the app was never launched),
         e.g.  7zip|2|2026-06-30 08:15:04,Acrobat|4|2026-07-01 17:42:19,MSWord|6|2026-07-02 09:03:55

      5. Keeps the line within Intune's 2048-character detection-output limit.
         If the full line is longer, the names are abbreviated (the file
         extension is stripped, e.g. WINWORD.EXE -> WINWORD). If it is still
         too long, the full line is written to a log file and STDOUT instead
         reads "Output is greater than 2048 limit, please see log for more
         info". The log is saved to
         C:\ProgramData\Microsoft\IntuneManagementExtension\Logs as
         <devicename>-AppLaunchCount-ddMMyyyy-HHmmss.log.

    The line is emitted to STDOUT (captured by Intune in the detection output /
    "Pre-remediation detection output" column) and the script exits 0.

    EDIT THE $SelectApps BLOCK BELOW to choose which apps to report and which
    executable file names map to each friendly app name, or leave it empty to
    report every launched executable on the device.

.NOTES
    INTUNE CONFIGURATION
      * Use as a custom **Detection** script (Remediations, or a Win32 app
        custom detection rule).
      * "Run this script using the logged-on credentials":
            No  (recommended) - runs as SYSTEM; the script reads every loaded
                                user hive in HKEY_USERS and sums the counts.
            Yes               - runs as the user; the script reads HKCU only.
      * "Enforce script signature check": No (unless you sign the script).
      * "Run script in 64-bit PowerShell": Yes (avoids registry redirection).

    LIMITATIONS
      * UserAssist only records launches made through Windows Explorer for the
        user. Programs started by the system, services, scripts or scheduled
        tasks are not counted.
      * A user's counts are only readable while their hive is loaded (i.e. they
        are logged on) when the script runs as SYSTEM. Offline profiles are not
        mounted by this detection script.
      * UserAssist must be enabled (it is by default on Windows 10/11).

    DISCLAIMER
        This script is provided "as is", without warranty of any kind, express
        or implied. It is not an official Microsoft product and is not supported
        by Microsoft. Use it at your own risk. Always review and test in a
        non-production environment before deploying through Intune. The author(s)
        accept no liability for any data loss, service disruption, cost or other
        damage arising from its use.
#>

#-----------------------------------------------------------------------------#
# Configuration - EDIT ME                                                     #
#-----------------------------------------------------------------------------#
# Each entry maps a friendly Name (used in the output) to one or more
# executable file names to count. Matching is case-insensitive on the file
# name only (path is ignored), so several executables can roll up to one app.
#
# Leave this list EMPTY  ->  $SelectApps = @()  to report EVERY executable
# found in UserAssist, using each executable's file name as the output name,
# ordered by launch count (highest first).
$SelectApps = @(
    #[pscustomobject]@{ Name = '7zip';    Executables = @('7zFM.exe', '7zG.exe', '7z.exe') }
    #[pscustomobject]@{ Name = 'Acrobat'; Executables = @('Acrobat.exe', 'AcroRd32.exe', 'AcroCEF.exe') }
    #[pscustomobject]@{ Name = 'MSWord';  Executables = @('WINWORD.EXE') }
)

# Include apps that were never launched (count 0) in the output. Set to $false
# to emit only apps with at least one recorded launch.
$IncludeZeroCounts = $true

#-----------------------------------------------------------------------------#
# Setup                                                                       #
#-----------------------------------------------------------------------------#
# UserAssist GUID that tracks executables (.exe) launched via Explorer.
$UserAssistExeGuid = '{CEBFF5CD-ACE2-4F4F-9178-9926F41749EA}'
$CountKeySuffix = "Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\$UserAssistExeGuid\Count"

# Byte offset of the 8-byte last-execution FILETIME within each entry's binary
# data (Windows 7+ UserAssist format).
$LastRunOffset = 60

#-----------------------------------------------------------------------------#
# Helpers                                                                     #
#-----------------------------------------------------------------------------#
function ConvertFrom-Rot13 {
    # UserAssist value names are ROT13-encoded; letters are rotated by 13.
    param([string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { return $Value }
    $sb = New-Object System.Text.StringBuilder $Value.Length
    foreach ($ch in $Value.ToCharArray()) {
        $code = [int][char]$ch
        if ($code -ge 65 -and $code -le 90) {
            [void]$sb.Append([char]((($code - 65 + 13) % 26) + 65))   # A-Z
        }
        elseif ($code -ge 97 -and $code -le 122) {
            [void]$sb.Append([char]((($code - 97 + 13) % 26) + 97))   # a-z
        }
        else {
            [void]$sb.Append($ch)
        }
    }
    return $sb.ToString()
}

function Get-TargetUserSids {
    # Returns the SIDs whose UserAssist data should be inspected.
    $sids = New-Object System.Collections.Generic.List[string]

    # Current identity (covers running in the logged-on user's context).
    try {
        $current = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        if ($current -and -not $current.IsSystem -and $current.User) {
            $sids.Add($current.User.Value)
        }
    }
    catch { }

    # All loaded real-user hives under HKEY_USERS (covers SYSTEM context).
    # Real user SIDs start with S-1-5-21-; skip the *_Classes companion hives.
    Get-ChildItem -Path 'Registry::HKEY_USERS' -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match '^S-1-5-21-' -and $_.PSChildName -notmatch '_Classes$' } |
        ForEach-Object { $sids.Add($_.PSChildName) }

    return ($sids | Select-Object -Unique)
}

function ConvertTo-OutputLine {
    # Renders Name/Count entries as "Name|Count,Name|Count". When -Abbreviate is
    # set, the trailing file extension is stripped from each name (e.g.
    # WINWORD.EXE -> WINWORD) to shorten the line.
    param(
        [object[]]$Entries,
        [switch]$Abbreviate
    )
    $parts = foreach ($e in $Entries) {
        $name = $e.Name
        if ($Abbreviate) {
            $short = $name -replace '\.[^.\\/]+$', ''
            if (-not [string]::IsNullOrEmpty($short)) { $name = $short }
        }
        $last = ''
        if ($e.LastLaunch -is [datetime]) {
            $last = $e.LastLaunch.ToString('yyyy-MM-dd HH:mm:ss')
        }
        '{0}|{1}|{2}' -f $name, $e.Count, $last
    }
    return ($parts -join ',')
}

#-----------------------------------------------------------------------------#
# Main                                                                        #
#-----------------------------------------------------------------------------#
# An empty $SelectApps switches to "all-apps" mode: report every executable
# found in UserAssist. Otherwise only the configured apps are tallied.
$collectAll = ($null -eq $SelectApps -or @($SelectApps).Count -eq 0)

# Curated mode: build a fast lookup of executable file name -> friendly app
# name, and an ordered tally initialised to zero for every configured app.
$exeToApp = @{}
$totals = [ordered]@{}
$lastLaunch = [ordered]@{}
if (-not $collectAll) {
    foreach ($app in $SelectApps) {
        $totals[$app.Name] = 0
        $lastLaunch[$app.Name] = $null
        foreach ($exe in $app.Executables) {
            if (-not [string]::IsNullOrWhiteSpace($exe)) {
                $exeToApp[$exe.ToLowerInvariant()] = $app.Name
            }
        }
    }
}

# All-apps mode: tally launch counts keyed by executable file name. The display
# map preserves the first-seen casing of each executable name, and $allLast
# holds the most recent launch time seen per executable.
$allTotals = @{}
$allDisplay = @{}
$allLast = @{}

try {
    foreach ($sid in (Get-TargetUserSids)) {
        $countKeyPath = "Registry::HKEY_USERS\$sid\$CountKeySuffix"
        $countKey = Get-Item -LiteralPath $countKeyPath -ErrorAction SilentlyContinue
        if (-not $countKey) { continue }

        foreach ($valueName in $countKey.GetValueNames()) {
            if ([string]::IsNullOrEmpty($valueName)) { continue }

            # Run count is a DWORD at byte offset 4 of the entry's binary data.
            $data = $countKey.GetValue($valueName)
            if ($data -isnot [byte[]] -or $data.Length -lt 8) { continue }
            $runCount = [System.BitConverter]::ToInt32($data, 4)
            if ($runCount -le 0) { continue }

            # Last-execution time is an 8-byte FILETIME at $LastRunOffset. Convert
            # to local device time; a zero/invalid value leaves it unset.
            $lastRun = $null
            if ($data.Length -ge ($LastRunOffset + 8)) {
                $fileTime = [System.BitConverter]::ToInt64($data, $LastRunOffset)
                if ($fileTime -gt 0) {
                    try { $lastRun = [DateTime]::FromFileTime($fileTime) } catch { }
                }
            }

            # Decode the ROT13 path and pull the executable's file name.
            $decoded = ConvertFrom-Rot13 $valueName
            $leaf = ($decoded -split '[\\/]')[-1]
            if ([string]::IsNullOrWhiteSpace($leaf)) { continue }

            if ($collectAll) {
                # Only count actual executables; skip .lnk shortcuts and the
                # UEME_* session/control counters that also live under Count.
                if ($leaf -notmatch '\.exe$') { continue }
                $key = $leaf.ToLowerInvariant()
                if (-not $allDisplay.ContainsKey($key)) { $allDisplay[$key] = $leaf }
                $allTotals[$key] = [int]$allTotals[$key] + $runCount
                if ($lastRun -and (-not $allLast[$key] -or $lastRun -gt $allLast[$key])) {
                    $allLast[$key] = $lastRun
                }
            }
            else {
                $appName = $exeToApp[$leaf.ToLowerInvariant()]
                if ($appName) {
                    $totals[$appName] += $runCount
                    if ($lastRun -and (-not $lastLaunch[$appName] -or $lastRun -gt $lastLaunch[$appName])) {
                        $lastLaunch[$appName] = $lastRun
                    }
                }
            }
        }
    }
}
catch {
    # Detection scripts must stay resilient; emit whatever has been tallied.
}

# Build the list of Name/Count entries to emit.
if ($collectAll) {
    # Every executable found, ordered by launch count (highest first), then name.
    $entries = $allTotals.GetEnumerator() |
        Sort-Object @{ Expression = { [int]$_.Value }; Descending = $true }, @{ Expression = { $allDisplay[$_.Key] } } |
        ForEach-Object { [pscustomobject]@{ Name = $allDisplay[$_.Key]; Count = [int]$_.Value; LastLaunch = $allLast[$_.Key] } }
}
else {
    $entries = foreach ($app in $SelectApps) {
        $count = [int]$totals[$app.Name]
        if ($IncludeZeroCounts -or $count -gt 0) {
            [pscustomobject]@{ Name = $app.Name; Count = $count; LastLaunch = $lastLaunch[$app.Name] }
        }
    }
}

# Intune captures only the first 2048 characters of the detection output. If the
# full line exceeds that, retry with abbreviated (extension-stripped) names; if
# it is still too long, write the full line to a log and emit a short pointer.
$MaxOutputLength = 2048
$LogDir = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'

$output = ConvertTo-OutputLine -Entries $entries

if ($output.Length -gt $MaxOutputLength) {
    $abbreviated = ConvertTo-OutputLine -Entries $entries -Abbreviate

    if ($abbreviated.Length -le $MaxOutputLength) {
        Write-Output $abbreviated
    }
    else {
        # Still over the limit: persist the full line to a log file named
        # <devicename>-AppLaunchCount-ddMMyyyy-HHmmss.log and point to it.
        try {
            if (-not (Test-Path -LiteralPath $LogDir)) {
                New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
            }
            $logName = '{0}-AppLaunchCount-{1}.log' -f $env:COMPUTERNAME, (Get-Date -Format 'ddMMyyyy-HHmmss')
            $logPath = Join-Path $LogDir $logName
            Set-Content -LiteralPath $logPath -Value $output -Encoding UTF8
        }
        catch { }
        Write-Output 'Output is greater than 2048 limit, please see log for more info'
    }
}
else {
    Write-Output $output
}
exit 0
