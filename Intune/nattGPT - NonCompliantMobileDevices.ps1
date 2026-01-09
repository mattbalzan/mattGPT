<#
.SYNOPSIS
	Non-Compliant Mobile Devices Automation Script
    Author: Matt Balzan (mattGPT)

.DESCRIPTION
	Query non-compliant devices in Intune
    Filter devices by model (the 4 retiring models)
    Validate device is a member of:
        - Required dynamic model group
        - NOT a member of the assigned “keep” group
    Initiate wipe on qualifying devices
    Detect and clean duplicate device records
    Log actions + failures (Log Analytics friendly)

    Graph API permissions (App / Managed Identity):
    
        DeviceManagementManagedDevices.ReadWrite.All	Wipe / read devices
        Device.Read.All	                                Group membership validation
        Group.Read.All	                                Security group checks
        Directory.Read.All	                            Duplicate object analysis

.NOTES
    +------------+---------+---------+--------------------------------------------------------------------+
    | Date       | Author  | Version | Changes                                                            |
    |------------+---------+---------+--------------------------------------------------------------------|
    | 2025-12-18 | mattGPT | 1.0     | Initial script.                                                    |
    +------------+---------+---------+--------------------------------------------------------------------+
#>


# ------------------------------
# GRAPH CONFIGURATION
# ------------------------------
$clientId     = ""
$tenantId     = ""
$clientSecret = ""
$url          = "https://graph.microsoft.com"
$ver          = "v1.0"
$NonCompliantDevices = @()
$targetModels = @("iPhone SE (1st generation)","iPhone SE (2nd generation)","SM-A528B","SM-G525F")


# ------------------------------
# LOG CONFIGURATION
# ------------------------------
$customer     = "mattGPT"
$feature      = "NonCompliantMobileDevices"
$IMElogPath   = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
$logPath      = "$IMElogPath\$customer\Logs\Remediations\$feature"
$logfile      = "$logPath\$feature.log"

if(!(Test-Path $logPath)){ New-Item -Path $logPath -ItemType Directory -Force }


# ------------------------------
# SET KNOWN ENTRA GROUP IDS
# ------------------------------
$DynamicModelGroupIds = @(
    'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    'ffffffff-1111-2222-3333-444444444444'
)

$KeepGroupId = '99999999-8888-7777-6666-555555555555'


# ------------------------------
# FUNCTION: PAGING GRAPH
# ------------------------------
function RunGraphAPI($uri, $method) {
    $Results = @()
    $short_uri = $uri -replace "https://graph.microsoft.com/v1.0",""
  do {
        Write-Host "$method $short_uri"
        $response = Invoke-MgGraphRequest -Method $method -Uri $uri
        $Results += $response
        $uri = $response.'@odata.nextLink'
    } while ($uri)
    return $Results
}


# ------------------------------
# FUNCTION: LOG
# ------------------------------
function Log($message){
"$(Get-Date -Format "dd-MM-yyyy hh:mm:ss") | $message" | Out-File $logfile -Append
Write-Host $message
}


# ------------------------------
# CONNECT TO GRAPH
# ------------------------------
$SecuredPW = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force
$ClientSecretCredential = New-Object System.Management.Automation.PSCredential ($clientId, $SecuredPW)
try{
    Connect-MgGraph -TenantId $tenantId -ClientSecretCredential $ClientSecretCredential
    $GraphSession = Get-MgContext
    Log "Connected to Graph with Client App: $($GraphSession.AppName)"
    Log "Using Graph API Permissions: $($GraphSession.Scopes)"
}catch{
    Log "There was a problem connecting to Graph: $($_.exception.message)"
}


# ------------------------------
# GET NON-COMPLIANT MOBILE DEVICES
# ------------------------------
Log "Searching for non-compliant mobile devices..."
#$NonCompliantDevices = (RunGraphAPI "$url/$ver/deviceManagement/managedDevices?`$filter=$filterPart&`$top=999" GET).value
$NonCompliantDevices = (RunGraphAPI "$url/$ver/deviceManagement/managedDevices?`$filter=complianceState eq 'noncompliant' and (operatingSystem eq 'iOS' or operatingSystem eq 'Android')&`$top=999" GET).value

$table = @()
$table = $NonCompliantDevices | % {
             [pscustomobject]@{
                            Model = $_.model
                            OS = $_.operatingSystem
                            OSVersion = $_.osVersion
                            OwnerType =  $_.managedDeviceOwnerType
                            Category = $_.deviceCategoryDisplayName 

             }
}


# ------------------------------
# FILTER & DISPLAY RESULTS
# ------------------------------
$table | Sort-Object OS, OwnerType | ft -AutoSize

$corpDevices = $table | ? { $_.OwnerType -eq 'company' }
$persDevices = $table | ? { $_.OwnerType -eq 'personal'}
$unknownDevices = $table | ? { $_.OwnerType -eq 'unknown'}


# ------------------------------
# GET GROUP MEMBER IDS
# ------------------------------
$KeepGroupMembers = (RunGraphAPI "$url/$ver/groups/$GroupId/members?`$select=id" GET).value

foreach ($Device in $corpDevices) {

    if ($Device.Model -in $targetModels) {
        continue
        # test target models:
        #"Found $($Device.Model) - $($Device.OS)"
    }

    # Exclude explicitly kept devices
    if ($KeepGroupMembers.ContainsKey($Device.azureADDeviceId)) {
        Log "Skipping KEEP device: $($Device.deviceName)"
        continue
    }

    

    try {
        Log "Wiping device: $($Device.deviceName) [$($Device.model)]"
        # Invoke-MgGraphRequest -Method POST -Uri "$url/$ver/deviceManagement/managedDevices/$($Device.id)/wipe" -Body @{ keepEnrollmentData = $false; keepUserData = $false }
    }
    catch {
        Log "Failed wipe: $($Device.deviceName) - $_"
    }
}


# ------------------------------
# END OF SCRIPT
# ------------------------------
