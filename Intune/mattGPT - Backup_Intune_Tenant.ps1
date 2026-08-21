<#
.SYNOPSIS
	Backup Intune Tenant
.AUTHOR
    Matt Balzan (mattGPT)
.DESCRIPTION
	Backup of Intune tenant data (including Assignment data):
        Configuration Profiles, Policies & Settings.
        Device Health & Management scripts.
        Policy Sets.
        Windows Updates & iOS policy updates.
        Enrollment settings.
        Filters.
        W365 (Cloud PC): Provisioning Policies, Azure Network Connections & User settings.
    Optionally cleans up backups older than -RetentionDays (off by default).
    Graph Permissions:  DeviceManagementServiceConfiguration.Read.All
                        DeviceManagementScripts.Read.All
                        DeviceManagementConfiguration.Read.All
                        DeviceManagementManagedDevices.Read.All
                        DeviceManagementApps.Read.All
                        CloudPC.Read.All
                        Group.Read.All
.NOTES
    +------------+---------+---------+--------------------------------------------------------------------+
    | Date       | Author  | Version | Changes                                                            |
    |------------+---------+---------+--------------------------------------------------------------------|
    | 2024-10-31 | mattGPT | 1.0     | Initial script.                                                    |
    | 2025-12-08 | mattGPT | 1.1     | Updated script to clear JSON props (id, lastModifiedDateTime and   |
    | 2025-12-08 | mattGPT | 1.1     | createDateTime). Added config policies to backup list.             |
    | 2026-08-21 | mattGPT | 1.2     | Runbook release: SAS-based storage context, OAuth2 client          |
    | 2026-08-21 | mattGPT | 1.2     | credentials in place of the Graph SDK cmdlets, unique blob names   |
    | 2026-08-21 | mattGPT | 1.2     | and named/extensioned script binaries.                             |
    | 2026-08-21 | mattGPT | 1.3     | Added Graph paging + throttle retry, settings catalog settings,    |
    | 2026-08-21 | mattGPT | 1.3     | simplified report table, opt-in blob retention.                    |
    +------------+---------+---------+--------------------------------------------------------------------+

    Required Automation Account variables (create the secret/SAS ones as Encrypted):
        IntuneBackup-ClientID, IntuneBackup-TenantID, IntuneBackup-ClientSecret,
        IntuneBackup-StorageAccount, IntuneBackup-Container, IntuneBackup-SasToken
.PARAMETER CleanupOldBackups
    Opt in to deleting backup sets older than -RetentionDays from the container. Default is $false.
    Requires Delete on the SAS token.
.PARAMETER RetentionDays
    Age in days beyond which a backup set is removed when -CleanupOldBackups is enabled. Default is 30.
#>

param(
    [bool]$CleanupOldBackups = $false,
    [int]$RetentionDays      = 30
)

# ---------------------------
# CONFIGURATION
# ---------------------------
$ClientID           = Get-AutomationVariable -Name "IntuneBackup-ClientID"
$TenantID           = Get-AutomationVariable -Name "IntuneBackup-TenantID"
$clientSecret       = Get-AutomationVariable -Name "IntuneBackup-ClientSecret"
$StorageAccountName = Get-AutomationVariable -Name "IntuneBackup-StorageAccount"
$Container          = Get-AutomationVariable -Name "IntuneBackup-Container"
$SasToken           = Get-AutomationVariable -Name "IntuneBackup-SasToken"

# ---------------------------
# STORAGE CONTEXT (SAS)
# ---------------------------
# SAS auth needs no Connect-AzAccount. The token requires container-scoped Create/Write/Add (racwl for cleanup).
$ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -SasToken $SasToken

# ---------------------------
# BACKUP FOLDER
# ---------------------------
$timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$backupFolderName = "IntuneBackup-$timestamp"
$blobDirectory    = $backupFolderName
$localRoot        = $env:TEMP   # only %TEMP% is writable in the Automation sandbox
$localBlobDir     = Join-Path $localRoot "IntuneBackup-$timestamp"
if (!(Test-Path $localBlobDir -ErrorAction Ignore)) { New-Item $localBlobDir -ItemType Directory -Force | Out-Null }

# ---------------------------
# FUNCTION: OAUTH2 TOKEN (CLIENT CREDENTIALS)
# ---------------------------
function Get-GraphAuthHeader {
    if ($script:tokenExpiry -and (Get-Date) -lt $script:tokenExpiry) { return $script:graphHeaders }
    $body = @{
        client_id     = $ClientID
        client_secret = $clientSecret
        scope         = "https://graph.microsoft.com/.default"
        grant_type    = "client_credentials"
    }
    $tokenResponse = Invoke-RestMethod -Method POST `
                                       -Uri "https://login.microsoftonline.com/$TenantID/oauth2/v2.0/token" `
                                       -Body $body `
                                       -ContentType "application/x-www-form-urlencoded" `
                                       -ErrorAction Stop
    $script:accessToken  = $tokenResponse.access_token
    # Renew 5 mins early so a long tenant backup doesn't 401 mid-run
    $script:tokenExpiry  = (Get-Date).AddSeconds($tokenResponse.expires_in - 300)
    $script:graphHeaders = @{ Authorization = "Bearer $($tokenResponse.access_token)" }
    return $script:graphHeaders
}

# ---------------------------
# FUNCTION: GRAPH API CALLS
# ---------------------------
function Get-GraphData {
    param (
        [string]$uri
    )
    try {
        $nextLink = "https://graph.microsoft.com/beta/$uri"
        $firstPage = $null
        $allItems  = @()
        do {
            $attempt  = 0
            $response = $null
            while ($null -eq $response) {
                try {
                    $response = Invoke-RestMethod -Method GET `
                                                  -Uri $nextLink `
                                                  -Headers (Get-GraphAuthHeader) `
                                                  -ContentType "application/json" `
                                                  -ErrorAction Stop
                }
                catch {
                    $status = $_.Exception.Response.StatusCode.value__
                    # Back off on throttling (429) and transient server errors, otherwise give up
                    if ($attempt -lt 4 -and ($status -eq 429 -or $status -ge 500)) {
                        Start-Sleep -Seconds ([Math]::Pow(2, $attempt) * 5)
                        $attempt++
                    }
                    else { throw }
                }
            }
            if ($null -eq $firstPage) { $firstPage = $response }
            if ($response.PSObject.Properties.Name -contains "value") {
                $allItems += $response.value
                $nextLink  = $response."@odata.nextLink"
            }
            else { $nextLink = $null }
        } while ($nextLink)

        # Collapse every page into the first response so callers still just read .value
        if ($firstPage.PSObject.Properties.Name -contains "value") { $firstPage.value = $allItems }
        $script:reportContent += "$(Get-Date -Format "dd-MM-yyyy HH:mm:ss") | $uri | Backup Successful"
        return $firstPage
    }
    catch {
        $script:reportContent += "$(Get-Date -Format "dd-MM-yyyy HH:mm:ss") | $uri | Backup Failed: $($_.exception.message)"
        $script:failed++
        return $null
    }
}

# ---------------------------
# FUNCTION: SAVE JSON CONTENT TO STORAGE
# ---------------------------
function Save-ContentToBlob {
    param (
        [string]$content,
        [string]$blobName,
        [string]$extension = "json"
    )
    # Filename sanitiser
    $fileName = $blobname -replace '[\\/:*?"<>|()[\]{}&™® ]', '_' -replace " ","_"
    # Extract the prefix
    $prefix = $fileName.Split('_')[0]
    # Define the subfolder path using the prefix
    $subFolderPath = "$localBlobDir\$prefix"
    # Create the subfolder if it doesn't exist
    if (!(Test-Path -Path $subFolderPath)) { New-Item -ItemType Directory -Path $subFolderPath -Force | Out-Null }
    $randchars = -join (1..10 | % {[char]((97..122) + (48..57) | Get-Random)})
    $leafName  = "$($fileName)_$timestamp`_$randchars.$extension"
    $localFile = Join-Path $subFolderPath $leafName
    Write-Output "Backing up: $leafName"
    try {
        # Write locally first: Set-AzStorageBlobContent -File needs a path, and the randchars keep
        # identically-named policies from overwriting each other in the container.
        $content | Out-File -FilePath $localFile -Encoding utf8 -ErrorAction Stop
        Set-AzStorageBlobContent -File $localFile -Container $Container -Blob "$blobDirectory/$prefix/$leafName" -Context $ctx -Force -ErrorAction Stop | Out-Null
    }
    catch {
        $script:reportContent += "$(Get-Date -Format "dd-MM-yyyy HH:mm:ss") | $blobName | Save Failed: $($_.exception.message)"
        $script:failed++
        Write-Error $_.exception.message -ErrorAction Continue
    }
}

# ---------------------------
# FUNCTION: CLEAN JSON FOR EXPORT
# ---------------------------
function Convert-ToCleanJson {
    param(
        [Parameter(Mandatory)]
        $Object,
        [int]$Depth = 15
    )
    # Invoke-RestMethod returns PSCustomObject, so exclude rather than mutate the source object
    $clean = $Object | Select-Object -Property * -ExcludeProperty id, lastModifiedDateTime, createdDateTime, "@odata.context"
    return ($clean | ConvertTo-Json -Depth $Depth)
}

# ---------------------------
# INITIALISE VARIABLES
# ---------------------------
$reportContent = @()
$scriptContent = @()
$failed = 0

# ---------------------------
# BACKUP CONTENT SECTION
# ---------------------------
$content = @()
$appConfigs = @()
$compliancePolicies = @()
$configProfiles = @()
$configPolicies = @()

# ---------------------------
# BACKUP APPS
# ---------------------------
$appConfigs = Get-GraphData -uri "deviceAppManagement/mobileApps?`$filter=(microsoft.graph.managedApp/appAvailability%20eq%20null%20or%20microsoft.graph.managedApp/appAvailability%20eq%20%27lineOfBusiness%27)&`$expand=Assignments"
if ($appConfigs.value) {
    foreach ($app in $appConfigs.value) {
        $json = Convert-ToCleanJson -Object $app
        Save-ContentToBlob -content $json -blobName "APP_$($app.displayName)"
    }
}

# ---------------------------
# BACKUP DEVICE COMPLIANCE POLICIES
# ---------------------------
$compliancePolicies = Get-GraphData -uri "deviceManagement/deviceCompliancePolicies?`$expand=Assignments"
if ($compliancePolicies.value) {
    foreach ($dcp in $compliancePolicies.value) {
        $json = Convert-ToCleanJson -Object $dcp
        Save-ContentToBlob -content $json -blobName "DCP_$($dcp.displayName)"
    }
}

# ---------------------------
# BACKUP DEVICE CONFIGURATIONS
# ---------------------------
$configProfiles = Get-GraphData -uri "deviceManagement/deviceConfigurations?`$expand=Assignments"
if ($configProfiles.value) {
    foreach ($cp in $configProfiles.value) {
        $json = Convert-ToCleanJson -Object $cp
        Save-ContentToBlob -content $json -blobName "CP_$($cp.displayName)"
    }
}

# ---------------------------
# BACKUP CONFIGURATION POLICIES
# ---------------------------
$configPolicies = Get-GraphData -uri "deviceManagement/configurationPolicies?`$expand=Assignments"
if ($configPolicies.value) {
    foreach ($cpo in $configPolicies.value) {
        # The collection returns metadata only, so pull the actual settings per policy
        $cpoSettings = Get-GraphData -uri "deviceManagement/configurationPolicies('$($cpo.id)')/settings"
        $cpo | Add-Member -NotePropertyName settings -NotePropertyValue $cpoSettings.value -Force
        $json = Convert-ToCleanJson -Object $cpo -Depth 25
        Save-ContentToBlob -content $json -blobName "CPO_$($cpo.name)"
    }
}

# ---------------------------
# BACKUP DEVICE HEALTH SCRIPTS
# ---------------------------
$scriptsDH = Get-GraphData -uri "deviceManagement/deviceHealthScripts?`$expand=Assignments" 
if ($scriptsDH.value) {
    foreach ($dh in $scriptsDH.value) {
        $json = Convert-ToCleanJson -Object $dh
        Save-ContentToBlob -content $json -blobName "DHS_$($dh.displayName)"
    }
}

# ---------------------------
# BACKUP DEVICE HEALTH SCRIPT BINARIES
# ---------------------------
foreach ($dh in $scriptsDH.value) {
    $scriptDHbin = Get-GraphData -uri "deviceManagement/deviceHealthScripts/$($dh.id)"
    if($scriptDHbin.detectionScriptContent ) {
    $scriptContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($($scriptDHbin.detectionScriptContent))) 
    Save-ContentToBlob -content $scriptContent -blobName "DHScripts_$($dh.displayName)_$($dh.id)_detScript" -extension "ps1"
    }
    if($scriptDHbin.remediationScriptContent) {
    $scriptContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($($scriptDHbin.remediationScriptContent))) 
    Save-ContentToBlob -content $scriptContent -blobName "DHScripts_$($dh.displayName)_$($dh.id)_remScript" -extension "ps1"
    }
}

# ---------------------------
# BACKUP DEVICE MANAGEMENT SCRIPTS
# ---------------------------
$scriptsDM = Get-GraphData -uri "deviceManagement/deviceManagementScripts?`$expand=Assignments"
if ($scriptsDM.value) {
    foreach ($dm in $scriptsDM.value) {
        $json = Convert-ToCleanJson -Object $dm
        Save-ContentToBlob -content $json -blobName "DMS_$($dm.displayName)"
    }
}

# ---------------------------
# BACKUP DEVICE MANAGEMENT SCRIPT BINARIES
# ---------------------------
foreach ($dm in $scriptsDM.value) {
    $scriptDMbin = Get-GraphData -uri "deviceManagement/deviceManagementScripts/$($dm.id)"
    if($scriptDMbin.ScriptContent ) {
    $scriptContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($($scriptDMbin.ScriptContent))) 
    Save-ContentToBlob -content $scriptContent -blobName "DMScripts_$($dm.displayName)_$($dm.id)" -extension "ps1"
    }
}

# ---------------------------
# BACKUP AUTOPILOT PROFILES
# ---------------------------
$autoProfiles = Get-GraphData -uri "deviceManagement/windowsAutopilotDeploymentProfiles?`$expand=assignments"
if ($autoProfiles.value) { 
    $autoProfiles.value | % { 
    $json = Convert-ToCleanJson -Object $_
    Save-ContentToBlob -content $json -blobName "AUTO_$($_.displayName)" 
    } 
}

# ---------------------------
# BACKUP ENROLLMENT PROFILES
# ---------------------------
$enrollProfiles = Get-GraphData -uri "deviceManagement/deviceEnrollmentConfigurations?`$expand=assignments&`$filter=deviceEnrollmentConfigurationType%20eq%20%27Windows10EnrollmentCompletionPageConfiguration%27"
if ($enrollProfiles.value) { 
    $enrollProfiles.value | % { 
    $json = Convert-ToCleanJson -Object $_
    Save-ContentToBlob -content $json -blobName "ESP_$($_.displayName)"
    } 
}

# ---------------------------
# BACKUP WINDOWS UPDATES PROFILES
# ---------------------------
$wuFB = Get-GraphData -uri "deviceManagement/deviceConfigurations?`$filter=isof(%27microsoft.graph.windowsUpdateForBusinessConfiguration%27)&`$expand=assignments"
if ($wuFB.value) { 
    $wuFB.value | % { 
    $json = Convert-ToCleanJson -Object $_
    Save-ContentToBlob -content $json -blobName "WUFB_$($_.displayName)"
    } 
}

# ---------------------------
# BACKUP FEATURE UPDATES PROFILES
# ---------------------------
$fuFB = Get-GraphData -uri "deviceManagement/windowsFeatureUpdateProfiles?`$expand=assignments"
if ($fuFB.value) { 
    $fuFB.value | % { 
    $json = Convert-ToCleanJson -Object $_
    Save-ContentToBlob -content $json -blobName "FUFB_$($_.displayName)"
    } 
}

# ---------------------------
# BACKUP QUALITY UPDATES PROFILES
# ---------------------------
$quFB = Get-GraphData -uri "deviceManagement/windowsQualityUpdateProfiles?`$expand=assignments"
if ($quFB.value) { 
    $quFB.value | % { 
    $json = Convert-ToCleanJson -Object $_
    Save-ContentToBlob -content $json -blobName "QUFB_$($_.displayName)"
    } 
}

# ---------------------------
# BACKUP DRIVER UPDATES PROFILES
# ---------------------------
$duFB = Get-GraphData -uri "deviceManagement/windowsDriverUpdateProfiles?`$expand=assignments"
if ($duFB.value) { 
    $duFB.value | % { 
    $json = Convert-ToCleanJson -Object $_
    Save-ContentToBlob -content $json -blobName "DUFB_$($_.displayName)"
    } 
}

# ---------------------------
# BACKUP iOS UDPATES PROFILES
# ---------------------------
$iOSu = Get-GraphData -uri "deviceManagement/deviceConfigurations?`$filter=isof(%27microsoft.graph.iosUpdateConfiguration%27)&`$expand=assignments"
if ($iOSu.value) { 
    $iOSu.value | % { 
    $json = Convert-ToCleanJson -Object $_
    Save-ContentToBlob -content $json -blobName "iOSU_$($_.displayName)"
    } 
}

# ---------------------------
# BACKUP MAC OS UPDATES PROFILES
# ---------------------------
$mOSu = Get-GraphData -uri "deviceManagement/deviceConfigurations?`$filter=isof(%27microsoft.graph.macOSSoftwareUpdateConfiguration%27)&`$expand=assignments"
if ($mOSu.value) { 
    $mOSu.value | % { 
    $json = Convert-ToCleanJson -Object $_
    Save-ContentToBlob -content $json -blobName "mOSU_$($_.displayName)"
    } 
}

# ---------------------------
# BACKUP POLICY SETS PROFILES
# ---------------------------
$psP = Get-GraphData -uri "deviceAppManagement/policySets"
if ($psP.value.id) { 
    $psP.value.id | % { 
    $psPitems = Get-GraphData -uri "deviceAppManagement/policySets/$_/?`$expand=assignments"
        $psPitems | % {
            $json = Convert-ToCleanJson -Object $_
            Save-ContentToBlob -content $json -blobName "PSP_$($_.displayName)"
        } 
    }   
}

# ---------------------------
# BACKUP ASSIGNMENT FILTERS
# ---------------------------
$afils = Get-GraphData -uri "deviceManagement/assignmentFilters"
if ($afils.value.id) { 
    $afils.value.id | % { 
    $afilsitems = Get-GraphData -uri "deviceManagement/assignmentFilters/$_"
        $afilsitems | % {
            $json = Convert-ToCleanJson -Object $_
            Save-ContentToBlob -content $json -blobName "FIL_$($_.displayName)"
        } 
    }   
}

# ---------------------------
# BACKUP W365 PROVISIONING PROFILES
# ---------------------------
$W365pp = Get-GraphData -uri "deviceManagement/virtualEndpoint/provisioningPolicies?`$expand=assignments&`$filter=managedBy eq 'Windows365'"
if ($W365pp.value.id) { 
    $W365pp.value.id | % { 
    $W365ppItems = Get-GraphData -uri "deviceManagement/virtualEndpoint/provisioningPolicies/$_"
        $W365ppItems | % {
            $json = Convert-ToCleanJson -Object $_
            Save-ContentToBlob -content $json -blobName "W365PP_$($_.displayName)"
        } 
    }   
}

# ---------------------------
# BACKUP W365 USER SETTINGS
# ---------------------------
$W365us = Get-GraphData -uri "deviceManagement/virtualEndpoint/userSettings?`$expand=assignments"
if ($W365us.value.id) { 
    $W365us.value.id | % { 
    $W365usItems = Get-GraphData -uri "deviceManagement/virtualEndpoint/userSettings/$_"
        $W365usItems | % {
            $json = Convert-ToCleanJson -Object $_
            Save-ContentToBlob -content $json -blobName "W365US_$($_.displayName)"
        } 
    }   
}

# ---------------------------
# BACKUP W365 AZURE NETWORK CONNECTIONS
# ---------------------------
$W365anc = Get-GraphData -uri "deviceManagement/virtualEndpoint/onPremisesConnections"
if ($W365anc.value.id) { 
    $W365anc.value.id | % { 
    $W365ancItems = Get-GraphData -uri "deviceManagement/virtualEndpoint/onPremisesConnections/$_"
        $W365ancItems | % {
            $json = Convert-ToCleanJson -Object $_
            Save-ContentToBlob -content $json -blobName "W365ANC_$($_.displayName)"
        } 
    }   
}

# ---------------------------
# DISPLAY REPORT
# ---------------------------
$summary = [ordered]@{
    "Application Configurations"    = $appConfigs.value.Count
    "Device Compliance Policies"    = $compliancePolicies.value.Count
    "Configuration Profiles"        = $configProfiles.value.Count
    "Configuration Policies"        = $configPolicies.value.Count
    "Device Health Scripts"         = $scriptsDH.value.Count
    "Device Management Scripts"     = $scriptsDM.value.Count
    "Autopilot Profiles"            = $autoProfiles.value.Count
    "Enrollment Profiles"           = $enrollProfiles.value.Count
    "Windows Updates Profiles"      = $wuFB.value.Count
    "Feature Updates Profiles"      = $fuFB.value.Count
    "Quality Updates Profiles"      = $quFB.value.Count
    "Driver Updates Profiles"       = $duFB.value.Count
    "iOS Updates Profiles"          = $iOSu.value.Count
    "MacOS Updates Profiles"        = $mOSu.value.Count
    "Policy Sets Profiles"          = $psP.value.Count
    "Filter Profiles"               = $afils.value.Count
    "W365 Provisioning Profiles"    = $W365pp.value.Count
    "W365 User Settings"            = $W365us.value.Count
    "W365 Azure Network Connections" = $W365anc.value.Count
    "Total Failed"                  = $failed
}
$title        = "BACKUP INTUNE REPORT - $(Get-Date)"
$summaryTable = $summary.GetEnumerator() |
                ForEach-Object { [PSCustomObject]@{ Item = $_.Key; Count = [int]$_.Value } } |
                Format-Table -AutoSize | Out-String
Write-Output ""
Write-Output $title
Write-Output $summaryTable

# Compile the final backup report and upload to Az Storage
$failedRows  = $reportContent | ? {$_ -like "*Failed*"}
$reportFile  = "$localBlobDir\BackupReport-$timestamp.txt"
@($title, $summaryTable, $reportContent) -join "`n" | Set-Content $reportFile
if($failedRows){ 
    Write-Output $failedRows
    # Decode the app roles on the token to diagnose missing Graph permissions
    $payload = $script:accessToken.Split('.')[1].Replace('-','+').Replace('_','/')
    switch ($payload.Length % 4) { 2 { $payload += '==' } 3 { $payload += '=' } }
    Write-Output "Token roles: $((([System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json).roles) -join ', ')"
    }
Set-AzStorageBlobContent -File $reportFile -Container $Container -Blob "$blobDirectory/BackupReport-$timestamp.txt" -Context $ctx -Force -ErrorAction Stop | Out-Null

# ---------------------------
# CLEAN UP OLD BACKUPS (OPT-IN)
# ---------------------------
if ($CleanupOldBackups) {
    $cutoff = (Get-Date).AddDays(-$RetentionDays)
    # Age comes from the folder name, not blob metadata, so a re-uploaded set can't reset the clock
    $staleBlobs = Get-AzStorageBlob -Container $Container -Context $ctx |
                  Where-Object { $_.Name -match '^IntuneBackup-(\d{8})-\d{6}/' -and
                                 [datetime]::ParseExact($Matches[1], 'yyyyMMdd', $null) -lt $cutoff }
    if ($staleBlobs) {
        $staleSets = ($staleBlobs.Name | ForEach-Object { $_.Split('/')[0] } | Sort-Object -Unique) -join ', '
        $staleBlobs | Remove-AzStorageBlob -Force
        Write-Output "Removed $($staleBlobs.Count) blob(s) older than $RetentionDays days from: $staleSets"
    }
    else { Write-Output "No backup sets older than $RetentionDays days." }
}

# End of script