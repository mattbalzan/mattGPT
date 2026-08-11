#==============================================================================
#  DISCLAIMER - READ BEFORE RUNNING
#==============================================================================
#  PROVIDED AS-IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED.
#
#  This script modifies disk partitions and boot-adjacent structures on
#  encrypted production devices. Partition operations carry an inherent risk
#  of data loss or of rendering a device unbootable.
#
#    - This is not an official Microsoft tool or a supported Microsoft fix,
#      and it is not covered by any Microsoft support agreement.
#    - TEST ON NON-PRODUCTION DEVICES FIRST, then pilot on a small, backed-up
#      sample before any wider deployment.
#    - Ensure devices are backed up and that BitLocker recovery keys are
#      escrowed and retrievable BEFORE running.
#    - Confirm BitLocker resumes cleanly and PCR7 rebinds as expected on pilot
#      devices before scaling.
#    - The author and PENTA Consulting accept no liability for any loss or
#      damage arising from its use. You run it at your own risk, and you are
#      responsible for validating it against your own environment and change
#      control process.
#==============================================================================

<#
.SYNOPSIS
    Rebuilds an undersized WinRE recovery partition.

    Shrinks C: to create a correctly sized recovery partition at the end of the
    disk and re-registers WinRE to it, for estates where the recovery partition
    sits BEFORE the OS partition and the documented KB5028997 fix cannot be used.
    Handles BitLocker suspend/resume, validates every step, and rolls back on
    failure. Run with -WhatIf first for a read-only pre-flight report.

.DESCRIPTION
    
    THE PROBLEM
    Windows Setup reports it needs ~582MB to place WinRE but only ~287MB is
    available, and BitLocker prevents it falling back to another partition:

        MeetPartitionRequirements Not enough free space
        req = 610,744,977   avail = 301,125,632
        MeetPartitionRequirements Partition has bitlocker
        [setup.exe] Can't put WinRE on other partitions, error:0x2

    Since June 2023 WinRE is serviced via the monthly cumulative update
    (KB5028997). A recovery partition too small to hold the updated image
    causes the LCU to report as failed and raises System Event ID 4502 with
    ErrorPhase 2.

    WHY NOT THE KB5028997 PROCEDURE
    The documented Microsoft procedure requires the recovery partition to sit
    AFTER the OS partition, because it deletes the recovery partition and
    extends into the freed space. This estate's task sequence creates:

        EFI (100MB) -> MSR (128MB) -> Recovery (300MB) -> Windows (remainder)

    Recovery sits BEFORE Windows, so the KB procedure cannot be followed as
    written. Anyone attempting it will fail at the shrink/extend step.

    WHAT THIS SCRIPT DOES INSTEAD
    'shrink' releases space at the END of the OS partition, so a new, correctly
    sized recovery partition is created there and WinRE is re-registered to it.
    The stale 300MB partition is deliberately LEFT IN PLACE - deleting a
    partition that sits between EFI and Windows carries real risk for no
    benefit. It is inert once WinRE points elsewhere.

    SAFETY
      - Refuses to run if the device is not on AC power, is low on disk, or
        already has a healthy WinRE configuration.
      - Suspends BitLocker before touching boot-adjacent structures.
      - Verifies winre.wim was successfully staged to C:\Windows\System32\Recovery
        BEFORE any partition operation. If it is not there, it stops.
      - Every diskpart operation is validated afterwards; failure triggers
        best-effort restoration of the original WinRE configuration.
      - -WhatIf is honoured throughout. ALWAYS pilot before fleet deployment.

.PARAMETER RecoverySizeMB
    Size of the new recovery partition. Default 1024MB. Microsoft's working
    guidance is 500-700MB for the image plus headroom; 1GB allows for 25H2
    and beyond without revisiting.

.PARAMETER MinFreeSpaceGB
    Refuse to run if C: has less than this much free space after the shrink.
    Default 15GB.

.PARAMETER Force
    Proceed even if WinRE currently reports as Enabled. Use when the partition
    is known to be undersized despite WinRE appearing healthy.

.PARAMETER LogPath
    Transcript location. Defaults to C:\Windows\Logs\WinRERemediation.

.EXAMPLE
    .\Repair-WinREPartition.ps1 -WhatIf
    Full pre-flight validation with no changes made. Run this first.

.EXAMPLE
    .\Repair-WinREPartition.ps1 -RecoverySizeMB 1024 -Verbose

.NOTES
    PROVIDED AS-IS, WITHOUT WARRANTY. Not an official Microsoft fix. See the
    DISCLAIMER banner at the top of this file before running.

    Author  : Matt Balzan | PENTA Consulting
    Requires: PowerShell 5.1+, elevated, Windows 10/11
    Exit    : 0 success | 1 pre-flight failed | 2 remediation failed
              3 rolled back

    PILOT FIRST. This alters boot-adjacent structures on encrypted production
    devices. Confirm BitLocker resumes cleanly and PCR7 rebinds before scaling.
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [ValidateRange(750, 4096)]
    [int]$RecoverySizeMB = 1024,

    [ValidateRange(5, 200)]
    [int]$MinFreeSpaceGB = 15,

    [switch]$Force,

    [string]$LogPath = 'C:\Windows\Logs\WinRERemediation'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region ---------- Logging ----------
if (-not (Test-Path $LogPath)) { $null = New-Item -Path $LogPath -ItemType Directory -Force }
$stamp      = Get-Date -Format 'yyyyMMdd-HHmmss'
$transcript = Join-Path $LogPath "WinRERemediation_$($env:COMPUTERNAME)_$stamp.log"
$stateFile  = Join-Path $LogPath "WinREState_$($env:COMPUTERNAME).json"

try { Start-Transcript -Path $transcript -Force | Out-Null } catch { }

function Write-Step {
    param([string]$Message,[ValidateSet('Info','Good','Warn','Fail','Step')][string]$Level='Info')
    $prefix = @{Info='  ';Good=' [OK] ';Warn=' [!] ';Fail=' [X] ';Step=''}[$Level]
    $colour = @{Info='Gray';Good='Green';Warn='Yellow';Fail='Red';Step='Cyan'}[$Level]
    Write-Host ("{0}{1}" -f $prefix,$Message) -ForegroundColor $colour
}
#endregion

#region ---------- Helpers ----------

function Test-Elevated {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-WinREStatus {
    <#
        Parses reagentc /info. Locale-independent parsing is not possible here,
        so we match on the GLOBALROOT path shape rather than the label text.
    #>
    $raw = (& reagentc.exe /info 2>&1) -join "`n"

    $enabled = $raw -match '(?im)^\s*Windows RE (status|Status).*:\s*(Enabled|Aktiviert|Activ)'
    if (-not $enabled) { $enabled = $raw -match '(?i)\bEnabled\b' }

    $disk = $null; $part = $null
    $m = [regex]::Match($raw,'harddisk(\d+)\\partition(\d+)',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m.Success) {
        $disk = [int]$m.Groups[1].Value
        $part = [int]$m.Groups[2].Value
    }

    [pscustomobject]@{
        Enabled        = [bool]$enabled
        DiskIndex      = $disk
        PartitionIndex = $part
        Raw            = $raw
    }
}

function Get-Event4502 {
    <#
        Get-WinEvent emits nothing (not an empty array) when no events match, and
        under Set-StrictMode -Version Latest a subsequent $null.Count throws.

        NOTE: do NOT use 'return ,$events' here. The comma operator preserves the
        empty array as a SINGLE pipeline object, so @(Get-Event4502) at the call
        site yields a one-element array CONTAINING an empty array: .Count reports
        1, and that phantom "event" has no TimeCreated property. On a device with
        zero 4502 events that would falsely report the diagnosis as confirmed.
        Plain output plus @() at the call site is the correct pattern.
    #>
    $events = @()
    try {
        $events = @(Get-WinEvent -FilterHashtable @{LogName='System'; Id=4502} `
                                 -MaxEvents 10 -ErrorAction Stop |
                    Select-Object TimeCreated, Message)
    }
    catch {
        # "No events were found that match the specified selection criteria" is
        # the expected result on a healthy device, not an error worth surfacing.
        Write-Verbose "Get-WinEvent returned no 4502 events: $($_.Exception.Message)"
    }
    return $events
}

function Get-DiskLayoutReport {
    # Every collection is wrapped in @() so .Count is always safe under StrictMode.
    $cPart = @(Get-Partition -DriveLetter C -ErrorAction Stop)
    if ($cPart.Count -eq 0) { throw "Could not locate the partition hosting drive C:." }

    $osDisk = $cPart[0].DiskNumber
    $parts  = @(Get-Partition -DiskNumber $osDisk | Sort-Object PartitionNumber)
    $disk   = Get-Disk -Number $osDisk

    $osPart = @($parts | Where-Object { $_.DriveLetter -eq 'C' })
    if ($osPart.Count -eq 0) { throw "Drive C: was not found on disk $osDisk." }

    [pscustomobject]@{
        DiskNumber     = $osDisk
        PartitionStyle = $disk.PartitionStyle
        Partitions     = $parts
        OSPartition    = $osPart[0]
        Recovery       = @($parts | Where-Object { $_.Type -eq 'Recovery' })
    }
}

function Invoke-DiskPart {
    <# Runs a diskpart script and returns the full output for validation. #>
    param([string[]]$Commands)

    $file = Join-Path $env:TEMP "dp_$([guid]::NewGuid().ToString('N')).txt"
    ($Commands + 'exit') | Set-Content -Path $file -Encoding ASCII
    Write-Verbose ("diskpart script:`n" + (($Commands) -join "`n"))
    try {
        $out = & diskpart.exe /s $file 2>&1 | Out-String
        return $out
    }
    finally { Remove-Item $file -Force -ErrorAction SilentlyContinue }
}

function Get-BitLockerState {
    try {
        $v = Get-BitLockerVolume -MountPoint 'C:' -ErrorAction Stop
        [pscustomobject]@{
            Present    = $true
            Protection = $v.ProtectionStatus
            Status     = $v.VolumeStatus
        }
    }
    catch {
        [pscustomobject]@{ Present = $false; Protection = 'Off'; Status = 'Unknown' }
    }
}
#endregion

#region ---------- Pre-flight ----------
Write-Host "`n=================================================" -ForegroundColor Cyan
Write-Host " WinRE Recovery Partition Remediation" -ForegroundColor Cyan
Write-Host " $($env:COMPUTERNAME)  |  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " PROVIDED AS-IS, WITHOUT WARRANTY. Not an official" -ForegroundColor DarkYellow
Write-Host " Microsoft fix. Modifies disk partitions - ensure" -ForegroundColor DarkYellow
Write-Host " backups exist and BitLocker keys are escrowed." -ForegroundColor DarkYellow
Write-Host " Run 'Get-Help .\Repair-WinREPartition.ps1 -Full'" -ForegroundColor DarkYellow
Write-Host "=================================================`n" -ForegroundColor Cyan

Write-Step "PRE-FLIGHT VALIDATION" -Level Step
$preflightFailed = @()

# 1. Elevation
if (Test-Elevated) { Write-Step "Running elevated" -Level Good }
else { $preflightFailed += "Not running as Administrator"; Write-Step "Not elevated" -Level Fail }

# 2. OS build
$os = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' |
      Select-Object CurrentBuild, UBR, DisplayVersion, EditionID
Write-Step ("OS: {0} build {1}.{2} ({3})" -f $os.DisplayVersion,$os.CurrentBuild,$os.UBR,$os.EditionID) -Level Good

# 3. AC power - a partition operation losing power mid-flight is the worst case
try {
    # @() guards against both "no battery" (desktop) and multi-battery devices.
    $battery = @(Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue)
    if ($battery.Count -gt 0 -and $battery[0].BatteryStatus -notin @(2,6,7,8,9)) {
        $preflightFailed += "Device is on battery power"
        Write-Step "On battery - connect AC power before running" -Level Fail
    } else { Write-Step "AC power confirmed (or desktop)" -Level Good }
}
catch { Write-Step "Could not determine power state - verify manually" -Level Warn }

# 4. Disk layout
$layout = Get-DiskLayoutReport
Write-Step ("Disk {0} ({1})" -f $layout.DiskNumber,$layout.PartitionStyle) -Level Good

Write-Host "`n  Current layout:" -ForegroundColor Gray
$layout.Partitions | ForEach-Object {
    $sizeMB = [math]::Round($_.Size/1MB,0)
    $tag = if ($_.DriveLetter -eq 'C') { '<- OS' } elseif ($_.Type -eq 'Recovery') { '<- Recovery' } else { '' }
    Write-Host ("    {0}. {1,-12} {2,8} MB  {3}" -f $_.PartitionNumber,$_.Type,$sizeMB,$tag) -ForegroundColor Gray
}

if ($layout.PartitionStyle -ne 'GPT') {
    $preflightFailed += "Disk is not GPT - this script targets GPT layouts only"
    Write-Step "Disk is MBR - not supported by this script" -Level Fail
}

# 5. Layout order check - this is the crux of why KB5028997 doesn't apply
$osPartNum  = $layout.OSPartition.PartitionNumber
$recAfterOS = @($layout.Recovery | Where-Object { $_.PartitionNumber -gt $osPartNum })

if ($layout.Recovery.Count -eq 0) {
    Write-Step "No existing recovery partition found" -Level Warn
}
elseif ($recAfterOS.Count -gt 0) {
    Write-Step "Recovery partition sits AFTER the OS partition" -Level Warn
    Write-Step "The KB5028997 shrink-and-extend method may apply here - review before using this script" -Level Warn
}
else {
    $recSizeMB = [math]::Round(($layout.Recovery[0].Size)/1MB,0)
    Write-Step ("Recovery ({0}MB) sits BEFORE the OS partition - KB5028997 method does not apply" -f $recSizeMB) -Level Good
    Write-Step "This script will create a new recovery partition at the end of the disk instead" -Level Info
}

# 6. Free space
$vol = Get-Volume -DriveLetter C
$freeGB = [math]::Round($vol.SizeRemaining/1GB,1)
$requiredGB = $MinFreeSpaceGB + [math]::Round($RecoverySizeMB/1024,1)
if ($freeGB -lt $requiredGB) {
    $preflightFailed += "Insufficient free space: ${freeGB}GB free, ${requiredGB}GB required"
    Write-Step ("Free space {0}GB - need {1}GB" -f $freeGB,$requiredGB) -Level Fail
} else {
    Write-Step ("Free space {0}GB (need {1}GB)" -f $freeGB,$requiredGB) -Level Good
}

# 7. Current WinRE state
$winre = Get-WinREStatus
if ($winre.Enabled) {
    Write-Step ("WinRE currently Enabled on disk {0} partition {1}" -f $winre.DiskIndex,$winre.PartitionIndex) -Level Good
    if (-not $Force) {
        $preflightFailed += "WinRE reports Enabled > use -Force if the partition is known to be undersized"
        Write-Step "WinRE appears healthy > use -Force to proceed anyway" -Level Warn
    }
} else {
    Write-Step "WinRE currently Disabled or not configured" -Level Warn
}

# 8. Event 4502 - the servicing failure fingerprint
$evt = @(Get-Event4502)
if ($evt.Count -gt 0) {
    Write-Step ("Found {0} Event ID 4502 (WinRE servicing failed) - confirms the diagnosis" -f $evt.Count) -Level Warn
    # Guard the property access: a malformed record should not abort pre-flight.
    $evt | Select-Object -First 3 | ForEach-Object {
        if ($null -ne $_ -and $_.PSObject.Properties['TimeCreated']) {
            Write-Host ("      {0}" -f $_.TimeCreated) -ForegroundColor DarkGray
        }
    }
} else {
    Write-Step "No Event ID 4502 found in recent System log" -Level Info
    Write-Step "Absence does not rule the diagnosis out - the System log may have rolled over" -Level Info
}

# 9. BitLocker
$bl = Get-BitLockerState
if ($bl.Present -and $bl.Protection -eq 'On') {
    Write-Step "BitLocker protection is ON - will be suspended for one reboot" -Level Warn
} else {
    Write-Step ("BitLocker protection: {0}" -f $bl.Protection) -Level Info
}

if ($preflightFailed.Count -gt 0) {
    Write-Host "`n  PRE-FLIGHT FAILED:" -ForegroundColor Red
    $preflightFailed | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
    Write-Host ""
    try { Stop-Transcript | Out-Null } catch { }
    exit 1
}

Write-Step "`nAll pre-flight checks passed" -Level Good

# Persist original state for rollback / audit
@{
    Computer       = $env:COMPUTERNAME
    Timestamp      = (Get-Date).ToString('o')
    WinREEnabled   = $winre.Enabled
    WinREDisk      = $winre.DiskIndex
    WinREPartition = $winre.PartitionIndex
    OSDisk         = $layout.DiskNumber
    OSPartition    = $osPartNum
    Event4502Count = $evt.Count
    ReagentcRaw    = $winre.Raw
} | ConvertTo-Json -Depth 4 | Set-Content -Path $stateFile -Encoding UTF8
Write-Step "Original state saved to $stateFile" -Level Info
#endregion

#region ---------- Remediation ----------
Write-Host ""
Write-Step "REMEDIATION" -Level Step

$target = "$env:COMPUTERNAME (create ${RecoverySizeMB}MB recovery partition)"
if (-not $PSCmdlet.ShouldProcess($target, "Repartition and re-register WinRE")) {
    Write-Step "WhatIf - no changes made. Pre-flight results above are valid." -Level Info
    try { Stop-Transcript | Out-Null } catch { }
    exit 0
}

$rollbackNeeded = $false

try {
    # --- Suspend BitLocker -------------------------------------------------
    if ($bl.Present -and $bl.Protection -eq 'On') {
        Write-Step "Suspending BitLocker for one reboot..."
        Suspend-BitLocker -MountPoint 'C:' -RebootCount 1 -ErrorAction Stop | Out-Null
        $check = Get-BitLockerVolume -MountPoint 'C:'
        if ($check.ProtectionStatus -ne 'Off') { throw "BitLocker did not suspend - aborting before any partition change." }
        Write-Step "BitLocker suspended" -Level Good
    }

    # --- Disable WinRE - this stages winre.wim back to the OS partition -----
    Write-Step "Disabling WinRE (stages winre.wim to C:\Windows\System32\Recovery)..."
    $null = & reagentc.exe /disable 2>&1
    Start-Sleep -Seconds 2

    # CRITICAL GATE: without the staged image there is nothing to re-register,
    # so we must not touch partitions.
    $wim = 'C:\Windows\System32\Recovery\winre.wim'
    if (-not (Test-Path $wim)) {
        throw "winre.wim was not staged to $wim after reagentc /disable. Stopping before any partition change. WinRE may need restoring from installation media."
    }
    $wimMB = [math]::Round((Get-Item $wim).Length/1MB,0)
    Write-Step ("winre.wim staged successfully ({0}MB)" -f $wimMB) -Level Good
    $rollbackNeeded = $true

    if ($wimMB -gt ($RecoverySizeMB - 200)) {
        Write-Step ("Image is {0}MB and target partition {1}MB - consider a larger -RecoverySizeMB" -f $wimMB,$RecoverySizeMB) -Level Warn
    }

    # --- Shrink C: and create the new partition ----------------------------
    # shrink releases space at the END of the volume, which is exactly where
    # we want the new recovery partition.
    Write-Step ("Shrinking C: by {0}MB and creating recovery partition..." -f $RecoverySizeMB)

    $dp = @(
        "select disk $($layout.DiskNumber)"
        "select partition $osPartNum"
        "shrink desired=$RecoverySizeMB minimum=$RecoverySizeMB"
        "create partition primary"
        "set id=de94bba4-06d1-4d40-a16a-bfd50179d6ac"
        "gpt attributes=0x8000000000000001"
        "format quick fs=ntfs label=`"Recovery`""
    )
    $dpOut = Invoke-DiskPart -Commands $dp
    Write-Verbose $dpOut

    if ($dpOut -match '(?i)DiskPart has encountered an error|failed|insufficient') {
        Write-Host $dpOut -ForegroundColor DarkGray
        throw "diskpart reported an error - see output above."
    }

    # --- Validate the new partition exists ---------------------------------
    Start-Sleep -Seconds 3
    $newLayout = Get-DiskLayoutReport
    $newRec = @($newLayout.Partitions |
                Where-Object { $_.Type -eq 'Recovery' -and $_.PartitionNumber -gt $osPartNum } |
                Sort-Object PartitionNumber)

    if ($newRec.Count -eq 0) { throw "New recovery partition was not created - diskpart reported success but the partition is absent." }
    $newRec = $newRec[-1]

    $newSizeMB = [math]::Round($newRec.Size/1MB,0)
    Write-Step ("New recovery partition created: partition {0}, {1}MB" -f $newRec.PartitionNumber,$newSizeMB) -Level Good

    # --- Re-enable WinRE ---------------------------------------------------
    Write-Step "Re-registering WinRE..."
    $enableOut = & reagentc.exe /enable 2>&1
    Start-Sleep -Seconds 2

    $post = Get-WinREStatus
    if (-not $post.Enabled) {
        Write-Host ($enableOut | Out-String) -ForegroundColor DarkGray
        throw "reagentc /enable did not report WinRE as Enabled."
    }
    Write-Step ("WinRE Enabled on disk {0} partition {1}" -f $post.DiskIndex,$post.PartitionIndex) -Level Good

    if ($post.PartitionIndex -ne $newRec.PartitionNumber) {
        Write-Step ("WinRE registered to partition {0}, expected {1} - verify manually" -f $post.PartitionIndex,$newRec.PartitionNumber) -Level Warn
    }

    $rollbackNeeded = $false

    # --- Resume BitLocker --------------------------------------------------
    if ($bl.Present -and $bl.Protection -eq 'On') {
        Write-Step "Resuming BitLocker protection..."
        Resume-BitLocker -MountPoint 'C:' -ErrorAction Stop | Out-Null
        $blPost = Get-BitLockerVolume -MountPoint 'C:'
        if ($blPost.ProtectionStatus -eq 'On') { Write-Step "BitLocker protection resumed" -Level Good }
        else { Write-Step "BitLocker did not resume - RESOLVE THIS BEFORE THE DEVICE IS RELEASED" -Level Fail }
    }

    # --- Summary -----------------------------------------------------------
    Write-Host "`n=================================================" -ForegroundColor Green
    Write-Host " REMEDIATION COMPLETE" -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host ""
    Write-Step ("New recovery partition : {0}MB (partition {1})" -f $newSizeMB,$newRec.PartitionNumber) -Level Info
    Write-Step  "Stale 300MB partition  : left in place, now inert" -Level Info
    Write-Step ("Log                    : {0}" -f $transcript) -Level Info
    Write-Host ""
    Write-Step "Next: install the pending cumulative update and confirm no new Event ID 4502." -Level Info

    try { Stop-Transcript | Out-Null } catch { }
    exit 0
}
catch {
    Write-Host ""
    Write-Step ("REMEDIATION FAILED: {0}" -f $_.Exception.Message) -Level Fail

    if ($rollbackNeeded) {
        Write-Step "Attempting to restore original WinRE configuration..." -Level Warn
        try {
            $null = & reagentc.exe /enable 2>&1
            Start-Sleep -Seconds 2
            $rb = Get-WinREStatus
            if ($rb.Enabled) { Write-Step "WinRE restored to Enabled" -Level Good }
            else { Write-Step "WinRE could NOT be restored - device needs manual attention" -Level Fail }
        }
        catch { Write-Step ("Rollback failed: {0}" -f $_.Exception.Message) -Level Fail }
    }

    if ($bl.Present -and $bl.Protection -eq 'On') {
        try {
            Resume-BitLocker -MountPoint 'C:' -ErrorAction Stop | Out-Null
            Write-Step "BitLocker protection resumed" -Level Good
        }
        catch { Write-Step "BitLocker did NOT resume - ESCALATE IMMEDIATELY" -Level Fail }
    }

    Write-Step ("Log: {0}" -f $transcript) -Level Info
    try { Stop-Transcript | Out-Null } catch { }
    exit $(if ($rollbackNeeded) { 3 } else { 2 })
}
#endregion
