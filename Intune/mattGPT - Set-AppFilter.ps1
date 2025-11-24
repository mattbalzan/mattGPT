<#
.SYNOPSIS
    Applies an assignment filter to selected Intune apps without modifying existing intents or settings.
    Supports targeting one app, multiple apps, or explicit app guids.
    Automatically backs up existing app assignment configurations for rollback.

.DESCRIPTION
    Retrieves all Windows-managed apps—or a subset defined by user selection —and injects an exclude filter
    into every assignment target. All existing intent, group targeting, and settings are preserved.
    REST API only, no modules. Backup JSON files stored per-app for rollback.
    
    Requires Microsoft Graph App Permissions:
        • DeviceManagementApps.ReadWrite.All
        • DeviceManagementConfiguration.ReadWrite.All

.PARAMETER AppName
    One or more App Names, comma-separated. Each value is automatically matched using a
    "*<value>*" pattern to support partial names and wildcard-style queries.

.PARAMETER AppID
    One or more explicit Intune application GUIDs, comma-separated.

.EXAMPLE
    .\mattGPT - Set-AppFilter.ps1 -AppName "7zip"

.EXAMPLE
    .\mattGPT - Set-AppFilter.ps1 -AppName "Office","Windows App"

.EXAMPLE
    .\mattGPT - Set-AppFilter.ps1 -AppID "c0dec289-ecb6-4bc3-89a4-6586a944b4a2"

.EXAMPLE
    .\mattGPT - Set-AppFilter.ps1 -AppID "65454a4c-9cf6-467a-a4aa-641d7a999c45","a0b0b9aa-ac3f-463b-b2f2-e4b3175f834d"

.NOTES
    +------------+---------+---------+--------------------------------------------------------------------+
    | Date       | Author  | Version | Changes                                                            |
    |------------+---------+---------+--------------------------------------------------------------------|
    | 2025-11-24 | mattGPT | 1.0     | Initial script.                                                    |
    +------------+---------+---------+--------------------------------------------------------------------+
#>

Param(
    [string[]]$AppName,
    [string[]]$AppID
)


# ======== AUTH ===============
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
$Headers       = @{ Authorization = "Bearer $AccessToken" }


# ======== CREATE OR GET FILTER ===============
$FilterMode      = "exclude"
$FilterName      = "Exclude Dev Box Devices"
$FilterRule      = '(device.model -startswith "Microsoft Dev Box")'
$FilterPlatform  = "windows10AndLater"
$FilterDesc      = "Exclude Dev Box devices based on model"

$FilterList = Invoke-RestMethod -Headers $Headers -Method GET `
    -Uri "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters?`$top=999"

$FilterObj = $FilterList.value | Where-Object { $_.displayName -eq $FilterName }

if ($FilterObj) {
    $FilterId = $FilterObj.id
} else {
    $createBody = @{
        displayName = $FilterName
        description = $FilterDesc
        platform    = $FilterPlatform
        assignmentFilterManagementType = "devices"
        rule = $FilterRule
    } | ConvertTo-Json

    $FilterId = (Invoke-RestMethod -Headers $Headers -Method POST `
        -Uri "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters" `
        -Body $createBody -ContentType "application/json").id
}


# ======== GET TARGETED APPS ===============
$Apps = @()
$filAppslist = @"
(isof(%27microsoft.graph.win32CatalogApp%27)%20or%20isof(%27microsoft.graph.windowsStoreApp%27)%20or%20isof(%27microsoft.graph.officeSuiteApp%27)%20or%20(isof(%27microsoft.graph.win32LobApp%27)%20and%20not(isof(%27microsoft.graph.win32CatalogApp%27)))%20or%20isof(%27microsoft.graph.windowsMicrosoftEdgeApp%27)%20or%20isof(%27microsoft.graph.windowsPhone81AppX%27)%20or%20isof(%27microsoft.graph.windowsPhone81StoreApp%27)%20or%20isof(%27microsoft.graph.windowsPhoneXAP%27)%20or%20isof(%27microsoft.graph.windowsAppX%27)%20or%20isof(%27microsoft.graph.windowsMobileMSI%27)%20or%20isof(%27microsoft.graph.windowsUniversalAppX%27)%20or%20isof(%27microsoft.graph.webApp%27)%20or%20isof(%27microsoft.graph.windowsWebApp%27)%20or%20isof(%27microsoft.graph.winGetApp%27))%20and%20(microsoft.graph.managedApp/appAvailability%20eq%20null%20or%20microsoft.graph.managedApp/appAvailability%20eq%20%27lineOfBusiness%27%20or%20isAssigned%20eq%20true)%20and%20isAssigned%20eq%20true
"@
$AllApps = (Invoke-RestMethod -Headers $Headers -Method GET -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$filter=$filAppslist").value

if ($AppName) {
    # AppName supports multiple entries, e.g. "Office","Chrome"
    $Apps = $AllApps | Where-Object {
        foreach ($p in $AppName) {
            # Always wrap the user input in wildcards
            $searchPattern = "*$p*"

            if ($_.displayName -like $searchPattern) {
                return $true
            }
        }
        return $false
    }
}

elseif ($AppID) {
    $Apps = $AllApps | Where-Object { $AppID -eq $_.id }
}

else {
    Write-Output "Specify -AppName or -AppID"
    exit
}

#=======================================================
# Debugging section
#Write-Output "DEBUG: AppName count = $($AppName.Count)"
#$Apps | Select displayName
#=======================================================

# ======== PROCESS EACH APP ===============
$BackupPath = ".\AppAssignmentBackup"
if (!(Test-Path $BackupPath)) { New-Item -ItemType Directory -Path $BackupPath | Out-Null }

$report = @()
$s = 0
$f = 0

foreach ($app in $Apps) {

    $AppID = $app.id
    $AppNameSafe = $app.displayName

    Write-Output "Processing $AppNameSafe ($AppID)"

    # get assignments
    $Assignments = (Invoke-RestMethod -Method GET `
        -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$AppID/assignments" `
        -Headers $Headers).value

    if (-not $Assignments) {
        Write-Output "No assignments found; skipping"
        continue
    }

    # ===== BACKUP =====
    $BackupFile = Join-Path $BackupPath "$AppID.json"
    $Assignments | ConvertTo-Json -Depth 15 | Out-File $BackupFile -Encoding utf8

    # ===== MODIFY =====
    $UpdatedAssignments = @()

    foreach ($assignment in $Assignments) {

        $TargetHash = [ordered]@{}
        $assignment.target.psobject.Properties |
            ForEach-Object { $TargetHash[$_.Name] = $_.Value }

        # Apply filter
        $TargetHash["deviceAndAppManagementAssignmentFilterId"]   = $FilterId
        $TargetHash["deviceAndAppManagementAssignmentFilterType"] = $FilterMode

        # Clone settings if exist
        $SettingsHash = $null
        if ($assignment.settings) {
            $SettingsHash = [ordered]@{}
            $assignment.settings.psobject.Properties |
                ForEach-Object { $SettingsHash[$_.Name] = $_.Value }
        }

        # Build final assignment block
        $assignHash = [ordered]@{
            "@odata.type" = "#microsoft.graph.mobileAppAssignment"
            intent        = $assignment.intent
            target        = $TargetHash
        }

        if ($SettingsHash) { $assignHash["settings"] = $SettingsHash }

        $UpdatedAssignments += $assignHash
    }

    # ===== SEND UPDATED LIST =====
    $Body = @{ mobileAppAssignments = $UpdatedAssignments } |
        ConvertTo-Json -Depth 15

    try {
        # Uncomment these lines below when you are satisfied with appname/appid searching and backing up apps
        #Invoke-RestMethod -Method POST `
        #    -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$AppID/assign" `
        #    -Headers $Headers -ContentType "application/json" -Body $Body

        $s++
        $status = "Updated"
    }
    catch {
        $f++
        $status = "Failed: $($_.Exception.Message)"
    }

    $report += [pscustomobject]@{
        App   = $app.displayName
        AppID = $AppID
        Status = $status
        Backup = $BackupFile
    }
}

$report | Format-Table -AutoSize
Write-Output "Total: $($report.Count) | Success: $s | Failed: $f"
