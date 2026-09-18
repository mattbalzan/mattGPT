<#
.SYNOPSIS
    Displays a branded shutdown countdown banner on the primary screen.

.DESCRIPTION
    - Borderless, always-on-top banner docked to the bottom-right of the primary screen.
    - Countdown duration and message are supplied as parameters (no need to edit the code).
    - A shrinking green bar gives a visual representation of the time remaining.
    - Win32 SetForegroundWindow is called on Shown to force the banner in front of everything.
    - A built-in default logo is drawn at runtime, or pass your own PNG via -LogoBase64.

.PARAMETER Seconds
    Countdown duration in seconds. Default = 120.

.PARAMETER Message
    Text shown before the HH:MM:SS countdown. Default = "Shutting down in".

.PARAMETER Title
    Window title. Hidden by the borderless style, but used by the taskbar / Alt-Tab.

.PARAMETER LogoBase64
    Optional base64 encoded PNG (60x60 recommended). Omit to use the built-in default logo.

.EXAMPLE
    .\Shutdown popup form counter.ps1

.EXAMPLE
    .\Shutdown popup form counter.ps1 -Seconds 300 -Message "Your device restarts in"

.NOTES
    +------------+---------+---------+--------------------------------------------------------------------------+
    | Date       | Author  | Version | Changes                                                                  |
    |------------+---------+---------+--------------------------------------------------------------------------|
    | 2024-09-10 | mattGPT | 1.0     | Original.                                                                |
    | 2024-09-10 | mattGPT | 1.1     | Changed countdown display to HH:MM:SS.                                   |
    | 2026-09-18 | mattGPT | 1.2     | Reformatted to standard header / section comment blocks.                 |
    |            |         |         | Added Win32 SetForegroundWindow to force the form to the front.          |
    |            |         |         | Added -Seconds / -Message / -Title parameters.                           |
    |            |         |         | Replaced the hard-coded brand logo with a generated default logo,        |
    |            |         |         | overridable with -LogoBase64.                                            |
    +------------+---------+---------+--------------------------------------------------------------------------+
#>
[CmdletBinding()] # Define parameters
param(
    [ValidateRange(1, 86400)]
    [int]$Seconds = 120,

    [string]$Message = "Shutting down in",

    [string]$Title = "Shutdown Countdown",

    [string]$LogoBase64
)

# ------------------- ASSEMBLIES -------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


# ------------------- WIN32 API: FORCE FOREGROUND -------------------
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinAPI {
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@


# ------------------- DEFAULT LOGO -------------------
Function New-DefaultLogo {

    param([int]$Size = 60)

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::LightGreen), 4
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round

    # Power symbol = broken ring plus a vertical stem
    $inset = [int]($Size * 0.25)
    $box   = $Size - ($inset * 2)
    $g.DrawArc($pen, $inset, $inset, $box, $box, -60, 300)
    $g.DrawLine($pen, [int]($Size / 2), [int]($inset * 0.6), [int]($Size / 2), [int]($Size / 2))

    $pen.Dispose()
    $g.Dispose()

    return $bmp
}


# ------------------- LOAD LOGO -------------------
if ([string]::IsNullOrWhiteSpace($LogoBase64)) {
    $icon = New-DefaultLogo -Size 60
}
else {
    $imageBytes = [Convert]::FromBase64String($LogoBase64)
    $ms         = New-Object IO.MemoryStream (, $imageBytes)
    $icon       = [System.Drawing.Image]::FromStream($ms, $true)
}


# ------------------- FORM -------------------
$screen = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea

$form                 = New-Object System.Windows.Forms.Form
$form.Text            = $Title
$form.Width           = 340
$form.Height          = 60
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None   # No minimize, maximize or close
$form.StartPosition   = [System.Windows.Forms.FormStartPosition]::Manual
$form.TopMost         = $true
$form.BackColor       = "#000000"

$xloc = ($screen.Right - $form.Size.Width)     # set to $screen.Left to dock on the left
$yloc = ($screen.Bottom - $form.Size.Height)
$form.Location = New-Object System.Drawing.Point($xloc, $yloc)


# ------------------- CONTROLS -------------------

# Brand logo
$pictureBox          = New-Object Windows.Forms.PictureBox
$pictureBox.Width    = $icon.Size.Width
$pictureBox.Height   = $icon.Size.Height
$pictureBox.Image    = $icon
$pictureBox.Location = New-Object System.Drawing.Point (0, 0)

# Progress bar - a read-only TextBox that shrinks as the time runs out
$initialTextBoxWidth = 260

$progBar             = New-Object System.Windows.Forms.TextBox
$progBar.BorderStyle = 0
$progBar.Width       = $initialTextBoxWidth
$progBar.Height      = 40
$progBar.BackColor   = "LightGreen"
$progBar.Top         = 50
$progBar.Left        = 60
$progBar.ReadOnly    = $true
$progBar.Multiline   = $false

# Remaining time label
$countdownLabel           = New-Object System.Windows.Forms.Label
$countdownLabel.Width     = 260
$countdownLabel.Height    = 20
$countdownLabel.TextAlign = 'MiddleLeft'
$countdownLabel.Top       = 20
$countdownLabel.Left      = 70
$countdownLabel.Font      = New-Object System.Drawing.Font("APTOS", 11)
$countdownLabel.ForeColor = "#FFFFFF"

$form.Controls.AddRange(@($pictureBox, $progBar, $countdownLabel))


# ------------------- BRING TO FRONT -------------------
$form.Add_Shown({
    $form.Activate()
    $form.BringToFront()
    Start-Sleep -Milliseconds 200
    [void][WinAPI]::SetForegroundWindow($form.Handle)
})


# ------------------- COUNTDOWN -------------------
$interval = 1   # seconds between updates

$form.Add_Shown({

    for ($i = $Seconds; $i -ge 0; $i--) {

        # Calculate hours, minutes and seconds
        $hours   = [math]::Floor($i / 3600)
        $minutes = [math]::Floor(($i % 3600) / 60)
        $secs    = $i % 60

        # Format the countdown as HH:MM:SS
        $timeString = "{0}:{1}:{2}" -f $hours.ToString("00"), $minutes.ToString("00"), $secs.ToString("00")

        $countdownLabel.Text = "$Message $timeString"
        $form.Refresh()

        # Shrink the bar proportionally, never below zero
        $newWidth      = $initialTextBoxWidth * ($i / $Seconds)
        $progBar.Width = [Math]::Max([int]$newWidth, 0)

        Start-Sleep -Seconds $interval
        $form.Refresh()
    }

    $form.Close()


    # ------------------- ACTION -------------------
    # Uncomment the line you need

    # Restart the device
    #Restart-Computer -Force

    # Or restart the Intune management service
    #Restart-Service -Name IntuneManagementExtension -Force
})


# ------------------- DISPLAY -------------------
[void]$form.ShowDialog()

# ------------------- END OF SCRIPT -------------------
