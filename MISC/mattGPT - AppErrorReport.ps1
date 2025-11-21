<#
.SYNOPSIS
	Gather Event Viewer + Reliability Records + WER crashdump data
    to send to Intune via Detection Script.

.DESCRIPTION
	{enter description here}

.NOTES
    +------------+---------+---------+--------------------------------------------------------------------+
    | Date       | Author  | Version | Changes                                                            |
    |------------+---------+---------+--------------------------------------------------------------------|
    | 2025-11-20 | mattGPT | 1.0     | Initial script.                                                    |
    +------------+---------+---------+--------------------------------------------------------------------+
#>

#--------------------------------------------------------
# Configuration
#--------------------------------------------------------
$AppName      = 'BTAG'
$reports      = New-Object System.Collections.ArrayList
$toIntune     = New-Object System.Collections.ArrayList

#--------------------------------------------------------
# Application Event Log Search (Event ID 1000)
#--------------------------------------------------------
$FilterXML = @'
<QueryList>
  <Query Id="0" Path="Application">
    <Select Path="Application">*[System[(EventID=1000)]]</Select>
  </Query>
</QueryList>
'@

$events = Get-WinEvent -FilterXml $FilterXML -ErrorAction Stop
$event = $events | Where-Object {$_.Message -cmatch $AppName} | Select-Object -First 1

if ($event) {
    $eventMessage      = $event.Message
    $eventTimeCreated  = $event.TimeCreated

    [void]$toIntune.Add("$eventTimeCreated,$eventMessage")

    # Build report object
    [void]$reports.Add([pscustomobject]@{
        'Time Created' = $eventTimeCreated
        'Type'         = 'Event'
        'Message'      = $eventMessage
    })
}

#--------------------------------------------------------
# Reliability Records Search (EventIdentifier 1000)
#--------------------------------------------------------
$record = Get-WmiObject -Class Win32_ReliabilityRecords `
          -ErrorAction Stop |
          Where-Object {
                $_.ProductName -cmatch $AppName -and
                $_.EventIdentifier -eq 1000
          } |
          Select-Object -First 1

if ($record) {

    # format TimeGenerated value into desired format
    $dt = [System.Management.ManagementDateTimeConverter]::ToDateTime($record.TimeGenerated)

    $formatted = $dt.ToString('dd/MM/yyyy HH:mm:ss')

    [void]$reports.Add([pscustomobject]@{
        'Time Created' = $formatted
        'Type'         = 'RR'
        'Message'      = $record.Message
    })
}



#--------------------------------------------------------
# WER reports (ReportArchive + LocalDumps)
#--------------------------------------------------------
$werRoots = @(
    "$env:ProgramData\Microsoft\Windows\WER\ReportArchive",
    "$env:ProgramData\Microsoft\Windows\WER\ReportQueue",
    "$env:LOCALAPPDATA\CrashDumps"
) | Select-Object -Unique

$werItems = foreach ($root in $werRoots) {
    if (Test-Path $root) {
      Get-ChildItem -Path $root -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        [pscustomobject]@{
          Path         = $_.FullName
          Name         = $_.Name
          LastWrite    = $_.LastWriteTime
          SourceRoot   = $root
          Type         = if ($_.Extension -match '\.dmp$') { 'Dump' } elseif ($_.Extension -match '\.xml$') { 'WER-XML' } else { 'Other' }
      }
    }
  }
} 

# Locate latest WER crash dump and copy to IME log folder for portal extraction
$werItem = if($werItems){ 
        Write-Output "Crashdump file found for $AppName`: $($werItem.path)"
        $werItems | Where-Object { $_.Path -cmatch $AppName} | Select-Object -First 1
}
Copy-Item -Path $werItem.Path -Recurse -Destination C:\ProgramData\Microsoft\IntuneManagementExtension\Logs -Force


#--------------------------------------------------------
# Output (for testing only, comment out when deploying Detection script)
#--------------------------------------------------------
$reports | Format-Table -AutoSize

#--------------------------------------------------------
# Send Detection output to Intune
#--------------------------------------------------------
# First check if we exceed the total chars allowed to send to Intune
$toIntune = $data
if($data.length -gt 2048){$data = "CRITICAL ERROR: Exceeded 2048 characters - review logs on machine."}
Write-Host $data

#--------------------------------------------------------
# End of script
#--------------------------------------------------------