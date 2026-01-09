<#
.SYNOPSIS
	Automation Runbook - Intune Device Membership App Updater

.DESCRIPTION
    Description:  1. Reads any new AzTable rows and gathers row data values.
                  2. Runs Graph Export job (AppInvRawData).
                  3. Downloads zip report to temp folder, extracts to csv and imports all the data.
                  4. Using condition operator, checks csv entries and adds all false to device ID list.
                  5. Runs Graph API Group Membership Patch to add all found device IDs to App Group ID.
	
    Permissions:  Azure Storage Table Contributor Role
                  Azure Storage Account Read/List actions
                  Group Owner
                  DeviceManagementApps.Read.All

    Requirements: Azure Table: DeviceMembership
                  Azure Table Row columns: APP_ID | APP_NAME | APP_VERSION | CONDITION | GROUP_ID | STATUS

.NOTES
    +------------+---------+---------+--------------------------------------------------------------------+
    | Date       | Author  | Version | Changes                                                            |
    |------------+---------+---------+--------------------------------------------------------------------|
    | 2025-01-31 | mattGPT | 1.0     | Initial script.                                                    |
    | 2025-02029 | mattGPT | 1.1     | Adjusted ASCII character lengths.                                  |
    |            |         |         | Added support for 1 device counts.                                 |
    |            |         |         | Added MgContext Scopes for troubleshooting permissions.            |
    +------------+---------+---------+--------------------------------------------------------------------+
#>


# Step status message function
function Log($message){
Write-Output "$(Get-Date -Format "dd-MM-yyyy hh:mm:ss") | $message"
}

# Set Report name
$report = "AppInvRawData"

# Azure Storage Table configuration
$ResourceGroup = "{custom RG name}"
$StorageAccountName = "{custom Az Table name}"
$tableName = "DeviceMembership"

# Connect to Azure | Import AzTable
Connect-AzAccount -Identity
Import-Module -Name Az.Storage,AzTable


# Connect to Azure Storage Table
Log "Connecting to Azure Storage Table $tableName..."
$account = Get-AzStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroup
$ctx = $account.Context

# Retrieve data from Azure Table Storage
$AzureTable = (Get-AzStorageTable -Context $ctx | where {$_.name -eq "$tableName"}).CloudTable
Log "Az Table: $AzureTable"

# Check for approved devices
$approvedApps = Get-AzTableRow -Table $AzureTable -CustomFilter "(STATUS eq 'APPROVED')"

if (-not $approvedApps) {
    Log "No recently added approved devices found. Exiting script."
    exit
}


# Import the App Registration variables
$ClientID     = "{custom client ID}"
$TenantID     = "{custom tenant ID}"
$clientSecret = "{custom secret cred value}"

Log "Connecting to Graph..."
$SecuredPW = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force
$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $clientId, $SecuredPW
Connect-MgGraph -TenantId $tenantId -ClientSecretCredential $ClientSecretCredential  

Log "Current Graph permissions:"
(Get-MgContext).Scopes

# Report total approved rows
Log "Approved Rows: $($approvedApps.count)"

# Run through each APPROVED App
foreach ($deviceMembership in $approvedApps){

# Extract necessary values from the table row
$AppName = $deviceMembership."APP_NAME"
$appID = $deviceMembership."APP_ID"
$appVersion = $deviceMembership."APP_VERSION"
$condition = $deviceMembership."CONDITION"
$groupID = $deviceMembership."GROUP_ID"

# Generate ASCII Table Header
$separator = "+----------------------------------------------+-----------------------------+---------------+-------------+--------------------------------------+"
$header =    "| APP ID                                       | APP NAME                    | APP VERSION   | CONDITION   | GROUP ID                             |"

Write-Output $separator
Write-Output $header
Write-Output $separator

# Print row in the ASCII Table
$row = "| {0,-44} | {1,-27} | {2,-13} | {3,-11} | {4,-36} |" -f $appID, $appName, $appVersion, $condition, $groupID
Write-Output $row
Write-Output $separator


# Run Graph api to get App Inventory raw data based on app name
try{

$body = @"
{
    "reportName": "$report",
    "filter": "(ApplicationName eq '$AppName')",
    "select": ["ApplicationId","ApplicationName","ApplicationShortVersion","DeviceId","DeviceName"],
    "format": "csv",
    "snapshotId": ""
}
"@ 

# Output the body for review ]
Log "Status | Posting report export job: $reportName"
Write-Output $body
""

$response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs" -Method POST -ContentType "application/json" -Body $body


# Set Export Job ID for status review
$id = $response.id

}catch{
        Write-Output $_.exception.message
        Break
    }


#  Loop until csv data is processed and ready for download
do
{
    $status = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs('$id')" -Method Get 
    
    Log "Status | Export job: $($status.status)"
    Start-Sleep 2 
}
while ($status.status -ne "completed")


# Download the zip file from temp storage URL
$ReportDateTime = Get-Date -Format "ddMMyy-HHmmss"
$zipFile = "$ENV:TEMP\$report`_$ReportDateTime.zip"
$csvFile = "$ENV:TEMP\$report`_$ReportDateTime"

try{
        Log "Status | Downloading zip file from: $($status.url)"
        
        Invoke-WebRequest -Uri $status.url -OutFile $zipFile  
        }
catch{
        Log $_.exception.message
        Break
}


# Extract the csv
Log "Status | Extracting file to temp dir..."
Expand-Archive -Path $zipFile -DestinationPath $csvFile -Force

# Import the csv data
Log "Status | Importing csv data..."
$csvData = @()
$csvData = Import-Csv -Path "$csvFile\*.csv" 


# Filter device IDs based on condition
Log "Status | Comparing csv data..."
$deviceIds = $csvData | Where-Object {
    $appVer = $_.ApplicationShortVersion
    $targetVer = $appVersion
    switch ($condition) {
        "<" { $appVer -lt $targetVer }
        ">" { $appVer -gt $targetVer }
        "<=" { $appVer -le $targetVer }
        ">=" { $appVer -ge $targetVer }
        "=" { $appVer -eq $targetVer }
        default { $false }
    }
} | Select-Object -ExpandProperty DeviceId


# Define batch size | Max devices 20 to add to Group membership
$batchSize = 20
$totalDevices = $deviceIds.Count

if ($totalDevices -gt 0) {

    if ($totalDevices -eq 1){ $body["members@odata.bind"] += "https://graph.microsoft.com/v1.0/directoryObjects/$deviceIds" }

    else {

        for ($i = 0; $i -lt $totalDevices; $i += $batchSize) {

        $batch = $deviceIds[$i..($i + $batchSize - 1)]

        
        # Construct request body for Microsoft Graph API PATCH call
        $body = @{ "members@odata.bind" = @() }
        foreach ($device in $batch) {
            $body["members@odata.bind"] += "https://graph.microsoft.com/v1.0/directoryObjects/$device"
        }
    }
        $jsonBody = $body | ConvertTo-Json -Depth 2
        
       
        # Example API call - Uncomment and replace with actual authentication
        $uri = "https://graph.microsoft.com/v1.0/groups/$groupID"
        
        # Output the body for review
        Log "Status | Device ID Patching to Group ID: $groupID"
        Write-Output $jsonBody
        ""

        # Add all devices to the Group ID
        Invoke-MgGraphRequest -Uri $uri -Method Patch -Body $jsonBody -ContentType "application/json"
    }

    Write-Output "$AppName | Total devices added: $($deviceIds.count)"

    } else {
        Log "Status | No devices found with an outdated ApplicationShortVersion."
    }
}

Log "Status | Runbook job complete"

# End of script
