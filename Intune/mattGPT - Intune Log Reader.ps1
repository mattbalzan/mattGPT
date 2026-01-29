<#
.SYNOPSIS
	Reads Intune logs and filters content.

.DESCRIPTION
	This script scans the Microsoft Intune Management Extension log directory. 
    It parses the CMTrace log format using Regular Expressions to extract messages, dates, times and log names. 
    It specifically filters for events that occurred within the last custom defined hours.

.EXAMPLE
    1-29-2026 12:00:34.1162211 | AppWorkload | [Win32AppAsync] Starting app check in

.NOTES
    +------------+---------+---------+--------------------------------------------------------------------+
    | Date       | Author  | Version | Changes                                                            |
    |------------+---------+---------+--------------------------------------------------------------------|
    | 2025-01-29 | mattGPT | 1.0     | Initial script.                                                    |
    +------------+---------+---------+--------------------------------------------------------------------+
#>

# Set cutoff time for logs (adjust as required)
$cutOff = 24

# Filter for log files beginning with their start names - eg: ^Health|^App|^Agent|^Device
$logFilters = "^AppWorkload|^Intune"

# External log file path | change to C:\Windows\CCM\Logs on live machine ]
$logs = Get-ChildItem -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"

# Get only the filtered logs
$logFiles = $logs | Where-Object { $_.Name -match $logFilters }

# Read the content of the log file
$logContent = @()
$logFiles | % { $logContent += Get-Content -Path $_.FullName -Raw }

# Filter content keywords
$filter = "Win32AppAsync|application poller|check in|Win32App DO"

# Define the regular expression pattern
$pattern = '<!\[LOG\[(.*?)\]LOG\]!>.*?time="(.*?)" date="(.*?)" component="(.*?)"'

# Define the cutoff time
$hoursAgo = (Get-Date).AddHours(-$cutOff)

# Find matches in the log content
$matches = [regex]::Matches($logContent, $pattern)

cls
foreach ($match in $matches) {
    # Check if the message matches your keyword filter
    if ($match.Groups[1].Value -match $filter) {
       
        $message = $match.Groups[1].Value
        $time = $match.Groups[2].Value
        $date = $match.Groups[3].Value
        $comp = $match.Groups[4].Value

        try {
            if ($cutOff -gt 0){
                $logDateTime = [datetime]"$date $time"

                # Only output if the log entry is newer than the cutoff time
                if ($logDateTime -gt $hoursAgo) {
                    Write-Host "$date $time | $comp | " -f DarkGray -NoNewline
                    Write-Host $message
                }
            }
            else {
                    Write-Host "$date $time | $comp | " -f DarkGray -NoNewline
                    Write-Host $message
            }
        }
        catch {
            continue
        }
    }
}

# End of script
