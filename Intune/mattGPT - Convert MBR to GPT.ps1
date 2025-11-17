<#
.SYNOPSIS
	Convert MBR to GPT.

.DESCRIPTION
	Validate and convert MBR → GPT using MBR2GPT.exe /validate /convert /allowFullOS.
  Suspend BitLocker if present.
  Log results for fleet reporting.
  Drop a marker (file or registry) when conversion succeeds.

.NOTES
    +------------+---------+---------+--------------------------------------------------------------------+
    | Date       | Author  | Version | Changes                                                            |
    |------------+---------+---------+--------------------------------------------------------------------|
    | 2025-11-04 | mattGPT | 1.0     | Initial script.                                                    |
    +------------+---------+---------+--------------------------------------------------------------------+
#>

[CmdletBinding()]
param([switch]$Convert)

$disk = Get-Disk | Where-Object PartitionStyle -eq 'MBR'
if (-not $disk) { Write-Host "Already GPT"; exit 0 }

# Suspend BitLocker if enabled
$bl = Get-BitLockerVolume -ErrorAction SilentlyContinue | Where-Object VolumeType -eq 'OperatingSystem'
if ($bl.ProtectionStatus -eq 'On') { Suspend-BitLocker -MountPoint $bl.MountPoint -RebootCount 1 }

# Validate
& "$env:SystemRoot\System32\mbr2gpt.exe" /validate /disk:$($disk.Number) /allowFullOS
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($Convert) {
    & "$env:SystemRoot\System32\mbr2gpt.exe" /convert /disk:$($disk.Number) /allowFullOS
    if ($LASTEXITCODE -eq 0) { New-Item 'C:\ProgramData\ReadyForUEFI.flag' -ItemType File }
}
