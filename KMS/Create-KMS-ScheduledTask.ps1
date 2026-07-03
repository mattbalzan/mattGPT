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
