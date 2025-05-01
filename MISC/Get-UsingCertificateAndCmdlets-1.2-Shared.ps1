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
# Setup environment for Microsoft Graph API calls using certificate authentication
# --------------------------------------------------------------------------------

# Define the working directory for logs
$WorkingFilePath = "Path"

# Ensure the working directory exists
if (!(Test-Path $WorkingFilePath)) {
    New-Item -ItemType Directory -Path $WorkingFilePath -Force
}

# Define the log file path (used for logging and filtering info)
$LogFilePath = "$WorkingFilePath\GET-DeviceMigration.log"

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

# ------------------------------------------------------------------------------
# Define parameters for filtering devices
# ------------------------------------------------------------------------------

# Specify how many days back to consider for filtering (default is 0 for actual last write time)
$DaysBack = 32  # Adjust this value for testing purposes
$ExcludeRecentHours = 0  # Exclude devices enrolled in the last X hours

# Define Azure Application credentials
$ApplicationClientId = 'Client ID' # Application (Client) ID
$TenantId = 'Tenant ID' # Tenant ID
$CertificateThumbprint = 'Certificate Thumbprint' # Certificate Thumbprint

# Determine the last write time of the log file, adjusted for the specified days back
$LastWriteTime = (Get-Item -Path $LogFilePath -ErrorAction SilentlyContinue).LastWriteTime.AddDays(-$DaysBack)
$LastWriteTimeUTC = $LastWriteTime.ToUniversalTime()

# Determine the exclusion cut-off time (to exclude recent enrollments)
$ExcludeRecentTimeUTC = (Get-Date).ToUniversalTime().AddHours(-$ExcludeRecentHours)

$LastWriteTimeISO = $LastWriteTimeUTC.ToString("yyyy-MM-ddTHH:mm:ssZ")  # Convert to ISO format
$ExcludeRecentTimeISO = $ExcludeRecentTimeUTC.ToString("yyyy-MM-ddTHH:mm:ssZ")


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
# Continue logging the filtering parameters
# ------------------------------------------------------------------------------
Write-Log -Message "DaysBack variable set to: $DaysBack" -Level "INFO"
Write-Log -Message "ExcludeRecentHours variable set to: $ExcludeRecentHours" -Level "INFO"
Write-Log -Message "Using Last Write Time for filtering: $LastWriteTimeISO" -Level "INFO"
Write-Log -Message "Excluding enrollments after: $ExcludeRecentTimeISO" -Level "INFO"

# ------------------------------------------------------------------------------
# Retrieve the certificate from the local machine store
# ------------------------------------------------------------------------------
$Certificate = Get-Item "Cert:\CurrentUser\My\$CertificateThumbprint"
if (-not $Certificate) {
    Write-Log -Message "Certificate not found. Ensure it is installed in the 'My' store." -Level "ERROR"
    Break
}

# ------------------------------------------------------------------------------
# Use configured settings to authenticate with Microsoft Graph
# ------------------------------------------------------------------------------
try {
    Connect-MgGraph -TenantId $TenantId -ClientId $ApplicationClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome
    Write-Log -Message "Successfully connected to Microsoft Graph." -Level "INFO"
} catch {
    Write-Log -Message "Failed to authenticate with Microsoft Graph: $_" -Level "ERROR"
    Break
}

# ------------------------------------------------------------------------------
# Use access to query Microsoft Graph for enrolled devices
# ------------------------------------------------------------------------------
$Devices = Get-MgDeviceManagementManagedDevice -Filter "enrolledDateTime ge $LastWriteTimeISO and enrolledDateTime le $ExcludeRecentTimeISO and operatingSystem eq 'Windows'" -All
Write-Log -Message "Successfully retrieved $($Devices.Count) devices enrolled within the specified range." -Level "INFO"

# ------------------------------------------------------------------------------
# Filter through retrieved devices and identify duplicates
# ------------------------------------------------------------------------------
# Identify Co-Managed (SCCM) and Intune-Managed Devices
$CoManagedDevices = $Devices | Where-Object { $_.ManagementAgent -eq "configurationManagerClientMdm" }
$IntuneManagedDevices = $Devices | Where-Object { $_.ManagementAgent -eq "mdm" }

Write-Log -Message "The count of Co-managed devices is: $($CoManagedDevices.count)" -Level "INFO"
Write-Log -Message "The count of Intune only managed devices is: $($IntuneManagedDevices.count)" -Level "INFO"

$PendingRemovals = @()

# Compare LastSyncDateTime and identify SCCM devices for deletion
foreach ($Device in $IntuneManagedDevices) {
    $CoManagedDevice = $CoManagedDevices | Where-Object { $_.SerialNumber -eq $Device.SerialNumber }

    if ($CoManagedDevice) {
        if ($CoManagedDevice.lastSyncDateTime -gt $Device.lastSyncDateTime) {
            Write-Log -Message "Skipping device $($Device.DeviceName) as co-managed sync is newer." -Level "INFO"
            continue
        }
        $PendingRemovals += $CoManagedDevice  # Store the SCCM-managed device for deletion
        Write-Log -Message "Duplicate device found: $($Device.DeviceName) added to pending removals." -Level "INFO"
    } else {
        Write-Log -Message "No duplicate found for device $($Device.DeviceName); keeping it in Intune." -Level "INFO"
    }
}

# ------------------------------------------------------------------------------
# Export SCCM-managed devices that should be deleted
# ------------------------------------------------------------------------------
if ($PendingRemovals) {
    $csvPath = "$WorkingFilePath\SCCMDevicesForDeletion_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".csv"
    $PendingRemovals | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Log -Message "CSV generated for SCCM-managed devices to delete at $csvPath. Review before proceeding." -Level "INFO"
} else {
    Write-Log -Message "No CSV generated as no SCCM-managed devices are pending removal." -Level "INFO"
}

# ------------------------------------------------------------------------------
# Disconnect from Microsoft Graph
# ------------------------------------------------------------------------------
# Optionally disconnect if needed
# Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
