This is a PowerShell-first KMS activation monitoring dashboard that runs directly on the KMS Host and exports:

KMS_ActivationEvents.csv
KMS_DeviceLastSeen.csv
KMS_ProductSummary.csv
KMS_Dashboard.html

It uses the Key Management Service event log because Microsoft states KMS host requests are logged there, specifically event 12290, and that organizations should periodically export the Key Management Service log if they use event logs to track or document KMS activations. Microsoft also documents that KMS troubleshooting normally involves checking both slmgr.vbs /dlv and event logs from the KMS host and clients.

PowerShell: KMS HTML Dashboard Generator

Save as:

C:\Scripts\New-KMSDashboard.ps1


Run it on the KMS Host
PowerShell.exe -ExecutionPolicy Bypass -File C:\Scripts\New-KMSDashboard.ps1


Example with a shorter lookback window:

PowerShell.exe -ExecutionPolicy Bypass -File C:\Scripts\New-KMSDashboard.ps1 -DaysBack 90


Example for their radio-silence risk thresholds:

PowerShell.exe -ExecutionPolicy Bypass -File C:\Scripts\New-KMSDashboard.ps1 `
  -DaysBack 210 `
  -WarningDays 120 `
  -CriticalDays 170

What this dashboard gives them
1. Which devices are connecting to the KMS server

The script groups by parsed client name or CMID where present in the KMS event message. Microsoft’s KMS troubleshooting guidance says the KMS host event log should be checked for event 12290 and to verify that the KMS client computer name is listed.

2. Which Microsoft products are being activated

The script extracts product name where available, otherwise it falls back to Activation ID. Microsoft’s activation event reference includes Activation ID as a field used to identify the license.

3. When activation requests are occurring

The script uses the event TimeCreated value and builds a daily trend chart. Microsoft documents that KMS activation troubleshooting uses event logs from the KMS host and clients.

4. Radio-silence risk

It flags devices not seen for configurable periods, defaulting to:

Status	Default thresholdOK	Seen within 90 days
Warning	Not seen for 90+ days
Critical	Not seen for 150+ days

That lines up with your operational concern around nodes potentially being away from the KMS host for extended periods. Your own offline KMS guide notes renewal occurs every 7 days and lease validity is 180 days.

Operational recommendation

For the customer, I’d schedule this locally on the KMS Host and export the output to a protected share:

$Action = New-ScheduledTaskAction `
  -Execute "PowerShell.exe" `
  -Argument "-ExecutionPolicy Bypass -File C:\Scripts\New-KMSDashboard.ps1 -DaysBack 210 -WarningDays 120 -CriticalDays 170"

$Trigger = New-ScheduledTaskTrigger -Daily -At 06:00

Register-ScheduledTask `
  -TaskName "Generate KMS Activation Dashboard" `
  -Action $Action `
  -Trigger $Trigger `
  -Description "Generates KMS activation monitoring CSV and HTML dashboard" `
  -RunLevel Highest


One caveat: KMS event message formatting can vary slightly between Windows/Office activation components, so I’ve built the parser defensively and preserved the raw message in the CSV for audit/debugging.
