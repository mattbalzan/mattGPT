# ---[ Windows Answer File / ISO2USB / ISO + VM Generator ]
# ---[ Created by Matt Balzan & Dave Coles (CRSP Consultants) ]
# ---[ Tested / Content by Alastair Toner & Tom Macartney (CRSP Assoc Consultants) ]
# ---[ Version 1.0 - Original 09/21 ]

# ---[ DISCLAIMER ~ The sample files are not supported under any Microsoft standard support program or service.
#      The sample files are provided AS IS without warranty of any kind. Microsoft further disclaims all implied
#      warranties including, without limitation, any implied warranties of merchantability or of fitness for a
#      particular purpose. The entire risk arising out of the use or performance of the sample files and documentation
#      remains with you. In no event shall Microsoft, its authors, or anyone else involved in the creation, production,
#      or delivery of the files be liable for any damages whatsoever (including, without limitation, damages for loss
#      of business profits, business interruption, loss of business information, or other pecuniary loss) arising out
#      of the use of or inability to use the sample scripts or documentation, even if Microsoft has been advised of the possibility of such damages.]


# ---[ VERSION ]
$global:ver = "v1.2"

# ---[ DEFINE GLOBALS ]
$global:TempDir = [System.IO.Path]::GetTempPath()
$global:WAF = "$TempDir" + "WAF"
$global:OSCDIMG = "$WAF\oscdimg"
$global:ISO_Final = "$WAF\ISO"
$global:OfflineBuild = "$WAF\OfflineBuild"
$global:VMs = "$WAF\VMs"
$global:USB = "$WAF\USB"
$global:HTMLFILE = "$WAF\HELP"

#  ---[ RUN AS ADMIN CHECKER ]
#Requires -RunAsAdministrator

# ---[ CREATE WAF DIRECTORIES ]
function CreateAnswerFileDirectories {

  # ---[ CREATES WAF FOLDERS IN USER TEMP FOLDER ]
  
  if (!(Test-Path $WAF)) { New-Item $WAF -ItemType Directory -Force }
  if (!(Test-Path $OSCDIMG)) { New-Item $OSCDIMG -ItemType Directory -Force }
  if (!(Test-Path $ISO_Final)) { New-Item $ISO_Final -ItemType Directory -Force }
  if (!(Test-Path $OfflineBuild)) { New-Item $OfflineBuild -ItemType Directory -Force }
  if (!(Test-Path $VMs)) { New-Item $VMs -ItemType Directory -Force }
  if (!(Test-Path $USB)) { New-Item $USB -ItemType Directory -Force }
  if (!(Test-Path $HTMLFILE)) { New-Item $HTMLFILE -ItemType Directory -Force }

}

function LightTheme {
  $Form.BackColor = "#FFFFFF"
  $Title.ForeColor = "#278BCE"
  $THEME.ForeColor = "#252525"
  $CURRENTVM.ForeColor = "#252525"
  $REMOVEVM.ForeColor = "#252525"
  $HELPDOCS.ForeColor = "#252525"
  $DETACHDRVS.ForeColor = "#000000"
  $GeneralSettings.ForeColor = "#000000"
  $ProductKey.ForeColor = "#000000"
  $PKEYCombobox.ForeColor = "#FFFFFF"
  $PKEYCombobox.BackColor = "#000000"
  $SetupLanguage.ForeColor = "#000000"
  $SULACombobox.ForeColor = "#FFFFFF"
  $SULACombobox.BackColor = "#000000"
  $TZINPUT.ForeColor = "#000000"
  $TZINCombobox.ForeColor = "#FFFFFF"
  $TZINCombobox.BackColor = "#000000"
  $CompName.ForeColor = "#000000"
  $CompNametxt.ForeColor = "#FFFFFF"
  $CompNametxt.BackColor = "#000000"
  $OrgName.ForeColor = "#000000"
  $OrgNametxt.ForeColor = "#FFFFFF"
  $OrgNametxt.BackColor = "#000000"
  $OOBESettings.ForeColor = "#000000"
  $OOBEPYPC.ForeColor = "#000000"
  $OOBEPYPCCombobox.ForeColor = "#FFFFFF"
  $OOBEPYPCCombobox.BackColor = "#000000"
  $OOBEEULA.ForeColor = "#000000"
  $OOBEHOR.ForeColor = "#000000"
  $OOBEHWS.ForeColor = "#000000"
  $FLDSettings.ForeColor = "#000000"
  $SOURCEtitle.ForeColor = "#000000"
  $SOURCEfiles.ForeColor = "#FFFFFF"
  $SOURCEfiles.BackColor = "#000000"
  $OSCDIMGtitle.ForeColor = "#000000"
  $OSCDIMGfiles.ForeColor = "#FFFFFF"
  $OSCDIMGfiles.BackColor = "#000000"
  $HYPERVtitle.ForeColor = "#000000"
  $HYPERVfiles.ForeColor = "#000000"
  $HYPERVfiles.BackColor = "#666666"
  $Apps.ForeColor = "#000000"
  $APPSadd.ForeColor = "#000000"
  $APPSplus.ForeColor = "#000000"
  $APPSmin.ForeColor = "#000000"
  $APPSLB.ForeColor = "#000000"
  $APPSLB.BackColor = "#FFFFFF"
  $APPStxt.ForeColor = "#FFFFFF"
  $APPStxt.BackColor = "#000000"
  $CREATEUSB.ForeColor = "#FFFFFF"
  $CREATEUSB.BackColor = "#000000"

}

function DarkTheme {
  $Form.BackColor = "#252525"
  $Title.ForeColor = "#FFFFFF"
  $THEME.ForeColor = "#FFFFFF"
  $CURRENTVM.ForeColor = "#FFFFFF"
  $REMOVEVM.ForeColor = "#FFFFFF"
  $HELPDOCS.ForeColor = "#FFFFFF"
  $DETACHDRVS.ForeColor = "#FFFFFF"
  $GeneralSettings.ForeColor = "#278BCE"
  $ProductKey.ForeColor = "#eeeeee"
  $PKEYCombobox.ForeColor = "#000000"
  $PKEYCombobox.BackColor = ""
  $SetupLanguage.ForeColor = "#eeeeee"
  $SULACombobox.ForeColor = "#000000"
  $SULACombobox.BackColor = ""
  $TZINPUT.ForeColor = "#eeeeee"
  $TZINCombobox.ForeColor = "#000000"
  $TZINCombobox.BackColor = ""
  $CompName.ForeColor = "#eeeeee"
  $CompNametxt.ForeColor = "#000000"
  $CompNametxt.BackColor = ""
  $OrgName.ForeColor = "#eeeeee"
  $OrgNametxt.ForeColor = "#000000"
  $OrgNametxt.BackColor = ""
  $OOBESettings.ForeColor = "#278BCE"
  $OOBEPYPC.ForeColor = "#eeeeee"
  $OOBEPYPCCombobox.ForeColor = "#000000"
  $OOBEPYPCCombobox.BackColor = ""
  $OOBEEULA.ForeColor = "#eeeeee"
  $OOBEHOR.ForeColor = "#eeeeee"
  $OOBEHWS.ForeColor = "#eeeeee"
  $FLDSettings.ForeColor = "#278BCE"
  $SOURCEtitle.ForeColor = "#eeeeee"
  $SOURCEfiles.ForeColor = "#000000"
  $SOURCEfiles.BackColor = "#FFFFFF"
  $OSCDIMGtitle.ForeColor = "#eeeeee"
  $OSCDIMGfiles.ForeColor = "#000000"
  $OSCDIMGfiles.BackColor = "#FFFFFF"
  $HYPERVtitle.ForeColor = "#eeeeee"
  $HYPERVfiles.ForeColor = "#000000"
  $HYPERVfiles.BackColor = "#FFFFFF"
  $Apps.ForeColor = "#278BCE"
  $APPSadd.ForeColor = "#eeeeee"
  $APPSmin.ForeColor = "#eeeeee"
  $APPSplus.ForeColor = "#eeeeee"
  $APPSLB.ForeColor = "#FFFFFF"
  $APPSLB.BackColor = "#252525"
  $APPStxt.ForeColor = "#000000"
  $APPStxt.BackColor = ""
  $CREATEUSB.ForeColor = "#000000"
  $CREATEUSB.BackColor = "#FFFFFF"
}

# ---[ TOGGLE THEMES (DARK / LIGHT) ]
function ToggleTheme {

  # ---[ SWITCH TO LIGHT THEME ]

  if ($Form.BackColor -eq "#252525") {
    LightTheme
    "LIGHT" | Out-File $WAF\theme.txt -Force
    $Form.Update()
  }

  # ---[ SWITCH TO DARK THEME ]
  else {

    DarkTheme
    "DARK" | Out-File $WAF\theme.txt -Force
    $Form.Update()
  }
}

# ---[ BASE64 LOGO // EXPORTS THE LOGO FOR THE HELP DOCS ]
$imgdata = @"
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
"@
$logo = "$HTMLFILE\waf.png"
[IO.File]::WriteAllBytes($logo,[Convert]::FromBase64String($imgdata))

# ---[ BASE64 SMALL PAW LOGO ]
$imgdata2 = @"
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
"@

# ---[ DEFINE PRODUCT EDITIONS ARRAY ]
[array]$Edition = @"
Name,Key
Windows 10 Pro,W269N-WFGWX-YVC9B-4J6C9-T83GX
Windows 10 Pro N,MH37W-N47XK-V7XM9-C7227-GCQG9
Windows 10 Pro for Workstations,NRG8B-VKK3Q-CXVCJ-9G2XF-6Q84J
Windows 10 Pro for Workstations N,9FNHH-K3HBT-3W4TD-6383H-6XYWF
Windows 10 Pro Education,6TP4R-GNPTD-KYYHQ-7B7DP-J447Y
Windows 10 Pro Education N,YVWGF-BXNMC-HTQYQ-CPQ99-66QFC
Windows 10 Education,NW6C2-QMPVW-D7KKK-3GKT6-VCFB2
Windows 10 Education N,2WH4N-8QGBV-H22JP-CT43Q-MDWWJ
Windows 10 Enterprise,NPPR9-FWDCX-D2C8J-H872K-2YT43
Windows 10 Enterprise N,DPH2V-TTNVB-4X9Q3-TJR4H-KHJW4
Windows 10 Enterprise G,YYVX9-NTFWV-6MDM3-9PT4T-4M68B
Windows 10 Enterprise G N,44RPN-FTY23-9VTTB-MP9BX-T84FV
Windows 11 Pro,W269N-WFGWX-YVC9B-4J6C9-T83GX
Windows 11 Pro N,MH37W-N47XK-V7XM9-C7227-GCQG9
Windows 11 Pro for Workstations,NRG8B-VKK3Q-CXVCJ-9G2XF-6Q84J
Windows 11 Pro for Workstations N,9FNHH-K3HBT-3W4TD-6383H-6XYWF
Windows 11 Pro Education,6TP4R-GNPTD-KYYHQ-7B7DP-J447Y
Windows 11 Pro Education N,YVWGF-BXNMC-HTQYQ-CPQ99-66QFC
Windows 11 Education,NW6C2-QMPVW-D7KKK-3GKT6-VCFB2
Windows 11 Education N,2WH4N-8QGBV-H22JP-CT43Q-MDWWJ
Windows 11 Enterprise,NPPR9-FWDCX-D2C8J-H872K-2YT43
Windows 11 Enterprise N,DPH2V-TTNVB-4X9Q3-TJR4H-KHJW4
Windows 11 Enterprise G,YYVX9-NTFWV-6MDM3-9PT4T-4M68B
Windows 11 Enterprise G N,44RPN-FTY23-9VTTB-MP9BX-T84FV
"@

# ---[ DEFINE SETUP UI: LOCALE / LANGUAGES / KEYBOARD]
[array]$SETUPUI = @"
Locale,Language,Keyboard
ar-SA,Arabic (Saudi Arabia),0401:00000401
bg-BG,Bulgarian (Bulgaria),0402:00030402
zh-cn,Chinese (PRC),0804:{81D4E9C9-1D3B-41BC-9E6C-4B40BF79E35E}{FA550B04-5AD7-411f-A5AC-CA038EC515D7}
zh-tw,Chinese (Taiwan),0404:{531FDEBF-9B4C-4A43-A2AA-960E8FCDC732}{B2F9C502-1742-11D4-9790-0080C882687E}
hr-HR,Croatian (Croatia),041a:0000041a
cs-CZ,Czech (Czech Republic),0405:00000405
da-DK,Danish (Denmark),0406:00000406
nl-NL,Dutch (Netherlands),0413:00020409
en-GB,English (United Kingdom),0809:00000809
en-US,English (United States),0409:00000409
et-EE,Estonian (Estonia),0425:00000425
fi-FI,Finnish (Finland),040b:0000040b
fr-FR,French (France),040c:0000040c
fr-CA,French (Canada),0c0c:00011009
de-DE,German (Germany),0407:00000407
gr-GR,Greek (Greece),0408:00000408
he-IL,Hebrew (Israel),040d:0002040d
hu-HU,Hungarian (Hungary),040e:0000040e
it-IT,Italian (Italy),0410:00000410
ja-JP,Japanese (Japan),0411:{03B5835F-F03C-411B-9CE2-AA23E1171E36}{A76C93D9-5523-4E90-AAFA-4DB112F9AC76}
ko-kr,Korean (Korea),0412:{A028AE76-01B1-46C2-99C4-ACD9858AE02F}{B5FE1F02-D5F2-4445-9C03-C568F23C99A1}
lv-LV,Latvian (Latvia),0426:00010426
lt-LT,Lithuanian (Lithuania),0427:00010427
nb-NO,Norwegian - Norway (Bokmal),0414:00000414
pl-pl,Polish (Poland),0415:00000415
pt-BR,Portuguese (Brazil),0416:00000416
pt-PT,Portuguese (Portugal),0816:00000816
ro-RO,Romanian (Romania),0418:00010418
ru-RU,Russian (Russia),0419:00000419
sr-Latn-RS,Serbian - Serbia (Latin),241a:0000081a
sk-SK,Slovak - Slovakia,041b:0000041b
sl-SI,Slovenian - Slovenia,0424:00000424
es-ES,Spanish (Spain),0c0a:0000040a
es-MX,Spanish - Mexico,080a:0000080a
sv-SE,Swedish (Sweden),041d:0000041d
"@

# ---[ DEFINE TIME ZONES ARRAY ]
[array]$TZ = @"
TimeZone,TZName
Dateline Standard Time,(UTC-12:00) International Date Line West
UTC-11,(UTC-11:00) Midway Island, Samoa
Hawaiian Standard Time,(UTC-10:00) Hawaii
Alaskan Standard Time,(UTC-09:00) Alaska
Pacific Standard Time,(UTC-08:00) Pacific Time (US & Canada)
Pacific Standard Time (Mexico),(UTC-08:00) Tijuana - Baja California
US Mountain Standard Time,(UTC-07:00) Arizona
Mountain Standard Time (Mexico),(UTC-07:00) Chihuahua - La Paz - Mazatlan
Mountain Standard Time,(UTC-07:00) Mountain Time (US & Canada)
Central America Standard Time,(UTC-06:00) Central America
Central Standard Time,(UTC-06:00) Central Time (US & Canada)
Central Standard Time (Mexico),(UTC-06:00) Guadalajara - Mexico City - Monterrey
Canada Central Standard Time,(UTC-06:00) Saskatchewan
SA Pacific Standard Time,(UTC-05:00) Bogota - Lima - Quito
Eastern Standard Time,(UTC-05:00) Eastern Time (US & Canada)
US Eastern Standard Time,(UTC-05:00) Indiana (East)
Venezuela Standard Time,(UTC-04:30) Caracas
Paraguay Standard Time,(UTC-04:00) Asuncion
Atlantic Standard Time,(UTC-04:00) Atlantic Time (Canada)
SA Western Standard Time,(UTC-04:00) Georgetown - La Paz - San Juan
Pacific SA Standard Time,(UTC-04:00) Santiago
Newfoundland Standard Time,(UTC-03:30) Newfoundland
E. South America Standard Time,(UTC-03:00) Brasilia
Argentina Standard Time,(UTC-03:00) Buenos Aires
SA Eastern Standard Time,(UTC-03:00) Cayenne
Greenland Standard Time,(UTC-03:00) Greenland
Montevideo Standard Time,(UTC-03:00) Montevideo
Mid-Atlantic Standard Time,(UTC-02:00) Mid-Atlantic
Azores Standard Time,(UTC-01:00) Azores
Cape Verde Standard Time,(UTC-01:00) Cape Verde Is.
Morocco Standard Time,(UTC) Casablanca
UTC,(UTC) Coordinated Universal Time
GMT Standard Time,(UTC) Dublin - Edinburgh - Lisbon - London
Greenwich Standard Time,(UTC) Monrovia - Reykjavik
W. Europe Standard Time,(UTC+01:00) Amsterdam - Berlin - Bern - Rome - Stockholm - Vienna
Central Europe Standard Time,(UTC+01:00) Belgrade - Bratislava - Budapest - Ljubljana - Prague
Romance Standard Time,(UTC+01:00) Brussels - Copenhagen - Madrid - Paris
Central European Standard Time,(UTC+01:00) Sarajevo - Skopje - Warsaw - Zagreb
W. Central Africa Standard Time,(UTC+01:00) West Central Africa
Jordan Standard Time,(UTC+02:00) Amman
GTB Standard Time,(UTC+02:00) Athens - Bucharest - Istanbul
Middle East Standard Time,(UTC+02:00) Beirut
Egypt Standard Time,(UTC+02:00) Cairo
South Africa Standard Time,(UTC+02:00) Harare - Pretoria
FLE Standard Time,(UTC+02:00) Helsinki - Kyiv - Riga - Sofia - Tallinn - Vilnius
Israel Standard Time,(UTC+02:00) Jerusalem
Kaliningrad Standard Time,(UTC+02:00) Minsk
Namibia Standard Time,(UTC+02:00) Windhoek
Arabic Standard Time,(UTC+03:00) Baghdad
Arab Standard Time,(UTC+03:00) Kuwait - Riyadh
Russian Standard Time,(UTC+03:00) Moscow - St. Petersburg - Volgograd
E. Africa Standard Time,(UTC+03:00) Nairobi
Georgian Standard Time,(UTC+03:00) Tbilisi
Iran Standard Time,(UTC+03:30) Tehran
Arabian Standard Time,(UTC+04:00) Abu Dhabi - Muscat
Azerbaijan Standard Time,(UTC+04:00) Baku
Mauritius Standard Time,(UTC+04:00) Port Louis
Caucasus Standard Time,(UTC+04:00) Yerevan
Afghanistan Standard Time,(UTC+04:30) Kabul
Ekaterinburg Standard Time,(UTC+05:00) Ekaterinburg
Pakistan Standard Time,(UTC+05:00) Islamabad - Karachi
West Asia Standard Time,(UTC+05:00) Tashkent
India Standard Time,(UTC+05:30) Chennai - Kolkata - Mumbai - New Delhi
Nepal Standard Time,(UTC+05:45) Kathmandu
N. Central Asia Standard Time,(UTC+06:00) Almaty - Novosibirsk
Central Asia Standard Time,(UTC+06:00) Astana - Dhaka
Myanmar Standard Time,(UTC+06:30) Yangon (Rangoon)
SE Asia Standard Time,(UTC+07:00) Bangkok - Hanoi - Jakarta
North Asia Standard Time,(UTC+07:00) Krasnoyarsk
China Standard Time,(UTC+08:00) Beijing, Chongqing - Hong Kong - Urumqi
North Asia East Standard Time,(UTC+08:00) Irkutsk - Ulaan Bataar
Singapore Standard Time,(UTC+08:00) Kuala Lumpur - Singapore
W. Australia Standard Time,(UTC+08:00) Perth
Taipei Standard Time,(UTC+08:00) Taipei
Tokyo Standard Time,(UTC+09:00) Osaka - Sapporo - Tokyo
Korea Standard Time,(UTC+09:00) Seoul
Yakutsk Standard Time,(UTC+09:00) Yakutsk
Cen. Australia Standard Time,(UTC+09:30) Adelaide
AUS Central Standard Time,(UTC+09:30) Darwin
E. Australia Standard Time,(UTC+10:00) Brisbane
AUS Eastern Standard Time,(UTC+10:00) Canberra - Melbourne - Sydney
West Pacific Standard Time,(UTC+10:00) Guam - Port Moresby
Tasmania Standard Time,(UTC+10:00) Hobart
Vladivostok Standard Time,(UTC+10:00) Vladivostok
Central Pacific Standard Time,(UTC+11:00) Magadan - Solomon Is. - New Caledonia
New Zealand Standard Time,(UTC+12:00) Auckland - Wellington
Fiji Standard Time,(UTC+12:00) Fiji, Marshall Is.
UTC+12,(UTC+12:00) Petropavlovsk-Kamchatsky
Tonga Standard Time,(UTC+13:00) Nuku'alofa
"@

# ---[ DEFINE ProtectYourPC ARRAY ]
[array]$PYPC = @"
Setting,Name
1,[1] Turns on Express settings.
2,[2] Turns on Express settings
3,[3] Turns off Express settings
"@


# ---[ CREATE HELP DOCUMENT]
function HelpDocs {
  $htmldoc = @"
<!DOCTYPE html>
<html class="theme-light">
	<head>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
		<title>WAF Build Help Docs</title>
		<style type="text/css">

        .theme-light {
            --color-primary: #ffffff;
            --color-secondary: #eee;
            --color-tdth: #ddd;
            --color-trnth:#f2f2f2;
            --color-trhover: #ddd;
            --font-color: #000000;
            --subtitle: #000000;
            --color-trmand: #cceeff;
        }

        .theme-dark {
            --color-primary: #232B32;
            --color-secondary: #000;
            --color-accent: #12cdea;
            --color-tdth: rgb(100, 100, 100);
            --color-trnth:#234250;
            --color-trhover: rgb(20, 20, 20);
            --font-color: #ffffff;
            --subtitle: #0099ff;
            --color-trmand: #005266;
        }
        
        h1 { color: var(--subtitle);}
		
		body{
			margin: 0;
			padding: 0;
			overflow: hidden;
			height: 100%; 
			max-height: 100%; 
			font-family:'Segoe UI';
			line-height: 1.5em;
            font-size: 14px;
		}
		
		#nav{
			position: absolute;
			top: 0;
			bottom: 0; 
			left: 0;
			width: 280px; /* Width of navigation frame */
			height: 100%;
			overflow: hidden; /* Disables scrollbars on the navigation frame. To enable scrollbars, change "hidden" to "scroll" */
			background: var(--color-secondary);
            color: var(--font-color);
		}
		
		main{
			position: fixed;
			top: 0; 
			left: 280px; /* Set this to the width of the navigation frame */
			right: 0;
			bottom: 0;
			overflow: auto; 
			background: var(--color-primary);
            color: var(--font-color);
		}
		
		.innertube{
			margin: 20px; /* Provides padding for the content */
		}
		
		nav ul {
			list-style-type: square;
			margin: 5;
			padding: 0;
            text-decoration: none;
            font-size: 12px;
            color:var(--font-color);
		}
		
        a {
            text-decoration: none;
            color:var(--font-color);

        }

        a:visited {
            text-decoration: none;
            color:var(--font-color);
        }
        
        a:hover {
            text-decoration: underline;
        }
				
		/*IE6 fix*/
		* html body{
			padding: 0 0 0 230px; /* Set the last value to the width of the navigation frame */
		}
		
		* html main{ 
			height: 100%; 
			width: 100%; 
		}

        td,th {
            border: 1px solid var(--color-tdth);
            padding: 8px;
        }

        .trheader{
                    background-color: var(--color-trnth);
                    font-weight: bold;}
        
        .trmand {
                    background-color: var(--color-trmand);

        }

        tr:hover {background-color: var(--color-trhover);}

		</style>
        <script>
            // function to set a given theme/color-scheme
                function setTheme(themeName) {
                    localStorage.setItem('theme', themeName);
                        document.documentElement.className = themeName;
                }
            // function to toggle between light and dark theme
                function toggleTheme() {
                    if (localStorage.getItem('theme') === 'theme-dark') {
                    setTheme('theme-light');
                    } else {
                    setTheme('theme-dark');
                    }
                }
            // Immediately invoked function to set the theme on initial load
                (function () {
                    if (localStorage.getItem('theme') === 'theme-dark') {
                    setTheme('theme-dark');
                    } else {
                    setTheme('theme-light');
                    }
                })();    
        </script>
	</head>
	<body>		
        <main>
            <br id="Top">
			<div class="innertube">
				<h1>Windows Answer File Help Guide</h1>
                <br>
                <article>
                        <br>
                            <h1 id="WhatAns">What is an Answer file?</h1>
                            <p>The answer (or Autounattend.xml) file is a configuration xml file which contains all the predetermined settings for a Windows Setup.</p>
                            <p>The purpose of this file is to automate as much as possible the setup without manual intervention or human error/typos.</p>
                            <p>In order to setup an answer file, you would normally download the ADKSetup binaries from the MSFT site and then install the Windows System Image Manager.</p>
                            <p>However, using the SIM requires some technical skill and is time consuming. The WAF GUI removes these burdens and lets you select various settings only needed for the customer build.</p>
                        <br>
                            <h1 id="PAWreq">What are the WAF creation requirements?</h1>
                            <p>To run the WAF Creator UI, you will need the following:</p>
                              <ul>
                                 <li>a physical device to test the script on</li>
                                 <li>a technician device running Windows 10 or 11 with 8GB RAM and the Hyper-V Feature enabled</li>
                                 <li>a clean source downloaded ISO file of the OS you wish to build</li>
                                 <li>a USB disk with minimum 8GB of disk space</li>
                                 <li>Administrator rights to run this WAF GUI PowerShell script</li>
                              </ul>   
                                 <br>
                            <p>optional:</p>
                              <ul>
                                 <li>drivers for the test device</li>
                                 <li>additional software copied to the USB drive</li>
                              </ul>
                        <br>
                              <h1 id="HowAns">How to create an Answer file</h1>
                            <p>1. Launch the WAF GUI PowerShell script as Administrator and select the following <b>General Settings</b> (the highlighted 3 rows below are mandatory!):</p>
                            <p>
                                <table>
                                    <tr class='trheader'><td>GENERAL SETTINGS</td></tr>
                                    <tr class='trmand'><td>PRODUCT KEY:</td><td>Click the combo box to select an operating system edition.</td></tr>
                                    <tr class='trmand'><td>SETUP LANGUAGE:</td><td>Choose from 35 languages (please select the language your ISO file was downloaded as!).</td></tr>
                                    <tr class='trmand'><td>TIME ZONE:</td><td>Choose a time zone.</td></tr>
                                    <tr><td>COMPUTER NAME:</td><td>You can enter the name of your choice or leave the random generated one.</td></tr>
                                    <tr><td>ORGANIZATION NAME:</td><td>You can enter the name of your choice.</td></tr>
                                </table>
                        <br>
                                <p>2. Choose your <b>Out Of Box Experience Settings</b> (these are optional and not needed for the answer file).</p>
                                <p>
                                <table>  
                                    <tr class='trheader'><td>OOBE SETTINGS</td></tr>
                                    <tr><td>PROTECT YOUR PC*:</td><td>1 - Turns on Express settings.<br>2 - Turns on Express settings.<br>3 - Turns off Express settings.<br>(1 is the default)</td></tr>
                                    <tr><td>HIDE EULA PAGE:</td><td>Enables/disables the EULA page during setup.</td></tr>
                                    <tr><td>HIDE OEM REGISTRATION SCREEN:</td><td>Enables/disables the OEM registration screen during setup.</td></tr>
                                    <tr><td>HIDE WIRELESS SETUP IN OOBE:</td><td>Enables/disables the wireless setup.</td></tr>
                                </table>
                                <p>*Express Settings explained <a href='https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-shell-setup-oobe-protectyourpc'><b>here</b>.</a></p>
                        <br>
                                <p>3. Skip the FOLDER SETTINGS as these are not needed for the answer file.</p>
                        
                                <p>4. Add any <b>Custom Commands</b> to run during post setup. (These commands are limited to a maximum of 259 characters)</p>

                                <p>Below are a few examples of how you would run several custom commands:<br><br>
                                <p><b>Example 1: </b><i>cmd /c if exist D:\script.ps1 PowerShell.exe -ex Bypass -file D:\script.ps1</i></p>
                                <p><b>Example 2: </b><i>cmd /c REG ADD HKEY_CURRENT_USER\Console /v Test /d "Test Data"</i></p>
                                <p><b>Example 3: </b><i>powershell.exe -ex bypass -command {Set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces\TCPIP* -Name NetBIOSoptions -Value 2}</i></p>
                        <br>
                                <p>Type your custom command in the input field, then press the <b>+</b> button. This will add your custom command to the custom command listbox.
                                <p>To remove the custom command, select the command from the listbox and then press the <b>-</b> button.
                                <p><b>NOTE!</b> If you do add any custom commands that call external files, ensure you copy them over to the USB drive or the commands will fail (setup will still continue).</p>
                        <br>
                                <p>5. Click the <b>[CREATE ANSWER FILE]</b> button. A pop-up will inform you where the file is located.</p>
                                
                                <p>6. Copy the answer file to your USB drive, together with ALL the contents of the ISO installer files. Once the files are copied, insert the USB drive into the device and press <b>F12</b> to boot from the USB drive.</p>
                            <br>
                            <h1 id="HowUSB">How to create a WAF using a USB disk</h1>
                            <p>1. Follow the steps as above, but this time you will need to action the <b>Folder Settings</b> section in step 3.</p>
                            <p>
                            <table>  
                                    <tr class='trheader'><td>FOLDER SETTINGS</td></tr>
                                    <tr><td>ISO SOURCE LOACTION:</td><td>Click <b>[ATTACH ISO...]</b> to locate your ISO installer file.</td></tr>
                                    <tr><td>OSCDIMG FILES SOURCE:</td><td>Click <b>[BROWSE...]</b> to locate your OSCDIMG folder.</td></tr>
                                    <tr><td>HYPER-V FEATURE:</td><td>If the button displays: ENABLED, then Hyper-V feature on the device is setup.<br>If ENABLE appears, then you will need to click this to enable Hyper-V (a reboot is necessary!)</td></tr>
                                </table>
                            <p>2. For step 5, click the <b>[CREATE ANSWER FILE + USB]</b> button. A pop-up will ask you which USB drive to choose from.</p>
                            <p>3. Once you have selected your USB drive, a warning will appear. Click OK to the warning.</p>
                            <p>4. The USB drive will be formatted and all the contents of the ISO and the autounattend file will be copied to it.</p>
                            <p>5. Once the script has completed, you are now ready to build a device. Insert the USB drive into the PAW device and press <b>F12</b> to boot from the USB drive.</p>
                        <br>
                        <h1 id="Gloss">Glossary</h1>
                        <table>
                            <tr><td>WAF</td><td>Windows Answer File</td></tr>
                            <tr><td>GUI</td><td>Graphical User Interface</td></tr>
                            <tr><td>USB</td><td>Universal Serial Bus</td></tr>
                            <tr><td>ISO</td><td>An ISO file is an exact copy of an entire optical disk such as a CD, DVD, or Blu-ray archived into a single file</td></tr>
                            <tr><td>OS</td><td>Operating System</td></tr>
                            <tr><td>RAM</td><td>Random Access Memory</td></tr>
                            <tr><td>XML</td><td>eXtended Markup Language</td></tr>
                            <tr><td>ANSWER or AUTOUNATTEND</td><td>XML configuration file to automate Windows Setup</td></tr>
                        </table>
                    </article>
				<p></p>
            </div>
		</main>
	
		<nav id="nav">
			<div class="innertube">
            <div><center><img src="$logo" alt="WAF logo"></center></div>
			<h3>INDEX</h3>
			<ul>
                <li><a href="#WhatAns">What is an Answer file?</a></li>
                <li><a href="#PAWreq">What are the WAF creation requirements?</a></li>
                <li><a href="#HowAns">How to create an Answer file</a></li>
                <li><a href="#HowUSB">How to create a WAF using a USB disk</a></li>
                <li><a href="#HowISO">How to create a WAF using an ISO file</a></li>
                <li><a href="#Gloss">Glossary</a></li>
            </ul>
            <p></p>
            <center><a href="#Top">GO TO TOP</a>&emsp;|&emsp;<a href="#" onclick="toggleTheme()">TOGGLE THEME</a></center>
			</div>
		</nav>
	</body>
</html>
"@

  # ---[ SET OUTFILE FOR HELP DOCS]
  $htmlout = "$HTMLFILE\helpdocs.html"

  # ---[ FIND LAST RUN HELP DOCS HTML AND REMOVE IT ]
  if (Test-Path -Path $htmlout) { Remove-Item $htmlout -Force }

  # ---[ APPEND ALL HTML CONTENT AND LAUNCH HELP DOCS AS A NEW EDGE WINDOW ]
  Add-Content $htmlout $htmldoc -Force
  Start-Process "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList "--new-window $htmlout"
}

# ---[ CREATE AND EXPORT THE AUTOUNATTEND.XML FILE ]
function CreateAutounattendFile ($AutounattendXML,$ANSTYPE) {

  $ANSFOLDER = "$(Get-date -Format ddMMyyHHMMss)"

  switch ($ANSTYPE) {
    '1' {
      $global:WAF_FINAL = "$WAF\$ANSFOLDER"
      New-Item -Path $WAF_FINAL -ItemType Directory -Force
      $AutounattendXML | Set-Content -Path $WAF_FINAL\Autounattend.xml -Force

      $TI = "SUCCESS! YOUR ANSWER FILE HAS BEEN SAVED IN:"
      $FT = "$WAF_FINAL"
      $BM = "`r`n`   1. COPY THE FILE FROM THE ABOVE LOCATION AND PLACE IT ON THE ROOT OF YOUR BOOTABLE USB DRIVE.`r`n`r`n   2. INSERT YOUR USB DRIVE INTO A POWERED OFF MACHINE.`r`n`r`n   3. POWER ON MACHINE AND PRESS [F12] FOR THE BOOT MENU.`r`n`r`n   4. SELECT THE USB DRIVE AND WAIT FOR THE BUILD TO FINISH."
      $AM = $false
      $MS = $true
      $PF = [System.Drawing.ColorTranslator]::FromHtml("#000000")
      PromptUser $TI $FT $BM $AM $MS $PF

    }
    '2' {
      $AutounattendXML | Set-Content -Path $USB\Autounattend.xml -Force
    }
    '3' {
      $AutounattendXML | Set-Content -Path $OfflineBuild\Autounattend.xml -Force
    }
  }

}

# ---[ PROMPT USER ANSWER FILE FORM ]    
function PromptUser ($TI,$FT,$BM,$AM,$MS,$PF) {

  # ---[ CREATE USER PROMPT FORM ]

  $PromptForm = New-Object system.Windows.Forms.Form
  $PromptForm.ClientSize = New-Object System.Drawing.Point (700,280)
  $PromptForm.StartPosition = 'CenterScreen'
  $PromptForm.FormBorderStyle = 'FixedSingle'
  $PromptForm.MinimizeBox = $false
  $PromptForm.MaximizeBox = $false
  $PromptForm.ShowIcon = $false
  $PromptForm.text = "Windows OS Answer File"
  $PromptForm.TopMost = $true
  $PromptForm.BackColor = $PF

  # ---[ TITLE, FILE PATH & INSTRUCTIONS ]

  $Title = New-Object System.Windows.Forms.Button
  $Title.FlatStyle = 'Flat'
  $Title.FlatAppearance.BorderSize = 0
  $Title.text = "$TI"
  $Title.width = 680
  $Title.height = 30
  $Title.Anchor = 'top,right,left'
  $Title.location = New-Object System.Drawing.Point (10,10)
  $Title.Font = New-Object System.Drawing.Font ('Consolas',10,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
  $Title.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
  $Title.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")

  $File = New-Object System.Windows.Forms.Button
  $File.FlatStyle = 'Flat'
  $File.text = "$FT"
  $File.width = 680
  $File.height = 30
  $File.Anchor = 'top,right,left'
  $File.location = New-Object System.Drawing.Point (10,50)
  $File.Font = New-Object System.Drawing.Font ('Consolas',10,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
  $File.ForeColor = $PF
  $File.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")

  $Message = New-Object System.Windows.Forms.TextBox
  $Message.BorderStyle = 0
  $Message.TextAlign = 'left'
  $Message.Multiline = $True
  $Message.text = "$BM"
  $Message.width = 680
  $Message.height = 140
  $Message.Anchor = 'top,right,left'
  $Message.location = New-Object System.Drawing.Point (10,90)
  $Message.Font = New-Object System.Drawing.Font ('Consolas',10,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
  $Message.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
  $Message.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
  $Message.Visible = $MS

  $AlertMessage = New-Object System.Windows.Forms.TextBox
  $AlertMessage.BorderStyle = 0
  $AlertMessage.TextAlign = 'CENTER'
  $AlertMessage.Multiline = $True
  $AlertMessage.text = "`r" + [char]57610
  $AlertMessage.width = 680
  $AlertMessage.height = 140
  $AlertMessage.Anchor = 'top,right,left'
  $AlertMessage.location = New-Object System.Drawing.Point (10,90)
  $AlertMessage.Font = New-Object System.Drawing.Font ('Segoe UI Symbol',70,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
  $AlertMessage.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
  $AlertMessage.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#B32C1E")
  $AlertMessage.Visible = $AM

  $Close = New-Object System.Windows.Forms.Button
  $Close.FlatStyle = 'Flat'
  $Close.FlatAppearance.BorderSize = 0
  $Close.text = 'EXIT'
  $Close.width = 680
  $Close.height = 30
  $Close.Anchor = 'top,right,left'
  $Close.location = New-Object System.Drawing.Point (10,240)
  $Close.Font = New-Object System.Drawing.Font ('Consolas',10,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
  $Close.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
  $Close.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")



  $PromptForm.controls.AddRange(@($Title,$File,$Message,$AlertMessage,$Close))

  $File.Add_Click({
      Invoke-Item $global:waf_final
    })

  $Close.Add_Click({ $PromptForm.Close() })

  # ---[ LAUNCH THE FORM ]
  [void]$PromptForm.ShowDialog()
}


# ---[ PROMPT USER VM + ISO FORM ]
function PromptISOVM {

  # ---[ CHECK FOR AUTOUNATTEND.XML FILE ]
  function checkAnswerFile {

    $ANSFILE = "$OfflineBuild\Autounattend.xml"


    if (!(Test-Path $ANSFILE)) {

      $ANSFILEcheck.text = [char]57610 #57610 = CROSS // 57611 = TICK
      $MAKEVMISO.Enabled = $false
      $MSGBOX.AppendText("ANSWER FILE IS MISSING!`r`nSOLUTION:`r`n`r`n- CLOSE THIS WINDOW`r`n- SELECT ALL THE REQUIRED FIELDS ON THE MAIN PAGE.`r`n- CLICK THE [CREATE ANSWER FILE + VM] BUTTON.`r`n")

    }

    else {

      $ANSFILEcheck.text = [char]57611
      #$MAKEVMISO.Enabled           = $true

    }
  }

  # ---[ CHECK FOR OSCDIMG FILES ]
  function checkOSCbinaries {

    $OSCBINFILES = Test-Path "$oscdimg\efisys.bin","$oscdimg\efisys_noprompt.bin","$oscdimg\etfsboot.com","$oscdimg\oscdimg.exe"

    if ($OSCBINFILES -like "False") {
      $OSCbutcheck.text = [char]57610 #57610 = CROSS // 57611 = TICK
      $MAKEVMISO.Enabled = $false
      $MSGBOX.AppendText("OSCDIMG FILES ARE MISSING!`r`nSOLUTION:`r`n`r`n- CLOSE THIS WINDOW`r`n- PLEASE GO TO THE MAIN PAGE AND CLICK THE [OSCDIMG FILE SOURCE] BUTTON.")

    }
    else {
      $OSCbutcheck.text = [char]57611
      #$MAKEVMISO.Enabled           = $true
    }

  }

  # ---[ CHECK FOR ISO FILES ]
  function checkISObinaries {

    $ISOFILES = Test-Path "$OfflineBuild\boot","$OfflineBuild\efi","$OfflineBuild\sources" `
      ,"$OfflineBuild\support","$OfflineBuild\Setup.exe","$OfflineBuild\bootmgr","$OfflineBuild\bootmgr.efi","$OfflineBuild\autorun.inf"

    if ($ISOFILES -like "False") {
      $ISObutcheck.text = [char]57610 #57610 = CROSS // 57611 = TICK
      $MAKEVMISO.Enabled = $false
      $MSGBOX.AppendText("`r`nPLEASE GO TO THE MAIN PAGE AND CLICK THE [ISO SOURCE LOCATION] BUTTON.")

    }
    else {
      $ISObutcheck.text = [char]57611
      #$MAKEVMISO.Enabled           = $true
    }

  }

  # ---[ ALL CHECKS ]
  function allChecks {

    if (($ANSFILEcheck.text -eq [char]57611) -and ($ISObutcheck.text -eq [char]57611) -and ($OSCbutcheck.text -eq [char]57611))
    {
      $MAKEVMISO.Visible = $true

      $MSGBOX.text = "`r`nYOU ARE GO FOR ISO + VM LAUNCH!"
    }
    else {

      $MAKEVMISO.Visible = $false

      $MSGBOX.text = "`r`nCHECKLIST SHOWS YOU STILL NEED TO FIX SOME STUFF!"

    }
  }

  # ---[ CREATE VM + ISO ]   

  function MakeISOVM {

    # ---[ CREATE ISO ]

    $ISO_outfile = "$ISO_Final\VM_$(Get-Date -Format yyyy-MM-dd-HH-mm).iso"

    $ISOARGS = "-b`"$oscdimg\efisys.bin`" -pEF -u1 -udfver102 `"$OfflineBuild`" $ISO_outfile"


    $ProgBar.Visible = $true
    $PROV.Visible = $true
    $ProgBar.width = 160
    $PercDone = [math]::Round(($($ProgBar.width) / 663) * 100)
    $PROV.text = "$PercDone %"

    $MSGBOX.text = "PLEASE DO NOT EXIT THIS WINDOW!`r`n`r`nCreating ISO file..."


    Start-Process $OSCDIMG\oscdimg.exe -ArgumentList $ISOARGS -Wait -WindowStyle Hidden

    $MSGBOX.AppendText("`r`nSetting up your hyper-v machine...")
    $ProgBar.width = 332
    $PercDone = [math]::Round(($($ProgBar.width) / 663) * 100)
    $PROV.text = "$PercDone %"

    # ---[ SETUP VM ]
    $vmName = "VM" + (Get-Date -Format "yyyy-MM-dd-HH-mm")
    New-VM -Name $vmName -NewVHDPath "$VMs\$vmName.vhdx" -NewVHDSizeBytes 64GB -MemoryStartupBytes 4GB -Path "$VMs\$vmName" -Generation 2

    $ProgBar.width = 370
    $PercDone = [math]::Round(($($ProgBar.width) / 663) * 100)
    $PROV.text = "$PercDone %"

    # ---[ SET VM DYNAMIC MEMORY ]
    Set-VMMemory -VMName $vmName -DynamicMemoryEnabled $false

    $ProgBar.width = 420
    $PercDone = [math]::Round(($($ProgBar.width) / 663) * 100)
    $PROV.text = "$PercDone %"

    # ---[ SET VM VIRTUAL PROCS ]
    Set-VMProcessor -VMName $vmName -Count 2 -Confirm:$false

    # ---[ ENABLE VM TPM // REQ FOR W11 ]
    Set-VMKeyProtector -VMName $vmName -NewLocalKeyProtector
    Enable-VMTPM -VMName $vmName

    $ProgBar.width = 470
    $PercDone = [math]::Round(($($ProgBar.width) / 663) * 100)
    $PROV.text = "$PercDone %"

    # ---[ ATTACH ISO AS A DVD DRIVE TO THE VM ]
    Add-VMDvdDrive -VMName $vmName -Path $ISO_outfile

    $ProgBar.width = 490
    $PercDone = [math]::Round(($($ProgBar.width) / 663) * 100)
    $PROV.text = "$PercDone %"

    # ---[ SET CORRECT BOOT ORDER (DVD DRIVE FIRST) ]
    $dvd = Get-VMDvdDrive -VMName $vmName
    Set-VMFirmware -VMName $vmName -FirstBootDevice $dvd

    $ProgBar.width = 510
    $PercDone = [math]::Round(($($ProgBar.width) / 663) * 100)
    $PROV.text = "$PercDone %"
    $MSGBOX.AppendText("`r`nConnecting to $vmName...")

    # ---[ Disable Enhanced Session Mode ]
    Set-VMHost -EnableEnhancedSessionMode $False

    $ProgBar.width = 540
    $PercDone = [math]::Round(($($ProgBar.width) / 663) * 100)
    $PROV.text = "$PercDone %"

    # ---[ START THE VM AND CONNECT TO IT ]
    vmconnect $env:COMPUTERNAME $vmName
    Start-VM -Name $VMName

    $ProgBar.width = 560
    $PercDone = [math]::Round(($($ProgBar.width) / 663) * 100)
    $PROV.text = "$PercDone %"
    $MSGBOX.AppendText("`r`nBooting from DVD iso...")

    # ---[ WAIT 3 SECONDS AND SEND {ENTER} KEY TO BOOT FROM ISO ]
    Start-Sleep -Seconds 3

    [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")

    $ProgBar.width = 663
    $PercDone = [math]::Round(($($ProgBar.width) / 663) * 100)
    $PROV.text = "$PercDone %"

    $MSGBOX.AppendText("`r`nJob done! You can now close this window.")

    $MAKEVMISO.Visible = $false
    $VMEXIT.Visible = $true

  }

  # ---[ CREATE USER PROMPT FORM ]
  $VMPromptForm = New-Object system.Windows.Forms.Form
  $VMPromptForm.ClientSize = New-Object System.Drawing.Point (700,360)
  $VMPromptForm.StartPosition = 'CenterScreen'
  $VMPromptForm.FormBorderStyle = 'FixedSingle'
  $VMPromptForm.MinimizeBox = $false
  $VMPromptForm.MaximizeBox = $false
  $VMPromptForm.ShowIcon = $false
  $VMPromptForm.text = "ANSWER FILE + VM"
  $VMPromptForm.TopMost = $true
  $VMPromptForm.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")


  # ---[ SUBTITLE VM  ]
  $VMSubtitle = New-Object System.Windows.Forms.Label
  $VMSubtitle.FlatStyle = 'Flat'
  $VMSubtitle.text = "CREATE ANSWER FILE + VM"
  $VMSubtitle.TextAlign = 'middlecenter'
  $VMSubtitle.width = 680
  $VMSubtitle.height = 50
  $VMSubtitle.Anchor = 'top,right,left'
  $VMSubtitle.location = New-Object System.Drawing.Point (10,10)
  $VMSubtitle.Font = New-Object System.Drawing.Font ('Consolas',12,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
  $VMSubtitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
  $VMSubtitle.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")


  $ANSFILEBIN = New-Object System.Windows.Forms.Button
  $ANSFILEBIN.FlatStyle = 'Flat'
  $ANSFILEBIN.text = "ANSWER FILE"
  $ANSFILEBIN.width = 150
  $ANSFILEBIN.height = 30
  $ANSFILEBIN.Anchor = 'top,right,left'
  $ANSFILEBIN.location = New-Object System.Drawing.Point (10,70)
  $ANSFILEBIN.Font = New-Object System.Drawing.Font ('Consolas',9)
  $ANSFILEBIN.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
  $ANSFILEBIN.Enabled = $false

  $ANSFILEcheck = New-Object System.Windows.Forms.Button
  $ANSFILEcheck.FlatStyle = 'Flat'
  $ANSFILEcheck.FlatAppearance.BorderSize = 0
  $ANSFILEcheck.width = 50
  $ANSFILEcheck.height = 30
  $ANSFILEcheck.Anchor = 'top,right,left'
  $ANSFILEcheck.location = New-Object System.Drawing.Point (170,70)
  $ANSFILEcheck.Font = New-Object System.Drawing.Font ('Segoe UI Symbol',14)
  $ANSFILEcheck.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")

  $OSCbut = New-Object System.Windows.Forms.Button
  $OSCbut.FlatStyle = 'Flat'
  $OSCbut.text = "OSCDIMG FILES"
  $OSCbut.width = 150
  $OSCbut.height = 30
  $OSCbut.Anchor = 'top,right,left'
  $OSCbut.location = New-Object System.Drawing.Point (250,70)
  $OSCbut.Font = New-Object System.Drawing.Font ('Consolas',9)
  $OSCbut.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
  $OSCbut.Enabled = $false

  $OSCbutcheck = New-Object System.Windows.Forms.Button
  $OSCbutcheck.FlatStyle = 'Flat'
  $OSCbutcheck.FlatAppearance.BorderSize = 0
  $OSCbutcheck.width = 50
  $OSCbutcheck.height = 30
  $OSCbutcheck.Anchor = 'top,right,left'
  $OSCbutcheck.location = New-Object System.Drawing.Point (410,70)
  $OSCbutcheck.Font = New-Object System.Drawing.Font ('Segoe UI Symbol',14)
  $OSCbutcheck.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")

  $ISObut = New-Object System.Windows.Forms.Button
  $ISObut.FlatStyle = 'Flat'
  $ISObut.text = "ISO FILES"
  $ISObut.width = 150
  $ISObut.height = 30
  $ISObut.Anchor = 'top,right,left'
  $ISObut.location = New-Object System.Drawing.Point (490,70)
  $ISObut.Font = New-Object System.Drawing.Font ('Consolas',9)
  $ISObut.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
  $ISObut.Enabled = $false

  $ISObutcheck = New-Object System.Windows.Forms.Button
  $ISObutcheck.FlatStyle = 'Flat'
  $ISObutcheck.FlatAppearance.BorderSize = 0
  $ISObutcheck.width = 50
  $ISObutcheck.height = 30
  $ISObutcheck.Anchor = 'top,right,left'
  $ISObutcheck.location = New-Object System.Drawing.Point (650,70)
  $ISObutcheck.Font = New-Object System.Drawing.Font ('Segoe UI Symbol',14)
  $ISObutcheck.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")

  $MAKEVMISO = New-Object System.Windows.Forms.Button
  $MAKEVMISO.FlatStyle = 'Flat'
  $MAKEVMISO.FlatAppearance.BorderSize = 0
  $MAKEVMISO.text = "CREATE + LAUNCH VM"
  $MAKEVMISO.width = 680
  $MAKEVMISO.height = 50
  $MAKEVMISO.Anchor = 'top,right,left'
  $MAKEVMISO.location = New-Object System.Drawing.Point (10,300)
  $MAKEVMISO.Font = New-Object System.Drawing.Font ('Consolas',10,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
  $MAKEVMISO.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
  $MAKEVMISO.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#278BCE")

  $VMEXIT = New-Object System.Windows.Forms.Button
  $VMEXIT.FlatStyle = 'Flat'
  $VMEXIT.FlatAppearance.BorderSize = 0
  $VMEXIT.text = "CLOSE"
  $VMEXIT.width = 680
  $VMEXIT.height = 50
  $VMEXIT.Anchor = 'top,right,left'
  $VMEXIT.location = New-Object System.Drawing.Point (10,300)
  $VMEXIT.Font = New-Object System.Drawing.Font ('Consolas',10,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
  $VMEXIT.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
  $VMEXIT.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
  $VMEXIT.Visible = $false


  # ---[ BOTTOM MESSAGE BOX ]
  $MSGBOX = New-Object System.Windows.Forms.TextBox
  $MSGBOX.TextAlign = 'LEFT'
  $MSGBOX.BorderStyle = 1
  $MSGBOX.width = 680
  $MSGBOX.height = 160
  $MSGBOX.Multiline = $true
  $MSGBOX.ScrollBars = "Vertical"
  $MSGBOX.Anchor = 'top,right,left'
  $MSGBOX.location = New-Object System.Drawing.Point (10,120)
  $MSGBOX.Font = New-Object System.Drawing.Font ('Consolas',10)
  $MSGBOX.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
  $MSGBOX.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
  $MSGBOX.ReadOnly = $true

  # --- [ MY OWN PROGRESS BAR :) ]

  $ProgBar = New-Object System.Windows.Forms.TextBox
  $ProgBar.TextAlign = 'left'
  $ProgBar.BorderStyle = 0
  $ProgBar.width = 0
  $ProgBar.height = 3
  $ProgBar.Anchor = 'top,right,left'
  $ProgBar.location = New-Object System.Drawing.Point (10,270)
  $ProgBar.Enabled = $false
  $ProgBar.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
  $ProgBar.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
  $ProgBar.Visible = $false

  # ---[ PAW OVERALL PROGESS ]
  $PROV = New-Object system.Windows.Forms.Label
  $PROV.text = ""
  $PROV.AutoSize = $true
  $PROV.width = 30
  $PROV.height = 30
  $PROV.Anchor = 'top,right,left'
  $PROV.location = New-Object System.Drawing.Point (10,285)
  $PROV.Font = New-Object System.Drawing.Font ('Consolas',8)
  $PROV.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
  $PROV.Visible = $false

  # ---[ START ISO + VM ]
  $MAKEVMISO.Add_Click({

      MakeISOVM
      $VMPromptForm.Show()

    })

  # ---[ START ISO + VM ]
  $VMEXIT.Add_Click({

      $VMPromptForm.Close()

    })

  # ---[ ADD CONTROLS TO THE FORM ]
  $VMPromptForm.controls.AddRange(@($VMSubtitle,$ISOBIN,$ANSFILEBIN,$ANSFILEcheck,$OSCbut,$OSCbutcheck,$ISObut,$ISObutcheck,$MAKEVMISO,$VMEXIT,$MSGBOX,$ProgBar,$PROV))

  # ---[ RUN FUNCTIONS AFTER FORM LOADS ]

  checkAnswerFile
  checkOSCbinaries
  checkISObinaries
  allChecks


  # ---[ LAUNCH THE FORM ]
  [void]$VMPromptForm.ShowDialog()

}

# ---[ PROMPT USER REMOVE VM FORM ]
function PromptRemoveVM {
  # ---[ CREATE USER PROMPT FORM ]
  $REMOVEVMForm = New-Object system.Windows.Forms.Form
  $REMOVEVMForm.ClientSize = New-Object System.Drawing.Point (700,370)
  $REMOVEVMForm.StartPosition = 'CenterScreen'
  $REMOVEVMForm.FormBorderStyle = 'FixedSingle'
  $REMOVEVMForm.MinimizeBox = $false
  $REMOVEVMForm.MaximizeBox = $false
  $REMOVEVMForm.ShowIcon = $false
  $REMOVEVMForm.text = "VM CLEANUP"
  $REMOVEVMForm.TopMost = $true
  $REMOVEVMForm.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")

  # ---[ TITLE ]
  $Title = New-Object System.Windows.Forms.Button
  $Title.FlatStyle = 'Flat'
  $Title.FlatAppearance.BorderSize = 0
  $Title.text = "CHOOSE A VM FROM THE LIST BELOW TO REMOVE"
  $Title.width = 350
  $Title.height = 30
  $Title.Anchor = 'top,right,left'
  $Title.location = New-Object System.Drawing.Point (150,10)
  $Title.Font = New-Object System.Drawing.Font ('Consolas',10,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
  $Title.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
  $Title.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")

  # ---[ VM REFRESH BUTTON ]
  $VMRefresh = New-Object System.Windows.Forms.Button
  $VMRefresh.FlatStyle = 'Flat'
  $VMRefresh.text = "REFRESH"
  $VMRefresh.width = 100
  $VMRefresh.height = 50
  $VMRefresh.Anchor = 'top,right,left'
  $VMRefresh.location = New-Object System.Drawing.Point (470,310)
  $VMRefresh.Font = New-Object System.Drawing.Font ('Consolas',9)
  $VMRefresh.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")

  # ---[ VM DELETE BUTTON ]
  $VMDelete = New-Object System.Windows.Forms.Button
  $VMDelete.FlatStyle = 'Flat'
  $VMDelete.text = "DELETE"
  $VMDelete.width = 100
  $VMDelete.height = 50
  $VMDelete.Anchor = 'top,right,left'
  $VMDelete.location = New-Object System.Drawing.Point (580,310)
  $VMDelete.Font = New-Object System.Drawing.Font ('Consolas',9)
  $VMDelete.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
  $VMDelete.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")


  # ---[ BOTTOM MESSAGE BOX ]
  $VMmsgbox = New-Object System.Windows.Forms.TextBox
  $VMmsgbox.TextAlign = 'center'
  $VMmsgbox.BorderStyle = 1
  $VMmsgbox.width = 450
  $VMmsgbox.height = 50
  $VMmsgbox.Multiline = $true
  $VMmsgbox.Anchor = 'top,right,left'
  $VMmsgbox.location = New-Object System.Drawing.Point (10,310)
  $VMmsgbox.Font = New-Object System.Drawing.Font ('Consolas',8)
  $VMmsgbox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
  $VMmsgbox.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
  $VMmsgbox.ReadOnly = $true

  # --- [ MY OWN PROGRESS BAR :) ]

  $PBVM = New-Object System.Windows.Forms.TextBox
  $PBVM.TextAlign = 'left'
  $PBVM.BorderStyle = 0
  $PBVM.width = 0
  $PBVM.height = 3
  $PBVM.Anchor = 'top,right,left'
  $PBVM.location = New-Object System.Drawing.Point (10,350)
  $PBVM.Enabled = $false
  $PBVM.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
  $PBVM.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
  $PBVM.Visible = $false


  # ---[ DATA GRID VIEW ]
  $data = New-Object System.Windows.Forms.DataGridView
  $data.width = 670
  $data.height = 250
  $data.Anchor = 'top,right,left'
  $data.location = New-Object System.Drawing.Point (10,50)
  $data.Font = New-Object System.Drawing.Font ('Consolas',9)
  $data.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
  $data.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
  $data.ColumnCount = 2
  $data.ColumnHeadersVisible = $true
  $data.GridColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
  $data.BackgroundColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
  $data.SelectionMode = 'FullRowSelect'
  $data.Columns[0].Name = "NAME"
  $data.Columns[1].Name = "STATE"
  $data.AllowUserToAddRows = $false
  $data.ReadOnly = $true
  $data.MultiSelect = $false
  $data.RowHeadersVisible = $false
  $data.AutoSizeColumnsMode = 'fill'
  $data.AllowUserToResizeRows = $false

  # ---[ LIST ALL CURRENT VMs ]
  function ListVMS {

    $data.Rows.Clear()

    $VMlist = Get-VM | Select-Object Name,State

    $VMlist | ForEach-Object {

      [void]$data.Rows.Add($_.Name,$_.State)

    }

  }

  # ---[ STOP & DELETE SELECTED VM ]
  function DeleteVMS {

    $VM = $data.CurrentRow.Cells['name'].Value

    $PBVM.Visible = $true
    $PBVM.width = 25
    $VMmsgbox.text = "`r`nTurning off $VM, please wait..."

    $VMISO = (Get-VMDvdDrive $VM).Path

    Get-Process vmconnect | Where-Object { $_.MainWindowTitle -eq "$VM on $env:COMPUTERNAME - Virtual Machine Connection" } | Stop-Process -Force -ErrorAction SilentlyContinue

    Get-VM $VM | Stop-VM -Force -TurnOff -Confirm:$false -ErrorAction SilentlyContinue

    (5..1) | ForEach-Object {
      Start-Sleep -Seconds 1
      $PBVM.width = $PBVM.width + 50
      $REMOVEVMForm.Show()
    }


    if ((Get-VM $VM).State -eq "Off") {

      $VMmsgbox.text = "`r`nDeleting $VM, please wait (do not close this window!)..."

      Get-VM $VM | Remove-VM -Force -ErrorAction SilentlyContinue

      (5..1) | ForEach-Object {
        Start-Sleep -Seconds 1
        $PBVM.width = $PBVM.width + 25
        $REMOVEVMForm.Show()
      }

      Remove-Item "$VMs\$VM" -Recurse -Force
      Remove-Item "$VMs\$VM.vhdx" -Force
      Remove-Item $VMISO -Force

      (2..1) | ForEach-Object {
        Start-Sleep -Seconds 1
        $PBVM.width = $PBVM.width + 25
      }

      $VMmsgbox.text = "`r`n$VM has been deleted."

    }


    ListVMS
  }


  ListVMS

  # ---[ REFRESH VM LIST BUTTON FUNCTION ]
  $VMRefresh.Add_Click({
      $VMmsgbox.text = "`r`nRefreshing list..."
      ListVMS
      $REMOVEVMForm.Show()

    })

  # ---[ ADD THE CONTROLS TO THE FORM ]
  $REMOVEVMForm.controls.AddRange(@($Title,$VM,$VMDelete,$VMRefresh,$data,$VMmsgbox,$PBVM))

  # ---[ DELETE VM BUTTON FUNCTION ]
  $VMDelete.Add_Click({

      DeleteVMS
      $REMOVEVMForm.Show()

    })

  # ---[ LAUNCH THE FORM ]
  [void]$REMOVEVMForm.ShowDialog()
}

# ---[ PROMPT USER FOR USB ]
function PromptUSB{

  

}

# ---[ FILE BROWSER DIALOG FOR ISO FILES ]
function SourceFiles {

  $Source = New-Object System.Windows.Forms.OpenFileDialog -Property @{
    InitialDirectory = [Environment]::GetFolderPath('Desktop')
    MultiSelect = $false
    ValidateNames = $true
    Filter = 'ISO files (*.iso)| *.iso'
  }
  $null = $Source.ShowDialog()

  if ($Source.Filename -like "*.iso") {

    Write-Host $Source.Filename
    $SOURCEfiles2.Visible = $true

    $ISODRV = Mount-DiskImage -ImagePath $Source.Filename

    $USBFIL = ($ISODRV | Get-Volume).DriveLetter + ":\*"

    $SOURCEfiles.text = $USBFIL
    $global:SRC = $USBFIL
  }
  else {

    $SOURCEfiles.text = "ATTACH ISO..."
    $SOURCEfiles2.Visible = $false
    return

  }

}

# ---[ DISMOUNT ALL ISO DRIVES ]
function DetachISODrives {

  if ((Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -ne "C:\" }).Name -ne $null)
  {
    (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -ne "C:\" }).Name | ForEach-Object { Dismount-DiskImage -DevicePath "\\.\$($_):" }

    $SOURCEfiles.text = "ATTACH ISO..."
    $SOURCEfiles.Enabled = $true
  }
  else {

    $SOURCEfiles.text = "ATTACH ISO..."
    $SOURCEfiles.Enabled = $true
  }
}

# ---[ FILE BROWSER DIALOG FOR OSCDIMG FILES]
function OSCDIMGSourceFiles {

  $Source2 = New-Object System.Windows.Forms.FolderBrowserDialog
  $Source2.SelectedPath = $Source2.RootFolder = [System.Environment+SpecialFolder]'MyComputer'
  $Source2.ShowNewFolderButton = $false
  $Source2.Description = "Select Source Folder"

  $loop = $true
  while ($loop)
  {
    if ($Source2.ShowDialog() -eq "OK")
    {
      $loop = $false

      #Insert your script here

    } else
    {
      $res = [System.Windows.Forms.MessageBox]::Show("You clicked Cancel. Would you like to try again or exit?","Select a location",[System.Windows.Forms.MessageBoxButtons]::RetryCancel)
      if ($res -eq "Cancel")
      {
        #Ends script
        return
      }
    }
  }
  $OSCDIMGfiles2.Visible = $true
  $global:SRC2 = $Source2.SelectedPath
  $Source2.Dispose()
}

# ---[ ANSWERFILE ]
function AnswerFile ($UILANGUAGE,$INPUTLOCALE,$TIMEZONE,$KEY,$COMPUTERNAME,$ORG,$APPS,$PROTECTMYPC,$HIDEEULA,$HIDEOEMREG,$HIDEWIRELESSOOBE,$EDITION) {
  $global:AutounattendXML = @"
<?xml version="1.0" encoding="utf-8"?>
  <unattend xmlns="urn:schemas-microsoft-com:unattend">
    <!-- SETUP UI Language -->
        <settings pass="windowsPE">
            <component language="neutral" name="Microsoft-Windows-International-Core-WinPE" versionScope="nonSxS" publicKeyToken="31bf3856ad364e35" processorArchitecture="amd64"
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
              <SetupUILanguage>
                    <UILanguage>$UILANGUAGE</UILanguage>
              </SetupUILanguage>
                <InputLocale>$INPUTLOCALE</InputLocale>
                <SystemLocale>$UILANGUAGE</SystemLocale>
                <UILanguage>$UILANGUAGE</UILanguage>
                <UILanguageFallback>$UILANGUAGE</UILanguageFallback>
                <UserLocale>$UILANGUAGE</UserLocale>
            </component>
    <!-- Format disk 0 using UEFI partitioning -->
            <component language="neutral" name="Microsoft-Windows-Setup" versionScope="nonSxS" publicKeyToken="31bf3856ad364e35" processorArchitecture="amd64"
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
                <DiskConfiguration>
    <Disk wcm:action="add">
    <DiskID>0</DiskID>
    <WillWipeDisk>true</WillWipeDisk>
    <CreatePartitions>
    <!-- Windows RE Tools partition -->
    <CreatePartition wcm:action="add">
    <Order>1</Order>
    <Type>Primary</Type>
    <Size>300</Size>
    </CreatePartition>
    <!-- System partition (ESP) -->
    <CreatePartition wcm:action="add">
    <Order>2</Order>
    <Type>EFI</Type>
    <Size>100</Size>
    </CreatePartition>
    <!-- Microsoft reserved partition (MSR) -->
    <CreatePartition wcm:action="add">
    <Order>3</Order>
    <Type>MSR</Type>
    <Size>128</Size>
    </CreatePartition>
    <!-- Windows partition -->
    <CreatePartition wcm:action="add">
    <Order>4</Order>
    <Type>Primary</Type>
    <Extend>true</Extend>
    </CreatePartition>
    </CreatePartitions>
    <ModifyPartitions>
    <!-- Windows RE Tools partition -->
    <ModifyPartition wcm:action="add">
    <Order>1</Order>
    <PartitionID>1</PartitionID>
    <Label>WINRE</Label>
    <Format>NTFS</Format>
    <TypeID>DE94BBA4-06D1-4D40-A16A-BFD50179D6AC</TypeID>
    </ModifyPartition>
    <!-- System partition (ESP) -->
    <ModifyPartition wcm:action="add">
    <Order>2</Order>
    <PartitionID>2</PartitionID>
    <Label>System</Label>
    <Format>FAT32</Format>
    </ModifyPartition>
    <!-- MSR partition does not need to be modified -->
    <ModifyPartition wcm:action="add">
    <Order>3</Order>
    <PartitionID>3</PartitionID>
    </ModifyPartition>
    <!-- Windows partition -->
    <ModifyPartition wcm:action="add">
    <Order>4</Order>
    <PartitionID>4</PartitionID>
    <Label>OS</Label>
    <Letter>C</Letter>
    <Format>NTFS</Format>
    </ModifyPartition>
    </ModifyPartitions>
    </Disk>
    </DiskConfiguration>
    <ImageInstall>
    <OSImage>
    <InstallTo>
    <DiskID>0</DiskID>
    <PartitionID>4</PartitionID>
    </InstallTo>
    <InstallToAvailablePartition>false</InstallToAvailablePartition>
    </OSImage>
    </ImageInstall>
    <!-- Sets the power scheme to high performance in WinPE for faster imaging -->
        <RunSynchronous>
            <RunSynchronousCommand>
                <Order>1</Order>
                    <Path>cmd /c PowerCfg.exe /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c</Path>
            </RunSynchronousCommand>
        </RunSynchronous>
    <UserData>
    <ProductKey>
    <Key>$KEY</Key>
    <WillShowUI>Never</WillShowUI>
    </ProductKey>
    <AcceptEula>true</AcceptEula>
    <FullName></FullName>
    <Organization>$ORG</Organization>
    </UserData>
    </component>
    </settings>
    <!-- Install Drivers of the machine you're building - add them in the root USB "Drivers" folder -->
        <settings pass="offlineServicing">
            <component name="Microsoft-Windows-PnpCustomizationsNonWinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"
                xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <DriverPaths>
                    <PathAndCredentials wcm:action="add" wcm:keyValue="1">
                        <Path>C:\Drivers</Path>
                    </PathAndCredentials>
                    <PathAndCredentials wcm:action="add" wcm:keyValue="2">
                        <Path>D:\Drivers</Path>
                    </PathAndCredentials>
                    <PathAndCredentials wcm:action="add" wcm:keyValue="3">
                        <Path>E:\Drivers</Path>
                    </PathAndCredentials>
                    <PathAndCredentials wcm:action="add" wcm:keyValue="4">
                        <Path>F:\Drivers</Path>
                    </PathAndCredentials>
                </DriverPaths>
            </component>
        </settings>
    <settings pass="specialize">
            <component language="neutral" name="Microsoft-Windows-Deployment" versionScope="nonSxS" publicKeyToken="31bf3856ad364e35" processorArchitecture="amd64"
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
    <!-- Custom commands -->
                <RunSynchronous>
                <RunSynchronousCommand wcm:action="add"><Order>1</Order><Path>cmd /c powercfg.exe /overlaysetactive overlay_scheme_max</Path></RunSynchronousCommand>$APPS
                </RunSynchronous>
            </component>
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <TimeZone>$TIMEZONE</TimeZone>
    <ComputerName>$COMPUTERNAME</ComputerName>
    <ProductKey>$KEY</ProductKey>
    </component>
    </settings>
    <!-- Hide EULA / OEM Registrations / ProtectYourPC -->
        <settings pass="oobeSystem">
            <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <OOBE>
                    <HideEULAPage>$HIDEEULA</HideEULAPage>
                    <HideOEMRegistrationScreen>$HIDEOEMREG</HideOEMRegistrationScreen>
                    <HideOnlineAccountScreens>false</HideOnlineAccountScreens>
                    <HideWirelessSetupInOOBE>$HIDEWIRELESSOOBE</HideWirelessSetupInOOBE>
                    <ProtectYourPC>$PROTECTMYPC</ProtectYourPC>
                </OOBE>
            <UserAccounts>
                <LocalAccounts>
                  <LocalAccount wcm:action="add">
                    <Description></Description>
                    <DisplayName>PAWUSER</DisplayName>
                    <Group>Users</Group>
                    <Name>PAWUSER</Name>
                  </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
              <RegisteredOwner>PAWUSER</RegisteredOwner>
            </component>
            <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
               <InputLocale>$INPUTLOCALE</InputLocale>
               <SystemLocale>$UILANGUAGE</SystemLocale>
               <UILanguage>$UILANGUAGE</UILanguage>
               <UserLocale>$UILANGUAGE</UserLocale>
            </component>
        </settings>
</unattend>
<!--.....................................................
    Type:       Windows Answer File
    Build:      $EDITION
    Language:   $UILANGUAGE
    Created by: $Author 
    Created on: $CreationDate
.....................................................-->
"@
}

# ---[ Define Answer file info]
$global:Author = $env:USERNAME
$global:CreationDate = Get-Date

# ---[ V ADJUSTERS ]
$Vloc = -50
$Bloc = -20

# ---[ CREATE GUI Form ]
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

$Form = New-Object system.Windows.Forms.Form
$Form.ClientSize = New-Object System.Drawing.Point (700,900)
$Form.StartPosition = 'CenterScreen'
$Form.FormBorderStyle = 'FixedSingle'
$Form.MinimizeBox = $true
$Form.MaximizeBox = $false
$Form.ShowIcon = $false
$Form.text = "Windows Answer File Generator $Ver"
$Form.TopMost = $false
$Form.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#252525")

# ---[ CONVERT FROM BASE64 TO LOGO ]
$imageBytes = [Convert]::FromBase64String($imgdata2)
$ms = New-Object IO.MemoryStream ($imageBytes,0,$imageBytes.Length)
$ms.Write($imageBytes,0,$imageBytes.Length);
$icon = [System.Drawing.Image]::FromStream($ms,$true)


# ---[ FORM PAW LOGO ]
$pictureBox = New-Object Windows.Forms.PictureBox
$pictureBox.width = ($icon.Size.width)
$pictureBox.height = ($icon.Size.height)
$pictureBox.Image = $icon
$pictureBox.location = New-Object System.Drawing.Point (10,10)

# ---[ GUI LEFT SECTION TITLE ]
$Title = New-Object System.Windows.Forms.Label
$Title.text = "WAF CREATOR"
$Title.TextAlign = 'MiddleCenter'
$Title.width = 190
$Title.height = 60
$Title.Anchor = 'top,right,left'
$Title.location = New-Object System.Drawing.Point (80,10)
$Title.Font = New-Object System.Drawing.Font ('Consolas',20,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
$Title.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
$Title.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")

# ---[ GUI RIGHT SECTION ]
$Title2 = New-Object System.Windows.Forms.Label
$Title2.text = "[ALL FIELDS MARKED WITH AN * NEED TO BE SELECTED!]"
$Title2.TextAlign = 'MiddleCenter'
$Title2.width = 440
$Title2.height = 60
$Title2.Anchor = 'top,right,left'
$Title2.location = New-Object System.Drawing.Point (230,10)
$Title2.Font = New-Object System.Drawing.Font ('Consolas',9,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
$Title2.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
$Title2.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")

# ---[ CREATE CURRENT VM BUTTON ]
$THEME = New-Object System.Windows.Forms.Button
$THEME.FlatStyle = 'Flat'
$THEME.text = "TOGGLE THEME"
$THEME.width = 90
$THEME.height = 20
$THEME.Anchor = 'top,right,left'
$THEME.location = New-Object System.Drawing.Point (350,75)
$THEME.Font = New-Object System.Drawing.Font ('Consolas',8)
$THEME.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
$THEME.FlatAppearance.BorderSize = 0

# ---[ CREATE CURRENT VM BUTTON ]
$CURRENTVM = New-Object System.Windows.Forms.Button
$CURRENTVM.FlatStyle = 'Flat'
$CURRENTVM.text = "RELOAD VM"
$CURRENTVM.width = 80
$CURRENTVM.height = 20
$CURRENTVM.Anchor = 'top,right,left'
$CURRENTVM.location = New-Object System.Drawing.Point (440,75)
$CURRENTVM.Font = New-Object System.Drawing.Font ('Consolas',8)
$CURRENTVM.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
$CURRENTVM.FlatAppearance.BorderSize = 0

# ---[ REMOVE VM BUTTON ]
$REMOVEVM = New-Object System.Windows.Forms.Button
$REMOVEVM.FlatStyle = 'Flat'
$REMOVEVM.text = "REMOVE VM"
$REMOVEVM.width = 80
$REMOVEVM.height = 20
$REMOVEVM.Anchor = 'top,right,left'
$REMOVEVM.location = New-Object System.Drawing.Point (520,75)
$REMOVEVM.Font = New-Object System.Drawing.Font ('Consolas',8)
$REMOVEVM.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
$REMOVEVM.FlatAppearance.BorderSize = 0

# ---[ HELP DOCS BUTTON SECTION ]
$HELPDOCS = New-Object System.Windows.Forms.Button
$HELPDOCS.FlatStyle = 'Flat'
$HELPDOCS.text = "HELP DOCS"
$HELPDOCS.width = 70
$HELPDOCS.height = 20
$HELPDOCS.Anchor = 'top,right,left'
$HELPDOCS.location = New-Object System.Drawing.Point (600,75)
$HELPDOCS.Font = New-Object System.Drawing.Font ('Consolas',8)
$HELPDOCS.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
$HELPDOCS.FlatAppearance.BorderSize = 0

# ---[ DETACH ISO DRIVES BUTTON SECTION ]
$DETACHDRVS = New-Object System.Windows.Forms.Button
$DETACHDRVS.FlatStyle = 'Flat'
$DETACHDRVS.text = "DETACH ISO DRIVES"
$DETACHDRVS.width = 120
$DETACHDRVS.height = 20
$DETACHDRVS.Anchor = 'top,right,left'
$DETACHDRVS.location = New-Object System.Drawing.Point (220,75)
$DETACHDRVS.Font = New-Object System.Drawing.Font ('Consolas',8)
$DETACHDRVS.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
$DETACHDRVS.FlatAppearance.BorderSize = 0

# ---[ GENERAL SETTINGS SECTION ]

$GeneralSettings = New-Object system.Windows.Forms.Label
$GeneralSettings.text = "GENERAL SETTINGS"
$GeneralSettings.AutoSize = $true
$GeneralSettings.width = 457
$GeneralSettings.height = 142
$GeneralSettings.Anchor = 'top,right,left'
$GeneralSettings.location = New-Object System.Drawing.Point (10,(140 + $Vloc))
$GeneralSettings.Font = New-Object System.Drawing.Font ('Consolas',15,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
$GeneralSettings.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#278BCE")

# ---[ GS: PRODUCT KEY & COMBO BOX ]

$ProductKey = New-Object System.Windows.Forms.Label
$ProductKey.FlatStyle = 'Flat'
$ProductKey.text = "PRODUCT KEY >"
$ProductKey.width = 150
$ProductKey.height = 30
$ProductKey.Anchor = 'top,right,left'
$ProductKey.location = New-Object System.Drawing.Point (10,(185 + $Vloc))
$ProductKey.Font = New-Object System.Drawing.Font ('Consolas',9)
$ProductKey.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#eeeeee")

$PKEYCombobox = New-Object System.Windows.Forms.Combobox
$PKEYCombobox.FlatStyle = 0
$PKEYCombobox.width = 490
$PKEYCombobox.height = 50
$PKEYCombobox.Anchor = 'top,right,left'
$PKEYCombobox.location = New-Object System.Drawing.Point (180,(180 + $Vloc))
$PKEYCombobox.Font = New-Object System.Drawing.Font ('Consolas',9)
$PKEYCombobox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
$PKEYCombobox.text = "Choose Product SKU*"

$Edition | ConvertFrom-Csv | Sort-Object -Property Name | ForEach-Object { [void]$PKEYCombobox.Items.Add($_.Name) }

# ---[ GS: SETUP LANGUAGE & COMBO BOX ]

$SetupLanguage = New-Object system.Windows.Forms.Label
$SetupLanguage.FlatStyle = 'Flat'
$SetupLanguage.text = "SETUP LANGUAGE >"
$SetupLanguage.width = 150
$SetupLanguage.height = 30
$SetupLanguage.Anchor = 'top,right,left'
$SetupLanguage.location = New-Object System.Drawing.Point (10,(225 + $Vloc))
$SetupLanguage.Font = New-Object System.Drawing.Font ('Consolas',9)
$SetupLanguage.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#eeeeee")

$SULACombobox = New-Object System.Windows.Forms.Combobox
$SULACombobox.FlatStyle = 0
$SULACombobox.width = 490
$SULACombobox.height = 50
$SULACombobox.Anchor = 'top,right,left'
$SULACombobox.location = New-Object System.Drawing.Point (180,(220 + $Vloc))
$SULACombobox.Font = New-Object System.Drawing.Font ('Consolas',9)
$SULACombobox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")

# ---[ ADD LANGUAGE COUNT & DISPLAY THEM IN COMBOBOX ]
$TotalLang = ($SETUPUI | ConvertFrom-Csv).count
$SETUPUI | ConvertFrom-Csv | Sort-Object -Property Language | ForEach-Object { [void]$SULACombobox.Items.Add($_.Language) }
$SULACombobox.text = "Choose from $TotalLang installer languages*"


#---[ RS: TIMEZONES COMBO BOX ]

$TZINPUT = New-Object System.Windows.Forms.Label
$TZINPUT.FlatStyle = 'Flat'
$TZINPUT.text = "TIME ZONE >"
$TZINPUT.width = 150
$TZINPUT.height = 30
$TZINPUT.Anchor = 'top,right,left'
$TZINPUT.location = New-Object System.Drawing.Point (10,(265 + $Vloc))
$TZINPUT.Font = New-Object System.Drawing.Font ('Consolas',9)
$TZINPUT.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#eeeeee")

$TZINCombobox = New-Object System.Windows.Forms.Combobox
$TZINCombobox.FlatStyle = 0
$TZINCombobox.width = 490
$TZINCombobox.height = 50
$TZINCombobox.Anchor = 'top,right,left'
$TZINCombobox.location = New-Object System.Drawing.Point (180,(260 + $Vloc))
$TZINCombobox.Font = New-Object System.Drawing.Font ('Consolas',9)
$TZINCombobox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
$TZINCombobox.text = "Choose a Time Zone*"

# ---[ ADD TIME ZONES TO COMBOBOX ]

$TZ | ConvertFrom-Csv | Sort-Object -Property TZName | ForEach-Object { [void]$TZINCombobox.Items.Add($_.TZName) }

# ---[ GS: COMPUTER NAME & TEXTBOX ]

$CompName = New-Object system.Windows.Forms.Label
$CompName.FlatStyle = 'Flat'
$CompName.text = "COMPUTER NAME >"
$CompName.width = 150
$CompName.height = 30
$CompName.Anchor = 'top,right,left'
$CompName.location = New-Object System.Drawing.Point (10,(305 + $Vloc))
$CompName.Font = New-Object System.Drawing.Font ('Consolas',9)
$CompName.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#eeeeee")

$CompNametxt = New-Object System.Windows.Forms.TextBox
$CompNametxt.width = 150
$CompNametxt.height = 30
$CompNametxt.Anchor = 'top,right,left'
$CompNametxt.location = New-Object System.Drawing.Point (180,(300 + $Vloc))
$CompNametxt.Font = New-Object System.Drawing.Font ('Consolas',9)
$CompNametxt.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")

# ---[ CREATE RANDOM GENERATED COMPUTER NAME ]
$randnumbers = (0..9) | Get-Random -Count 4 | ForEach-Object { $_ }
$randletters = (65..90) | Get-Random -Count 4 | ForEach-Object { [char]$_ }
$serial = "PC-" + $randletters + $randnumbers
$serial = $serial -replace '\s',''

$CompNametxt.text = $serial

# ---[ GS: ORG NAME & TEXTBOX ]

$OrgName = New-Object system.Windows.Forms.Label
$OrgName.FlatStyle = 'Flat'
$OrgName.text = "ORGANIZATION NAME >"
$OrgName.width = 150
$OrgName.height = 30
$OrgName.Anchor = 'top,right,left'
$OrgName.location = New-Object System.Drawing.Point (350,(305 + $Vloc))
$OrgName.Font = New-Object System.Drawing.Font ('Consolas',9)
$OrgName.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#eeeeee")

$OrgNametxt = New-Object System.Windows.Forms.TextBox
$OrgNametxt.text = ""
$OrgNametxt.width = 150
$OrgNametxt.height = 30
$OrgNametxt.Anchor = 'top,right,left'
$OrgNametxt.location = New-Object System.Drawing.Point (520,(300 + $Vloc))
$OrgNametxt.Font = New-Object System.Drawing.Font ('Consolas',9)
$OrgNametxt.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")


# --- [ OOBE SETTINGS ]

$OOBESettings = New-Object system.Windows.Forms.Label
$OOBESettings.text = "OUT OF BOX EXPERIENCE SETTINGS"
$OOBESettings.AutoSize = $true
$OOBESettings.width = 457
$OOBESettings.height = 142
$OOBESettings.Anchor = 'top,right,left'
$OOBESettings.location = New-Object System.Drawing.Point (10,(360 + $Vloc))
$OOBESettings.Font = New-Object System.Drawing.Font ('Consolas',15,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
$OOBESettings.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#278BCE")

# ---[ OS: PROTECT YOUR COMPUTER & COMBO BOX ]

$OOBEPYPC = New-Object System.Windows.Forms.Label
$OOBEPYPC.FlatStyle = 'Flat'
$OOBEPYPC.text = "PROTECT YOUR PC >"
$OOBEPYPC.width = 150
$OOBEPYPC.height = 30
$OOBEPYPC.Anchor = 'top,right,left'
$OOBEPYPC.location = New-Object System.Drawing.Point (10,(405 + $Vloc))
$OOBEPYPC.Font = New-Object System.Drawing.Font ('Consolas',9)
$OOBEPYPC.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#eeeeee")

$OOBEPYPCCombobox = New-Object System.Windows.Forms.Combobox
$OOBEPYPCCombobox.FlatStyle = 0
$OOBEPYPCCombobox.width = 280
$OOBEPYPCCombobox.height = 50
$OOBEPYPCCombobox.Anchor = 'top,right,left'
$OOBEPYPCCombobox.location = New-Object System.Drawing.Point (180,(400 + $Vloc))
$OOBEPYPCCombobox.Font = New-Object System.Drawing.Font ('Consolas',9)
$OOBEPYPCCombobox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
$OOBEPYPCCombobox.text = "Choose a setting (default is 3)"


# ---[https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-shell-setup-oobe-protectyourpc]
$PYPC | ConvertFrom-Csv | Select-Object -Property Name | ForEach-Object { ([void]$OOBEPYPCCombobox.Items.Add($_.Name)) }


# ---[ OS: HIDE EULA PAGE & CHECK BOX ]

$OOBEEULA = New-Object System.Windows.Forms.Label
$OOBEEULA.FlatStyle = 'Flat'
$OOBEEULA.text = "HIDE EULA PAGE >"
$OOBEEULA.width = 150
$OOBEEULA.height = 30
$OOBEEULA.Anchor = 'top,right,left'
$OOBEEULA.location = New-Object System.Drawing.Point (490,(405 + $Vloc))
$OOBEEULA.Font = New-Object System.Drawing.Font ('Consolas',9)
$OOBEEULA.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#eeeeee")

$OSEUCheckbox = New-Object System.Windows.Forms.CheckBox
$OSEUCheckbox.AutoSize = 1
$OSEUCheckbox.FlatStyle = 'Flat'
$OSEUCheckbox.Checked = $true
$OSEUCheckbox.Anchor = 'top,right,left'
$OSEUCheckbox.location = New-Object System.Drawing.Point (650,(405 + $Vloc))
$OSEUCheckbox.Font = New-Object System.Drawing.Font ('Consolas',12)
$OSEUCheckbox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")

# ---[ OS: HIDE OEM REG SCREEN & CHECK BOX ]

$OOBEHOR = New-Object System.Windows.Forms.Label
$OOBEHOR.FlatStyle = 'Flat'
$OOBEHOR.text = "HIDE OEM REGISTRATION SCREEN >"
$OOBEHOR.width = 220
$OOBEHOR.height = 30
$OOBEHOR.Anchor = 'top,right,left'
$OOBEHOR.location = New-Object System.Drawing.Point (10,(445 + $Vloc))
$OOBEHOR.Font = New-Object System.Drawing.Font ('Consolas',9)
$OOBEHOR.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#eeeeee")

$OSHORCheckbox = New-Object System.Windows.Forms.CheckBox
$OSHORCheckbox.AutoSize = 1
$OSHORCheckbox.FlatStyle = 'Flat'
$OSHORCheckbox.Checked = $true
$OSHORCheckbox.Anchor = 'top,right,left'
$OSHORCheckbox.location = New-Object System.Drawing.Point (240,(445 + $Vloc))
$OSHORCheckbox.Font = New-Object System.Drawing.Font ('Consolas',12)
$OSHORCheckbox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")

# ---[ OS: HIDE WIRELESS SETUP IN OOBE & CHECK BOX ]

$OOBEHWS = New-Object System.Windows.Forms.Label
$OOBEHWS.FlatStyle = 'Flat'
$OOBEHWS.text = "HIDE WIRELESS SETUP IN OOBE >"
$OOBEHWS.width = 220
$OOBEHWS.height = 30
$OOBEHWS.Anchor = 'top,right,left'
$OOBEHWS.location = New-Object System.Drawing.Point (10,(485 + $Vloc))
$OOBEHWS.Font = New-Object System.Drawing.Font ('Consolas',9)
$OOBEHWS.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#eeeeee")

$OSHWSCheckbox = New-Object System.Windows.Forms.CheckBox
$OSHWSCheckbox.AutoSize = 1
$OSHWSCheckbox.FlatStyle = 'Flat'
$OSHWSCheckbox.Checked = $false
$OSHWSCheckbox.Anchor = 'top,right,left'
$OSHWSCheckbox.location = New-Object System.Drawing.Point (240,(485 + $Vloc))
$OSHWSCheckbox.Font = New-Object System.Drawing.Font ('Consolas',12)
$OSHWSCheckbox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")


# --- [ FOLDER SETTINGS ]

$FLDSettings = New-Object system.Windows.Forms.Label
$FLDSettings.text = "FOLDER SETTINGS"
$FLDSettings.AutoSize = $true
$FLDSettings.width = 457
$FLDSettings.height = 142
$FLDSettings.Anchor = 'top,right,left'
$FLDSettings.location = New-Object System.Drawing.Point (10,(530 + $Vloc))
$FLDSettings.Font = New-Object System.Drawing.Font ('Consolas',15,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
$FLDSettings.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#278BCE")

# ---[ SOURCE FILES SECTION ]
$SOURCEtitle = New-Object System.Windows.Forms.Label
$SOURCEtitle.FlatStyle = 'Flat'
$SOURCEtitle.text = "ISO SOURCE LOCATION >"
$SOURCEtitle.width = 150
$SOURCEtitle.height = 30
$SOURCEtitle.Anchor = 'top,right,left'
$SOURCEtitle.location = New-Object System.Drawing.Point (10,(575 + $Vloc))
$SOURCEtitle.Font = New-Object System.Drawing.Font ('Consolas',9)
$SOURCEtitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#eeeeee")

# ---[ SOURCE FILES BUTTON SECTION ]
$SOURCEfiles = New-Object System.Windows.Forms.Button
$SOURCEfiles.FlatStyle = 'Flat'
$SOURCEfiles.FlatAppearance.BorderSize = 0
$SOURCEfiles.text = "ATTACH ISO..."
$SOURCEfiles.width = 150
$SOURCEfiles.height = 30
$SOURCEfiles.Anchor = 'top,right,left'
$SOURCEfiles.location = New-Object System.Drawing.Point (180,(570 + $Vloc))
$SOURCEfiles.Font = New-Object System.Drawing.Font ('Consolas',9,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
$SOURCEfiles.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
$SOURCEfiles.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")

# ---[ COPY SOURCE FILES BUTTON SECTION ]
$SOURCEfiles2 = New-Object System.Windows.Forms.Button
$SOURCEfiles2.FlatStyle = 'Flat'
$SOURCEfiles2.FlatAppearance.BorderSize = 0
$SOURCEfiles2.text = "COPY FILES"
$SOURCEfiles2.width = 150
$SOURCEfiles2.height = 30
$SOURCEfiles2.Anchor = 'top,right,left'
$SOURCEfiles2.location = New-Object System.Drawing.Point (350,(570 + $Vloc))
$SOURCEfiles2.Font = New-Object System.Drawing.Font ('Consolas',9,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
$SOURCEfiles2.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
$SOURCEfiles2.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#278BCE")
$SOURCEfiles2.Visible = $false

# ---[ OSCDIMG FILES SECTION ]
$OSCDIMGtitle = New-Object System.Windows.Forms.Label
$OSCDIMGtitle.FlatStyle = 'Flat'
$OSCDIMGtitle.text = "OSCDIMG FILES SOURCE >"
$OSCDIMGtitle.width = 155
$OSCDIMGtitle.height = 30
$OSCDIMGtitle.Anchor = 'top,right,left'
$OSCDIMGtitle.location = New-Object System.Drawing.Point (10,(615 + $Vloc))
$OSCDIMGtitle.Font = New-Object System.Drawing.Font ('Consolas',9)
$OSCDIMGtitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#eeeeee")

# ---[ OSCDIMG FILES BUTTON SECTION ]
$OSCDIMGfiles = New-Object System.Windows.Forms.Button
$OSCDIMGfiles.FlatStyle = 'Flat'
$OSCDIMGfiles.FlatAppearance.BorderSize = 0
$OSCDIMGfiles.text = "BROWSE..."
$OSCDIMGfiles.width = 150
$OSCDIMGfiles.height = 30
$OSCDIMGfiles.Anchor = 'top,right,left'
$OSCDIMGfiles.location = New-Object System.Drawing.Point (180,(610 + $Vloc))
$OSCDIMGfiles.Font = New-Object System.Drawing.Font ('Consolas',9,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
$OSCDIMGfiles.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
$OSCDIMGfiles.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")

# ---[ COPY OSCDIMG FILES BUTTON SECTION ]
$OSCDIMGfiles2 = New-Object System.Windows.Forms.Button
$OSCDIMGfiles2.FlatStyle = 'Flat'
$OSCDIMGfiles2.FlatAppearance.BorderSize = 0
$OSCDIMGfiles2.text = "COPY FILES"
$OSCDIMGfiles2.width = 150
$OSCDIMGfiles2.height = 30
$OSCDIMGfiles2.Anchor = 'top,right,left'
$OSCDIMGfiles2.location = New-Object System.Drawing.Point (350,(610 + $Vloc))
$OSCDIMGfiles2.Font = New-Object System.Drawing.Font ('Consolas',9,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
$OSCDIMGfiles2.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
$OSCDIMGfiles2.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#278BCE")
$OSCDIMGfiles2.Visible = $false


# ---[ HYPERV FILES SECTION ]
$HYPERVtitle = New-Object System.Windows.Forms.Label
$HYPERVtitle.FlatStyle = 'Flat'
$HYPERVtitle.text = "HYPER-V FEATURE >"
$HYPERVtitle.width = 150
$HYPERVtitle.height = 30
$HYPERVtitle.Anchor = 'top,right,left'
$HYPERVtitle.location = New-Object System.Drawing.Point (10,(655 + $Vloc))
$HYPERVtitle.Font = New-Object System.Drawing.Font ('Consolas',9)
$HYPERVtitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#eeeeee")

# ---[ HYPERV FILES BUTTON SECTION ]
$HYPERVfiles = New-Object System.Windows.Forms.Button
$HYPERVfiles.FlatStyle = 'Flat'
$HYPERVfiles.FlatAppearance.BorderSize = 0
$HYPERVfiles.text = "ENABLE"
$HYPERVfiles.width = 150
$HYPERVfiles.height = 30
$HYPERVfiles.Anchor = 'top,right,left'
$HYPERVfiles.location = New-Object System.Drawing.Point (180,(650 + $Vloc))
$HYPERVfiles.Font = New-Object System.Drawing.Font ('Consolas',9,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
$HYPERVfiles.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
$HYPERVfiles.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")

# ---[ CUSTOM COMMANDS ]
$Apps = New-Object System.Windows.Forms.Label
$Apps.text = "CUSTOM COMMANDS"
$Apps.AutoSize = $true
$Apps.width = 457
$Apps.height = 142
$Apps.Anchor = 'top,right,left'
$Apps.location = New-Object System.Drawing.Point (10,(700 + $Vloc))
$Apps.Font = New-Object System.Drawing.Font ('Consolas',15,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
$Apps.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#278BCE")

$APPSadd = New-Object System.Windows.Forms.Button
$APPSadd.FlatStyle = 'Flat'
$APPSadd.text = "TYPE INSTALL COMMAND THEN CLICK +`r`n`r`nTO REMOVE FROM LIST, SELECT COMMAND AND THEN CLICK -"
$APPSadd.width = 150
$APPSadd.height = 160
$APPSadd.Anchor = 'top,right,left'
$APPSadd.location = New-Object System.Drawing.Point (10,(740 + $Vloc))
$APPSadd.Font = New-Object System.Drawing.Font ('Consolas',10)
$APPSadd.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#eeeeee")

$APPStxt = New-Object System.Windows.Forms.TextBox
$APPStxt.text = "Enter install command here (max characters:259)"
$APPStxt.width = 440
$APPStxt.height = 25
$APPStxt.Anchor = 'top,right,left'
$APPStxt.location = New-Object System.Drawing.Point (180,(740 + $Vloc))
$APPStxt.Font = New-Object System.Drawing.Font ('Consolas',9)
$APPStxt.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")

$APPSplus = New-Object System.Windows.Forms.Button
$APPSplus.FlatStyle = 'Flat'
$APPSplus.FlatAppearance.BorderSize = 0
$APPSplus.text = "+"
$APPSplus.width = 40
$APPSplus.height = 40
$APPSplus.Anchor = 'top,right,left'
$APPSplus.location = New-Object System.Drawing.Point (620,(730 + $Vloc))
$APPSplus.Font = New-Object System.Drawing.Font ('Consolas',20)
$APPSplus.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#eeeeee")

$APPSmin = New-Object System.Windows.Forms.Button
$APPSmin.FlatStyle = 'Flat'
$APPSmin.FlatAppearance.BorderSize = 0
$APPSmin.text = "-"
$APPSmin.width = 40
$APPSmin.height = 40
$APPSmin.Anchor = 'top,right,left'
$APPSmin.location = New-Object System.Drawing.Point (660,(730 + $Vloc))
$APPSmin.Font = New-Object System.Drawing.Font ('Consolas',20)
$APPSmin.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#eeeeee")

$APPSLB = New-Object System.Windows.Forms.ListBox
$APPSLB.BorderStyle = 1
$APPSLB.SelectionMode = 'MultiExtended'
$APPSLB.width = 510
$APPSLB.height = 115
$APPSLB.Anchor = 'top,right,left'
$APPSLB.location = New-Object System.Drawing.Point (180,(780 + $Vloc))
$APPSLB.Font = New-Object System.Drawing.Font ('Consolas',9)
$APPSLB.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
$APPSLB.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#252525")


# ---[ CREATE ANSWER FILE BUTTON ]

$CREATEANS = New-Object System.Windows.Forms.Button
$CREATEANS.FlatStyle = 'Flat'
$CREATEANS.FlatAppearance.BorderSize = 0
$CREATEANS.text = "CREATE ANSWER FILE"
$CREATEANS.width = 220
$CREATEANS.height = 30
$CREATEANS.Anchor = 'top,right,left'
$CREATEANS.location = New-Object System.Drawing.Point (10,(880 + $Bloc))
$CREATEANS.Font = New-Object System.Drawing.Font ('Consolas',10,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
$CREATEANS.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
$CREATEANS.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#278BCE")

# ---[ CREATE ANSWER FILE + USB BUTTON ]

$CREATEUSB = New-Object System.Windows.Forms.Button
$CREATEUSB.FlatStyle = 'Flat'
$CREATEUSB.FlatAppearance.BorderSize = 0
$CREATEUSB.text = "CREATE ANSWER FILE + USB"
$CREATEUSB.width = 220
$CREATEUSB.height = 30
$CREATEUSB.Anchor = 'top,right,left'
$CREATEUSB.location = New-Object System.Drawing.Point (240,(880 + $Bloc))
$CREATEUSB.Font = New-Object System.Drawing.Font ('Consolas',10,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
$CREATEUSB.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#000000")
$CREATEUSB.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")

# ---[ CREATE ISO + VM FILE BUTTON ]

$CREATEISOVM = New-Object System.Windows.Forms.Button
$CREATEISOVM.FlatStyle = 'Flat'
$CREATEISOVM.FlatAppearance.BorderSize = 0
$CREATEISOVM.text = "CREATE ANSWER FILE + VM"
$CREATEISOVM.width = 220
$CREATEISOVM.height = 30
$CREATEISOVM.Anchor = 'top,right,left'
$CREATEISOVM.location = New-Object System.Drawing.Point (470,(880 + $Bloc))
$CREATEISOVM.Font = New-Object System.Drawing.Font ('Consolas',10,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
$CREATEISOVM.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
$CREATEISOVM.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#1C73AC")

$OSCBINFILES = Test-Path "$oscdimg\efisys.bin","$oscdimg\efisys_noprompt.bin","$oscdimg\etfsboot.com","$oscdimg\oscdimg.exe"

$ISOFILES = Test-Path "$OfflineBuild\boot","$OfflineBuild\efi","$OfflineBuild\sources" `
  ,"$OfflineBuild\support","$OfflineBuild\setup.exe","$OfflineBuild\bootmgr","$OfflineBuild\bootmgr.efi","$OfflineBuild\autorun.inf"



if ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All).State -eq "Enabled") {
  $HYPERVfiles.Enabled = $false
  $HYPERVfiles.text = "ENABLED"
}

# --- [ LAUNCH CLEAR MOUNTED DRIVES ]
$DETACHDRVS.Add_Click({

    DetachISODrives

  })

$THEME.Add_Click({

    ToggleTheme

  })

# ---[ SOURCE FILES BUTTON CLICK ]
$SOURCEfiles.Add_Click({

    CreateAnswerFileDirectories
    SourceFiles


  })

# ---[ COPY SOURCE FILES BUTTON CLICK ]
$SOURCEfiles2.Add_Click({

    $SOURCEfiles2.text = "COPYING..."
    $SOURCEfiles2.Enabled = $false
    Copy-Item -Path $SRC -Destination $OfflineBuild -Recurse -Force



    if ($ISOFILES -like "False") {
      $SOURCEfiles2.Enabled = $true
      $SOURCEfiles.text = "ATTACH ISO..."
      $SOURCEfiles2.text = "COPY FILES"
    }

    else {
      $SOURCEfiles2.Enabled = $false
      $SOURCEfiles2.text = "FILES COPIED!"
    }


  })

# ---[ OSCDIMG FILES SOURCE BUTTON CLICK ]
$OSCDIMGfiles.Add_Click({
    CreateAnswerFileDirectories
    OSCDIMGSourceFiles
    $OSCDIMGfiles.text = "$SRC2"
    $OSCDIMGfiles2.text = "COPY FILES"
  })

# ---[ COPY OSCDIMG FILES BUTTON CLICK ]
$OSCDIMGfiles2.Add_Click({

    $OSCDIMGfiles2.text = "COPYING..."
    $OSCDIMGfiles2.Enabled = $false
    Copy-Item -Path $SRC2\* -Destination $OSCDIMG -Force


    if ($OSCBINFILES -like "False") {
      $OSCDIMGfiles2.Enabled = $true
      $OSCDIMGfiles.text = "BROWSE..."
      $OSCDIMGfiles2.text = "COPY FILES"
    }

    else {
      $OSCDIMGfiles2.Enabled = $true
      $OSCDIMGfiles2.text = "FILES COPIED!"
      $CREATEISOVM.Enabled = $true
    }


  })

# ---[ INSTALL HYPER-V FEATURE (REQUIRES A REBOOT!) ]
$HYPERVfiles.Add_Click({

    $ArgsList = "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All"
    $Result = Start-Process -File powershell.exe -ArgumentList $ArgsList -Wait

    $TI = "HYPER-V FEATURE ENABLED!"
    $BM = ""
    $AM = $true
    $MS = $false
    $PF = [System.Drawing.ColorTranslator]::FromHtml("#B32C1E")

    if ($Result.RestartNeeded -eq $true -and $Result.Online -eq $true)
    {
      $FT = "This machine will reboot in 30 seconds."

      PromptUser $TI $FT $BM $AM $MS $PF
      Start-Sleep -Seconds 30
      Restart-Computer $env:COMPUTERNAME -Force
    }
    else {
      $FT = "No need for restart."
      $PF = [System.Drawing.ColorTranslator]::FromHtml("#B32C1E")
      PromptUser $TI $FT $BM $AM $MS $PF
    }
  })


# --- [ LAUNCH HELP DOCS ]
$HELPDOCS.Add_Click({

    CreateAnswerFileDirectories
    HelpDocs

  })


# ---[ ADD ALL THE OBJECTS TO THE FORM ]
$Form.controls.AddRange(@($Title,$Title2,$pictureBox,$DETACHDRVS,$THEME,$CURRENTVM,$REMOVEVM,$HELPDOCS `
      ,$GeneralSettings,$ProductKey,$SetupLanguage,$SULACombobox,$PKEYCombobox,$CompName,$CompNametxt,$OrgName,$OrgNametxt `
      ,$TZINPUT,$TZINCombobox `
      ,$OOBESettings,$OOBEPYPC,$OOBEPYPCCombobox,$OOBEEULA,$OSEUCheckbox,$OOBEHOR,$OSHORCheckbox,$OOBEHWS,$OSHWSCheckbox `
      ,$FLDSettings,$SOURCEtitle,$SOURCEfiles,$SOURCEfiles2,$OSCDIMGtitle,$OSCDIMGfiles,$OSCDIMGfiles2,$HYPERVtitle,$HYPERVfiles `
      ,$Apps,$APPSadd,$APPStxt,$APPSplus,$APPSmin,$APPSLB `
      ,$CREATEANS,$CREATEUSB,$CREATEISOVM))


# ---[ APPS: ADD A COMMAND LINE ]
$APPSplus.Add_Click({

    if ($APPStxt.text -ne $null) {
      $APPSLB.Items.Add($APPStxt.text)
      $APPStxt.text = "<Enter install command here>"
    }
  })

# ---[ APPS: REMOVE A COMMAND LINE ]
$APPSmin.Add_Click({
    if ($APPSLB.SelectedItems -ne $null) {
      $items = $APPSLB.SelectedItems
      foreach ($item in $items) {
        $APPSLB.Items.Remove($item)
      }
    }
  })


# ---[ "CREATE ANSWER FILE" BUTTON  ]
$CREATEANS.Add_Click({

    #---[ VALIDATE FORM THEN CREATE ANSWER FILE WITH SELECTED VALUES AND EXPORT IT.]

    if (($PKEYCombobox.SelectedItem -and $SULACombobox.SelectedItem -and $TZINCombobox.SelectedItem) -gt 0) {

      # ---[ GENERAL SETTINGS ]
      $KEY = ($Edition | ConvertFrom-Csv | Where-Object { $_.Name -eq $PKEYCombobox.SelectedItem }).Key
      $UILANGUAGE = ($SETUPUI | ConvertFrom-Csv | Where-Object { $_.Language -eq $SULACombobox.SelectedItem }).Locale
      $INPUTLOCALE = ($SETUPUI | ConvertFrom-Csv | Where-Object { $_.Language -eq $SULACombobox.SelectedItem }).Keyboard
      $TIMEZONE = ($TZ | ConvertFrom-Csv | Where-Object { $_.TZName -eq $TZINCombobox.SelectedItem }).TimeZone
      $COMPUTERNAME = $CompNametxt.text
      $ORG = $OrgNametxt.text
      $EDITION = $PKEYCombobox.SelectedItem

      # ---[ OOBE SETTINGS ]
      if ($OOBEPYPCCombobox.SelectedItem -ne $null)
      {
        ($PROTECTMYPC = ($PYPC | ConvertFrom-Csv | Where-Object { $_.Name -eq $OOBEPYPCCombobox.SelectedItem }).Setting)
      }
      else {

        $PROTECTMYPC = "3"
      }

      $HIDEEULA = if ($OSEUCheckbox.Checked -eq $true) { "true" } else { "false" }
      $HIDEOEMREG = if ($OSHORCheckbox.Checked -eq $true) { "true" } else { "false" }
      $HIDEWIRELESSOOBE = if ($OSHWSCheckbox.Checked -eq $true) { "true" } else { "false" }

      # ---[ ADD CUSTOM COMMANDS ]
      $ListCmds = $APPSLB.Items
      $APPS = ''
      $c = 2

      foreach ($ListCmd in $ListCmds) {

        $APPS += "<RunSynchronousCommand wcm:action=`"add`"><Order>$c</Order><Path>$ListCmd</Path></RunSynchronousCommand>"
        $c++
      }

      AnswerFile $UILANGUAGE $INPUTLOCALE $TIMEZONE $KEY $COMPUTERNAME $ORG $APPS $PROTECTMYPC $HIDEEULA $HIDEOEMREG $HIDEWIRELESSOOBE $EDITION



<#       $TI = "SUCCESS! YOUR ANSWER FILE HAS BEEN SAVED IN:"
      $FT = "$WAF_FINAL"
      $BM = "`r`n`   1. COPY THE FILE FROM THE ABOVE LOCATION AND PLACE IT ON THE ROOT OF YOUR BOOTABLE USB DRIVE.`r`n`r`n   2. INSERT YOUR USB DRIVE INTO A POWERED OFF MACHINE.`r`n`r`n   3. POWER ON MACHINE AND PRESS [F12] FOR THE BOOT MENU.`r`n`r`n   4. SELECT THE USB DRIVE AND WAIT FOR THE BUILD TO FINISH."
      $AM = $false
      $MS = $true
      $PF = [System.Drawing.ColorTranslator]::FromHtml("#000000")
      PromptUser $TI $FT $BM $AM $MS $PF #>

      #$ANSTYPE = 1
      CreateAnswerFileDirectories
      CreateAutounattendFile $AutounattendXML 1
      


    }


    else {

      $TI = "OH NO!!!"
      $FT = "PLEASE SELECT ALL THE FIELDS MARKED WITH AN * !!!"
      $BM = ""
      $AM = $true
      $MS = $false
      $PF = [System.Drawing.ColorTranslator]::FromHtml("#B32C1E")

      PromptUser $TI $FT $BM $AM $MS $PF

    }
  })


# ---[ "CREATE ISO + USB + ANSWER" FILE BUTTON ]
$CREATEUSB.Add_Click({

    #---[ VALIDATE FORM THEN CREATE ANSWER FILE WITH SELECTED VALUES AND EXPORT IT.]

    if (($PKEYCombobox.SelectedItem -and $SULACombobox.SelectedItem -and $TZINCombobox.SelectedItem) -gt 0) {

      # ---[ GENERAL SETTINGS ]
      $KEY = ($Edition | ConvertFrom-Csv | Where-Object { $_.Name -eq $PKEYCombobox.SelectedItem }).Key
      $UILANGUAGE = ($SETUPUI | ConvertFrom-Csv | Where-Object { $_.Language -eq $SULACombobox.SelectedItem }).Locale
      $INPUTLOCALE = ($SETUPUI | ConvertFrom-Csv | Where-Object { $_.Language -eq $SULACombobox.SelectedItem }).Keyboard
      $TIMEZONE = ($TZ | ConvertFrom-Csv | Where-Object { $_.TZName -eq $TZINCombobox.SelectedItem }).TimeZone
      $COMPUTERNAME = $CompNametxt.text
      $ORG = $OrgNametxt.text
      $EDITION = $PKEYCombobox.SelectedItem

      # ---[ OOBE SETTINGS ]
      if ($OOBEPYPCCombobox.SelectedItem -ne $null)
      {
        ($PROTECTMYPC = ($PYPC | ConvertFrom-Csv | Where-Object { $_.Name -eq $OOBEPYPCCombobox.SelectedItem }).Setting)
      }
      else {

        $PROTECTMYPC = "1"
      }

      $HIDEEULA = if ($OSEUCheckbox.Checked -eq $true) { "true" } else { "false" }
      $HIDEOEMREG = if ($OSHORCheckbox.Checked -eq $true) { "true" } else { "false" }
      $HIDEWIRELESSOOBE = if ($OSHWSCheckbox.Checked -eq $true) { "true" } else { "false" }


      # ---[ ADD CUSTOM COMMANDS ]
      $ListCmds = $APPSLB.Items
      $APPS = ''
      $c = 2

      foreach ($ListCmd in $ListCmds) {

        $APPS += "<RunSynchronousCommand wcm:action=`"add`"><Order>$c</Order><Path>$ListCmd</Path></RunSynchronousCommand>"
        $c++
      }
    }
    AnswerFile $UILANGUAGE $INPUTLOCALE $TIMEZONE $KEY $COMPUTERNAME $ORG $APPS $PROTECTMYPC $HIDEEULA $HIDEOEMREG $HIDEWIRELESSOOBE $EDITION

    CreateAnswerFileDirectories
    CreateAutounattendFile $AutounattendXML 2
    #PromptUSB
  })

# ---[ "CREATE ISO + VM + ANSWER FILE" BUTTON ]
$CREATEISOVM.Add_Click({
    #---[ VALIDATE FORM THEN CREATE ANSWER FILE WITH SELECTED VALUES AND EXPORT IT.]

    if (($PKEYCombobox.SelectedItem -and $SULACombobox.SelectedItem -and $TZINCombobox.SelectedItem) -gt 0) {

      # ---[ GENERAL SETTINGS ]
      $KEY = ($Edition | ConvertFrom-Csv | Where-Object { $_.Name -eq $PKEYCombobox.SelectedItem }).Key
      $UILANGUAGE = ($SETUPUI | ConvertFrom-Csv | Where-Object { $_.Language -eq $SULACombobox.SelectedItem }).Locale
      $INPUTLOCALE = ($SETUPUI | ConvertFrom-Csv | Where-Object { $_.Language -eq $SULACombobox.SelectedItem }).Keyboard
      $TIMEZONE = ($TZ | ConvertFrom-Csv | Where-Object { $_.TZName -eq $TZINCombobox.SelectedItem }).TimeZone
      $COMPUTERNAME = $CompNametxt.text
      $ORG = $OrgNametxt.text
      $EDITION = $PKEYCombobox.SelectedItem

      # ---[ OOBE SETTINGS ]
      if ($OOBEPYPCCombobox.SelectedItem -ne $null)
      {
        ($PROTECTMYPC = ($PYPC | ConvertFrom-Csv | Where-Object { $_.Name -eq $OOBEPYPCCombobox.SelectedItem }).Setting)
      }
      else {

        $PROTECTMYPC = "1"
      }

      $HIDEEULA = if ($OSEUCheckbox.Checked -eq $true) { "true" } else { "false" }
      $HIDEOEMREG = if ($OSHORCheckbox.Checked -eq $true) { "true" } else { "false" }
      $HIDEWIRELESSOOBE = if ($OSHWSCheckbox.Checked -eq $true) { "true" } else { "false" }


      # ---[ ADD CUSTOM COMMANDS ]
      $ListCmds = $APPSLB.Items
      $APPS = ''
      $c = 2

      foreach ($ListCmd in $ListCmds) {

        $APPS += "<RunSynchronousCommand wcm:action=`"add`"><Order>$c</Order><Path>$ListCmd</Path></RunSynchronousCommand>"
        $c++
      }

      AnswerFile $UILANGUAGE $INPUTLOCALE $TIMEZONE $KEY $COMPUTERNAME $ORG $APPS $PROTECTMYPC $HIDEEULA $HIDEOEMREG $HIDEWIRELESSOOBE $EDITION
      CreateAnswerFileDirectories
      CreateAutounattendFile $AutounattendXML 3
      PromptISOVM
    }

    else {
      $TI = "OH NO!!!"
      $FT = "Please select all the fields marked with an * !!!"
      $BM = ""
      $AM = $true
      $MS = $false
      $PF = [System.Drawing.ColorTranslator]::FromHtml("#B32C1E")

      PromptUser $TI $FT $BM $AM $MS $PF

    }
  })


# ---[ LIST AND REMOVE MULTIPLE VMs ]
$REMOVEVM.Add_Click({
    PromptRemoveVM
  })

# ---[ "CREATE CURRENT VM" BUTTON ]
$CURRENTVM.Add_Click({

    PromptISOVM

  })


#---[ SET FIRST TIME RUN DEFAULT THEME ]
if (!(Test-Path "$WAF\theme.txt")) {
  New-Item "$WAF\Theme.txt" -ItemType File -Force
  "DARK" | Out-File "$WAF\Theme.txt" -Force
}

# ---[ GET CURRENT SET THEME AND APPLY IT ]
$SetTheme = Get-Content "$WAF\Theme.txt"

if ($SetTheme -eq "DARK") {
  DarkTheme
}
else {
  LightTheme
}

if ($OSCBINFILES -like "False" -and $ISOFILES -like "False") {
  $CREATEISOVM.Enabled = $false
  $CREATEUSB.Enabled = $false
  $CREATEUSB.BackColor = "#666666"
}
else {
  $CREATEISOVM.Enabled = $true
  $CREATEUSB.Enabled = $true
}

# ---[ LAUNCH THE FORM ]
[void]$Form.ShowDialog()
