<#
.SYNOPSIS
    Author: Matt Balzan (mattGPT)
    Uploads or downloads Azure Blob Storage content using a SAS token.
    
.DESCRIPTION
    Uses Azure Blob Storage REST API to perform:
      - Upload operations (Put Blob)
      - Download operations (Get Blob)

    Requires only a SAS URL token. 
    Provides detailed error diagnostics including reading the Azure Storage
    service response body on REST failures.

.PARAMETER AccountName
    Storage account name (without domain).

.PARAMETER Container
    Blob container name.

.PARAMETER BlobName
    Target blob name.

.PARAMETER Sas
    Shared Access Signature token.

.PARAMETER Content
    Text content supplied for upload operations only.

.PARAMETER Upload
    Executes a blob upload using HTTP PUT.

.PARAMETER Download
    Executes a blob download using HTTP GET.

.EXAMPLE
    Invoke-BlobTransfer -Upload -AccountName acct -Container logs -BlobName file.txt -Content "data" -Sas $sasKey

.EXAMPLE
    $data = Invoke-BlobTransfer -Download -AccountName acct -Container logs -BlobName file.txt -Sas $sasKey

.NOTES
    API: Azure Blob Storage REST API (Put Blob, Get Blob)
    Compatible: PowerShell 5.1+
#>

function Invoke-BlobTransfer {
    [CmdletBinding(DefaultParameterSetName='Download')]
    param(
        [Parameter(Mandatory, ParameterSetName='Upload')]
        [Parameter(Mandatory, ParameterSetName='Download')]
        [string]$AccountName,

        [Parameter(Mandatory, ParameterSetName='Upload')]
        [Parameter(Mandatory, ParameterSetName='Download')]
        [string]$Container,

        [Parameter(Mandatory, ParameterSetName='Upload')]
        [Parameter(Mandatory, ParameterSetName='Download')]
        [string]$BlobName,

        [Parameter(Mandatory, ParameterSetName='Upload')]
        [Parameter(Mandatory, ParameterSetName='Download')]
        [string]$Sas,

        [Parameter(Mandatory, ParameterSetName='Upload')]
        [string]$Content,

        [Parameter(Mandatory, ParameterSetName='Upload')]
        [switch]$Upload,

        [Parameter(Mandatory, ParameterSetName='Download')]
        [switch]$Download
    )

    # Build URI (ensure safe ? handling)
    $uri = "https://$AccountName.blob.core.windows.net/$Container/$BlobName`?$Sas"

    try {
        if ($Upload) {
            Invoke-RestMethod `
                -Method Put `
                -Uri $uri `
                -Body $Content `
                -ContentType "text/plain" `
                -Headers @{
                    "x-ms-blob-type" = "BlockBlob"
                    "x-ms-version"   = "2020-10-02"
                } | Out-Null

            return "Upload complete"
        }

        if ($Download) {
            $result = Invoke-RestMethod `
                -Method Get `
                -Uri $uri `
                -Headers @{
                    "x-ms-version" = "2020-10-02"
                }

            return $result
        }
    }
    catch {
        Write-Error ("Blob operation failed: " + $_.Exception.Message)

        # Try to expose storage service response content if present
        if ($_.Exception.Response -and $_.Exception.Response.GetResponseStream()) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $body = $reader.ReadToEnd()
            Write-Error ("Storage Error Response: " + $body)
        }

        throw
    }
}

