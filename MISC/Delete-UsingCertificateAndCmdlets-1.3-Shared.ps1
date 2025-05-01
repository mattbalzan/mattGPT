<# DISCLAIMER
    THIS CODE IS SAMPLE CODE. THESE SAMPLES ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND.
    MICROSOFT FURTHER DISCLAIMS ALL IMPLIED WARRANTIES INCLUDING WITHOUT LIMITATION ANY IMPLIED WARRANTIES
    OF MERCHANTABILITY OR OF FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK ARISING OUT OF THE USE OR
    PERFORMANCE OF THE SAMPLES REMAINS WITH YOU. IN NO EVENT SHALL MICROSOFT OR ITS SUPPLIERS BE LIABLE FOR
    ANY DAMAGES WHATSOEVER (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF BUSINESS PROFITS, BUSINESS
    INTERRUPTION, LOSS OF BUSINESS INFORMATION, OR OTHER PECUNIARY LOSS) ARISING OUT OF THE USE OF OR
    INABILITY TO USE THE SAMPLES, EVEN IF MICROSOFT HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
#>

# --------------------------------------------------------------------------------
# Delete-UsingCertificateAndCmdlets.ps1
#
# Setup environment for Microsoft Graph API calls using certificate authentication
# and process the latest CSV file containing SCCM-managed devices for deletion.
# After processing, the CSV is moved to a "processed" subfolder.
# --------------------------------------------------------------------------------

# Define the working directory for logs
$WorkingFilePath = "path"

# Define the log file path for the delete script
$LogFilePath = "$WorkingFilePath\DELETE-DeviceMigration.log"

#Set Device Limit to determine impact scope

$DeviceLimit = 5


# ------------------------------------------------------------------------------
# Define a custom logging function
# ------------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Rename the existing log file immediately to archive it
# -----------------------------------------------------------------------------
# Create a timestamp string for renaming the log file
$LastWriteTimeForLogRename = (Get-Item -Path $LogFilePath -ErrorAction SilentlyContinue).LastWriteTime
$TimeForLogRename = $LastWriteTimeForLogRename.ToString("yyyy-MM-ddTHH-mm-ss")

if (Test-Path $LogFilePath) {
    $NewLogFileName = (Get-ChildItem $LogFilePath).BaseName + "-$TimeForLogRename.log"
    $NewLogFilePath = Join-Path -Path $WorkingFilePath -ChildPath $NewLogFileName
    Rename-Item -Path $LogFilePath -NewName $NewLogFileName -Force
    Write-Log -Message "----- Starting process -----" -Level "INFO"
    Write-Log -Message "Existing log file renamed to $NewLogFilePath" -Level "INFO"
}

# ------------------------------------------------------------------------------
# Get the latest CSV file from the working directory
# ------------------------------------------------------------------------------
$CsvFilePattern = "SCCMDevicesForDeletion*.csv"
$LatestCsv = Get-ChildItem -Path $WorkingFilePath -Filter $CsvFilePattern 

If ($LatestCsv.count -gt 1) {Write-Log -Message "More than 1 CSV file found" -Level "ERROR" ; break}

$LatestCsv = Get-ChildItem -Path $WorkingFilePath -Filter $CsvFilePattern | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $LatestCsv) {
    Write-Log -Message "No CSV file matching pattern '$CsvFilePattern' found in $WorkingFilePath." -Level "ERROR"
    break
}

# Set the CSV file path variable to the latest file found
$CsvFilePath = $LatestCsv.FullName
Write-Log -Message "Using CSV file: $CsvFilePath" -Level "INFO"

# ------------------------------------------------------------------------------
# Define Azure Application credentials
# ------------------------------------------------------------------------------
# Define Azure Application credentials
$ApplicationClientId = 'Client ID' # Application (Client) ID
$TenantId = 'Tenant ID' # Tenant ID
$CertificateThumbprint = 'Thumbprint' # Certificate Thumbprint

# ------------------------------------------------------------------------------
# Define AD OU to move old device to
# ------------------------------------------------------------------------------
$ADOULocation = "OU=DeviceMigrationComplete,OU=Windows 10,OU=Client,OU=HO Managed,DC=Poise,DC=HomeOffice,DC=Local"

# ------------------------------------------------------------------------------
# Define the WhatIf flag for dry-run (set to $true for simulation, $false for actual changes)
# ------------------------------------------------------------------------------
$WhatIf = $false

Write-Log -Message "Using Certificate Authentication for Microsoft Graph." -Level "INFO"

# ------------------------------------------------------------------------------
# Retrieve the certificate from the local machine store
# ------------------------------------------------------------------------------
$Certificate = Get-Item "Cert:\CurrentUser\My\$CertificateThumbprint"
if (-not $Certificate) {
    Write-Log -Message "Certificate not found. Ensure it is installed in the 'My' store." -Level "ERROR"
    break
}

# --------------------------------------------------------------------------------
# Use configured settings to authenticate with Microsoft Graph
# --------------------------------------------------------------------------------
try {
    Connect-MgGraph -TenantId $TenantId -ClientId $ApplicationClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome
    Write-Log -Message "Successfully connected to Microsoft Graph." -Level "INFO"
} catch {
    Write-Log -Message "Failed to authenticate with Microsoft Graph: $_" -Level "ERROR"
    break
}

# --------------------------------------------------------------------------------
# Process the CSV file for SCCM-managed devices to delete
# --------------------------------------------------------------------------------

# Import CSV containing SCCM-managed devices
if (-Not (Test-Path $CsvFilePath)) {
    Write-Log -Message "CSV file not found: $CsvFilePath" -Level "ERROR"
    break
}

$DevicesToRemove = Import-Csv -Path $CsvFilePath

if ($DevicesToRemove.Count -eq 0) {
    Write-Log -Message "No devices found in the CSV for processing." -Level "INFO"
    break
}

Write-Log -Message "Processing $($DevicesToRemove.Count) devices for removal." -Level "INFO"

$DeviceCount = 0

foreach ($Device in $DevicesToRemove) {

    If ($DeviceCount -lt $DeviceLimit ) {

    Write-Log -Message "Processing device: $($Device.DeviceName), Serial Number: $($Device.SerialNumber)" -Level "INFO"
    $ConfirmDelete = Read-Host -Prompt "Are you sure you want to delete $($Device.DeviceName) - Type Y to confirm!"
    if (-not($ConfirmDelete -eq "Y")) {
        Write-Log -Message "Delete cancelled for device: $($Device.DeviceName)" -Level "INFO"
        continue
    } else {
        Write-Log -Message "Will delete device: $($Device.DeviceName)" -Level "INFO"
    }

    # Remove device from Intune
    if ($Device.Id) {
        if ($WhatIf) {
            Write-Log -Message "[WhatIf] Would remove Intune object for device: $($Device.DeviceName)" -Level "INFO"
        } else {
            Write-Log -Message "Removing Intune object for device: $($Device.DeviceName)" -Level "INFO"
            Remove-MgDeviceManagementManagedDevice -ManagedDeviceId $Device.Id -Confirm:$false
        }
    } else {
        Write-Log -Message "No Intune ID found for device: $($Device.DeviceName)" -Level "WARNING"
    }

    # Remove device from Entra ID
    if ($Device.AzureAdDeviceId) {
        $EntraDevice = Get-MgDevice -Filter "deviceId eq '$($Device.AzureAdDeviceId)'"
        if ($EntraDevice) {
            if ($WhatIf) {
                Write-Log -Message "[WhatIf] Would remove Entra ID object for device: $($Device.DeviceName), ID: $($EntraDevice.Id)" -Level "INFO"
            } else {
                Write-Log -Message "Removing Entra ID object for device: $($Device.DeviceName), ID: $($EntraDevice.Id)" -Level "INFO"
                Remove-MgDevice -DeviceId $EntraDevice.Id -Confirm:$false
            }
        } else {
            Write-Log -Message "No Entra ID found for device: $($Device.DeviceName)" -Level "WARNING"
        }
    }

    # Move and disable AD object whilst setting AD object description
    $ADObject = Get-ADComputer -Filter "ObjectGUID -eq '$($Device.AzureAdDeviceId)'" -Properties DistinguishedName

    # Get the current date 
    $currentDate = Get-Date -Format "dd-MM-yyyy"

    # Define the new description
    $newDescription = "Disabled $currentDate by IPU Device Clean Up"

    if ($ADObject) {
        if ($WhatIf) {
            Write-Log -Message "[WhatIf] Would move AD object for device: $($Device.DeviceName) to $ADOULocation" -Level "INFO"
            Write-Log -Message "[WhatIf] Would disable AD object for device: $($Device.DeviceName)" -Level "INFO"
            Write-Log -Message "[WhatIf] Would write description for AD object for device: $($Device.DeviceName) to $newdescription" -Level "INFO"
        } else {
            Write-Log -Message "Moving AD object for device: $($Device.DeviceName) to $ADOULocation" -Level "INFO"
            Set-ADComputer -Identity $ADObject.DistinguishedName -Enabled $false -Description $newDescription
            Move-ADObject -Identity $ADObject.DistinguishedName -TargetPath $ADOULocation
        }
    } else {
        Write-Log -Message "AD object not found for device: $($Device.DeviceName)" -Level "WARNING"
    }
        } else {
        Write-Log -Message "Count exceeded device limit" -Level "INFO" 
        break 
        }
    $DeviceCount++
}

Write-Log -Message "Cleanup process completed." -Level "INFO"

# --------------------------------------------------------------------------------
# Move the processed CSV file to the 'processed' subfolder
# --------------------------------------------------------------------------------
$ProcessedFolder = Join-Path -Path $WorkingFilePath -ChildPath "processed"
if (-not (Test-Path $ProcessedFolder)) {
    New-Item -Path $ProcessedFolder -ItemType Directory -Force | Out-Null
}

$DestinationFile = Join-Path -Path $ProcessedFolder -ChildPath $LatestCsv.Name

try {
    Move-Item -Path $CsvFilePath -Destination $DestinationFile -Force
    Write-Log -Message "CSV file moved to processed folder: $DestinationFile" -Level "INFO"
} catch {
    Write-Log -Message "Failed to move CSV file to processed folder: $_" -Level "WARNING"
}

# --------------------------------------------------------------------------------
# Disconnect from Microsoft Graph
# --------------------------------------------------------------------------------
#Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
