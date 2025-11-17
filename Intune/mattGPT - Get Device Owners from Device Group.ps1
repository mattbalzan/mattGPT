<#
.SYNOPSIS
	  Retrieves all User Principal Names (UPNs) for devices in an Intune dynamic device group (Windows 10).

.DESCRIPTION
	  Uses Microsoft Graph REST API directly (no Graph SDK).
    Authenticates via a pre-obtained OAuth token (App or User-based).

    Graph permissions: Device.Read.All | Group.Read.All | User.Read.All

.NOTES
    +------------+---------+---------+--------------------------------------------------------------------+
    | Date       | Author  | Version | Changes                                                            |
    |------------+---------+---------+--------------------------------------------------------------------|
    | 2025-11-07 | mattGPT | 1.0     | Initial script.                                                    |
    +------------+---------+---------+--------------------------------------------------------------------+
#>

# ======= CONFIGURATION =======
$TenantId     = "<TenantID>"
$ClientId     = "<ClientID>"
$ClientSecret = "<ClientSecret>"
$GroupName    = "Windows 10 Devices"  # edit your Entra ID Group here

# ======= TOKEN RETRIEVAL =======
$Body = @{
    grant_type    = "client_credentials"
    scope         = "https://graph.microsoft.com/.default"
    client_id     = $ClientId
    client_secret = $ClientSecret
}

$TokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method POST -Body $Body
$Headers = @{ Authorization = "Bearer $($TokenResponse.access_token)" }


# ======= 1. GET GROUP ID =======
$GroupUrl = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$GroupName'"
$Group = (Invoke-RestMethod -Headers $Headers -Uri $GroupUrl -Method GET).value | Select-Object -First 1

if (-not $Group) {
    Write-Error "Group '$GroupName' not found."
    exit
}


# ======= 2. GET DEVICE MEMBERS =======
$Devices = @()
$NextLink = "https://graph.microsoft.com/v1.0/groups/$($Group.id)/members"
do {
    $Response = Invoke-RestMethod -Headers $Headers -Uri $NextLink -Method GET
    $Devices += $Response.value
    $NextLink = $Response.'@odata.nextLink'
} while ($NextLink)


# ======= 3. GET REGISTERED OWNERS (UPNs) =======
$Results = foreach ($Device in $Devices) {
    $OwnersUrl = "https://graph.microsoft.com/v1.0/devices/$($Device.id)/registeredOwners"
    $Owners = (Invoke-RestMethod -Headers $Headers -Uri $OwnersUrl -Method GET -ErrorAction SilentlyContinue).value
    foreach ($Owner in $Owners) {
        [PSCustomObject]@{
            DeviceName = $Device.displayName
            DeviceId   = $Device.id
            UserUPN    = $Owner.userPrincipalName
        }
    }
}

# ======= 4. OUTPUT =======
$Results | Where-Object { $_.UserUPN } | Sort-Object UserUPN | Format-Table -AutoSize
