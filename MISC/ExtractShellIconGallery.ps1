<#
.SYNOPSIS
    Windows Icons | Extract icons from common DLLs/EXEs and generate an HTML gallery.

.DESCRIPTION
    - Extracts icons from multiple Windows DLLs (e.g. shell32.dll, imageres.dll, ddores.dll, moricons.dll).
    - Saves icons into DLL-specific subfolders under C:\ExtractedIcons.
    - Automatically generates an HTML gallery with sectioned icon previews per DLL.
    - Clicking an icon updates a PowerShell shortcut creation example with the correct DLL path + icon index.
    - Includes a Copy to Clipboard button (shown only after an icon is clicked).

.NOTES
    +------------+---------+---------+------------------------------------------------------------+
    | Date       | Author  | Version | Changes                                                    |
    |------------+---------+---------+------------------------------------------------------------|
    | 2025-10-02 | mattGPT | 1.0     | Initial version: Extract multiple DLL icons + HTML gallery |
    +------------+---------+---------+------------------------------------------------------------+
#>

# -------------------------------
# Extract icons from DLL/EXE
# -------------------------------
$dllSources = @(
    "$env:SystemRoot\System32\shell32.dll",
    "$env:SystemRoot\System32\imageres.dll",
    "$env:SystemRoot\System32\ddores.dll",
    "$env:SystemRoot\System32\setupapi.dll",
    "$env:SystemRoot\System32\stobject.dll",
    "$env:SystemRoot\System32\mshtml.dll",
    "$env:SystemRoot\System32\Taskmgr.exe"
)

$baseFolder = "C:\ExtractedIcons"
New-Item -ItemType Directory -Force -Path $baseFolder | Out-Null

# Load WinAPI functions (once only)
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;

public class Win32 {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr DestroyIcon(IntPtr handle);

    [DllImport("shell32.dll", CharSet = CharSet.Auto)]
    public static extern int ExtractIconEx(
        string lpszFile,
        int nIconIndex,
        IntPtr[] phiconLarge,
        IntPtr[] phiconSmall,
        int nIcons
    );
}
"@ -IgnoreWarnings

foreach ($dllPath in $dllSources) {
    $dllName = [System.IO.Path]::GetFileNameWithoutExtension($dllPath)
    $iconsFolder = Join-Path $baseFolder $dllName
    New-Item -ItemType Directory -Force -Path $iconsFolder | Out-Null

    # Count total icons
    $totalIcons = [Win32]::ExtractIconEx($dllPath, -1, $null, $null, 0)
    Write-Host "Extracting $totalIcons icons from $dllName.dll ..."

    for ($i = 0; $i -lt $totalIcons; $i++) {
        $hIcon = New-Object IntPtr[] 1
        [Win32]::ExtractIconEx($dllPath, $i, $hIcon, $null, 1) | Out-Null
        if ($hIcon[0] -ne [IntPtr]::Zero) {
            $icon = [System.Drawing.Icon]::FromHandle($hIcon[0])
            $bitmap = $icon.ToBitmap()
            $file = Join-Path $iconsFolder "$i.png"
            $bitmap.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
            [Win32]::DestroyIcon($hIcon[0])
        }
    }
}
$outputHtml = Join-Path $baseFolder "IconGallery.html"

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Windows Icon Gallery - [mattGPT]</title>
<style>
body { font-family: Arial, sans-serif; background: #f0f0f0; margin: 0; padding: 0; }
h1 { text-align: center; padding-top: 20px; }
h2 { margin-left: 30px; margin-top: 30px; }
#example-container { background: #222; color: #fff; padding: 20px; margin: 20px auto; width: 80%; border-radius: 10px; font-family: Consolas, monospace; }
#example { white-space: pre; }
#copyBtn { display: none; margin-top: 10px; padding: 5px 10px; cursor: pointer; border-radius: 5px; border: none; background: #4CAF50; color: white; font-weight: bold; }
.gallery { display: flex; flex-wrap: wrap; gap: 10px; justify-content: flex-start; padding: 20px; }
.icon-card { background: #fff; border-radius: 10px; padding: 10px; text-align: center; width: 100px; cursor: pointer; box-shadow: 0 2px 5px rgba(0,0,0,0.2); transition: transform 0.1s; }
.icon-card:hover { transform: scale(1.1); }
.icon-card img { width: 64px; height: 64px; }
.icon-card span { display: block; margin-top: 5px; font-size: 12px; }
</style>
</head>
<body>
<h1>Windows Icon Gallery - [mattGPT]</h1>

<div id="example-container">
<div id="example"># Click on any icon to view a PowerShell example to create a shortcut</div>
<button id="copyBtn" onclick="copyExample()">Copy to Clipboard</button>
</div>
"@

# Loop through DLL folders and create a section for each
foreach ($dllPath in $dllSources) {
    $dllName = [System.IO.Path]::GetFileNameWithoutExtension($dllPath)
    $iconsFolder = Join-Path $baseFolder $dllName
    $icons = Get-ChildItem -Path $iconsFolder -Filter "*.png" |
             Sort-Object {[int]([System.IO.Path]::GetFileNameWithoutExtension($_.Name))}

    $html += "<h2>$dllName.dll</h2><div class='gallery'>`n"

    foreach ($icon in $icons) {
        $iconPath = $icon.FullName.Replace("\","\\")
        $iconIndex = [System.IO.Path]::GetFileNameWithoutExtension($icon.Name)
        $html += "<div class='icon-card' onclick='updateExample(`"$iconPath`",$iconIndex)'><img src='file:///$iconPath' alt='$iconIndex'><span>Icon Index: $iconIndex</span></div>`n"
    }

    $html += "</div>`n"
}

$html += @"
<script>

function updateExample(iconPath, iconIndex) {
    const exampleDiv = document.getElementById('example');
    const copyBtn = document.getElementById('copyBtn');
    copyBtn.style.display = 'inline-block'; // show button on first click
    
    exampleDiv.innerText = [
        '# PowerShell example to create a shortcut',
        '`$wsh = New-Object -ComObject WScript.Shell',
        '`$shortcut = `$wsh.CreateShortcut("\`$env:USERPROFILE\\Desktop\\MyApp.lnk")',
        '`$shortcut.TargetPath = "C:\\Windows\\System32\\MyApp.exe"',
        '`$shortcut.IconLocation = "%SystemRoot%\\system32\\SHELL32.dll,' + iconIndex + '"',
        '`$shortcut.Save()'
    ].join('\n');
}

function copyExample() {
    const exampleDiv = document.getElementById('example');
    navigator.clipboard.writeText(exampleDiv.innerText)
        .then(() => alert("PowerShell snippet copied to clipboard!"))
        .catch(err => alert("Failed to copy: " + err));
}
</script>

</body>
</html>
"@

$html | Out-File -FilePath $outputHtml -Encoding UTF8
Invoke-Item $outputHtml
