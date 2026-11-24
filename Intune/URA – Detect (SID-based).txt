<#
.SYNOPSIS
    User Rights Assignment (URA) detection for Intune Remediations (SID-based, secedit USER_RIGHTS).
.DESCRIPTION
    * Embedded CSV = single source of truth (Right, Mode, Principals). Principals may be SIDs or names;
      everything is normalised to SIDs before comparing.
    * Mode 'Exact'    -> live list must equal the expected list.
      Mode 'Contains' -> live list must include the expected principals (remedy keeps existing ones).
    * Exports the live USER_RIGHTS with secedit, compares, and writes a SecEdit INF containing ONLY the
      drifted rights. The working folder is locked to SYSTEM + Administrators (the INF is applied as SYSTEM).
    * Exit 0 = compliant, Exit 1 = non-compliant (triggers the remediation script).
    Deploy: Intune > Devices > Scripts and remediations. Run as SYSTEM, 64-bit PowerShell = Yes.
.NOTES
    | Date       | Version | Changes                                   |
    | 2026-11-24 | 2.0     | Draft: URA/SID variant of the NBB pattern |
    NOT TESTED - validate on a non-production device first.
#>
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

# ---------------- CONFIGURATION ----------------
$BaseDir      = Join-Path $env:ProgramData 'URA-Remediation'
$LogFile      = Join-Path $BaseDir 'URA.log'
$InfFile      = Join-Path $BaseDir 'URA-Desired.inf'
$LiveFile     = Join-Path $BaseDir 'URA-Live.inf'
$MaxLogSizeMB = 5

# EXAMPLE VALUES ONLY - replace with the customer's approved rights/principals.
$csv = @'
Right,Mode,Principals
SeInteractiveLogonRight,Exact,"S-1-5-32-544;S-1-5-32-545"
SeRemoteInteractiveLogonRight,Exact,"S-1-5-32-544;S-1-5-32-555"
SeDenyNetworkLogonRight,Contains,"S-1-5-32-546"
'@ | ConvertFrom-Csv

# ---------------- SECURE WORKING FOLDER ----------------
if (-not (Test-Path -LiteralPath $BaseDir)) { New-Item -Path $BaseDir -ItemType Directory -Force | Out-Null }
# Remove inherited ACEs; SYSTEM + Administrators only (prevents a standard user tampering with the INF)
& icacls.exe $BaseDir /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null

# ---------------- HELPERS ----------------
function Log {
    param([string]$Message)
    try {
        if ((Test-Path -LiteralPath $LogFile) -and ((Get-Item -LiteralPath $LogFile).Length / 1MB) -ge $MaxLogSizeMB) {
            Rename-Item -LiteralPath $LogFile -NewName ('URA.log.{0}' -f (Get-Date -Format 'yyyyMMdd_HHmmss')) -Force
        }
        [System.IO.File]::AppendAllText($LogFile, ("{0} | DETECT | {1}{2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message, [Environment]::NewLine))
    } catch {}
}

function ConvertTo-SidString {
    param([string]$Principal)
    $p = $Principal.Trim()
    if ($p -match '^\*?(S-1-\d+(-\d+)+)$') { return $Matches[1].ToUpperInvariant() }
    try {
        return ([System.Security.Principal.NTAccount]$p).Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch {
        return $p   # unresolved/orphaned name: keep raw so it shows up as drift
    }
}

function Get-LiveRights {
    & secedit.exe /export /cfg $LiveFile /areas USER_RIGHTS /quiet | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "secedit /export failed ($LASTEXITCODE)" }
    $map = @{}
    foreach ($line in Get-Content -LiteralPath $LiveFile) {
        if ($line -match '^\s*(Se\w+)\s*=\s*(.*)$') {
            $map[$Matches[1]] = @($Matches[2] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } |
                                  ForEach-Object { ConvertTo-SidString $_ })
        }
    }
    $map
}

# ---------------- COMPARE ----------------
try {
    Log '===== URA detection started ====='
    $live    = Get-LiveRights
    $desired = [ordered]@{}

    foreach ($row in $csv) {
        $right    = $row.Right.Trim()
        $expected = @($row.Principals -split ';' | Where-Object { $_.Trim() } | ForEach-Object { ConvertTo-SidString $_ } | Sort-Object -Unique)
        $actual   = @(if ($live.ContainsKey($right)) { $live[$right] | Sort-Object -Unique })

        $missing = @($expected | Where-Object { $_ -notin $actual })
        $extra   = @($actual   | Where-Object { $_ -notin $expected })

        $compliant = if ($row.Mode -eq 'Contains') { $missing.Count -eq 0 } else { ($missing.Count -eq 0 -and $extra.Count -eq 0) }

        if ($compliant) {
            Log "COMPLIANT: $right"
        } else {
            Log ("NON-COMPLIANT: {0} | Mode={1} | Missing=[{2}] | Extra=[{3}]" -f $right, $row.Mode, ($missing -join ','), ($extra -join ','))
            $desired[$right] = if ($row.Mode -eq 'Contains') { @($actual + $expected | Sort-Object -Unique) } else { $expected }
        }
    }

    if ($desired.Count -eq 0) {
        Remove-Item -LiteralPath $InfFile -Force -ErrorAction SilentlyContinue   # never leave a stale INF behind
        Log 'No drift detected.'
        Write-Output 'Compliant'
        exit 0
    }

    $inf = [System.Collections.Generic.List[string]]::new()
    $inf.Add('[Unicode]'); $inf.Add('Unicode=yes')
    $inf.Add('[Version]'); $inf.Add('signature="$CHICAGO$"'); $inf.Add('Revision=1')
    $inf.Add('[Privilege Rights]')
    foreach ($k in $desired.Keys) { $inf.Add(('{0} = {1}' -f $k, (($desired[$k] | ForEach-Object { "*$_" }) -join ','))) }
    Set-Content -LiteralPath $InfFile -Value $inf -Encoding Unicode

    Log "Desired INF written ($($desired.Count) right(s)). Triggering remediation."
    Write-Output ('Non-compliant: ' + ($desired.Keys -join ','))
    exit 1
}
catch {
    Log "ERROR: $($_.Exception.Message)"
    Write-Output "Detection error: $($_.Exception.Message)"
    exit 1
}
