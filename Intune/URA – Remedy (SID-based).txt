<#
.SYNOPSIS
    User Rights Assignment (URA) remediation for Intune Remediations (SID-based, secedit USER_RIGHTS).
.DESCRIPTION
    * Applies the INF written by the detection script (only drifted rights).
    * Takes a timestamped backup of the live USER_RIGHTS first (rollback = secedit /configure with that file).
    * Checks secedit's exit code (native exe failures are NOT caught by try/catch), then re-reads the
      live rights and verifies every right in the INF now matches.
    * Cleans up only on verified success, so failures stay diagnosable.
.NOTES
    | Date       | Version | Changes                                   |
    | 2026-11-24 | 2.0     | Draft: URA/SID variant of the NBB pattern |
    NOT TESTED - validate on a non-production device first.
#>
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$BaseDir      = Join-Path $env:ProgramData 'URA-Remediation'
$LogFile      = Join-Path $BaseDir 'URA.log'
$InfFile      = Join-Path $BaseDir 'URA-Desired.inf'
$LiveFile     = Join-Path $BaseDir 'URA-Live.inf'
$SdbFile      = Join-Path $BaseDir 'URA-Temp.sdb'
$SeceditLog   = Join-Path $BaseDir 'URA-Secedit.log'
$MaxLogSizeMB = 5

function Log {
    param([string]$Message)
    try {
        if ((Test-Path -LiteralPath $LogFile) -and ((Get-Item -LiteralPath $LogFile).Length / 1MB) -ge $MaxLogSizeMB) {
            Rename-Item -LiteralPath $LogFile -NewName ('URA.log.{0}' -f (Get-Date -Format 'yyyyMMdd_HHmmss')) -Force
        }
        [System.IO.File]::AppendAllText($LogFile, ("{0} | REMEDY | {1}{2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message, [Environment]::NewLine))
    } catch {}
}

function ConvertTo-SidString {
    param([string]$Principal)
    $p = $Principal.Trim()
    if ($p -match '^\*?(S-1-\d+(-\d+)+)$') { return $Matches[1].ToUpperInvariant() }
    try { return ([System.Security.Principal.NTAccount]$p).Translate([System.Security.Principal.SecurityIdentifier]).Value }
    catch { return $p }
}

function Read-RightsFile {
    param([string]$Path)
    $map = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*(Se\w+)\s*=\s*(.*)$') {
            $map[$Matches[1]] = @($Matches[2] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } |
                                  ForEach-Object { ConvertTo-SidString $_ } | Sort-Object -Unique)
        }
    }
    $map
}

try {
    Log '===== URA remediation started ====='
    if (-not (Test-Path -LiteralPath $InfFile)) { Log 'No desired INF present - nothing to do.'; Write-Output 'Nothing to remediate'; exit 0 }

    # 1) Backup (rollback point)
    $backup = Join-Path $BaseDir ('URA-Backup-{0}.inf' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    & secedit.exe /export /cfg $backup /areas USER_RIGHTS /quiet | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Backup export failed ($LASTEXITCODE) - aborting before any change." }
    Log "Backup saved: $backup"

    # 2) Apply
    & secedit.exe /configure /db $SdbFile /cfg $InfFile /areas USER_RIGHTS /log $SeceditLog /quiet
    if ($LASTEXITCODE -ne 0) { throw "secedit /configure failed ($LASTEXITCODE). See $SeceditLog" }

    # 3) Verify against what we asked for
    & secedit.exe /export /cfg $LiveFile /areas USER_RIGHTS /quiet | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Post-change export failed ($LASTEXITCODE)" }
    $want = Read-RightsFile $InfFile
    $now  = Read-RightsFile $LiveFile
    $bad  = foreach ($r in $want.Keys) {
        $have = @(if ($now.ContainsKey($r)) { $now[$r] })
        if (Compare-Object -ReferenceObject $want[$r] -DifferenceObject $have) { $r }
    }
    if ($bad) { throw "Verification failed for: $($bad -join ', ')" }

    # 4) Cleanup on verified success only (keep the newest backups)
    Remove-Item -LiteralPath $InfFile, $SdbFile, "$SdbFile.jfm" -Force -ErrorAction SilentlyContinue
    Get-ChildItem -LiteralPath $BaseDir -Filter 'URA-Backup-*.inf' | Sort-Object LastWriteTime -Descending |
        Select-Object -Skip 5 | Remove-Item -Force -ErrorAction SilentlyContinue

    Log "Remediation verified for: $($want.Keys -join ', ')"
    Write-Output "Remediated: $($want.Keys -join ', ')"
    exit 0
}
catch {
    Log "ERROR: $($_.Exception.Message)"
    Write-Output "Remediation error: $($_.Exception.Message)"
    exit 1
}
