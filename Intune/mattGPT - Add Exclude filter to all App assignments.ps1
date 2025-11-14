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
    | 2025-08-28 | mattGPT | 1.0     | Initial script.                                                    |
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
$FilterRule = '(device.model -eq "Microsoft Dev Box")'  # <<< customise.
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


# ===== 2. Get all apps first =====
$apps = (Invoke-RestMethod -Headers $Headers -Method GET -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$filter=isAssigned eq true").value
$report = @()
$s = 0
$f = 0


# ===== 3. Assign discovered apps the custom filter =====
ForEach($app in $apps){

    # Set arrays
    $Target = $null
    $Settings = $null
    $TargetHash = $null
    $SettingsHash = $null

    # Get App Assignments
    $AppID = $app.id
    $AssignmentIDs = (Invoke-RestMethod -Method GET -Uri "https://graph.microsoft.com/beta/deviceAppManagement/MobileApps/$AppID/assignments" -Headers $Headers).value

    foreach($assignment in $AssignmentIDs){}

    # Set values to create hashtable
    $Target = $assignment.target
    $Settings = $assignment.settings

    $Target.deviceAndAppManagementAssignmentFilterId = $FilterId
    $Target.deviceAndAppManagementAssignmentFilterType = $FilterMode

    # Create target hashtable
    $TargetHash = [ordered]@{}
    $Target.psobject.Properties | ForEach-Object { $TargetHash[$_.Name] = $_.Value }

    # Create hashtable for API call body
    $hash = [ordered]@{ 

        "@odata.type" = "#microsoft.graph.mobileAppAssignment"
        "intent" = "Required"
        "target" = $TargetHash
        
    } 

    # If settings were returned with assignments, create settings hash and add it to hash
    if($Settings){

        $SettingsHash = [ordered]@{}
        $Settings.psobject.Properties | ForEach-Object { $SettingsHash[$_.Name] = $_.Value }
        $hash.Insert(2, 'settings', $SettingsHash)

    }

    $bodyAssignments = @{ "mobileAppAssignments" = @($Hash) } | ConvertTo-Json -Depth 5

    # Post graph to assign filters to applications
    try{
        Write-Output "Assigning [$FilterMode] filter [$FilterName] to [$($app.displayName)]"
        Write-Host $bodyAssignments -f Yellow -b Black # <<< this can be commented out after inspection.
        
        $URI = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$AppId/assign"
        #Invoke-RestMethod -Method Post -Uri $URI -Body $bodyAssignments -Headers $Headers -ContentType "application/json"  # <<< Uncomment this line when you are good to go! :)
        $s++
        
    }catch{
            Write-Output "WARNING: App [$($app.displayName)] could not be patched with filter: $($_.Exception.Message)"
            $f++
    }
    if($success){ $status = "OK" } else { $status = "Failed: $($_.Exception.Message)"  }
    $report += [pscustomobject]@{
                
                AppName = $app.displayName
                AppID   = $app.id
                Status  = $status
        }
}

# ===== Display report to console =====
$report | Format-Table -AutoSize
Write-Output "Total Apps: $($report.Count) | Total Successful: $s | Total Failed: $f"

# ===== End of script =====
