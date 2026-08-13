<#
.TITLE
    Force AppX / Store Package Update
.SYNOPSIS
    Repairs wedged AppX registration state and forces a Store update scan.
    Works with NO payload (reset + re-register from local manifest), or with a
    local .appx/.msix payload when the Store is locked down.
    Supports -WhatIf for a report-only, zero-change run.
.DESCRIPTION
    Execution order (each stage optional):

      STAGE 1 - RESET      (-ResetFirst)
        Reset-AppxPackage restores the app to its initial configuration, as if
        freshly installed. Clears wedged per-package state without uninstalling.

      STAGE 2 - RE-REGISTER (-ReRegister, or automatic with -ResetFirst and no payload)
        Add-AppxPackage -Register -DisableDevelopmentMode against the package's
        existing AppxManifest.xml. This rebuilds the registration from what is
        already staged on disk - no download, no Store, no payload required.
        Falls back to -DeferRegistrationWhenPackagesAreInUse when the codec is
        loaded, which is the direct counter to 'PackagesInUseRestarted'.

      STAGE 3 - UPDATE FROM PAYLOAD (-LocalPackagePath)
        Add-AppxPackage -Update from a supplied .appx/.msix. Only needed when you
        must move to a newer build and the Store cannot deliver it.

      STAGE 4 - TRIGGER SCAN (default, disable with -SkipScan)
        Invokes UpdateScanMethod on the MDM WMI Bridge class
        MDM_EnterpriseModernAppManagement_AppManagement01 (Root\cimv2\mdm\dmmap),
        then reports LastScanError. Runs last so it can pick up anything newer
        after the local state has been repaired.

    -WhatIf = REPORT ONLY. Inventories packages, matches any payload, and prints
    exactly what WOULD be done - no reset, no register, no install, no scan.

.PARAMETER Packages
    Package name fragments to target. Defaults to the three confirmed codecs.
.PARAMETER ResetFirst
    Run Reset-AppxPackage to clear wedged state. Implies -ReRegister when no
    payload is supplied, so the package is rebuilt after the reset.
.PARAMETER ReRegister
    Re-register each package from its existing AppxManifest.xml. Can be used on
    its own without -ResetFirst for a lighter-touch repair.
.PARAMETER LocalPackagePath
    Optional folder containing .appx/.msix payloads (Store-locked-down scenario).
.PARAMETER ForceShutdown
    Add -ForceApplicationShutdown / -ForceTargetApplicationShutdown. This will
    terminate processes using the package - do NOT use in user hours.
.PARAMETER SkipScan
    Skip the UpdateScanMethod trigger.
.PARAMETER ReportPath
    Optional path to write a text log.

.EXAMPLE
    .\Force-AppxPackageUpdate.ps1 -ResetFirst -WhatIf
    REPORT ONLY. Shows the reset + re-register + scan plan. Changes nothing.

.EXAMPLE
    .\Force-AppxPackageUpdate.ps1 -ResetFirst
    Reset wedged state, re-register from the local manifest, then trigger the
    Store update scan. No payload required. THIS IS THE WEDGED-STATE REPAIR.

.EXAMPLE
    .\Force-AppxPackageUpdate.ps1 -ReRegister -SkipScan
    Lighter touch: re-register only, no reset, no scan.

.EXAMPLE
    .\Force-AppxPackageUpdate.ps1 -ResetFirst -LocalPackagePath C:\Payload
    Reset, then update from payload, then scan.

.NOTES
    Author: Matt Balzan | Version 1.2 | Run elevated.
    v1.2 - -ResetFirst now works standalone: auto re-registers from the existing
           AppxManifest.xml, so no payload is needed. Scan moved to run last.
    v1.1 - added SupportsShouldProcess for a true -WhatIf report-only run.
    Best run pre-logon / SYSTEM at startup so Explorer, Photos, Edge, Teams and
    SearchIndexer have not yet loaded the codec and taken handles.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string[]]$Packages = @(
        'Microsoft.WebpImageExtension',
        'Microsoft.HEIFImageExtension',
        'Microsoft.VP9VideoExtension'
    ),
    [switch]$ResetFirst,
    [switch]$ReRegister,
    [string]$LocalPackagePath,
    [switch]$ForceShutdown,
    [switch]$SkipScan,
    [string]$ReportPath
)

$ErrorActionPreference = 'SilentlyContinue'
$log = New-Object System.Collections.Generic.List[string]

$IsWhatIf = $PSCmdlet.MyInvocation.BoundParameters['WhatIf'].IsPresent -or $WhatIfPreference

# A reset with no payload leaves nothing to rebuild the registration, so
# re-registration is implied. This is the "wedged state, no payload" path.
$DoReRegister = $ReRegister -or ($ResetFirst -and -not $LocalPackagePath)

function Write-Log {
    param([string]$Message,[ValidateSet('INFO','WARN','ERROR','OK','PLAN')][string]$Level='INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    $log.Add($line) | Out-Null
    switch ($Level) {
        'ERROR' { Write-Host $line -ForegroundColor Red }
        'WARN'  { Write-Host $line -ForegroundColor Yellow }
        'OK'    { Write-Host $line -ForegroundColor Green }
        'PLAN'  { Write-Host $line -ForegroundColor Cyan }
        default { Write-Host $line }
    }
}

function Get-PkgSnapshot {
    param([string[]]$Names)
    foreach ($n in $Names) {
        $p = Get-AppxPackage -Name "$n*" -AllUsers | Sort-Object Version -Descending | Select-Object -First 1
        $manifestPath = if ($p) { Join-Path $p.InstallLocation 'AppxManifest.xml' } else { $null }
        [PSCustomObject]@{
            Package      = $n
            Version      = if ($p) { $p.Version.ToString() } else { 'not installed' }
            Status       = if ($p) { ($p.Status -join ',') } else { '-' }
            FullName     = if ($p) { $p.PackageFullName } else { '-' }
            Family       = if ($p) { $p.PackageFamilyName } else { '-' }
            ManifestPath = if ($manifestPath -and (Test-Path $manifestPath)) { $manifestPath } else { $null }
        }
    }
}

$isAdmin = ([Security.Principal.WindowsPrincipal]::new(
             [Security.Principal.WindowsIdentity]::GetCurrent()
           )).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Log "=== Force AppX package update started on $env:COMPUTERNAME (admin: $isAdmin) ==="
if ($IsWhatIf) {
    Write-Log "*** -WhatIf MODE: REPORT ONLY. No reset, re-register, install or scan will occur. ***" 'PLAN'
}
if ($ResetFirst -and -not $LocalPackagePath) {
    Write-Log "Mode: WEDGED-STATE REPAIR (reset + re-register from local manifest, no payload)." 'INFO'
}
if (-not $isAdmin -and -not $IsWhatIf) { Write-Log "Not elevated - AppX operations will likely fail." 'WARN' }

# ---------------------------------------------------------------------------
# Inventory (read-only)
# ---------------------------------------------------------------------------
Write-Log "--- Package versions BEFORE ---"
$before = Get-PkgSnapshot -Names $Packages
$before | Select-Object Package, Version, Status,
                        @{n='Manifest';e={ if ($_.ManifestPath) { 'present' } else { 'MISSING' } }} |
    Format-Table -AutoSize | Out-String | ForEach-Object { Write-Log $_ }

foreach ($row in $before) {
    if ($row.FullName -ne '-' -and -not $row.ManifestPath) {
        Write-Log ("{0}: AppxManifest.xml NOT found - re-register cannot work, payload or reinstall needed." -f $row.Package) 'WARN'
    }
}

# ---------------------------------------------------------------------------
# Payload matching (read-only)
# ---------------------------------------------------------------------------
$payloadMap = @{}
if ($LocalPackagePath) {
    if (-not (Test-Path $LocalPackagePath)) {
        Write-Log "LocalPackagePath not found: $LocalPackagePath" 'ERROR'
    }
    else {
        $payloads = Get-ChildItem -Path $LocalPackagePath -Include '*.appx','*.msix','*.appxbundle','*.msixbundle' -File -Recurse
        Write-Log ("Payload folder contains {0} package file(s)." -f @($payloads).Count)
        foreach ($p in $Packages) {
            $file = $payloads | Where-Object { $_.Name -like "*$p*" } | Sort-Object Name -Descending | Select-Object -First 1
            if ($file) { $payloadMap[$p] = $file ; Write-Log ("  MATCH  {0}  ->  {1}" -f $p, $file.Name) }
            else       { Write-Log ("  NO MATCH for {0} - would be skipped." -f $p) 'WARN' }
        }
    }
}

# ---------------------------------------------------------------------------
# -WhatIf: print plan and exit
# ---------------------------------------------------------------------------
if ($IsWhatIf) {
    Write-Log ''
    Write-Log "--- PLANNED ACTIONS (nothing executed) ---" 'PLAN'

    if ($ResetFirst) {
        foreach ($row in $before) {
            if ($row.FullName -ne '-') { Write-Log ("WhatIf: Reset-AppxPackage -Package {0}" -f $row.FullName) 'PLAN' }
            else { Write-Log ("WhatIf: {0} not installed - reset skipped." -f $row.Package) 'PLAN' }
        }
    } else { Write-Log "WhatIf: No reset (-ResetFirst not supplied)." 'PLAN' }

    if ($DoReRegister) {
        foreach ($row in $before) {
            if ($row.ManifestPath) {
                Write-Log ("WhatIf: Add-AppxPackage -Register '{0}' -DisableDevelopmentMode" -f $row.ManifestPath) 'PLAN'
                Write-Log  "WhatIf:   On failure, retry with -DeferRegistrationWhenPackagesAreInUse." 'PLAN'
            } elseif ($row.FullName -ne '-') {
                Write-Log ("WhatIf: {0} has no manifest - re-register would fail." -f $row.Package) 'WARN'
            }
        }
    } else { Write-Log "WhatIf: No re-registration planned." 'PLAN' }

    if ($LocalPackagePath) {
        foreach ($p in $Packages) {
            if ($payloadMap.ContainsKey($p)) {
                $flags = @('-Update','-ForceUpdateFromAnyVersion')
                if ($ForceShutdown) { $flags += '-ForceApplicationShutdown','-ForceTargetApplicationShutdown' }
                Write-Log ("WhatIf: Add-AppxPackage -Path '{0}' {1}" -f $payloadMap[$p].FullName, ($flags -join ' ')) 'PLAN'
            }
        }
    } else { Write-Log "WhatIf: No payload update (no -LocalPackagePath)." 'PLAN' }

    if (-not $SkipScan) {
        Write-Log "WhatIf: Invoke UpdateScanMethod on MDM_EnterpriseModernAppManagement_AppManagement01, then read LastScanError." 'PLAN'
    } else { Write-Log "WhatIf: Update scan SKIPPED (-SkipScan)." 'PLAN' }

    if ($ForceShutdown) { Write-Log "WhatIf: -ForceShutdown SET. Live run would terminate processes using these packages." 'WARN' }

    Write-Log ''
    Write-Log "=== WhatIf complete. No changes made. Re-run without -WhatIf to execute. ===" 'PLAN'
    if ($ReportPath) { $log | Out-File -FilePath $ReportPath -Encoding UTF8 -Force ; Write-Host "`nReport saved to: $ReportPath" -ForegroundColor Green }
    return
}

# ---------------------------------------------------------------------------
# STAGE 1: Reset wedged package state
# ---------------------------------------------------------------------------
if ($ResetFirst) {
    Write-Log "--- STAGE 1: Reset-AppxPackage (restore to initial configuration) ---"
    foreach ($row in $before) {
        if ($row.FullName -eq '-') { Write-Log "$($row.Package) not installed - reset skipped." 'WARN' ; continue }
        if ($PSCmdlet.ShouldProcess($row.FullName, "Reset-AppxPackage")) {
            try {
                Reset-AppxPackage -Package $row.FullName -ErrorAction Stop
                Write-Log "Reset OK: $($row.Package)" 'OK'
            } catch {
                Write-Log "Reset failed for $($row.Package): $($_.Exception.Message)" 'WARN'
            }
        }
    }
}

# ---------------------------------------------------------------------------
# STAGE 2: Re-register from the existing AppxManifest.xml (no payload needed)
# ---------------------------------------------------------------------------
if ($DoReRegister) {
    Write-Log "--- STAGE 2: Re-register from local AppxManifest.xml ---"

    # Re-read state: a reset can change the package full name / install location
    $current = Get-PkgSnapshot -Names $Packages

    foreach ($row in $current) {
        if (-not $row.ManifestPath) {
            Write-Log "$($row.Package): no manifest found - cannot re-register. Payload or reinstall required." 'WARN'
            continue
        }
        if (-not $PSCmdlet.ShouldProcess($row.Package, "Add-AppxPackage -Register from manifest")) { continue }

        $splat = @{
            Register               = $true
            Path                   = $row.ManifestPath
            DisableDevelopmentMode = $true
            ErrorAction            = 'Stop'
        }
        if ($ForceShutdown) {
            $splat['ForceApplicationShutdown']       = $true
            $splat['ForceTargetApplicationShutdown'] = $true
            Write-Log "ForceShutdown enabled - processes using $($row.Package) will be terminated." 'WARN'
        }

        try {
            Add-AppxPackage @splat
            Write-Log "Re-registered $($row.Package) from local manifest." 'OK'
        }
        catch {
            Write-Log "Re-register failed for $($row.Package): $($_.Exception.Message)" 'ERROR'

            # In-use fallback - the direct counter to PackagesInUseRestarted
            Write-Log "Retrying $($row.Package) with -DeferRegistrationWhenPackagesAreInUse..."
            try {
                Add-AppxPackage -Register $row.ManifestPath `
                                -DisableDevelopmentMode `
                                -DeferRegistrationWhenPackagesAreInUse `
                                -ErrorAction Stop
                Write-Log "Deferred registration accepted for $($row.Package) - applies on next activation/reboot." 'OK'
            }
            catch {
                Write-Log "Deferred retry also failed for $($row.Package): $($_.Exception.Message)" 'ERROR'
            }
        }
    }
}

# ---------------------------------------------------------------------------
# STAGE 3: Update from local payload (only if supplied)
# ---------------------------------------------------------------------------
if ($LocalPackagePath -and $payloadMap.Count -gt 0) {
    Write-Log "--- STAGE 3: Update from payload: $LocalPackagePath ---"
    foreach ($p in $Packages) {
        if (-not $payloadMap.ContainsKey($p)) { Write-Log "No payload for $p - skipped." 'WARN' ; continue }
        $file = $payloadMap[$p]
        if (-not $PSCmdlet.ShouldProcess($p, "Add-AppxPackage -Update from $($file.Name)")) { continue }

        $splat = @{
            Path                      = $file.FullName
            Update                    = $true
            ForceUpdateFromAnyVersion = $true
            ErrorAction               = 'Stop'
        }
        if ($ForceShutdown) {
            $splat['ForceApplicationShutdown']       = $true
            $splat['ForceTargetApplicationShutdown'] = $true
        }

        try {
            Add-AppxPackage @splat
            Write-Log "Updated $p from $($file.Name)" 'OK'
        }
        catch {
            Write-Log "Update failed for $p : $($_.Exception.Message)" 'ERROR'
            Write-Log "Retrying $p with -DeferRegistrationWhenPackagesAreInUse..."
            try {
                Add-AppxPackage -Path $file.FullName `
                                -DeferRegistrationWhenPackagesAreInUse `
                                -ForceUpdateFromAnyVersion `
                                -ErrorAction Stop
                Write-Log "Deferred-registration update accepted for $p (applies on next activation)." 'OK'
            }
            catch {
                Write-Log "Deferred retry also failed for $p : $($_.Exception.Message)" 'ERROR'
            }
        }
    }
}

# ---------------------------------------------------------------------------
# STAGE 4: Trigger the modern-app update scan (runs LAST, post-repair)
# ---------------------------------------------------------------------------
if (-not $SkipScan) {
    if ($PSCmdlet.ShouldProcess("Modern app update scan (MDM WMI Bridge)", "Invoke UpdateScanMethod")) {
        Write-Log "--- STAGE 4: Triggering UpdateScanMethod (MDM WMI Bridge) ---"
        try {
            $cim = Get-CimInstance -Namespace 'Root\cimv2\mdm\dmmap' `
                                   -ClassName 'MDM_EnterpriseModernAppManagement_AppManagement01' `
                                   -ErrorAction Stop
            $res = $cim | Invoke-CimMethod -MethodName 'UpdateScanMethod' -ErrorAction Stop
            Write-Log ("UpdateScanMethod returned: {0}" -f ($res.ReturnValue)) 'OK'

            Start-Sleep -Seconds 5

            $post = Get-CimInstance -Namespace 'Root\cimv2\mdm\dmmap' `
                                    -ClassName 'MDM_EnterpriseModernAppManagement_AppManagement01'
            $err = $post.LastScanError
            if ($err -eq 0 -or $null -eq $err) { Write-Log "LastScanError = $err (0 / null = no scan error)" 'OK' }
            else { Write-Log ("LastScanError = {0} (0x{1:X8}) - scan reported a problem" -f $err, $err) 'WARN' }
        }
        catch {
            Write-Log "UpdateScanMethod failed: $($_.Exception.Message)" 'ERROR'
            Write-Log "Note: this can hang if the Store app is open, or be blocked by policy." 'WARN'
        }
    }
}

# ---------------------------------------------------------------------------
# AFTER snapshot + delta
# ---------------------------------------------------------------------------
Start-Sleep -Seconds 3
Write-Log "--- Package versions AFTER ---"
$after = Get-PkgSnapshot -Names $Packages
$after | Format-Table Package, Version, Status -AutoSize | Out-String | ForEach-Object { Write-Log $_ }

Write-Log "--- CHANGE SUMMARY ---"
foreach ($b in $before) {
    $a = $after | Where-Object Package -eq $b.Package
    $verChanged = $b.Version  -ne $a.Version
    $stChanged  = $b.Status   -ne $a.Status
    $note = if ($verChanged) { '*** VERSION UPDATED ***' }
            elseif ($stChanged) { '*** STATUS CHANGED (repair applied) ***' }
            else { 'no change' }
    Write-Log ("{0,-35} {1} [{2}]  ->  {3} [{4}]   {5}" -f `
              $b.Package, $b.Version, $b.Status, $a.Version, $a.Status, $note) `
              $(if ($verChanged -or $stChanged) { 'OK' } else { 'INFO' })
}

$lastErr = Get-AppxLastError
if ($lastErr) { Write-Log "Get-AppxLastError: $lastErr" 'WARN' }

Write-Log "=== Complete. If deferred registration was used, reboot or re-activate the app to apply. ==="
Write-Log "Next: monitor C:\Windows\Temp for new AppXErrorReport*.txt / *.evtx to confirm the loop has stopped."

if ($ReportPath) {
    $log | Out-File -FilePath $ReportPath -Encoding UTF8 -Force
    Write-Host "`nLog saved to: $ReportPath" -ForegroundColor Green
}
