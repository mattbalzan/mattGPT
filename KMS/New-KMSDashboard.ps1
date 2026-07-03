<#
.SYNOPSIS
    Generates a CSV and HTML dashboard for KMS activation monitoring.

.DESCRIPTION
    Runs on the KMS Host.
    Reads the "Key Management Service" event log.
    Extracts activation request details where available.
    Produces CSV files and an HTML dashboard showing:
        - Devices contacting KMS
        - Products / Activation IDs being requested
        - Success / failure status
        - Last seen device date
        - Devices not seen recently
        - Event trend by day

.NOTES
    Author: Matt-friendly Copilot version
    PowerShell: 5.1+
    Run as Administrator on the KMS Host.

    Microsoft references:
      - KMS host event ID 12290 records requests from KMS clients.
      - KMS client event IDs 12288/12289 relate to request/response processing.
      - KMS activation logging is stored in the Key Management Service event log.
#>

[CmdletBinding()]
param(
    [string]$OutputPath = "C:\Temp\KMSDashboard",

    [int]$DaysBack = 180,

    [int]$WarningDays = 90,

    [int]$CriticalDays = 150,

    [string]$KmsLogName = "Key Management Service"
)

# -----------------------------
# Setup
# -----------------------------

$ErrorActionPreference = "Stop"

if (-not (Test-Path -Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

$Now = Get-Date
$StartTime = $Now.AddDays(-$DaysBack)

$EventCsvPath      = Join-Path $OutputPath "KMS_ActivationEvents.csv"
$DeviceCsvPath     = Join-Path $OutputPath "KMS_DeviceLastSeen.csv"
$ProductCsvPath    = Join-Path $OutputPath "KMS_ProductSummary.csv"
$HtmlPath          = Join-Path $OutputPath "KMS_Dashboard.html"
$RawEventExport    = Join-Path $OutputPath "KMS_RawEvents.evtx"
$FailurePath       = Join-Path $OutputPath "KMS_Dashboard_Errors.txt"

# -----------------------------
# Helper functions
# -----------------------------

function ConvertTo-KmsStatusText {
    param([string]$Value)

    switch ($Value) {
        "0" { "Unlicensed" }
        "1" { "Licensed" }
        "2" { "OOB Grace" }
        "3" { "OOT Grace" }
        "4" { "Non-Genuine Grace" }
        "5" { "Notification" }
        "6" { "Extended Grace" }
        default { $Value }
    }
}

function Get-RegexValue {
    param(
        [string]$Text,
        [string[]]$Patterns
    )

    foreach ($Pattern in $Patterns) {
        $Match = [regex\]::Match($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions\]::IgnoreCase)
        if ($Match.Success -and $Match.Groups.Count -gt 1) {
            return ($Match.Groups[1].Value.Trim())
        }
    }

    return $null
}

function ConvertTo-SafeHtml {
    param([string]$Text)

    if ($null -eq $Text) {
        return ""
    }

    return [System.Net.WebUtility\]::HtmlEncode($Text)
}

function Get-KmsHostDlv {
    $Result = [ordered]@{
        RawOutput       = $null
        CurrentCount    = $null
        ListeningPort   = $null
        LicenseStatus   = $null
        Description     = $null
        PartialKey      = $null
    }

    try {
        $Output = & cscript.exe //nologo "$env:windir\System32\slmgr.vbs" /dlv 2>&1
        $Text = ($Output -join "`n")
        $Result.RawOutput = $Text

        $Result.CurrentCount = Get-RegexValue -Text $Text -Patterns @(
            "Current count:\s*(\d+)",
            "Current Count:\s*(\d+)"
        )

        $Result.ListeningPort = Get-RegexValue -Text $Text -Patterns @(
            "Listening on Port:\s*(\d+)",
            "Key Management Service listening on port:\s*(\d+)"
        )

        $Result.LicenseStatus = Get-RegexValue -Text $Text -Patterns @(
            "License Status:\s*([^\r\n]+)"
        )

        $Result.Description = Get-RegexValue -Text $Text -Patterns @(
            "Description:\s*([^\r\n]+)"
        )

        $Result.PartialKey = Get-RegexValue -Text $Text -Patterns @(
            "Partial Product Key:\s*([A-Z0-9]+)"
        )
    }
    catch {
        $Result.RawOutput = "Failed to run slmgr.vbs /dlv. $($_.Exception.Message)"
    }

    [pscustomobject]$Result
}

function Parse-KmsEvent {
    param(
        [System.Diagnostics.Eventing.Reader.EventRecord]$Event
    )

    $Message = $Event.Message

    # KMS event data can vary slightly between OS / product versions.
    # These regex patterns intentionally support multiple common formats.

    $ClientName = Get-RegexValue -Text $Message -Patterns @(
        "Client Machine Name:\s*([^\r\n,]+)",
        "Machine Name:\s*([^\r\n,]+)",
        "Machine:\s*([^\r\n,]+)",
        "Name:\s*([A-Za-z0-9\.\-_]+)"
    )

    $CMID = Get-RegexValue -Text $Message -Patterns @(
        "CMID:\s*([0-9a-fA-F\-]{36})",
        "Client Machine ID:\s*([0-9a-fA-F\-]{36})",
        "([0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12})"
    )

    $ActivationId = Get-RegexValue -Text $Message -Patterns @(
        "Activation ID:\s*([0-9a-fA-F\-]{36})",
        "ActID:\s*([0-9a-fA-F\-]{36})"
    )

    $ApplicationId = Get-RegexValue -Text $Message -Patterns @(
        "Application ID:\s*([0-9a-fA-F\-]{36})",
        "AppID:\s*([0-9a-fA-F\-]{36})"
    )

    $ProductName = Get-RegexValue -Text $Message -Patterns @(
        "License Family:\s*([^\r\n,]+)",
        "Product Name:\s*([^\r\n,]+)",
        "SKU:\s*([^\r\n,]+)"
    )

    $ResultCode = Get-RegexValue -Text $Message -Patterns @(
        "HRESULT:\s*(0x[0-9a-fA-F]+)",
        "Result Code:\s*(0x[0-9a-fA-F]+)",
        "Error Code:\s*(0x[0-9a-fA-F]+)"
    )

    $LicenseStatusRaw = Get-RegexValue -Text $Message -Patterns @(
        "License Status:\s*(\d+)",
        "Status:\s*(\d+)"
    )

    $KmsCurrentCount = Get-RegexValue -Text $Message -Patterns @(
        "Current Count:\s*(\d+)",
        "KMS current count\s*(\d+)",
        "Count:\s*(\d+)"
    )

    $ActivatedFlag = Get-RegexValue -Text $Message -Patterns @(
        "Activation Flag:\s*(\d+)",
        "Activated flag\s*(\d+)",
        "fBound:\s*(\d+)"
    )

    $ClientTime = Get-RegexValue -Text $Message -Patterns @(
        "Client Time:\s*([^\r\n,]+)",
        "Request timestamp:\s*([^\r\n,]+)"
    )

    $ServerPort = Get-RegexValue -Text $Message -Patterns @(
        "Server:Port\s*([A-Za-z0-9\.\-_]+:\d+)",
        "([A-Za-z0-9\.\-_]+:1688)"
    )

    $Success = $false
    if ($ResultCode -eq "0x0" -or $ActivatedFlag -eq "1") {
        $Success = $true
    }

    # Event ID 12290 on the host indicates a KMS host processed a client request.
    # If fields are not parseable, still preserve the raw message.
    [pscustomobject]@{
        TimeCreated       = $Event.TimeCreated
        EventId           = $Event.Id
        ProviderName      = $Event.ProviderName
        Level             = $Event.LevelDisplayName
        ClientName        = $ClientName
        CMID              = $CMID
        ProductName       = $ProductName
        ActivationId      = $ActivationId
        ApplicationId     = $ApplicationId
        ResultCode        = $ResultCode
        Success           = $Success
        LicenseStatus     = ConvertTo-KmsStatusText -Value $LicenseStatusRaw
        LicenseStatusRaw  = $LicenseStatusRaw
        KmsCurrentCount   = $KmsCurrentCount
        ServerPort        = $ServerPort
        ClientTime        = $ClientTime
        Message           = $Message
    }
}

# -----------------------------
# Collect KMS events
# -----------------------------

try {
    Write-Host "Collecting KMS events from '$KmsLogName' since $StartTime ..." -ForegroundColor Cyan

    $Events = Get-WinEvent -FilterHashtable @{
        LogName   = $KmsLogName
        StartTime = $StartTime
    } -ErrorAction Stop

    # Export raw event log as evidence
    try {
        wevtutil epl "$KmsLogName" "$RawEventExport" "/q:*[System[TimeCreated[timediff(@SystemTime) <= $($DaysBack * 24 * 60 * 60 * 1000)]]]" 2>$null
    }
    catch {
        "Raw EVTX export failed: $($_.Exception.Message)" | Out-File -FilePath $FailurePath -Append -Encoding UTF8
    }
}
catch {
    $Message = @"
Failed to read the '$KmsLogName' event log.

Error:
$($_.Exception.Message)

Confirm the script is running on the KMS Host as Administrator.
"@

    $Message | Out-File -FilePath $FailurePath -Encoding UTF8
    throw $Message
}

$ParsedEvents = foreach ($Event in $Events) {
    Parse-KmsEvent -Event $Event
}

$ParsedEvents = $ParsedEvents | Sort-Object TimeCreated -Descending

# -----------------------------
# Summaries
# -----------------------------

$KmsHostDlv = Get-KmsHostDlv

$DeviceSummary =
    $ParsedEvents |
    Where-Object { $_.ClientName -or $_.CMID } |
    Group-Object @{Expression = {
        if ($_.ClientName) {
            $_.ClientName
        }
        elseif ($_.CMID) {
            $_.CMID
        }
        else {
            "Unknown"
        }
    }} |
    ForEach-Object {
        $Rows = $_.Group
        $Last = $Rows | Sort-Object TimeCreated -Descending | Select-Object -First 1
        $First = $Rows | Sort-Object TimeCreated | Select-Object -First 1
        $DaysSinceSeen = [math\]::Round(($Now - $Last.TimeCreated).TotalDays, 1)

        $Health =
            if ($DaysSinceSeen -ge $CriticalDays) { "Critical" }
            elseif ($DaysSinceSeen -ge $WarningDays) { "Warning" }
            else { "OK" }

        [pscustomobject]@{
            DeviceOrCMID       = $_.Name
            LastSeen           = $Last.TimeCreated
            FirstSeen          = $First.TimeCreated
            DaysSinceSeen      = $DaysSinceSeen
            Health             = $Health
            RequestCount       = $Rows.Count
            LastProductName    = $Last.ProductName
            LastActivationId   = $Last.ActivationId
            LastResultCode     = $Last.ResultCode
            LastSuccess        = $Last.Success
            LastLicenseStatus  = $Last.LicenseStatus
            CMID               = $Last.CMID
        }
    } |
    Sort-Object DaysSinceSeen -Descending

$ProductSummary =
    $ParsedEvents |
    Group-Object @{Expression = {
        if ($_.ProductName) {
            $_.ProductName
        }
        elseif ($_.ActivationId) {
            "ActivationId: $($_.ActivationId)"
        }
        else {
            "Unknown product / activation ID"
        }
    }} |
    ForEach-Object {
        $Rows = $_.Group
        $Last = $Rows | Sort-Object TimeCreated -Descending | Select-Object -First 1

        [pscustomobject]@{
            ProductOrActivationId = $_.Name
            RequestCount          = $Rows.Count
            LastSeen              = $Last.TimeCreated
            SuccessCount          = ($Rows | Where-Object { $_.Success }).Count
            FailureCount          = ($Rows | Where-Object { -not $_.Success }).Count
        }
    } |
    Sort-Object RequestCount -Descending

$DailyTrend =
    $ParsedEvents |
    Group-Object @{Expression = { $_.TimeCreated.ToString("yyyy-MM-dd") }} |
    Sort-Object Name |
    ForEach-Object {
        [pscustomobject]@{
            Date         = $_.Name
            Requests     = $_.Count
            SuccessCount = ($_.Group | Where-Object { $_.Success }).Count
            FailureCount = ($_.Group | Where-Object { -not $_.Success }).Count
        }
    }

# -----------------------------
# Export CSV
# -----------------------------

$ParsedEvents |
    Select-Object TimeCreated, EventId, Level, ClientName, CMID, ProductName, ActivationId, ApplicationId, ResultCode, Success, LicenseStatus, KmsCurrentCount, ServerPort, ClientTime, Message |
    Export-Csv -Path $EventCsvPath -NoTypeInformation -Encoding UTF8

$DeviceSummary |
    Export-Csv -Path $DeviceCsvPath -NoTypeInformation -Encoding UTF8

$ProductSummary |
    Export-Csv -Path $ProductCsvPath -NoTypeInformation -Encoding UTF8

# -----------------------------
# HTML rendering helpers
# -----------------------------

function New-HtmlTable {
    param(
        [object[]]$Data,
        [string]$EmptyMessage = "No data found."
    )

    if (-not $Data -or $Data.Count -eq 0) {
        return "<p class='muted'>$EmptyMessage</p>"
    }

    $Properties = $Data[0].PSObject.Properties.Name

    $Html = "<table><thead><tr>"
    foreach ($Prop in $Properties) {
        $Html += "<th>$(ConvertTo-SafeHtml $Prop)</th>"
    }
    $Html += "</tr></thead><tbody>"

    foreach ($Row in $Data) {
        $RowClass = ""

        if ($Row.PSObject.Properties.Name -contains "Health") {
            if ($Row.Health -eq "Critical") { $RowClass = "criticalRow" }
            elseif ($Row.Health -eq "Warning") { $RowClass = "warningRow" }
        }

        $Html += "<tr class='$RowClass'>"

        foreach ($Prop in $Properties) {
            $Value = $Row.$Prop

            if ($Value -is [datetime]) {
                $Value = $Value.ToString("yyyy-MM-dd HH:mm:ss")
            }

            $Css = ""

            if ($Prop -eq "Health") {
                if ($Value -eq "Critical") { $Css = "badge critical" }
                elseif ($Value -eq "Warning") { $Css = "badge warning" }
                elseif ($Value -eq "OK") { $Css = "badge ok" }
            }

            if ($Css) {
                $Html += "<td><span class='$Css'>$(ConvertTo-SafeHtml ([string]$Value))</span></td>"
            }
            else {
                $Html += "<td>$(ConvertTo-SafeHtml ([string]$Value))</td>"
            }
        }

        $Html += "</tr>"
    }

    $Html += "</tbody></table>"
    return $Html
}

function New-BarChartHtml {
    param(
        [object[]]$Trend
    )

    if (-not $Trend -or $Trend.Count -eq 0) {
        return "<p class='muted'>No trend data available.</p>"
    }

    $Max = ($Trend | Measure-Object -Property Requests -Maximum).Maximum
    if (-not $Max -or $Max -lt 1) { $Max = 1 }

    $Html = "<div class='chart'>"

    foreach ($Point in $Trend) {
        $Height = [math\]::Max(4, [math\]::Round(($Point.Requests / $Max) * 160))
        $Title = "$($Point.Date): $($Point.Requests) requests"
        $Html += @"
<div class="barWrapper" title="$(ConvertTo-SafeHtml $Title)">
    <div class="bar" style="height:${Height}px;"></div>
    <div class="barLabel">$($Point.Date.Substring(5))</div>
</div>
"@
    }

    $Html += "</div>"
    return $Html
}

# -----------------------------
# Build HTML dashboard
# -----------------------------

$TotalEvents       = $ParsedEvents.Count
$UniqueDevices    = ($DeviceSummary | Measure-Object).Count
$UniqueProducts   = ($ProductSummary | Measure-Object).Count
$SuccessCount     = ($ParsedEvents | Where-Object { $_.Success }).Count
$FailureCount     = ($ParsedEvents | Where-Object { -not $_.Success }).Count
$WarningCount     = ($DeviceSummary | Where-Object { $_.Health -eq "Warning" }).Count
$CriticalCount    = ($DeviceSummary | Where-Object { $_.Health -eq "Critical" }).Count
$LastEvent        = $ParsedEvents | Sort-Object TimeCreated -Descending | Select-Object -First 1

$TopDevices =
    $DeviceSummary |
    Sort-Object RequestCount -Descending |
    Select-Object -First 20 DeviceOrCMID, RequestCount, LastSeen, DaysSinceSeen, Health, LastProductName, LastResultCode, LastSuccess

$AtRiskDevices =
    $DeviceSummary |
    Where-Object { $_.Health -ne "OK" } |
    Select-Object DeviceOrCMID, LastSeen, DaysSinceSeen, Health, RequestCount, LastProductName, LastResultCode

$RecentEvents =
    $ParsedEvents |
    Select-Object -First 100 TimeCreated, EventId, ClientName, CMID, ProductName, ActivationId, ResultCode, Success, LicenseStatus, KmsCurrentCount

$Css = @"
<style>
    body {
        font-family: "Segoe UI", Arial, sans-serif;
        background: #f6f8fb;
        color: #1f2937;
        margin: 0;
        padding: 0;
    }

    header {
        background: linear-gradient(135deg, #1b4d89, #2563eb);
        color: white;
        padding: 28px 36px;
    }

    header h1 {
        margin: 0;
        font-size: 28px;
        font-weight: 650;
    }

    header p {
        margin: 8px 0 0 0;
        color: #dbeafe;
    }

    main {
        padding: 24px 36px 42px 36px;
    }

    .grid {
        display: grid;
        grid-template-columns: repeat(4, minmax(180px, 1fr));
        gap: 16px;
        margin-bottom: 22px;
    }

    .card {
        background: white;
        border: 1px solid #e5e7eb;
        border-radius: 14px;
        padding: 16px;
        box-shadow: 0 4px 14px rgba(15, 23, 42, 0.06);
    }

    .card h2 {
        margin: 0 0 12px 0;
        font-size: 18px;
        color: #111827;
    }

    .metricLabel {
        font-size: 13px;
        color: #6b7280;
        margin-bottom: 6px;
    }

    .metric {
        font-size: 30px;
        font-weight: 700;
        color: #111827;
    }

    .metricSmall {
        font-size: 13px;
        color: #6b7280;
        margin-top: 5px;
    }

    table {
        width: 100%;
        border-collapse: collapse;
        margin-top: 6px;
        font-size: 13px;
    }

    th {
        text-align: left;
        background: #eef2ff;
        color: #1f2937;
        border-bottom: 1px solid #c7d2fe;
        padding: 8px;
        position: sticky;
        top: 0;
        z-index: 1;
    }

    td {
        border-bottom: 1px solid #edf2f7;
        padding: 8px;
        vertical-align: top;
    }

    tr:hover {
        background: #f9fafb;
    }

    .tableWrap {
        max-height: 520px;
        overflow: auto;
        border: 1px solid #e5e7eb;
        border-radius: 10px;
    }

    .badge {
        display: inline-block;
        padding: 3px 8px;
        border-radius: 999px;
        font-size: 12px;
        font-weight: 650;
    }

    .ok {
        color: #065f46;
        background: #d1fae5;
    }

    .warning {
        color: #92400e;
        background: #fef3c7;
    }

    .critical {
        color: #991b1b;
        background: #fee2e2;
    }

    .warningRow {
        background: #fffbeb;
    }

    .criticalRow {
        background: #fef2f2;
    }

    .muted {
        color: #6b7280;
    }

    .chart {
        display: flex;
        gap: 6px;
        align-items: flex-end;
        min-height: 190px;
        overflow-x: auto;
        padding: 12px 6px 4px 6px;
        border: 1px solid #e5e7eb;
        border-radius: 10px;
        background: #fbfdff;
    }

    .barWrapper {
        width: 28px;
        text-align: center;
        flex: 0 0 auto;
    }

    .bar {
        width: 18px;
        margin: 0 auto;
        background: #2563eb;
        border-radius: 6px 6px 0 0;
    }

    .barLabel {
        font-size: 10px;
        color: #6b7280;
        transform: rotate(-45deg);
        margin-top: 12px;
        white-space: nowrap;
    }

    .twoCol {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 16px;
        margin-bottom: 18px;
    }

    .section {
        margin-bottom: 18px;
    }

    pre {
        white-space: pre-wrap;
        word-break: break-word;
        background: #111827;
        color: #e5e7eb;
        padding: 14px;
        border-radius: 10px;
        max-height: 300px;
        overflow: auto;
    }

    footer {
        padding: 18px 36px;
        color: #6b7280;
        font-size: 12px;
    }

    @media print {
        .tableWrap {
            max-height: none;
            overflow: visible;
        }

        header {
            background: #1b4d89 !important;
            print-color-adjust: exact;
        }
    }
</style>
"@

$TrendChartHtml = New-BarChartHtml -Trend $DailyTrend

$HostSummaryTable = New-HtmlTable -Data @(
    [pscustomobject]@{
        KmsHost                  = $env:COMPUTERNAME
        ReportGenerated          = $Now
        DaysBack                 = $DaysBack
        CurrentCountFromSlmgr    = $KmsHostDlv.CurrentCount
        ListeningPortFromSlmgr   = $KmsHostDlv.ListeningPort
        HostLicenseStatus        = $KmsHostDlv.LicenseStatus
        HostDescription          = $KmsHostDlv.Description
        HostPartialProductKey    = $KmsHostDlv.PartialKey
    }
)

$Html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<title>KMS Activation Dashboard</title>
$Css
</head>
<body>
<header>
    <h1>KMS Activation Monitoring Dashboard</h1>
    <p>KMS Host: $env:COMPUTERNAME | Generated: $($Now.ToString("yyyy-MM-dd HH:mm:ss")) | Event window: last $DaysBack days</p>
</header>

<main>
    <section class="grid">
        <div class="card">
            <div class="metricLabel">Total KMS Events</div>
            <div class="metric">$TotalEvents</div>
            <div class="metricSmall">From '$KmsLogName'</div>
        </div>
        <div class="card">
            <div class="metricLabel">Unique Devices / CMIDs</div>
            <div class="metric">$UniqueDevices</div>
            <div class="metricSmall">Based on parsed client name or CMID</div>
        </div>
        <div class="card">
            <div class="metricLabel">Products / Activation IDs</div>
            <div class="metric">$UniqueProducts</div>
            <div class="metricSmall">Based on product or activation ID</div>
        </div>
        <div class="card">
            <div class="metricLabel">At-Risk Devices</div>
            <div class="metric">$($WarningCount + $CriticalCount)</div>
            <div class="metricSmall">Warning: $WarningCount | Critical: $CriticalCount</div>
        </div>
    </section>

    <section class="twoCol">
        <div class="card">
            <h2>KMS Host Summary</h2>
            $HostSummaryTable
        </div>
        <div class="card">
            <h2>Activation Outcome Summary</h2>
            $(New-HtmlTable -Data @(
                [pscustomobject]@{
                    SuccessEvents = $SuccessCount
                    NonSuccessEvents = $FailureCount
                    LastEventTime = if ($LastEvent) { $LastEvent.TimeCreated } else { $null }
                    LastEventId = if ($LastEvent) { $LastEvent.EventId } else { $null }
                }
            ))
        </div>
    </section>

    <section class="card section">
        <h2>Activation Request Trend by Day</h2>
        $TrendChartHtml
    </section>

    <section class="card section">
        <h2>Devices Not Seen Recently</h2>
        <p class="muted">Warning threshold: $WarningDays days. Critical threshold: $CriticalDays days.</p>
        <div class="tableWrap">
            $(New-HtmlTable -Data $AtRiskDevices -EmptyMessage "No devices breached the configured thresholds.")
        </div>
    </section>

    <section class="card section">
        <h2>Top Devices by Activation Requests</h2>
        <div class="tableWrap">
            $(New-HtmlTable -Data $TopDevices)
        </div>
    </section>

    <section class="card section">
        <h2>Product / Activation ID Summary</h2>
        <div class="tableWrap">
            $(New-HtmlTable -Data $ProductSummary)
        </div>
    </section>

    <section class="card section">
        <h2>Recent KMS Events</h2>
        <div class="tableWrap">
            $(New-HtmlTable -Data $RecentEvents)
        </div>
    </section>

    <section class="card section">
        <h2>Generated Files</h2>
        <table>
            <tr><th>File</th><th>Path</th></tr>
            <tr><td>Event CSV</td><td>$EventCsvPath</td></tr>
            <tr><td>Device Last Seen CSV</td><td>$DeviceCsvPath</td></tr>
            <tr><td>Product Summary CSV</td><td>$ProductCsvPath</td></tr>
            <tr><td>Raw EVTX Export</td><td>$RawEventExport</td></tr>
            <tr><td>HTML Dashboard</td><td>$HtmlPath</td></tr>
        </table>
    </section>
</main>

<footer>
    Dashboard generated locally from the KMS Host event log. Parsing depends on fields present in the event message for the installed Windows / Office activation components.
</footer>
</body>
</html>
"@

$Html | Out-File -FilePath $HtmlPath -Encoding UTF8
board generated successfully." -ForegroundColor Green
Write-Host "HTML : $HtmlPath" -ForegroundColor Cyan
Write-Host "CSV  : $EventCsvPath" -ForegroundColor Cyan
Write-Host "CSV  : $DeviceCsvPath" -ForegroundColor Cyan
Write-Host "CSV  : $ProductCsvPath" -ForegroundColor Cyan
Write-Host "EVTX : $RawEventExport" -ForegroundColor Cyan
