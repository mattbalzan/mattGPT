<#
.SYNOPSIS
    Applies a device model–based exclude filter to all existing Intune mobile app assignments using Microsoft Graph batching
    and app-only (client credential) authentication. Optimized to update assignments at scale using batch PATCH operations.

.DESCRIPTION
    This solution automates the process of preventing Dev Box devices (identified by device.model) from receiving Intune’s 
    default mobile app assignments. It performs the following steps:

        1. Authenticates to Microsoft Graph using a client credential application.
        2. Creates or retrieves an Intune assignment filter that matches Dev Box devices by model name.
        3. Enumerates all mobile apps that have active assignments.
        4. Identifies assignments targeting devices or groups that require an exclude filter.
        5. Applies the exclude filter to each relevant assignment in an idempotent manner.
    
    Requires Microsoft Graph App Permissions:
        • DeviceManagementApps.ReadWrite.All
        • DeviceManagementConfiguration.ReadWrite.All

.NOTES
    +------------+---------+---------+--------------------------------------------------------------------+
    | Date       | Author  | Version | Changes                                                            |
    |------------+---------+---------+--------------------------------------------------------------------|
    | 2025-11-14 | mattGPT | 1.0     | Initial script.                                                    |
    +------------+---------+---------+--------------------------------------------------------------------+
    | 2025-11-17 | mattGPT | 1.1     | Pull all existing assignments, modify only the targets (add filter)|
    |            |         |         | preserve original intent and settings, re-POST the full list.      |
    +------------+---------+---------+--------------------------------------------------------------------+
#>

# ===== GET ACCESS TOKEN =====
$TenantId     = ""
$ClientId     = ""
$ClientSecret = ""

$TokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
$Body = @{
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = "https://graph.microsoft.com/.default"
    grant_type    = "client_credentials"
}

$TokenResponse = Invoke-RestMethod -Uri $TokenUri -Method POST -Body $Body
$AccessToken   = $TokenResponse.access_token
$Headers = @{ Authorization = "Bearer $AccessToken" }


# ===== 1. Create or Retrieve the Assignment Filter =====
$FilterMode = "Exclude"
$FilterName = "Exclude Dev Box Devices"  # <<< customise.              
$FilterRule = '(device.model -startswith "Microsoft Dev Box")'  # <<< customise.
$FilterDesc = "Exclude Dev Box devices based on model"  # <<< customise.
$FilterPlatform = "windows10AndLater"

# Lookup assignment filters
$FilterList = Invoke-RestMethod -Headers $Headers -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters?`$top=50&`$search=`"$FilterName`""

# Eyeball all filters in tenant 
$FilterList.value | select displayName,rule,description # <<< this can be commented out after inspection.

# Check if filter exists, if not create it
if ($FilterList.value) {
    $FilterId = $FilterList.value[0].id
}
else {
    $FilterBody = @{
        displayName = $FilterName
        description = $FilterDesc
        platform    = $FilterPlatform
        assignmentFilterManagementType = "devices"
        rule        = $FilterRule
    } | ConvertTo-Json

    $FilterId = (Invoke-RestMethod -Headers $Headers -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters" -Body $FilterBody -ContentType "application/json").id
}


# ===== 2. Get all Windows apps first =====
$filAppslist = @"
(isof(%27microsoft.graph.win32CatalogApp%27)%20or%20isof(%27microsoft.graph.windowsStoreApp%27)%20or%20isof(%27microsoft.graph.officeSuiteApp%27)%20or%20(isof(%27microsoft.graph.win32LobApp%27)%20and%20not(isof(%27microsoft.graph.win32CatalogApp%27)))%20or%20isof(%27microsoft.graph.windowsMicrosoftEdgeApp%27)%20or%20isof(%27microsoft.graph.windowsPhone81AppX%27)%20or%20isof(%27microsoft.graph.windowsPhone81StoreApp%27)%20or%20isof(%27microsoft.graph.windowsPhoneXAP%27)%20or%20isof(%27microsoft.graph.windowsAppX%27)%20or%20isof(%27microsoft.graph.windowsMobileMSI%27)%20or%20isof(%27microsoft.graph.windowsUniversalAppX%27)%20or%20isof(%27microsoft.graph.webApp%27)%20or%20isof(%27microsoft.graph.windowsWebApp%27)%20or%20isof(%27microsoft.graph.winGetApp%27))%20and%20(microsoft.graph.managedApp/appAvailability%20eq%20null%20or%20microsoft.graph.managedApp/appAvailability%20eq%20%27lineOfBusiness%27%20or%20isAssigned%20eq%20true)%20and%20isAssigned%20eq%20true
"@
$apps = (Invoke-RestMethod -Headers $Headers -Method GET -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$filter=$filAppslist").value

# Eyeball returned apps in tenant 
$apps | select displayName # <<< this can be commented out after inspection.


# ===== 3. Assign discovered apps the custom filter =====
$report = @()
$s = 0
$f = 0

foreach ($app in $apps) {

    $AppID = $app.id
    $Assignments = (Invoke-RestMethod -Method GET -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$AppID/assignments" -Headers $Headers).value

    if (-not $Assignments) { continue }

    $UpdatedAssignments = @()

    foreach ($assignment in $Assignments) {

        # clone target
        $TargetHash = [ordered]@{}
        $assignment.target.psobject.Properties |
            ForEach-Object { $TargetHash[$_.Name] = $_.Value }

        # apply filter
        $TargetHash["deviceAndAppManagementAssignmentFilterId"]   = $FilterId
        $TargetHash["deviceAndAppManagementAssignmentFilterType"] = $FilterMode

        # clone settings (if present)
        $SettingsHash = $null
        if ($assignment.settings) {
            $SettingsHash = [ordered]@{}
            $assignment.settings.psobject.Properties |
                ForEach-Object { $SettingsHash[$_.Name] = $_.Value }
        }

        # preserve intent + settings
        $assignHash = [ordered]@{
            "@odata.type" = "#microsoft.graph.mobileAppAssignment"
            intent        = $assignment.intent     # PRESERVED
            target        = $TargetHash            # UPDATED
        }

        if ($SettingsHash) {
            $assignHash["settings"] = $SettingsHash
        }

        $UpdatedAssignments += $assignHash
    }

    # send full set
    $Body = @{ mobileAppAssignments = $UpdatedAssignments } |
        ConvertTo-Json -Depth 10

    try {
        Write-Output "Assigning filter to app: $($app.displayName)"
        
        # POST overwrite-all behaviour is required – but now safe
        Invoke-RestMethod -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$AppID/assign" -Headers $Headers -Body $Body -ContentType "application/json"
        $s++
        $status = "OK"
    }
    catch {
        $f++
        $status = "Failed: $($_.Exception.Message)"
    }

    $report += [pscustomobject]@{
        AppName = $app.displayName
        AppID   = $AppID
        Status  = $status
    }
}

$report | Format-Table -AutoSize
Write-Output "Total Apps: $($report.Count) | Successful: $s | Failed: $f"

# ===== End of script =====
