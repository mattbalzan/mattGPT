<#
.SYNOPSIS
	Installs one or more device drivers from a specified folder using PnPUtil.

.DESCRIPTION
    This script recursively scans a target directory for all .inf driver files and
    installs each driver using Microsoft's recommended PnPUtil method. It includes
    basic error handling, supports structured output, and is suitable for use in
    Intune, MECM Task Sequences, or local automation. The script can be extended
    to include logging, hardware-strict matching, or pre-installation comparison
    against currently installed drivers.

.NOTES
    +------------+---------+---------+--------------------------------------------------------------------+
    | Date       | Author  | Version | Changes                                                            |
    |------------+---------+---------+--------------------------------------------------------------------|
    | 2025-11-18 | mattGPT | 1.0     | Initial script.                                                    |
    +------------+---------+---------+--------------------------------------------------------------------+
#>

param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ })]
    [string]$DriverPath
)

# Create debug log
$Log = "C:\Windows\Temp\DriverInstall_$(Get-Date -Format yyyyMMdd_HHmm).log"
Start-Transcript -Path $Log -Force

# Enumerate all .inf driver files
$infFiles = Get-ChildItem -Path $DriverPath -Recurse -Filter *.inf -ErrorAction Stop

if (-not $infFiles) {
    Write-Error "No .inf files found in $DriverPath"
    exit 1
}

foreach ($inf in $infFiles) {
    try {
        Write-Output "Installing driver: $($inf.FullName)"
        
        # Add and install the driver
        $result = pnputil.exe /add-driver "$($inf.FullName)" /install

        Write-Output $result
    }
    catch {
        Write-Warning "Failed to install driver: $($inf.FullName). Error: $($_.Exception.Message)"
    }
}

Stop-Transcript

# End of script
