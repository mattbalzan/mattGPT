<#
.SYNOPSIS
	Checks whether all required Services are present and running, then reports a Boolean compliance value for Intune Compliance.

.DESCRIPTION
	This script validates the state of several Sophos security-related Windows services.  
    It confirms that each required service exists and is currently in a Running state.  
    If any service is missing or not running, the script returns a Boolean value of False;  
    otherwise, it returns True.  
    The result is output as a flat JSON object formatted specifically for Intune Custom  
    Compliance policies, where the SettingName "SophosServicesRunning" is evaluated  
    against a Boolean rule in the associated JSON definition.

.OUTPUTS
JSON object containing:
    { "SophosServicesRunning": <Boolean> }

.NOTES
    +------------+---------+---------+--------------------------------------------------------------------+
    | Date       | Author  | Version | Changes                                                            |
    |------------+---------+---------+--------------------------------------------------------------------|
    | 2025-11-15 | mattGPT | 1.0     | Initial script.                                                    |
    +------------+---------+---------+--------------------------------------------------------------------+
#>

# Ensure strict mode for safety
Set-StrictMode -Version Latest

# Service list (use service *names*, not display names, for reliability)
$services = @(
    "Sophos Endpoint Defense Service",
    "Sophos MCS Agent",
    "Sophos MCS Client",
    "Sophos File Scanner Service",
    "Sophos Network Threat Protection"
)

$allRunning = $true

foreach ($service in $services) {
    try {
        $svc = Get-Service -Name $service -ErrorAction Stop
        if ($svc.Status -ne 'Running') {
            $allRunning = $false
        }
    }
    catch {
        # Service missing
        $allRunning = $false
    }
}

# Force boolean type to avoid Intune parsing issues
$result = @{
    SophosServicesRunning = [bool]$allRunning
}

$result | ConvertTo-Json -Compress
