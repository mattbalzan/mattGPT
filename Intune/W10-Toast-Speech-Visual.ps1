# --[ Load UI assembly ]
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
$null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

Add-Type -AssemblyName System.speech


# --[ Customise your title/message ]
$title    = "CONTOSO EVIL CORP"
$message  = "Don't bother rebooting your device. We're firing you."

# --[ Setup Toast message ]
$toastXml = [Windows.Data.Xml.Dom.XmlDocument]::new()

$xmlString = @"
  <toast launch = "Test1" scenario='alarm'>
    <visual>
      <binding template="ToastGeneric">
        <text>$title</text>
        <text>$message</text>
        <image id="1" src="C:\Scripts\badgeimage.jpg" />
      </binding>
    </visual>
    <actions>
        <action content="Sure" arguments="yes" />
        <action content="WTF !?"  arguments="no"  />
    </actions>
  </toast>
"@

$toastXml.LoadXml($XmlString)
$toast = [Windows.UI.Notifications.ToastNotification]::new($toastXml)
$appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
$notify = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId)

# --[ Get event handles ]
$Action1Script = { Write-Host "User selected: Remind me later" }
$Action2Script = { Write-Host "User selected: Reboot" }

<#
$Toast.Activated.add({
        
          if ($_ -eq "yes") {
            Invoke-Command -ScriptBlock $Action1Script
        } elseif ($_ -eq "no") {
            Invoke-Command -ScriptBlock $Action2Script
        }
    })
#>



# --[ Show the message ]
$notify.Show($toast)

# --[ Covering all bases, we can also play the message for Accessibility scenarios ]
([System.Speech.Synthesis.SpeechSynthesizer]::New()).Speak("Attention! Message from EVIL CORP, Don't bother rebooting your device, we're firing you.")
