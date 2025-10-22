<#
.SYNOPSIS
    Searches Intune configuration policies for a specified keyword within the policy JSON body.

.DESCRIPTION
    This script connects to Microsoft Graph using an Azure AD App Registration and retrieves all Intune device configuration policies.
    It searches the JSON body of each policy for a user-defined keyword (case-insensitive) and outputs matching key-value pairs along with policy metadata.

.OUTPUTS
    A formatted table showing:
        - PolicyName
        - JSON (confirmation that keyword was found)
        - ValueFound (matching key-value pairs)
        - PolicyId
        - Type (policy type from Graph)

.NOTES
    Author: Matt Balzan
    Website: mattGPT.co.uk
    Date: 04/04/2025
    Version: 1.0
    Requires: Microsoft.Graph PowerShell SDK
    Permissions: DeviceManagementConfiguration.Read.All (Application)
    Graph Endpoint: https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations

#>


# --[ Customise your search keyword ]
$SearchValue = "firewall"

# --[ Import the App Registration variables ]
$ClientID     = ""
$TenantID     = ""
$clientSecret = ""

# --[ Convert secret to secure string ]
$SecuredPW = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force

# --[ Make up the client secret credential ]
$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $clientId, $SecuredPW

# --[ Connect to Graph ]
Connect-MgGraph -TenantId $tenantId -ClientSecretCredential $ClientSecretCredential
(Get-MgContext).Scopes

# --[ Run graph api call to get all config profiles ]
$uri = "deviceManagement/deviceConfigurations"
$Policies = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/$uri").value

# --[ Initialize results array ]
$Results = @()
$hits = 0

# --[ Search for the value in the entire JSON body using regex ]
foreach ($Policy in $Policies) {
    $PolicyJson = $Policy | ConvertTo-Json -Depth 100 -Compress

    if ($PolicyJson -match $SearchValue) {
        # --[ Regex to extract key-value pairs containing the search value ]
        $matches = [regex]::Matches($PolicyJson, '"([^"]*?' + [regex]::Escape($SearchValue) + '[^"]*?)"\s*:\s*(".*?"|\d+|true|false|null)', 'IgnoreCase')

        $FoundValues = foreach ($match in $matches) {
            "$($match.Groups[1].Value) = $($match.Groups[2].Value)"
            $hits++
        }

        $Results += [PSCustomObject]@{
            PolicyName = $Policy.displayName
            JSON       = "$SearchValue found"
            ValueFound = ($FoundValues -join "`n")
            PolicyId   = $Policy.Id
            Type       = $Policy."@odata.type" -replace "#microsoft.graph.",""
        }
    }
}

# --[ Output the search results ]
if($Results){

Write-Host "Found $hits hits on keyword: " -f Cyan -b Black -NoNewline
Write-Host $SearchValue -f Black -b Cyan

$Results | Format-Table -AutoSize -Property * -Wrap
}
else { 

Write-Host "$hits hits on keyword: " -f Yellow -b Black -NoNewline
Write-Host $SearchValue -f Black -b Yellow

}

# --[ End of script ]
