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
