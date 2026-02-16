<#
.SYNOPSIS
	Detection script for Intune to report on WinRE status and version matching.

.DESCRIPTION
	Returns JSON for logs and Exit 1 if WinRE is disabled or mismatched.

.NOTES
    +------------+---------+---------+--------------------------------------------------------------------+
    | Date       | Author  | Version | Changes                                                            |
    |------------+---------+---------+--------------------------------------------------------------------|
    | 2026-02-16 | mattGPT | 1.0     | Initial script.                                                    |
    +------------+---------+---------+--------------------------------------------------------------------+
#>

$report = [PSCustomObject]@{
    "OS_Name"           = "Unknown"
    "OS_Version"        = "Unknown"
    "OS_Build"          = "Unknown"
    "WinRE_Status"      = "Unknown"
    "WinRE_WIM_Version" = "Unknown"
    "WinRE_WIM_Build"   = "Unknown"
    "Healthy_Match"     = "No"
    "Created"           = "Unknown"
    "Modified"          = "Unknown"
    "WinRE_Path"        = "Unknown"
    "Error_Log"         = ""
}

try {
    # 1. Get OS Information
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $report.OS_Name = $os.Caption
    $report.OS_Version = $os.Version
    $report.OS_Build = [string]$os.BuildNumber

    # 2. Get ReagentC Info (Out-String is critical here to prevent null array errors)
    $reagentRaw = reagentc /info | Out-String
    
    # Robust Regex Matching for Status and Path
    if ($reagentRaw -match "Windows RE status:\s+(?<status>\w+)") {
        $report.WinRE_Status = $Matches['status'].Trim()
    }
    
    if ($reagentRaw -match "Windows RE location:\s+(?<path>.*)") {
        $report.WinRE_Path = $Matches['path'].Trim()
    }

    # 3. Handle Partition Mounting
    if ($report.WinRE_Path -match 'partition(?<num>\d+)') {
        $partitionNum = $Matches['num']
        try {
            # Finding partition by number based on the reagentc path
            $partition = Get-Partition | Where-Object { $_.PartitionNumber -eq $partitionNum } | Select-Object -First 1
            
            if ($partition) {
                $tempDrive = "Z" 
                Set-Partition -InputObject $partition -NewDriveLetter $tempDrive -ErrorAction Stop
                
                $wimFile = "Z:\Recovery\WindowsRE\Winre.wim"
                
                if (Test-Path $wimFile) {
                    $dismInfo = dism /Get-ImageInfo /ImageFile:$wimFile /Index:1 | Out-String
                    
                    if ($dismInfo -match "Version\s+:\s+(?<ver>.*)") { $report.WinRE_WIM_Version = $Matches['ver'].Trim() }
                    if ($dismInfo -match "ServicePack Build\s+:\s+(?<build>.*)") { $report.WinRE_WIM_Build = $Matches['build'].Trim() }
                    
                    # Safe Date Extraction using Match Collection to avoid null index errors
                    $dateRegex = '\d{1,2}/\d{1,2}/\d{4}'
                    $foundDates = [regex]::Matches($dismInfo, $dateRegex)
                    
                    if ($foundDates.Count -ge 1) { $report.Created = $foundDates[0].Value }
                    if ($foundDates.Count -ge 2) { $report.Modified = $foundDates[1].Value }
                } else {
                    $report.Error_Log = "WIM file not found on mounted drive."
                }
            }
        }
        catch {
            $report.Error_Log = "Partition Mount Error: $($_.Exception.Message)"
        }
        finally {
            if (Get-Partition -DriveLetter "Z" -ErrorAction SilentlyContinue) {
                Remove-PartitionAccessPath -DriveLetter "Z" -AccessPath "Z:\" -ErrorAction SilentlyContinue
            }
        }
    }
}
catch {
    $report.Error_Log = "General Script Error: $($_.Exception.Message)"
}

# Determine Health
if ($report.OS_Build -eq $report.WinRE_WIM_Build -and $report.WinRE_Status -eq "Enabled") {
    $report.Healthy_Match = "Yes"
} else {
    $report.Healthy_Match = "Mismatch or Disabled"
}

# 4. Final Output
$jsonOutput = $report | ConvertTo-Json -Compress
Write-Output $jsonOutput

# Intune Logic
if ($report.Healthy_Match -eq "Yes") { exit 0 } else { exit 1 }