# --[ Extract and summarize Distribution Points from SCCM client logs ]
# --[ Matt Balzan | mattGPT.co.uk | 07/05/2025                        ]


# --[ Define the path to the SCCM client logs ]
$logPath = "$env:SystemRoot\CCM\Logs"

# --[ Filter for log files beginning with their start names ]
$LogFilters = "^ContentTransfer|^DataTransfer|^LocationServ"

# --[ Get only the filtered logs ]
$LogFiles = Get-ChildItem -Path $logPath | Where-Object { $_.Name -match $LogFilters }

# Regex to extract HTTP(S) and UNC paths without trailing junk
$dpPattern = "(http[s]?://[^\s'""\]\)\><]+)|(\\\\[^\s'""\]\)\><]+)"

# Function to clean DP strings
function Clean-MatchedDP {
    param ($value)
    return ($value -replace "['""\]\)\><`t].*$", "")
}

# Collect all DP occurrences
$allDPs = @()

# Parse logs
foreach ($logFile in $logFiles) {
    $fullPath = Join-Path -Path $logPath -ChildPath $logFile

    if (Test-Path $fullPath) {
        Write-Host "`n--- Checking $logFile ---" -ForegroundColor Cyan

        $entries = Select-String -Path $fullPath -Pattern $dpPattern -AllMatches

        foreach ($entry in $entries) {
            $timestamp = "Unknown"
            if ($entry.Line -match "(\d{2}:\d{2}:\d{2}\.\d{3})") {
                $timestamp = $matches[1]
            }

            foreach ($match in $entry.Matches) {
                $cleanDP = Clean-MatchedDP $match.Value
                if ($cleanDP) {
                    $allDPs += [PSCustomObject]@{
                        LogFile   = $logFile
                        Timestamp = $timestamp
                        DP        = $cleanDP
                    }
                }
            }
        }
    } else {
        Write-Host "Log file not found: $fullPath" -ForegroundColor Yellow
    }
}

# --[ Deduplicate detailed entries ]
$distinctDPs = $allDPs | Sort-Object DP, Timestamp -Unique

# --[ Output detailed DP records ]
if ($distinctDPs.Count -gt 0) {
    Write-Host "`n== Cleaned Distribution Points with Timestamps ==" -ForegroundColor Cyan
    $distinctDPs | Format-Table -AutoSize
} else {
    Write-Warning "No valid Distribution Points found in logs."
}

# --[ Export full DP list to CSV ]
$outputPath = "$env:USERPROFILE\Desktop\SCCM_DPs_With_Timestamps.csv"
$distinctDPs | Export-Csv -Path $outputPath -NoTypeInformation
Write-Host "`nExported DP list to: $outputPath" -ForegroundColor Yellow

# --[ Group and count by HTTPS DP FQDN only ]
$httpsBaseDPs = $allDPs | Where-Object { $_.DP -like "https://*" } | ForEach-Object {
    $uri = [uri]$_."DP"
    $fqdn = "$($uri.Scheme)://$($uri.Host)"
    $fqdn
}

$dpSummary = $httpsBaseDPs | Group-Object | Sort-Object Count -Descending

Write-Host "`n== Summary: Base HTTPS Distribution Points ==" -ForegroundColor Cyan
$dpSummary | Select-Object @{Name="DP FQDN";Expression={$_.Name}}, Count | Format-Table -AutoSize

# --[ Optional CSV export of FQDN summary ]
$summaryPath = "$env:USERPROFILE\Desktop\SCCM_DP_FQDN_Summary.csv"
$dpSummary | Select-Object @{Name="DP FQDN";Expression={$_.Name}}, Count |
    Export-Csv -Path $summaryPath -NoTypeInformation
Write-Host "`nExported FQDN summary to: $summaryPath" -ForegroundColor Yellow

# --[ End of script ]