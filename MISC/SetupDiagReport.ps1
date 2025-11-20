<#
.SYNOPSIS
	Downloads latest version of SetupDiag and launches it.

.DESCRIPTION
	Downloads latest version of SetupDiag and launches it, to produce the report log file.

.NOTES
    +------------+---------+---------+--------------------------------------------------------------------+
    | Date       | Author  | Version | Changes                                                            |
    |------------+---------+---------+--------------------------------------------------------------------|
    | 2025-11-20 | mattGPT | 1.0     | Initial script.                                                    |
    +------------+---------+---------+--------------------------------------------------------------------+
#>

# ----- CONFIGURATION -----
$deviceName    = $env:COMPUTERNAME
$SetupDiagURL  = "https://go.microsoft.com/fwlink/?linkid=870142"
$SetUpDiagPath = "C:\ProgramData\SetupDiag"
$resultslog    = "$SetUpDiagPath\${deviceName}_SetupDiagResults.log"
$switches      = "/Output:$resultsLog"
$file          = "$SetUpDiagPath\setupdiag.exe"


# ----- Create local SetupDiag dir -----
if(!(Test-Path $SetUpDiagPath)){ New-Item -Path $SetUpDiagPath -ItemType Directory -Force}


# ----- Download file -----
Function Download ($source,$output){

        Write-Host "Setting TLS to 1.2..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        $file = Split-Path $output -Leaf

        Write-Host "Downloading SetupDiag.exe..."
        (New-Object System.Net.WebClient).DownloadFile($source, $output)
}


# ----- Download SetupDiag from MSFT site -----
try{

        if(!(Test-Path "$file")){
            
            Write-Host "SetupDiag.exe file is missing - added to download job."
            Download $SetupDiagURL $file
            }
        
        else{
            Write-Host "SetupDiag.exe file exists."
            }
}
catch{ 
        Write-Host $_.Exception.Message
        Exit 1
        
        }


# ----- Execute setupdiag -----
Start-Process -FilePath $file -ArgumentList $switches -Wait


# ----- Launch Results log file -----
&notepad $Resultslog