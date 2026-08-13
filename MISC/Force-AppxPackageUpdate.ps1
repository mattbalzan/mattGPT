<#
.TITLE
    Force AppX / Store Package Update
.SYNOPSIS
    Forces a Microsoft Store / AppX package update scan, and optionally applies an
    update from a local .appx/.msix payload - with in-use-safe registration.
    Supports -WhatIf for a report-only, zero-change run.
.DESCRIPTION
    Three escalating methods, all scriptable and Store-UI free:

      MODE 1 (default) - TRIGGER SCAN
        Invokes UpdateScanMethod on the MDM WMI Bridge class
        MDM_EnterpriseModernAppManagement_AppManagement01 (Root\cimv2\mdm\dmmap),
        which starts the Windows Update scan for modern apps, then reports the
        LastScanError property so you can verify the outcome.

      MODE 2 (-LocalPackagePath) - UPDATE FROM PAYLOAD
        Uses Add-AppxPackage -Update against a supplied .appx/.msix. The new
        package MUST have the same package family name as the installed one.
        Falls back to -DeferRegistrationWhenPackagesAreInUse so registration is
        delayed until next activation if the codec is currently loaded - the
        direct counter to 'PackagesInUseRestarted' failures.

      MODE 3 (-ResetFirst) - RESET THEN UPDATE
        Runs Reset-AppxPackage (restores the app to initial configuration)
        before attempting the update. Use when registration state looks wedged.

    -WhatIf  =  REPORT ONLY. Enumerates the packages, shows current version and
    status, matches available payload files, and prints exactly what WOULD be
    done - without triggering a scan, resetting, or installing anything.

.PARAMETER Packages
    Package name fragments to target. Defaults to the three confirmed codecs.
.PARAMETER LocalPackagePath
    Optional folder containing .appx/.msix payloads. Enables MODE 2.
    Files are matched to packages by name fragment.
.PARAMETER ResetFirst
    Run Reset-AppxPackage before updating (MODE 3).
.PARAMETER ForceShutdown
    Add -ForceApplicationShutdown / -ForceTargetApplicationShutdown. This will
    terminate processes using the package - do NOT use in user hours.
.PARAMETER SkipScan
    Skip the UpdateScanMethod trigger (payload-only run).
.PARAMETER ReportPath
    Optional path to write a text log.

.EXAMPLE
    .\Force-AppxPackageUpdate.ps1 -WhatIf
    REPORT ONLY. Lists the codec packages, versions, status and planned actions.
    Changes nothing.

.EXAMPLE
    .\Force-AppxPackageUpdate.ps1 -LocalPackagePath C:\Payload -WhatIf
    REPORT ONLY. Also shows which payload file would be applied to which package.

.EXAMPLE
    .\Force-AppxPackageUpdate.ps1
    Trigger a Store update scan and report LastScanError + package versions.

.EXAMPLE
    .\Force-AppxPackageUpdate.ps1 -LocalPackagePath C:\Payload
    Trigger scan, then update each codec from local payload, deferring
    registration if the package is in use.

.NOTES
    Author: Matt Balzan | Version 1.1 | Run elevated.
    v1.1 - added SupportsShouldProcess so -WhatIf gives a true report-only run.
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
    [string]$LocalPackagePath,
    [switch]$ResetFirst,
    [switch]$ForceShutdown,
    [switch]$SkipScan,
    [string]$ReportPath
)

$ErrorActionPreference = 'SilentlyContinue'
$log = New-Object System.Collections.Generic.List[string]

# True when -WhatIf is supplied
$IsWhatIf = $PSCmdlet.MyInvocation.BoundParameters['WhatIf'].IsPresent -or $WhatIfPreference

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
        [PSCustomObject]@{
            Package  = $n
            Version  = if ($p) { $p.Version.ToString() } else { 'not installed' }
            Status   = if ($p) { ($p.Status -join ',') } else { '-' }
            FullName = if ($p) { $p.PackageFullName } else { '-' }
            Family   = if ($p) { $p.PackageFamilyName } else { '-' }
            Manifest = if ($p -and (Test-Path (Join-Path $p.InstallLocation 'AppxManifest.xml'))) { $true } else { $false }
        }
    }
}

$isAdmin = ([Security.Principal.WindowsPrincipal]::new(
             [Security.Principal.WindowsIdentity]::GetCurrent()
           )).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Log "=== Force AppX package update started on $env:COMPUTERNAME (admin: $isAdmin) ==="
if ($IsWhatIf) {
    Write-Log "*** -WhatIf MODE: REPORT ONLY. No scan, no reset, no install will occur. ***" 'PLAN'
}
if (-not $isAdmin -and -not $IsWhatIf) { Write-Log "Not elevated - AppX operations will likely fail." 'WARN' }

# ---------------------------------------------------------------------------
# Package inventory (always runs - read-only)
# ---------------------------------------------------------------------------
Write-Log "--- Package versions BEFORE ---"
$before = Get-PkgSnapshot -Names $Packages
$before | Format-Table Package, Version, Status, Manifest -AutoSize | Out-String | ForEach-Object { Write-Log $_ }

# ---------------------------------------------------------------------------
# Payload matching (read-only - useful in -WhatIf to prove what would apply)
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
            if ($file) {
                $payloadMap[$p] = $file
                Write-Log ("  MATCH  {0}  ->  {1}" -f $p, $file.Name)
            } else {
                Write-Log ("  NO MATCH for {0} - would be skipped." -f $p) 'WARN'
            }
        }
    }
}

# ---------------------------------------------------------------------------
# -WhatIf: print the plan and exit before any state change
# ---------------------------------------------------------------------------
if ($IsWhatIf) {
    Write-Log ''
    Write-Log "--- PLANNED ACTIONS (nothing executed) ---" 'PLAN'

    if (-not $SkipScan) {
        Write-Log "WhatIf: Would invoke UpdateScanMethod on MDM_EnterpriseModernAppManagement_AppManagement01 (Root\cimv2\mdm\dmmap), then read LastScanError." 'PLAN'
    } else {
        Write-Log "WhatIf: Update scan SKIPPED (-SkipScan supplied)." 'PLAN'
    }

    if ($ResetFirst) {
        foreach ($row in $before) {
            if ($row.FullName -ne '-') {
                Write-Log ("WhatIf: Would run Reset-AppxPackage -Package {0}" -f $row.FullName) 'PLAN'
            } else {
                Write-Log ("WhatIf: {0} not installed - reset would be skipped." -f $row.Package) 'PLAN'
            }
        }
    }

    if ($LocalPackagePath) {
        foreach ($p in $Packages) {
            if ($payloadMap.ContainsKey($p)) {
                $flags = @('-Update','-ForceUpdateFromAnyVersion')
                if ($ForceShutdown) { $flags += '-ForceApplicationShutdown','-ForceTargetApplicationShutdown' }
                Write-Log ("WhatIf: Would run Add-AppxPackage -Path '{0}' {1}" -f $payloadMap[$p].FullName, ($flags -join ' ')) 'PLAN'
                Write-Log ("WhatIf:   On failure, would retry with -DeferRegistrationWhenPackagesAreInUse.") 'PLAN'
            }
        }
    } else {
        Write-Log "WhatIf: No -LocalPackagePath supplied - no payload update would be attempted." 'PLAN'
    }

    if ($ForceShutdown) {
        Write-Log "WhatIf: -ForceShutdown is SET. Live run would terminate processes using these packages." 'WARN'
    }

    Write-Log ''
    Write-Log "=== WhatIf complete. No changes made. Re-run without -WhatIf to execute. ===" 'PLAN'

    if ($ReportPath) {
        $log | Out-File -FilePath $ReportPath -Encoding UTF8 -Force
        Write-Host "`nReport saved to: $ReportPath" -ForegroundColor Green
    }
    return
}

# ---------------------------------------------------------------------------
# MODE 1: Trigger the modern-app update scan via MDM WMI Bridge
# ---------------------------------------------------------------------------
if (-not $SkipScan) {
    if ($PSCmdlet.ShouldProcess("Modern app update scan (MDM WMI Bridge)", "Invoke UpdateScanMethod")) {
        Write-Log "Triggering UpdateScanMethod (MDM WMI Bridge)..."
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
            if ($err -eq 0 -or $null -eq $err) {
                Write-Log "LastScanError = $err (0 / null = no scan error)" 'OK'
            } else {
                Write-Log ("LastScanError = {0} (0x{1:X8}) - scan reported a problem" -f $err, $err) 'WARN'
            }
        }
        catch {
            Write-Log "UpdateScanMethod failed: $($_.Exception.Message)" 'ERROR'
            Write-Log "Note: this can hang if the Store app is open, or be blocked by policy." 'WARN'
        }
    }
}

# ---------------------------------------------------------------------------
# MODE 3: Optional reset of wedged package state
# ---------------------------------------------------------------------------
if ($ResetFirst) {
    Write-Log "--- Reset-AppxPackage (restore to initial configuration) ---"
    foreach ($row in $before) {
        if ($row.FullName -ne '-') {
            if ($PSCmdlet.ShouldProcess($row.FullName, "Reset-AppxPackage")) {
                try {
                    Reset-AppxPackage -Package $row.FullName -ErrorAction Stop
                    Write-Log "Reset OK: $($row.FullName)" 'OK'
                } catch {
                    Write-Log "Reset failed for $($row.Package): $($_.Exception.Message)" 'WARN'
                }
            }
        }
    }
}

# ---------------------------------------------------------------------------
# MODE 2: Update from local payload (Store-locked-down friendly)
# ---------------------------------------------------------------------------
if ($LocalPackagePath -and $payloadMap.Count -gt 0) {
    Write-Log "--- Updating from payload: $LocalPackagePath ---"

    foreach ($p in $Packages) {
        if (-not $payloadMap.ContainsKey($p)) {
            Write-Log "No payload found for $p - skipped." 'WARN'
            continue
        }
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
            Write-Log "ForceShutdown enabled - processes using $p will be terminated." 'WARN'
        }

        try {
            Add-AppxPackage @splat
            Write-Log "Updated $p from $($file.Name)" 'OK'
        }
        catch {
            Write-Log "Update failed for $p : $($_.Exception.Message)" 'ERROR'

            # Retry with deferred registration - the counter to PackagesInUseRestarted
            Write-Log "Retrying $p with -DeferRegistrationWhenPackagesAreInUse..." 'INFO'
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
# AFTER snapshot + delta
# ---------------------------------------------------------------------------
Start-Sleep -Seconds 3
Write-Log "--- Package versions AFTER ---"
$after = Get-PkgSnapshot -Names $Packages
$after | Format-Table Package, Version, Status -AutoSize | Out-String | ForEach-Object { Write-Log $_ }

Write-Log "--- CHANGE SUMMARY ---"
foreach ($b in $before) {
    $a = $after | Where-Object Package -eq $b.Package
    $changed = $b.Version -ne $a.Version
    Write-Log ("{0,-35} {1}  ->  {2}   {3}" -f $b.Package, $b.Version, $a.Version,
              $(if ($changed) { '*** UPDATED ***' } else { 'no change' })) `
              $(if ($changed) { 'OK' } else { 'INFO' })
}

$lastErr = Get-AppxLastError
if ($lastErr) { Write-Log "Get-AppxLastError: $lastErr" 'WARN' }

Write-Log "=== Complete. If deferred registration was used, reboot or re-activate the app to apply. ==="

if ($ReportPath) {
    $log | Out-File -FilePath $ReportPath -Encoding UTF8 -Force
    Write-Host "`nLog saved to: $ReportPath" -ForegroundColor Green
}
