<#
.SYNOPSIS
    Detects and repairs a damaged Windows servicing baseline before a Feature Update,
    with a Windows Update repair tier for estates locked to WSUS.

.DESCRIPTION
    Windows Feature Updates can fail during the migration/provisioning phase when the
    component store (WinSxS) is missing baseline component directories. Typical signatures:

        CBS.log
            Hydration failed ... NTSTATUS_FROM_WIN32(774)
            Component directory missing. Dir: \SystemRoot\WinSxS\amd64_microsoft-windows-...
            Error 0x800f0983  (PSFX_E_MATCHING_COMPONENT_DIRECTORY_MISSING)

        setuperr.log / setupact.log
            Failed to load migration plugin ... 0x8007007F
            ProvMigration failed ... 0x80070003

    Windows stores components as differential (delta) payload plus a reverse delta against
    a baseline. If the matching baseline directory is gone, the servicing stack cannot
    reconstruct the full binary - so cumulative updates fail, and Setup's migration phase
    fails when it tries to load components from the source OS.

    ------------------------------------------------------------------------------------
    WHY THE WINDOWS UPDATE REPAIR TIER MATTERS
    ------------------------------------------------------------------------------------
    DISM /RestoreHealth needs a source of replacement component payload. Two things
    commonly prevent it finding one in a managed enterprise:

      1. WSUS does not host component-store repair content. A client pointed at WSUS
         with UseWUServer=1 has no reachable source for repair payload.

      2. /LimitAccess explicitly forbids DISM from contacting Windows Update, so the
         most commonly copy-pasted repair command is also the one least likely to work
         on a locked-down estate.

    Policies that block the self-repair path:

        HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate
            DisableWindowsUpdateAccess                    = 1
            DoNotConnectToWindowsUpdateInternetLocations  = 1
        HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU
            UseWUServer                                   = 1

    The documented override is:

        HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing
            RepairContentServerSource (DWORD) = 2
                -> download repair content from Windows Update instead of WSUS

    Tier 1 sets that override, runs DISM /RestoreHealth with NO /Source and NO
    /LimitAccess, verifies the outcome, then restores every original value.

    Fetching from Windows Update is often MORE precise than a staged WIM, because a WIM
    only contains the component versions that shipped in that media build, whereas
    Windows Update can supply the exact version the servicing stack is asking for.

    A useful diagnostic signal: if devices allowed direct internet access to Windows
    Update succeed while WSUS-managed devices fail with identical hardware and image,
    the update-source policy is a strong suspect - not the image.

    ------------------------------------------------------------------------------------
    REPAIR TIERS
    ------------------------------------------------------------------------------------
      Tier 1   Windows Update as repair source          (default, disable with -SkipWindowsUpdate)
      Tier 2   Staged install.wim / install.esd         (fallback, or primary if Tier 1 off)
      Tier 3   Neither worked -> CanUpgrade = False, escalate to in-place repair or reimage

    Runs standalone, or inside a ConfigMgr task sequence. When a task sequence is detected
    it publishes its findings as TS variables and ALWAYS exits 0, so the sequence author
    controls flow with step conditions rather than the script failing the deployment.

.PARAMETER SourcePath
    Path to a folder containing \sources\install.wim (or install.esd) for Tier 2.
    Ignored when running in a task sequence if -SourceVariable resolves to a path.

.PARAMETER SourceVariable
    Task sequence variable holding the staged media path. A "Download Package Content"
    step with "Save path as a variable" set to MyVar creates MyVar01 - pass the full name
    including the numeric suffix. Default: RepairSrc01

.PARAMETER SkipWindowsUpdate
    Disable Tier 1. Use where Microsoft update endpoints are hard-blocked at the firewall
    and the DNS pre-check would be the only thing catching it.

.PARAMETER WindowsUpdateTimeoutMinutes
    Abort Tier 1 after this many minutes and fall through to Tier 2. Default 45.

.PARAMETER RestoreUpdatePolicy
    Restore the original update-source policy values after the repair attempt.
    Default $true. Leave enabled in production - the relaxation is temporary and scoped
    to component repair only.

.PARAMETER Edition
    Image name to select from the WIM for Tier 2. Default 'Windows 11 Enterprise'.

.PARAMETER ComponentPattern
    WinSxS directory patterns to test for presence. Override to target the components
    named in your own CBS log. Defaults cover the most commonly reported ones.

.PARAMETER MinimumFreeSpaceGB
    Abort before repairing if the system volume has less free space than this. Default 25.

.PARAMETER SkipRepair
    Detect and classify only. Makes no changes. Useful for an estate-wide discovery sweep.

.PARAMETER RemoveBlockingDrivers
    Remove OEM driver packages flagged BlockMigration=True in CompatData.xml, plus
    unsigned oem*.inf packages. Off by default - review what it would remove first.

.PARAMETER SuspendBitLocker
    Suspend BitLocker for 3 reboots when a PIN protector is present. Encryption stays
    enabled; only pre-boot validation is relaxed, avoiding recovery prompts when boot
    measurements change during the upgrade.

.PARAMETER LogPath
    Log destination. Defaults to the TS log folder when in a task sequence, else
    C:\Windows\Temp.

.EXAMPLE
    # Detection only - safe to run estate-wide
    .\Invoke-ServicingBaselinePreflight.ps1 -SkipRepair -Verbose

.EXAMPLE
    # Single device: try Windows Update, fall back to local media
    .\Invoke-ServicingBaselinePreflight.ps1 -SourcePath D:\ -Verbose

.EXAMPLE
    # Inside a ConfigMgr task sequence
    .\Invoke-ServicingBaselinePreflight.ps1 -SourceVariable RepairSrc01 -SuspendBitLocker

.EXAMPLE
    # Air-gapped or endpoint-blocked site - staged media only
    .\Invoke-ServicingBaselinePreflight.ps1 -SkipWindowsUpdate -SourceVariable RepairSrc01

.EXAMPLE
    # Target a component named in your own CBS log
    .\Invoke-ServicingBaselinePreflight.ps1 -ComponentPattern 'amd64_microsoft-windows-servicingstack*'

.OUTPUTS
    A PSCustomObject summarising the run, plus CSV/JSON in $LogPath.

    Task sequence variables (when running in a TS):
        PFBucket           A|B|Z
        PFDefectFound      True|False
        PFRepairAttempted  True|False
        PFRepairTier       WindowsUpdate|StagedWIM|Both|None
        PFRepairResult     Verified|Incomplete|NotAttempted|SourceMissing|InsufficientSpace
        PFWuRepairResult   Success|Failed|Blocked|Skipped|TimedOut
        PFCanUpgrade       True|False   <- gate the Upgrade OS step on this
        PFDetail           free-text diagnostics

    Exit codes (standalone only - always 0 inside a task sequence):
        0  Healthy, or repair verified
        1  Defect detected, detection-only mode
        2  Repair attempted but verification failed
        3  No usable repair source
       20  Not elevated

.NOTES
    Requires: PowerShell 5.1+, elevated (SYSTEM is fine). No external modules.
    Licence: MIT. Provided as-is - test before production use.

    Tier 1 modifies update-source policy temporarily. It backs up every value it touches,
    restores them in the exit path even on early failure, and triggers a machine policy
    refresh afterwards. Review Set-RepairPolicy / Restore-RepairPolicy before deploying
    in a regulated environment.
#>

[CmdletBinding()]
param(
    [string]   $SourcePath,
    [string]   $SourceVariable              = 'RepairSrc01',
    [switch]   $SkipWindowsUpdate,
    [int]      $WindowsUpdateTimeoutMinutes = 45,
    [bool]     $RestoreUpdatePolicy         = $true,
    [string]   $Edition                     = 'Windows 11 Enterprise',
    [string[]] $ComponentPattern            = @(
                   'amd64_microsoft-windows-servicingstack*',
                   'amd64_microsoft-windows-container-manager*',
                   'amd64_microsoft-windows-hyper-v*'
               ),
    [int]      $MinimumFreeSpaceGB          = 25,
    [switch]   $SkipRepair,
    [switch]   $RemoveBlockingDrivers,
    [switch]   $SuspendBitLocker,
    [string]   $LogPath
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

#region ---------- environment ------------------------------------------------

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error 'Must run elevated (Administrator or SYSTEM).'
    exit 20
}

$tsEnv = $null
try   { $tsEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment }
catch { Write-Verbose 'No task sequence environment - running standalone.' }

if (-not $LogPath) {
    $LogPath = if ($tsEnv) { $tsEnv.Value('_SMSTSLogPath') } else { 'C:\Windows\Temp' }
}
if (-not $LogPath -or -not (Test-Path $LogPath)) { $LogPath = 'C:\Windows\Temp' }
$logFile = Join-Path $LogPath 'ServicingPreflight.log'

function Write-Log {
    param([string]$Message,[ValidateSet('INFO','WARN','ERROR')][string]$Level='INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -f 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    switch ($Level) {
        'WARN'  { Write-Host $line -ForegroundColor Yellow }
        'ERROR' { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line }
    }
    try { Add-Content -Path $logFile -Value $line -Encoding UTF8 } catch { }
}

function Get-RegValue {
    param([string]$Path,[string]$Name)
    try { (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name } catch { $null }
}

function Set-TSVar {
    param([string]$Name,[string]$Value)
    if ($tsEnv) {
        try { $tsEnv.Value($Name) = $Value; Write-Log "  TS var $Name = $Value" }
        catch { Write-Log "  failed to set TS var $Name" WARN }
    }
}

$winsxs = Join-Path $env:SystemRoot 'WinSxS'
$cvKey  = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'

$result = [ordered]@{
    ComputerName          = $env:COMPUTERNAME
    TimeUtc               = (Get-Date).ToUniversalTime().ToString('s')
    Manufacturer          = $null
    Model                 = $null
    OSDisplayVersion      = Get-RegValue $cvKey 'DisplayVersion'
    OSBuild               = Get-RegValue $cvKey 'CurrentBuildNumber'
    UBR                   = Get-RegValue $cvKey 'UBR'
    FreeSpaceGB           = $null
    UseWUServer           = $null
    DisableDualScan       = $null
    RepairContentSource   = $null
    ComponentStoreState   = $null
    ServicingStackDirs    = $null
    MissingComponents     = $null
    CbsHydrationHits      = 0
    MigrationPluginHits   = 0
    DefectFound           = $false
    Bucket                = 'Z'
    RepairAttempted       = $false
    RepairTier            = 'None'
    WuRepairResult        = 'Skipped'
    WuDismExitCode        = $null
    WimDismExitCode       = $null
    SfcResult             = $null
    PostRepairMissing     = $null
    PostRepairStoreState  = $null
    CanUpgrade            = $true
    RepairResult          = 'NotAttempted'
    Detail                = ''
}

$script:PolicyBackup = @{}

#endregion

#region ---------- exit path --------------------------------------------------

function Complete-Preflight {
    param([int]$ExitCode)

    # Safety net - never leave update policy relaxed, even on an early exit
    if ($script:PolicyBackup.Count -gt 0 -and $RestoreUpdatePolicy) { Restore-RepairPolicy }

    Set-TSVar 'PFBucket'          $result.Bucket
    Set-TSVar 'PFDefectFound'     ([string]$result.DefectFound)
    Set-TSVar 'PFRepairAttempted' ([string]$result.RepairAttempted)
    Set-TSVar 'PFRepairTier'      $result.RepairTier
    Set-TSVar 'PFRepairResult'    $result.RepairResult
    Set-TSVar 'PFWuRepairResult'  $result.WuRepairResult
    Set-TSVar 'PFCanUpgrade'      ([string]$result.CanUpgrade)
    Set-TSVar 'PFDetail'          $result.Detail

    $obj   = [pscustomobject]$result
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    try {
        $obj | Export-Csv (Join-Path $LogPath "Preflight_$($env:COMPUTERNAME)_$stamp.csv") -NoTypeInformation -Encoding UTF8
        $obj | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $LogPath "Preflight_$($env:COMPUTERNAME)_$stamp.json") -Encoding UTF8
    } catch { Write-Log "Could not write result files: $($_.Exception.Message)" WARN }

    Write-Log "COMPLETE - Bucket=$($result.Bucket) Tier=$($result.RepairTier) Result=$($result.RepairResult) CanUpgrade=$($result.CanUpgrade)"
    $obj | Format-List

    # Inside a TS always exit 0 - flow is controlled by step conditions on the variables
    if ($tsEnv) { exit 0 } else { exit $ExitCode }
}

#endregion

#region ---------- update-source policy control -------------------------------

$servicingKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing'
$auKey        = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
$wuKey        = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'

function Set-RepairPolicy {
    Write-Log 'Temporarily allowing component repair content from Windows Update'

    $script:PolicyBackup = @{
        RepairContentServerSource         = Get-RegValue $servicingKey 'RepairContentServerSource'
        UseWUServer                       = Get-RegValue $auKey        'UseWUServer'
        DisableWindowsUpdateAccess        = Get-RegValue $wuKey        'DisableWindowsUpdateAccess'
        DoNotConnectToWUInternetLocations = Get-RegValue $wuKey        'DoNotConnectToWindowsUpdateInternetLocations'
        ServicingKeyExisted               = (Test-Path $servicingKey)
    }
    Write-Log ('  backup: RCSS={0} UseWUServer={1} DisableWUAccess={2} DoNotConnect={3}' -f
        $script:PolicyBackup.RepairContentServerSource,
        $script:PolicyBackup.UseWUServer,
        $script:PolicyBackup.DisableWindowsUpdateAccess,
        $script:PolicyBackup.DoNotConnectToWUInternetLocations)

    try {
        if (-not (Test-Path $servicingKey)) { New-Item $servicingKey -Force | Out-Null }
        # 2 = fetch repair content from Windows Update rather than WSUS
        New-ItemProperty $servicingKey -Name 'RepairContentServerSource' -Value 2 `
                         -PropertyType DWord -Force | Out-Null

        if (Test-Path $auKey) {
            Set-ItemProperty $auKey -Name 'UseWUServer' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path $wuKey) {
            Set-ItemProperty $wuKey -Name 'DisableWindowsUpdateAccess' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty $wuKey -Name 'DoNotConnectToWindowsUpdateInternetLocations' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        }

        Restart-Service wuauserv -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5
        Write-Log '  policy relaxed, Windows Update service restarted'
        return $true
    }
    catch {
        Write-Log "  failed to relax policy: $($_.Exception.Message)" WARN
        return $false
    }
}

function Restore-RepairPolicy {
    Write-Log 'Restoring original update-source policy'
    try {
        $b = $script:PolicyBackup

        if ($null -ne $b.RepairContentServerSource) {
            Set-ItemProperty $servicingKey -Name 'RepairContentServerSource' `
                             -Value $b.RepairContentServerSource -Type DWord -Force -ErrorAction SilentlyContinue
        } else {
            Remove-ItemProperty $servicingKey -Name 'RepairContentServerSource' -Force -ErrorAction SilentlyContinue
            if (-not $b.ServicingKeyExisted) {
                $remaining = (Get-Item $servicingKey -ErrorAction SilentlyContinue).Property
                if (-not $remaining) { Remove-Item $servicingKey -Force -ErrorAction SilentlyContinue }
            }
        }

        if ($null -ne $b.UseWUServer) {
            Set-ItemProperty $auKey -Name 'UseWUServer' -Value $b.UseWUServer -Type DWord -Force -ErrorAction SilentlyContinue
        }
        if ($null -ne $b.DisableWindowsUpdateAccess) {
            Set-ItemProperty $wuKey -Name 'DisableWindowsUpdateAccess' `
                             -Value $b.DisableWindowsUpdateAccess -Type DWord -Force -ErrorAction SilentlyContinue
        }
        if ($null -ne $b.DoNotConnectToWUInternetLocations) {
            Set-ItemProperty $wuKey -Name 'DoNotConnectToWindowsUpdateInternetLocations' `
                             -Value $b.DoNotConnectToWUInternetLocations -Type DWord -Force -ErrorAction SilentlyContinue
        }

        Restart-Service wuauserv -Force -ErrorAction SilentlyContinue
        Start-Process gpupdate.exe -ArgumentList '/target:computer /force' -WindowStyle Hidden -ErrorAction SilentlyContinue
        $script:PolicyBackup = @{}
        Write-Log '  policy restored, machine policy refresh triggered'
    }
    catch { Write-Log "  policy restore error: $($_.Exception.Message)" WARN }
}

function Test-WindowsUpdateReachable {
    # Cheap pre-check so we do not burn the timeout against a hard-blocked network
    $endpoints = 'windowsupdate.microsoft.com','download.windowsupdate.com','fe3.delivery.mp.microsoft.com'
    $ok = 0
    foreach ($e in $endpoints) {
        try   { if (Resolve-DnsName $e -ErrorAction Stop) { $ok++ } }
        catch { Write-Log "  DNS resolution failed: $e" WARN }
    }
    Write-Log "  Windows Update endpoints resolved: $ok/$($endpoints.Count)"
    return ($ok -gt 0)
}

#endregion

#region ---------- detection --------------------------------------------------

Write-Log "=== Servicing baseline pre-flight on $env:COMPUTERNAME ==="
Write-Log ('OS {0} build {1}.{2}' -f $result.OSDisplayVersion, $result.OSBuild, $result.UBR)

try {
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $result.Manufacturer = $cs.Manufacturer
    $result.Model        = $cs.Model
} catch { Write-Log 'Win32_ComputerSystem query failed - possible WMI damage' WARN }

# --- update-source posture: diagnostic value even when no repair runs --------
$result.UseWUServer         = Get-RegValue $auKey        'UseWUServer'
$result.DisableDualScan     = Get-RegValue $wuKey        'DisableDualScan'
$result.RepairContentSource = Get-RegValue $servicingKey 'RepairContentServerSource'

Write-Log 'Update-source policy:'
Write-Log "  UseWUServer               = $($result.UseWUServer)"
Write-Log "  DisableDualScan           = $($result.DisableDualScan)"
Write-Log "  RepairContentServerSource = $($result.RepairContentSource)"
if ($result.UseWUServer -eq 1 -and $null -eq $result.RepairContentSource) {
    Write-Log '  NOTE: client is WSUS-managed with no repair-content override.' WARN
    Write-Log '        Component repair has no reachable source in this configuration.' WARN
}

# --- component store ----------------------------------------------------------
try {
    $check = & dism.exe /Online /Cleanup-Image /CheckHealth 2>&1 | Out-String
    $result.ComponentStoreState =
        if     ($check -match 'No component store corruption detected') { 'Healthy' }
        elseif ($check -match 'not repairable')                         { 'NotRepairable' }
        elseif ($check -match 'repairable')                             { 'Repairable' }
        else                                                            { 'Unknown' }
} catch { $result.ComponentStoreState = 'CheckFailed' }
Write-Log "Component store: $($result.ComponentStoreState)"

# --- named component directories ----------------------------------------------
$missing = foreach ($c in $ComponentPattern) {
    if (-not (Get-ChildItem $winsxs -Directory -Filter $c -ErrorAction SilentlyContinue)) { $c }
}
$result.MissingComponents = ($missing -join '; ')
if ($missing) { Write-Log "Missing component directories: $($result.MissingComponents)" WARN }

$result.ServicingStackDirs = @(Get-ChildItem $winsxs -Directory -Filter '*servicing-stack*' -ErrorAction SilentlyContinue).Count
Write-Log "Servicing stack folders: $($result.ServicingStackDirs)"

# --- CBS signatures -----------------------------------------------------------
try {
    $result.CbsHydrationHits = @(
        Get-ChildItem (Join-Path $env:SystemRoot 'Logs\CBS') -Filter '*.log' -ErrorAction Stop |
        Sort-Object LastWriteTime -Descending | Select-Object -First 5 |
        Select-String -Pattern 'Hydration failed|PSFX_E_|0x800f0983|Component directory missing' -ErrorAction SilentlyContinue
    ).Count
} catch { Write-Log 'CBS log folder unreadable' WARN }
Write-Log "CBS hydration signatures: $($result.CbsHydrationHits)"

# --- Setup migration signatures -----------------------------------------------
$pantherPaths = @(
    "$env:SystemDrive\`$WINDOWS.~BT\Sources\Panther",
    (Join-Path $env:SystemRoot 'Panther')
) | Where-Object { Test-Path $_ }

foreach ($p in $pantherPaths) {
    $result.MigrationPluginHits += @(
        Get-ChildItem $p -Include 'setuperr.log','setupact.log' -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 3 |
        Select-String -Pattern 'migration plugin|ProvMigration failed|0x8007007F' -ErrorAction SilentlyContinue
    ).Count
}
Write-Log "Setup migration signatures: $($result.MigrationPluginHits)"

# --- classify ------------------------------------------------------------------
$result.DefectFound = ($result.ComponentStoreState -in 'Repairable','NotRepairable') -or
                      [bool]$missing -or
                      ($result.CbsHydrationHits    -gt 0) -or
                      ($result.MigrationPluginHits -gt 0) -or
                      ($result.ServicingStackDirs  -eq 0)

$result.Bucket = switch ($true) {
    { $result.ComponentStoreState -eq 'NotRepairable' -or
      $result.CbsHydrationHits -gt 0 -or
      $result.ServicingStackDirs -eq 0 -or
      $missing }                          { 'A'; break }   # servicing baseline damaged
    { $result.MigrationPluginHits -gt 0 } { 'B'; break }   # Setup migration failure
    default                               { 'Z' }          # no known defect
}
$result.Detail = "store=$($result.ComponentStoreState);ss=$($result.ServicingStackDirs);cbs=$($result.CbsHydrationHits);mig=$($result.MigrationPluginHits)"
Write-Log "Classification: bucket $($result.Bucket) (defect found: $($result.DefectFound))"

#endregion

#region ---------- early exits ------------------------------------------------

if ($SkipRepair) {
    Write-Log 'Detection-only mode - no changes made'
    Complete-Preflight -ExitCode ([int]$result.DefectFound)
}

if (-not $result.DefectFound) {
    Write-Log 'No servicing defect detected'
    $result.CanUpgrade = $true
    Complete-Preflight -ExitCode 0
}

#endregion

#region ---------- housekeeping -----------------------------------------------

Write-Log 'Clearing stale upgrade state'
foreach ($path in @(
    "$env:SystemDrive\`$WINDOWS.~BT",
    "$env:SystemDrive\`$WINDOWS.~WS",
    "$env:SystemRoot\SoftwareDistribution\Download\*"
)) {
    Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
}

try {
    $result.FreeSpaceGB = [math]::Round(
        (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'").FreeSpace / 1GB, 1)
    Write-Log "Free space: $($result.FreeSpaceGB) GB"
    if ($result.FreeSpaceGB -lt $MinimumFreeSpaceGB) {
        Write-Log "Below $MinimumFreeSpaceGB GB - aborting before repair" WARN
        $result.CanUpgrade   = $false
        $result.RepairResult = 'InsufficientSpace'
        Complete-Preflight -ExitCode 2
    }
} catch { }

if ($RemoveBlockingDrivers) {
    Write-Log 'Checking CompatData for driver hard blocks'
    try {
        $compat = Get-ChildItem "$env:SystemDrive\`$WINDOWS.~BT\Sources\Panther" -Filter 'CompatData*.xml' `
                    -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($compat) {
            $xml = [xml](Get-Content $compat.FullName -Raw)
            $blocked = $xml.SelectNodes('//DriverPackage') |
                       Where-Object { $_.BlockMigration -eq 'True' } | ForEach-Object { $_.Inf }
            foreach ($inf in ($blocked | Sort-Object -Unique)) {
                Write-Log "Removing blocking driver: $inf" WARN
                & pnputil.exe /delete-driver $inf /uninstall /force 2>&1 | Out-Null
            }
            if ($blocked) { $result.Detail += ";removedDrivers=$($blocked -join ',')" }
        } else {
            Write-Log '  no CompatData.xml - no prior upgrade attempt recorded'
        }
    } catch { Write-Log "Driver removal error: $($_.Exception.Message)" WARN }
}

#endregion

#region ---------- verification helper ----------------------------------------

function Test-RepairOutcome {
    <# True only when the store reports healthy AND every named component dir is present. #>
    $stillMissing = foreach ($c in $ComponentPattern) {
        if (-not (Get-ChildItem $winsxs -Directory -Filter $c -ErrorAction SilentlyContinue)) { $c }
    }
    $post = & dism.exe /Online /Cleanup-Image /CheckHealth 2>&1 | Out-String
    $postState =
        if     ($post -match 'No component store corruption detected') { 'Healthy' }
        elseif ($post -match 'not repairable')                         { 'NotRepairable' }
        elseif ($post -match 'repairable')                             { 'Repairable' }
        else                                                           { 'Unknown' }

    $result.PostRepairMissing    = ($stillMissing -join '; ')
    $result.PostRepairStoreState = $postState
    Write-Log "  verify: store=$postState stillMissing=$($stillMissing -join ';')"
    return (-not $stillMissing -and $postState -eq 'Healthy')
}

function Invoke-Sfc {
    Write-Log '  running sfc /scannow'
    $sfc = & sfc.exe /scannow 2>&1 | Out-String
    $result.SfcResult =
        if     ($sfc -match 'did not find any integrity violations') { 'Clean' }
        elseif ($sfc -match 'successfully repaired')                 { 'Repaired' }
        elseif ($sfc -match 'unable to fix')                         { 'UnrepairedFilesRemain' }
        else                                                        { 'Unknown' }
    Write-Log "  sfc: $($result.SfcResult)"
}

#endregion

#region ---------- TIER 1: Windows Update -------------------------------------

$repaired = $false

if (-not $SkipWindowsUpdate) {

    Write-Log '--- TIER 1: Windows Update as repair source ---'

    if (-not (Test-WindowsUpdateReachable)) {
        Write-Log 'Windows Update unreachable - skipping Tier 1' WARN
        $result.WuRepairResult = 'Blocked'
    }
    elseif (Set-RepairPolicy) {

        $result.RepairAttempted = $true
        $result.RepairTier      = 'WindowsUpdate'

        Write-Log "Running DISM /RestoreHealth with no /Source and no /LimitAccess (timeout ${WindowsUpdateTimeoutMinutes}m)"
        $sw = [Diagnostics.Stopwatch]::StartNew()

        $p = Start-Process dism.exe -NoNewWindow -PassThru -ArgumentList @(
            '/Online','/Cleanup-Image','/RestoreHealth',
            "/LogPath:$(Join-Path $LogPath 'dism-wu.log')"
        )

        if (-not $p.WaitForExit($WindowsUpdateTimeoutMinutes * 60 * 1000)) {
            Write-Log "Tier 1 exceeded ${WindowsUpdateTimeoutMinutes} min - terminating" WARN
            try { $p.Kill() } catch { }
            Start-Sleep -Seconds 10
            $result.WuRepairResult = 'TimedOut'
        }
        else {
            $sw.Stop()
            $result.WuDismExitCode = $p.ExitCode
            Write-Log "DISM exit $($p.ExitCode) after $([int]$sw.Elapsed.TotalMinutes) min"

            if ($p.ExitCode -eq 0) {
                Invoke-Sfc
                if (Test-RepairOutcome) {
                    Write-Log 'TIER 1 SUCCEEDED - component store repaired from Windows Update'
                    Write-Log 'If this device is WSUS-managed, the update-source policy was blocking self-repair.'
                    $result.WuRepairResult = 'Success'
                    $repaired = $true
                } else {
                    Write-Log 'Tier 1 completed but verification still shows defects' WARN
                    $result.WuRepairResult = 'Failed'
                }
            } else {
                Write-Log ('Tier 1 DISM failed with 0x{0:X8}' -f $p.ExitCode) WARN
                $result.WuRepairResult = 'Failed'
            }
        }

        if ($RestoreUpdatePolicy) { Restore-RepairPolicy }
    }
    else {
        $result.WuRepairResult = 'Failed'
        $result.Detail += ';policySetFailed'
    }
}
else {
    Write-Log 'Tier 1 disabled by -SkipWindowsUpdate'
    $result.WuRepairResult = 'Skipped'
}

#endregion

#region ---------- TIER 2: staged media ---------------------------------------

if (-not $repaired) {

    Write-Log '--- TIER 2: staged install.wim ---'

    $src = $SourcePath
    if (-not $src -and $tsEnv) {
        try { $src = $tsEnv.Value($SourceVariable) } catch { }
        if (-not $src) { try { $src = $tsEnv.Value('RepairSrc01') } catch { } }
    }
    Write-Log "Repair source: '$src'"

    if (-not $src -or -not (Test-Path $src)) {
        Write-Log 'No usable repair source' ERROR
        $result.RepairResult = 'SourceMissing'
        $result.CanUpgrade   = $false
        Complete-Preflight -ExitCode 3
    }

    $wim = Get-ChildItem (Join-Path $src 'sources') -Include 'install.wim','install.esd' -Recurse -ErrorAction SilentlyContinue |
           Select-Object -First 1
    if (-not $wim) {
        $wim = Get-ChildItem $src -Include 'install.wim','install.esd' -Recurse -ErrorAction SilentlyContinue |
               Select-Object -First 1
    }
    if (-not $wim) {
        Write-Log "No install.wim or install.esd found under $src" ERROR
        $result.RepairResult = 'SourceMissing'
        $result.CanUpgrade   = $false
        Complete-Preflight -ExitCode 3
    }
    Write-Log "Using: $($wim.FullName)"

    $index = $null
    $info  = & dism.exe /Get-WimInfo /WimFile:"$($wim.FullName)" 2>&1 | Out-String
    foreach ($b in [regex]::Matches($info, 'Index\s*:\s*(\d+)\s*\r?\nName\s*:\s*(.+?)\r?\n')) {
        if ($b.Groups[2].Value.Trim() -eq $Edition) { $index = $b.Groups[1].Value; break }
    }
    if (-not $index) {
        $index = 1
        Write-Log "Edition '$Edition' not found - defaulting to index 1" WARN
    }
    Write-Log "Image index: $index"

    $result.RepairAttempted = $true
    $result.RepairTier      = if ($result.WuRepairResult -in 'Failed','TimedOut','Blocked') { 'Both' } else { 'StagedWIM' }

    $sourceArg = 'WIM:{0}:{1}' -f $wim.FullName, $index
    Write-Log "Running DISM /RestoreHealth /Source:$sourceArg /LimitAccess"

    $sw = [Diagnostics.Stopwatch]::StartNew()
    $p  = Start-Process dism.exe -Wait -NoNewWindow -PassThru -ArgumentList @(
        '/Online','/Cleanup-Image','/RestoreHealth',"/Source:$sourceArg",'/LimitAccess',
        "/LogPath:$(Join-Path $LogPath 'dism-wim.log')"
    )
    $sw.Stop()
    $result.WimDismExitCode = $p.ExitCode
    Write-Log "DISM exit $($p.ExitCode) after $([int]$sw.Elapsed.TotalMinutes) min"

    Invoke-Sfc
    $repaired = Test-RepairOutcome
}

#endregion

#region ---------- outcome ----------------------------------------------------

if ($repaired) {
    Write-Log "Repair VERIFIED via $($result.RepairTier)"
    $result.RepairResult = 'Verified'
    $result.CanUpgrade   = $true
} else {
    Write-Log 'Repair INCOMPLETE - consider an in-place repair upgrade or reimage' WARN
    $result.RepairResult = 'Incomplete'
    $result.CanUpgrade   = $false
}

if ($SuspendBitLocker -and $result.CanUpgrade) {
    try {
        $prot = & manage-bde.exe -protectors -get $env:SystemDrive 2>&1 | Out-String
        if ($prot -match 'PIN') {
            Write-Log 'TPM+PIN protector present - suspending BitLocker for 3 reboots'
            Suspend-BitLocker -MountPoint $env:SystemDrive -RebootCount 3 -ErrorAction Stop
            $result.Detail += ';bitlockerSuspended=True'
        } else {
            Write-Log 'No PIN protector - suspend not required'
        }
    } catch { Write-Log "BitLocker suspend failed: $($_.Exception.Message)" WARN }
}

Complete-Preflight -ExitCode $(if ($repaired) { 0 } else { 2 })

#endregion
