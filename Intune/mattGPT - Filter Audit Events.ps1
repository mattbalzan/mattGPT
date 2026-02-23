<#
.SYNOPSIS
	Query Intune Audit Events for importing Autopilot devices.

.DESCRIPTION
	Query Intune Audit Events for importing Autopilot devices.
    Filters activities within custom date range.

.NOTES
    +------------+---------+---------+--------------------------------------------------------------------+
    | Date       | Author  | Version | Changes                                                            |
    |------------+---------+---------+--------------------------------------------------------------------|
    | 2026-02-23 | mattGPT | 1.0     | Initial script.                                                    |
    +------------+---------+---------+--------------------------------------------------------------------+
#>

# ---------------------------
# CALCULATE N-DAY WINDOW
# ---------------------------
# Days to look back
$days = 90

# Correct ISO8601 formats with milliseconds + Z
$dateNow  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$cutoff   = (Get-Date).AddDays(-$days).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")


# ---------------------------
# CONFIGURATION
# ---------------------------
$clientID     = ""
$tenantID     = ""
$clientSecret = ""
$SecuredPW = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force
$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $clientId, $SecuredPW
Connect-MgGraph -TenantId $tenantId -ClientSecretCredential $ClientSecretCredential


# ----------------------------------------------------------
# GET ALL FILTERED AUDIT ACTIVITY EVENTS IN THE LAST N DAYS
# ----------------------------------------------------------
# Build audit filter
$auditFilter = @(
    "activityDateTime gt $cutoff"
    "activityDateTime le $dateNow"
    "category eq 'Enrollment'"
    "activityType eq 'CreateImportedWindowsAutopilotDeviceIdentity ImportedWindowsAutopilotDeviceIdentity'"
) -join " and "

$uri = "https://graph.microsoft.com/beta/deviceManagement/auditEvents?`$filter=$auditFilter&`$top=999"

# Init collection
$events = @()

# Pagination loop
do {
    $response = Invoke-MgGraphRequest -Method GET -Uri $uri
    if ($response.value) {
        $events += $response.value
    }
    $uri = $response.'@odata.nextLink'
}
while ($uri)

# Extract results
$results = foreach ($evt in $events) {
        [PSCustomObject]@{
            DateTime     = $evt.activityDateTime
            Actor        = $evt.actor.userPrincipalName
            ActivityType = $evt.resources.auditResourceType
            Result       = $evt.activityResult
            ResourceID   = $evt.resources.resourceId
       }
}


# ----------------------------------------------------------
# OUTPUT SORTED BY MOST RECENT EVENTS
# ----------------------------------------------------------
$results | Sort-Object DateTime -Descending | Format-Table -AutoSize