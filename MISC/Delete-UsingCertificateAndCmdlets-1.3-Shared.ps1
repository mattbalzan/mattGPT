<# DISCLAIMER
    THIS CODE IS SAMPLE CODE. THESE SAMPLES ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND.
    THE ENTIRE RISK ARISING OUT OF THE USE OR PERFORMANCE OF THE SAMPLES REMAINS WITH YOU.
#>

# --------------------------------------------------------------------------------
# Delete-UsingCertificateAndCmdlets.ps1 (Sanitized Version)
# --------------------------------------------------------------------------------

# Define the working directory for logs
param(
    [string]$WorkingFilePath = "C:\DefaultPath",
    [string]$ADOULocation = "Default AD Location",
    [int]$DeviceLimit = 5,
    [switch]$WhatIf = $false
)

# Define log file path for the delete script
$LogFilePath = Join-Path -Path $WorkingFilePath -ChildPath "DELETE-DeviceMigration-$((Get-Date).ToString('yyyyMMdd')).log"

# -------------------------------------------------------------------------------
# Define a custom logging function
# -------------------------------------------------------------------------------
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO",
        [string]$LogFile = $LogFilePath
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] - $Message"
    Add-Content -Path $LogFile -Value $logEntry
    Write-Output $Message
}

# Rename existing log file for archiving
if (Test-Path $LogFilePath) {
    $TimeForLogRename = (Get-Date -Format "yyyy-MM-ddTHH-mm-ss")
    $NewLogFileName = "$(Get-ChildItem $LogFilePath).BaseName-$TimeForLogRename.log"
    $NewLogFilePath = Join-Path -Path $WorkingFilePath -ChildPath $NewLogFileName
    Rename-Item -Path $LogFilePath -NewName $NewLogFileName -Force
    Write-Log -Message "Existing log file renamed to $NewLogFilePath" -Level "INFO"
}

# Get the latest CSV file
$CsvFilePattern = "SCCMDevicesForDeletion*.csv"
$LatestCsv = Get-ChildItem -Path $WorkingFilePath -Filter $CsvFilePattern | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $LatestCsv) {
    Write-Log -Message "No CSV file matching pattern '$CsvFilePattern' found in $WorkingFilePath." -Level "ERROR"
    return
}

$CsvFilePath = $LatestCsv.FullName
Write-Log -Message "Using CSV file: $CsvFilePath" -Level "INFO"

# Retrieve Azure credentials securely
$ApplicationClientId = (Get-EnvironmentVariable -Name "APP_CLIENT_ID")
$TenantId = (Get-EnvironmentVariable -Name "TENANT_ID")
$CertificateThumbprint = (Get-EnvironmentVariable -Name "CERT_THUMBPRINT")

Write-Log -Message "Using Certificate Authentication for Microsoft Graph." -Level "INFO"

# Retrieve the certificate
$Certificate = Get-Item "Cert:\CurrentUser\My\$CertificateThumbprint"
if (-not $Certificate) {
    Write-Log -Message "Certificate not found. Ensure it is installed in the 'My' store." -Level "ERROR"
    return
}

# Authenticate with Microsoft Graph
try {
    Connect-MgGraph -TenantId $TenantId -ClientId $ApplicationClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome
    Write-Log -Message "Successfully connected to Microsoft Graph." -Level "INFO"
} catch {
    Write-Log -Message "Failed to authenticate with Microsoft Graph: $_" -Level "ERROR"
    return
}

# Process the CSV file for deletion
$DevicesToRemove = Import-Csv -Path $CsvFilePath
if ($DevicesToRemove.Count -eq 0) {
    Write-Log -Message "No devices found in the CSV for processing." -Level "INFO"
    return
}

Write-Log -Message "Processing $($DevicesToRemove.Count) devices for removal." -Level "INFO"
$DeviceCount = 0

foreach ($Device in $DevicesToRemove) {
    if ($DeviceCount -lt $DeviceLimit) {
        Write-Log -Message "Processing device: $($Device.DeviceName)" -Level "INFO"
        if ($WhatIf) {
            Write-Log -Message "[WhatIf] Would remove device: $($Device.DeviceName)" -Level "INFO"
        } else {
            # Add device deletion logic here
            Write-Log -Message "Device $($Device.DeviceName) removed." -Level "INFO"
        }
    } else {
        Write-Log -Message "Device limit reached: $DeviceLimit" -Level "INFO"
        break
    }
    $DeviceCount++
}

Write-Log -Message "Cleanup process completed." -Level "INFO"

# Move processed CSV to 'processed' folder
$ProcessedFolder = Join-Path -Path $WorkingFilePath -ChildPath "processed"
if (-not (Test-Path $ProcessedFolder)) {
    New-Item -Path $ProcessedFolder -ItemType Directory -Force | Out-Null
}

$DestinationFile = Join-Path -Path $ProcessedFolder -ChildPath $LatestCsv.Name
try {
    Move-Item -Path $CsvFilePath -Destination $DestinationFile -Force
    Write-Log -Message "CSV file moved to processed folder: $DestinationFile" -Level "INFO"
} catch {
    Write-Log -Message "Failed to move CSV file: $_" -Level "WARNING"
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
