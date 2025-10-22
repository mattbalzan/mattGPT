<#
.SYNOPSIS
    Performs a full backup of the Intune tenant including configurations, policies, and related data.

.DESCRIPTION
    This script automates the backup of the main Intune tenant, covering:
    - Configuration Profiles and Policies with settings and assignments.
    - Device Health and Device Management Scripts.
    - Policy Sets, Windows Update and iOS update profiles.
    - Enrollment Profiles and Filters.
    - Windows 365 components: Provisioning Policies, Azure Network Connections, and User Settings.
    - Automated cleanup of backups older than 30 days.

.OUTPUTS
    Backup folders containing exported JSON configurations for each Intune component.
    Console output summarizing total items backed up and any failed operations.

.NOTES
    Author: Matt Balzan
    Website: mattgpt.co.uk
    Version History:
    1.0 | 31.10.2024 | Original
    1.1 | 01.11.2024 | Added Device Health & Management Scripts
    1.2 | 09.12.2024 | Added Filters, W365 components, cleanup for >30 days
    1.3 | 16.12.2024 | Added failed count, new API permission, fixed URLs, added filters

    Permissions Required:
        DeviceManagementServiceConfiguration.Read.All
        DeviceManagementConfiguration.Read.All
        DeviceManagementManagedDevices.Read.All
        DeviceManagementApps.Read.All
        CloudPC.Read.All
        Group.Read.All

#>


# --[ Import the App Registration variables ]
$ClientID     = ""
$TenantID     = ""
$clientSecret = ""


# --[ Convert secret to secure string ]
$SecuredPW = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force

# --[ Make up the client secret credential ]
$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $clientId, $SecuredPW

# --[ Connect to Graph ]
Connect-MgGraph -TenantId $tenantId -ClientSecretCredential $ClientSecretCredential


# --[ Date time folder for Backup ]
$timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$backupFolderName = "IntuneBackup-$timestamp"


# --[ Define the Blob Folder ]
$blobDirectory = "$backupFolderName"



# --[ *** local drive save test *** ]
$localBlobDir = "C:\temp\IntuneBackup-$timestamp"
if (!(Test-Path $localBlobDir -ErrorAction Ignore)) { New-Item $localBlobDir -ItemType Directory -Force }


# -[ Init variables ]
$reportContent = @()
$scriptContent = @()
$failed = 0

# --[ Graph API calls ]
function Get-GraphData {
    param (
        [string]$uri
    )
    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/$uri"
        $global:reportContent += "$uri | Backup Successful"
        return $response
    }
    catch {
        $global:reportContent += "$uri | Backup Failed: $($_.exception.message)"
        $global:failed++
        return $null
    }
}


# --[ Save JSON content to Blob Storage ]
function Save-ContentToBlob {
    param (
        [string]$content,
        [string]$blobName,
        [string]$count
    )
    $blobNameWithPath = "$blobDirectory/$blobName.json"
    #$blob = Set-AzStorageBlobContent -File $content -Container $Container -Blob $blobNameWithPath -Context $ctx -Force -ErrorAction Stop # - Uncomment for automation!

    
    # *** local save test | this can be COMMENTED OUT when using automation ***
    #Write-Host $content -f Black -b Yellow
    #Write-Host $blobName -f Black -b Gray
    
    # --[ Filename sanitiser ]
    $fileName = $blobname -replace '[\\/:*?"<>|()[\]{}&™® ]', '_' -replace " ","_"

    # --[ Extract the prefix ]
    $prefix = $fileName.Split('_')[0]
    
    # --[ Define the subfolder path using the prefix ]
    $subFolderPath = "$localBlobDir\$prefix"

    # --[ Create the subfolder if it doesn't exist ]
    if (!(Test-Path -Path $subFolderPath)) {
        New-Item -ItemType Directory -Path $subFolderPath
    }
    
    Write-Host "Backing up: " -NoNewline -f Black -b Gray
    Write-Host $filename -f White -b Red

    $randchars = -join (1..10 | % {[char]((97..122) + (48..57) | Get-Random)})

    try { $content | Out-File "$subFolderPath\$($fileName)_$timestamp`_$randchars.json" }
    
    catch { Write-Host $_.exception.message -f Red -b Black }
    
    }



# --[ BACKUP CONTENT SECTION ]
$content = @()
$appConfigs = @()
$compliancePolicies = @()
$configProfiles = @()


# --[ Backup Application Configurations and Assignments ]
$appConfigs = Get-GraphData -uri "deviceAppManagement/mobileApps?`$filter=(microsoft.graph.managedApp/appAvailability%20eq%20null%20or%20microsoft.graph.managedApp/appAvailability%20eq%20%27lineOfBusiness%27)&`$expand=Assignments"
if ($appConfigs.value) { 

    $appConfigs.value | % { 
    
    Save-ContentToBlob -content ($_ | ConvertTo-Json -Depth 10) -blobName "APP_$($_.displayName)" } 
   
}


# --[ Backup Device Compliance Policies and Assignments ]
$compliancePolicies = Get-GraphData -uri "deviceManagement/deviceCompliancePolicies?`$expand=Assignments"
if ($compliancePolicies.value) { $compliancePolicies.value | % { Save-ContentToBlob -content ($_ | ConvertTo-Json -Depth 10) -blobName "DCP_$($_.displayName)" } 


}


# --[ Backup Configuration Profiles and Assignments ]
$configProfiles = Get-GraphData -uri "deviceManagement/deviceConfigurations?`$expand=Assignments"
if ($configProfiles.value) { $configProfiles.value | % { Save-ContentToBlob -content ($_ | ConvertTo-Json -Depth 10) -blobName "CP_$($_.displayName)"  }

}


# --[ Backup Device Health Scripts and Assignments ]
$scriptsDH = Get-GraphData -uri "deviceManagement/deviceHealthScripts?`$expand=Assignments" 
if ($scriptsDH.value) { $scriptsDH.value | % { Save-ContentToBlob -content ($_ | ConvertTo-Json -Depth 10) -blobName "DHS_$($_.displayName)" }


}


# --[ Backup DH Script binaries ]
$scriptsDH.value.id | % { 

$scriptDHbin = Get-GraphData -uri "deviceManagement/deviceHealthScripts/$_"

    if($scriptDHbin.detectionScriptContent ) {

    $scriptContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($($scriptDHbin.detectionScriptContent))) 
    Save-ContentToBlob -content $scriptContent -blobName "DHScripts_$($_)_detScript"
    }


    if($scriptDHbin.remediationScriptContent) {

    $scriptContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($($scriptDHbin.remediationScriptContent))) 
    Save-ContentToBlob -content $scriptContent -blobName "DHScripts_$($_)_remScript"
    }

}


# --[ Backup Device Management Scripts and Assignments ]
$scriptsDM = Get-GraphData -uri "deviceManagement/deviceManagementScripts?`$expand=Assignments"
if ($scriptsDM.value) { $scriptsDM.value | % { Save-ContentToBlob -content ($_| ConvertTo-Json -Depth 10) -blobName "DMS_$($_.displayName)" }

}


# --[ Backup DM Script binaries ]
$scriptsDM.value.id | % { 

$scriptDMbin = Get-GraphData -uri "deviceManagement/deviceManagementScripts/$_"

    if($scriptDMbin.ScriptContent ) {

    $scriptContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($($scriptDMbin.ScriptContent))) 
    Save-ContentToBlob -content $scriptContent -blobName "DMScripts_$_"
    }


}


# --[ Backup Autopilot Profiles and Assignments ]
$autoProfiles = Get-GraphData -uri "deviceManagement/windowsAutopilotDeploymentProfiles?`$expand=assignments"
if ($autoProfiles.value) { 

    $autoProfiles.value | % { 
    
    Save-ContentToBlob -content ($_ | ConvertTo-Json -Depth 10) -blobName "AUTO_$($_.displayName)" } 
   
}


# --[ Backup Enrollment Profiles and Assignments ]
$enrollProfiles = Get-GraphData -uri "deviceManagement/deviceEnrollmentConfigurations?`$expand=assignments&`$filter=deviceEnrollmentConfigurationType%20eq%20%27Windows10EnrollmentCompletionPageConfiguration%27"
if ($enrollProfiles.value) { 

    $enrollProfiles.value | % { 
    
    Save-ContentToBlob -content ($_ | ConvertTo-Json -Depth 10) -blobName "ESP_$($_.displayName)" } 
   
}


# --[ Backup Windows Updates Profiles and Assignments ]
$wuFB = Get-GraphData -uri "deviceManagement/deviceConfigurations?`$filter=isof(%27microsoft.graph.windowsUpdateForBusinessConfiguration%27)&`$expand=assignments"
if ($wuFB.value) { 

    $wuFB.value | % { 
    
    Save-ContentToBlob -content ($_ | ConvertTo-Json -Depth 10) -blobName "WUFB_$($_.displayName)" } 
   
}


# --[ Backup Feature Updates Profiles and Assignments ]
$fuFB = Get-GraphData -uri "deviceManagement/windowsFeatureUpdateProfiles?`$expand=assignments"
if ($fuFB.value) { 

    $fuFB.value | % { 
    
    Save-ContentToBlob -content ($_ | ConvertTo-Json -Depth 10) -blobName "FUFB_$($_.displayName)" } 
   
}


# --[ Backup Quality Updates Profiles and Assignments ]
$quFB = Get-GraphData -uri "deviceManagement/windowsQualityUpdateProfiles?`$expand=assignments"
if ($quFB.value) { 

    $quFB.value | % { 
    
    Save-ContentToBlob -content ($_ | ConvertTo-Json -Depth 10) -blobName "QUFB_$($_.displayName)" } 
    
}


# --[ Backup Driver Updates Profiles and Assignments ]
$duFB = Get-GraphData -uri "deviceManagement/windowsDriverUpdateProfiles?`$expand=assignments"
if ($duFB.value) { 

    $duFB.value | % { 
    
    Save-ContentToBlob -content ($_ | ConvertTo-Json -Depth 10) -blobName "DUFB_$($_.displayName)" } 
    
}


# --[ Backup iOS Updates Profiles and Assignments ]
$iOSu = Get-GraphData -uri "deviceManagement/deviceConfigurations?`$filter=isof(%27microsoft.graph.iosUpdateConfiguration%27)&`$expand=assignments"
if ($iOSu.value) { 

    $iOSu.value | % { 
    
    Save-ContentToBlob -content ($_ | ConvertTo-Json -Depth 10) -blobName "iOSU_$($_.displayName)" } 
   
}


# --[ Backup iOS Updates Profiles and Assignments ]
$mOSu = Get-GraphData -uri "deviceManagement/deviceConfigurations?`$filter=isof(%27microsoft.graph.macOSSoftwareUpdateConfiguration%27)&`$expand=assignments"
if ($mOSu.value) { 

    $mOSu.value | % { 
    
    Save-ContentToBlob -content ($_ | ConvertTo-Json -Depth 10) -blobName "mOSU_$($_.displayName)" } 
 
}


# --[ Backup Policy Sets Profiles and Assignments ]
$psP = Get-GraphData -uri "deviceAppManagement/policySets"
if ($psP.value.id) { 

    $psP.value.id | % { 
    
    $psPitems = Get-GraphData -uri "deviceAppManagement/policySets/$_/?`$expand=assignments"

    $psPitems | % {

    Save-ContentToBlob -content ($_ | ConvertTo-Json -Depth 10) -blobName "PSP_$($_.displayName)" } 
    
    }   
}


# --[ Backup Assignment Filters and Assignments ]
$afils = Get-GraphData -uri "deviceManagement/assignmentFilters"
if ($afils.value.id) { 

    $afils.value.id | % { 
    
    $afilsitems = Get-GraphData -uri "deviceManagement/assignmentFilters/$_"

    $afilsitems | % {

    Save-ContentToBlob -content ($_ | ConvertTo-Json -Depth 10) -blobName "FIL_$($_.displayName)" } 
 
    }   
}


# --[ Backup W365 Provisioning Policies and Assignments ]
$W365pp = Get-GraphData -uri "deviceManagement/virtualEndpoint/provisioningPolicies?`$expand=assignments&`$filter=managedBy eq 'Windows365'"
if ($W365pp.value.id) { 

    $W365pp.value.id | % { 
    
    $W365ppItems = Get-GraphData -uri "deviceManagement/virtualEndpoint/provisioningPolicies/$_"

    $W365ppItems | % {

    Save-ContentToBlob -content ($_ | ConvertTo-Json -Depth 10) -blobName "W365PP_$($_.displayName)" } 
 
    }   
}


# --[ Backup W365 User Settings and Assignments ]
$W365us = Get-GraphData -uri "deviceManagement/virtualEndpoint/userSettings?`$expand=assignments"
if ($W365us.value.id) { 

    $W365us.value.id | % { 
    
    $W365usItems = Get-GraphData -uri "deviceManagement/virtualEndpoint/userSettings/$_"

    $W365usItems | % {

    Save-ContentToBlob -content ($_ | ConvertTo-Json -Depth 10) -blobName "W365US_$($_.displayName)" } 
 
    }   
}


# --[ Backup W365 Azure Network Connections ]
$W365anc = Get-GraphData -uri "deviceManagement/virtualEndpoint/onPremisesConnections"
if ($W365anc.value.id) { 

    $W365anc.value.id | % { 
    
    $W365ancItems = Get-GraphData -uri "deviceManagement/virtualEndpoint/onPremisesConnections/$_"

    $W365ancItems | % {

    Save-ContentToBlob -content ($_ | ConvertTo-Json -Depth 10) -blobName "W365ANC_$($_.displayName)" } 
 
    }   
}

# ---[ Intune Backup Summary ASCII Table ]---
# Generate dynamic title with timestamp
$Title = "Intune Backup - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# Collect data into array of hashtables
$BackupSummary = @(
    @{ Name = "Application Configurations"; Value = $appConfigs.value.Count }
    @{ Name = "Device Compliance Policies"; Value = $compliancePolicies.value.Count }
    @{ Name = "Configuration Profiles"; Value = $configProfiles.value.Count }
    @{ Name = "Device Health Scripts"; Value = $scriptsDH.value.Count }
    @{ Name = "Device Management Scripts"; Value = $scriptsDM.value.Count }
    @{ Name = "Autopilot Profiles"; Value = $autoProfiles.value.Count }
    @{ Name = "Enrollment Profiles"; Value = $enrollProfiles.value.Count }
    @{ Name = "Windows Updates Profiles"; Value = $wuFB.value.Count }
    @{ Name = "Feature Updates Profiles"; Value = $fuFB.value.Count }
    @{ Name = "Quality Updates Profiles"; Value = $quFB.value.Count }
    @{ Name = "Driver Updates Profiles"; Value = $duFB.value.Count }
    @{ Name = "iOS Updates Profiles"; Value = $iOSu.value.Count }
    @{ Name = "MacOS Updates Profiles"; Value = $mOSu.value.Count }
    @{ Name = "Policy Sets Profiles"; Value = $psP.value.Count }
    @{ Name = "Filter Profiles"; Value = $afils.value.Count }
    @{ Name = "W365 Provisioning Profiles"; Value = $W365pp.value.Count }
    @{ Name = "W365 User Settings"; Value = $W365us.value.Count }
    @{ Name = "W365 Azure Network Connections"; Value = $W365anc.value.Count }
    @{ Name = "Total Failed Backups"; Value = $failed }
)

# ---[ Calculate dynamic column widths ]---
$NameWidth  = ($BackupSummary.Name | Measure-Object -Property Length -Maximum).Maximum + 2
$ValueWidth = ($BackupSummary.Value | ForEach-Object { $_.ToString().Length } | Measure-Object -Maximum).Maximum + 2
$TableWidth = $NameWidth + $ValueWidth + 5

# ---[ Render ASCII table header ]---
Write-Host ""
$TitlePadded = $Title.PadLeft(($TableWidth + $Title.Length) / 2).PadRight($TableWidth)
Write-Host $TitlePadded -ForegroundColor Black -BackgroundColor Red
Write-Host ("{0,-$NameWidth}{1,$ValueWidth}" -f "Category", "Count") -ForegroundColor Gray

# ---[ Render each row with color formatting ]---
foreach ($Item in $BackupSummary) {
    if ($Item.Name -eq "Total Failed Backups") {
        Write-Host ("{0,-$NameWidth}" -f $Item.Name) -ForegroundColor Black -BackgroundColor Gray -NoNewline
        Write-Host ("{0,$ValueWidth}" -f $Item.Value) -ForegroundColor Red -BackgroundColor Black
    }
    else {
        Write-Host ("{0,-$NameWidth}" -f $Item.Name) -ForegroundColor Gray -BackgroundColor Black -NoNewline
        Write-Host ("{0,$ValueWidth}" -f $Item.Value) -ForegroundColor Red -BackgroundColor Black
    }
}


# --[ Compile the final backup report and upload to Az Storage ]
$finalReport = $reportContent -join "`n"
$finalReport | Set-Content "$localBlobDir\BackupReport-$timestamp.txt"

#Set-AzStorageBlobContent -File $content -Container $Container -Blob "$blobDirectory/BackupReport-$timestamp.txt" -Context $ctx -Force -ErrorAction Stop # - Uncomment for automation!


# --[ CLEAN UP OLD BACKUPS SECTION ]
# --[ Get all backup folders in the root directory ]
$backupFolders = Get-ChildItem -Path C:\temp -Directory | Where-Object {
    $_.Name -match '^IntuneBackup-\d{8}-\d{6}$'
}

# --[ Filter and delete backups older than 30 days ]
$thirtyDaysAgo = (Get-Date).AddDays(-30)
$oldBackups = $backupFolders | Where-Object {
    $_.CreationTime -lt $thirtyDaysAgo
}
foreach ($oldBackup in $oldBackups) {
    Remove-Item -Path $oldBackup.FullName -Recurse -Force
    Write-Host "Deleted old backup: $($oldBackup.FullName)"
}

# --[ Ensure no more than 30 most recent backups are retained ]
$backupFolders = Get-ChildItem -Path C:\temp -Directory | Where-Object {
    $_.Name -match '^IntuneBackup-\d{8}-\d{6}$'
} | Sort-Object -Property CreationTime -Descending

if ($backupFolders.Count -gt 30) {
    $foldersToDelete = $backupFolders | Select-Object -Skip 30
    foreach ($folder in $foldersToDelete) {
        Remove-Item -Path $folder.FullName -Recurse -Force
        Write-Host "Deleted extra backup: $($folder.FullName)"
    }
}

Write-Host "Backup cleanup complete."


# --[ End of script ]