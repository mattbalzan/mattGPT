# --[ MECM Log Parser                          ]
# --[ Matt Balzan | mattGPT.co.uk | 05-06-2024 ]

<#

    Description:    1. Locates only filtered logs (add as many as you need but follow the regex pattern).
                    2. Imports all the content based on search patterns.
                    3. Parses the log data.
                    4. Displays the content in date time order. 

    Notes:          Version 1.0 - Original

#>

$ErrorActionPreference = "SILENTLYCONTINUE"

# --[ Set search patterns ]
$filters  =  "0x87D00324" #,"0x80070002"


# --[ Set log regex patterns ]
$logPattern  = '\[LOG\[(.*?)\]LOG\]'
$datePattern = 'date="(.*?)"'
$timePattern = 'time="(.*?)"'
$compPattern = 'component="(.*?)"'


# --[ Filter for log files beginning with their start names ]
$LogFilters = "^Update | ^App"


# --[ External log file path | change to C:\Windows\CCM\Logs on live machine ]
$Logs = Get-ChildItem -Path "C:\Windows\CCM\Logs"


# --[ Get only the filtered logs ]
$LogFiles = $Logs | Where-Object { $_.Name -match $LogFilters }


# --[ Grab all the filtered content ]
$content = ""
$content = 

foreach ($log in $LogFiles){

Write-Host "Searching $($log.Name)"

if($filters -eq ""){ Get-Content -Path $log.FullName }
else{ Get-Content -Path $log.FullName | Select-String -Pattern $filters }

}


# --[ Display all the parsed content ]
$output = ""
$output =
foreach ($line in $content) {
 
$date    = [regex]::Match($line, $datePattern).Groups[1].Value
$time    = [regex]::Match($line, $timePattern).Groups[1].Value -replace ".{8}$"
$comp    = [regex]::Match($line, $compPattern).Groups[1].Value
$message = [regex]::Match($line, $logPattern).Groups[1].Value

[datetime]$dt = "$date $time" 

    [pscustomobject]@{

        DateTime  = $dt
        Component = $comp
        Message   = $message

    }
}

$records = $output | Sort-Object DateTime
$records | ft -AutoSize


# --[ End of script ]
