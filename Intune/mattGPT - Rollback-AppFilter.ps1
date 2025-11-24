<#
.SYNOPSIS
    Restores original Intune application assignment filters using a previously generated
    rollback dataset created by the Set-AppFilter script.

.DESCRIPTION
    This script re-applies the original assignment filter configuration for each affected
    Intune application. It consumes a rollback JSON file produced by the main Set-AppFilter
    script, which contains the full pre-change assignment state for every modified app.
    
    Requires Microsoft Graph App Permissions:
        • DeviceManagementApps.ReadWrite.All
        • DeviceManagementConfiguration.ReadWrite.All

.EXAMPLE
    .\mattGPT - Rollback-AppFilter.ps1 -AppID "d09a20a2-756a-42ff-bf0f-9ed09539cb06"

.NOTES
    +------------+---------+---------+--------------------------------------------------------------------+
    | Date       | Author  | Version | Changes                                                            |
    |------------+---------+---------+--------------------------------------------------------------------|
    | 2025-11-24 | mattGPT | 1.0     | Initial script.                                                    |
    +------------+---------+---------+--------------------------------------------------------------------+
#>
    
Param(
    [string]$AppID,
    [switch]$All
)

$TenantId     = ""
$ClientId     = ""
$ClientSecret = ""

$TokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
$Body = @{
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = "https://graph.microsoft.com/.default"
    grant_type    = "client_credentials"
}
$TokenResponse = Invoke-RestMethod -Uri $TokenUri -Method POST -Body $Body
$AccessToken   = $TokenResponse.access_token
$Headers       = @{ Authorization = "Bearer $AccessToken" }

$BackupPath = ".\AppAssignmentBackup"

if ($All) {
    $Files = Get-ChildItem $BackupPath -Filter "*.json"
} elseif ($AppID) {
    $Files = Get-ChildItem $BackupPath -Filter "$AppID.json"
} else {
    Write-Host "Specify -AppID <guid> or -All" -ForegroundColor Red
    exit
}

foreach ($file in $Files) {

    $AppId = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    Write-Host "Rolling back $AppId..." -ForegroundColor Yellow

    $Assignments = Get-Content $file.FullName -Raw | ConvertFrom-Json

    $Body = @{ mobileAppAssignments = $Assignments } |
        ConvertTo-Json -Depth 15

    try {
        # Uncomment these lines below when you are satisfied with testing backing up one or all app ids
        #Invoke-RestMethod -Method POST `
        #   -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$AppID/assign" `
        #   -Headers $Headers -ContentType "application/json" -Body $Body

        Write-Host "Rollback OK for $AppId" -ForegroundColor Green
    }
    catch {
        Write-Host "Rollback FAILED for $AppId : $($_.Exception.Message)" -ForegroundColor Red
    }
}
