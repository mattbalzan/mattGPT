<#
.SYNOPSIS
    Captures the execution context and read/write access state on a ConfigMgr site or
    SMS Provider server, for diffing a passing invocation against a failing one.

.DESCRIPTION
    Built to isolate 0x80070005 (E_ACCESSDENIED) raised during ConfigurationManager
    module import / CMSite PSDrive creation, where ConfigMgr RBAC is unchanged and
    therefore cannot be the variable.

    Every probe is independent and non-fatal: a failure is recorded with its full
    exception detail and the run continues. Nothing is swallowed.

    All probes are READ-ONLY with one deliberate exception - the HKCU write probe -
    which creates and immediately removes a scratch key. That probe is the point of
    the script, since the module writes to HKCU during initialisation.

    Run this from the SAME caller that exhibits the failure (ESExec / IIS / scheduler),
    not from an interactive console, or the result is meaningless.

.PARAMETER ComputerName
    Target server. Omit to probe locally.

.PARAMETER Credential
    Optional credential for the remote session.

.PARAMETER Label
    Free-text tag written into the output (e.g. 'run1-pass', 'run2-fail') so captures
    can be told apart when diffing.

.PARAMETER OutputPath
    Optional path to write the result as JSON for later comparison.

.PARAMETER SkipWriteProbe
    Suppress the HKCU scratch-key write probe. Read checks only.

.EXAMPLE
    .\Test-CMExecutionContext.ps1 -ComputerName 'cmserver.contoso.com' -Label 'run1' `
        -OutputPath 'C:\Temp\run1.json'

.EXAMPLE
    # Diff two captures
    $a = Get-Content C:\Temp\run1.json | ConvertFrom-Json
    $b = Get-Content C:\Temp\run2.json | ConvertFrom-Json
    Compare-Object $a.Checks $b.Checks -Property Name,Status -PassThru

.NOTES
    Does NOT import the ConfigurationManager module. Loading it is what fails; this
    script measures the preconditions instead.
#>

[CmdletBinding()]
param(
    [string]$ComputerName,

    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]
    $Credential = [System.Management.Automation.PSCredential]::Empty,

    [string]$Label = (Get-Date -Format 'yyyyMMdd-HHmmss'),

    [string]$OutputPath,

    [switch]$SkipWriteProbe
)

$ErrorActionPreference = 'Stop'

$Probe = {
    param([string]$Label, [bool]$SkipWriteProbe)

    # Deliberately permissive inside the probe - each check owns its own error handling.
    $ErrorActionPreference = 'Stop'

    $Checks = [System.Collections.Generic.List[object]]::new()

    # Records a probe outcome. Status is Pass / Fail / Skipped / Info so that a check
    # which is merely informational never reads as a failure when diffing.
    function Add-Check {
        param(
            [string]$Name,
            [string]$Category,
            [string]$Status,
            $Value,
            [System.Management.Automation.ErrorRecord]$ErrorRecord
        )

        $Detail = $null
        $Type   = $null
        $Code   = $null

        if ($ErrorRecord) {
            $Type = $ErrorRecord.Exception.GetType().FullName

            if ($ErrorRecord.Exception.HResult) {
                $Code = "0x{0:X8}" -f $ErrorRecord.Exception.HResult
            }

            # Walk the full chain - the meaningful HRESULT is often two levels down.
            $Chain = @()
            $Ex = $ErrorRecord.Exception
            while ($null -ne $Ex) {
                $Chain += "[{0}] {1}" -f $Ex.GetType().Name, $Ex.Message
                $Ex = $Ex.InnerException
            }
            $Detail = $Chain -join ' --> '
        }

        $Checks.Add([pscustomobject]@{
            Name      = $Name
            Category  = $Category
            Status    = $Status
            Value     = $Value
            ErrorType = $Type
            ErrorCode = $Code
            Error     = $Detail
        })
    }

    # Wraps a probe so a throw is captured rather than aborting the run.
    function Invoke-Probe {
        param(
            [string]$Name,
            [string]$Category,
            [scriptblock]$Test
        )
        try {
            $Value = & $Test
            Add-Check -Name $Name -Category $Category -Status 'Pass' -Value $Value
        }
        catch {
            Add-Check -Name $Name -Category $Category -Status 'Fail' -Value $null -ErrorRecord $_
        }
    }

    #-----------------------------------------------------------------------
    # 1. Identity and token
    #-----------------------------------------------------------------------
    Invoke-Probe -Name 'RunAsUser' -Category 'Identity' -Test {
        [Security.Principal.WindowsIdentity]::GetCurrent().Name
    }

    Invoke-Probe -Name 'IsElevated' -Category 'Identity' -Test {
        $Id = [Security.Principal.WindowsIdentity]::GetCurrent()
        ([Security.Principal.WindowsPrincipal]$Id).IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    Invoke-Probe -Name 'TokenGroupCount' -Category 'Identity' -Test {
        # A filtered token carries noticeably fewer groups. Compare across runs.
        ([Security.Principal.WindowsIdentity]::GetCurrent()).Groups.Count
    }

    Invoke-Probe -Name 'AuthenticationType' -Category 'Identity' -Test {
        [Security.Principal.WindowsIdentity]::GetCurrent().AuthenticationType
    }

    Invoke-Probe -Name 'ImpersonationLevel' -Category 'Identity' -Test {
        [string][Security.Principal.WindowsIdentity]::GetCurrent().ImpersonationLevel
    }

    Invoke-Probe -Name 'IsSystem' -Category 'Identity' -Test {
        [Security.Principal.WindowsIdentity]::GetCurrent().IsSystem
    }

    #-----------------------------------------------------------------------
    # 2. Process and host
    #-----------------------------------------------------------------------
    Invoke-Probe -Name 'ProcessId' -Category 'Process' -Test { $PID }

    Invoke-Probe -Name 'ProcessStartTime' -Category 'Process' -Test {
        (Get-Process -Id $PID).StartTime.ToString('o')
    }

    Invoke-Probe -Name 'ParentProcess' -Category 'Process' -Test {
        # Identifies the wrapper host - ESExec, w3wp, svchost, wsmprovhost.
        $P = Get-CimInstance Win32_Process -Filter "ProcessId=$PID"
        $Parent = Get-CimInstance Win32_Process -Filter "ProcessId=$($P.ParentProcessId)" -EA SilentlyContinue
        if ($Parent) { "$($Parent.Name) ($($Parent.ProcessId))" } else { "unknown ($($P.ParentProcessId))" }
    }

    Invoke-Probe -Name 'PSVersion' -Category 'Process' -Test {
        $PSVersionTable.PSVersion.ToString()
    }

    Invoke-Probe -Name 'LanguageMode' -Category 'Process' -Test {
        # Constrained mode under WDAC will break the module in ways unrelated to access.
        [string]$ExecutionContext.SessionState.LanguageMode
    }

    Invoke-Probe -Name 'Is64BitProcess' -Category 'Process' -Test {
        [Environment]::Is64BitProcess
    }

    Invoke-Probe -Name 'ConcurrentPSHosts' -Category 'Process' -Test {
        # Parallel invocations are a plausible source of intermittent provider errors.
        @(Get-Process -Name 'powershell','pwsh','wsmprovhost' -EA SilentlyContinue |
            Select-Object Name, Id, @{n='Start';e={$_.StartTime.ToString('HH:mm:ss')}}) |
            ForEach-Object { "$($_.Name)/$($_.Id)@$($_.Start)" }
    }

    #-----------------------------------------------------------------------
    # 3. User profile state
    #-----------------------------------------------------------------------
    Invoke-Probe -Name 'UserProfilePath' -Category 'Profile' -Test { $env:USERPROFILE }

    Invoke-Probe -Name 'UserProfileExists' -Category 'Profile' -Test {
        Test-Path -Path $env:USERPROFILE
    }

    Invoke-Probe -Name 'IsTempProfile' -Category 'Profile' -Test {
        # A temp profile is the classic cause of works-once-then-denied.
        $env:USERPROFILE -match 'TEMP|\.bak' -or $env:USERPROFILE -match '\\Temp$'
    }

    Invoke-Probe -Name 'ProfileListBackupEntries' -Category 'Profile' -Test {
        @(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' |
            Where-Object { $_.PSChildName -match '\.bak$' } |
            Select-Object -ExpandProperty PSChildName)
    }

    Invoke-Probe -Name 'TempPath' -Category 'Profile' -Test { $env:TEMP }

    Invoke-Probe -Name 'TempPathReadable' -Category 'Profile' -Test {
        $null = Get-ChildItem -Path $env:TEMP -EA Stop | Select-Object -First 1
        $true
    }

    #-----------------------------------------------------------------------
    # 4. Registry read access
    #-----------------------------------------------------------------------
    $RegistryReads = @(
        @{ Name = 'HKCU_Root';        Path = 'HKCU:\Software' }
        @{ Name = 'HKCU_ConfigMgr10'; Path = 'HKCU:\Software\Microsoft\ConfigMgr10' }
        @{ Name = 'HKCU_AdminUI';     Path = 'HKCU:\Software\Microsoft\ConfigMgr10\AdminUI' }
        @{ Name = 'HKLM_SMS';         Path = 'HKLM:\SOFTWARE\Microsoft\SMS' }
        @{ Name = 'HKLM_SMS_Identification'; Path = 'HKLM:\SOFTWARE\Microsoft\SMS\Identification' }
        @{ Name = 'HKLM_ConfigMgr10'; Path = 'HKLM:\SOFTWARE\Microsoft\ConfigMgr10' }
        @{ Name = 'HKLM_AdminUI';     Path = 'HKLM:\SOFTWARE\Microsoft\ConfigMgr10\AdminUI' }
    )

    foreach ($Reg in $RegistryReads) {
        $Name = $Reg.Name
        $Path = $Reg.Path

        try {
            if (-not (Test-Path -Path $Path)) {
                # Absent is not the same as denied - record it as Info, not Fail.
                Add-Check -Name "RegRead:$Name" -Category 'RegistryRead' `
                          -Status 'Info' -Value "not present: $Path"
                continue
            }

            $Key = Get-Item -Path $Path -EA Stop
            $ValueCount = @($Key.GetValueNames()).Count
            $SubKeyCount = @($Key.GetSubKeyNames()).Count

            Add-Check -Name "RegRead:$Name" -Category 'RegistryRead' -Status 'Pass' `
                      -Value "values=$ValueCount subkeys=$SubKeyCount"
        }
        catch {
            Add-Check -Name "RegRead:$Name" -Category 'RegistryRead' -Status 'Fail' `
                      -Value $Path -ErrorRecord $_
        }
    }

    # ACL read on the HKCU ConfigMgr key - denial here is highly diagnostic.
    Invoke-Probe -Name 'RegAcl:HKCU_ConfigMgr10' -Category 'RegistryRead' -Test {
        $P = 'HKCU:\Software\Microsoft\ConfigMgr10'
        if (-not (Test-Path $P)) { return 'key absent' }
        (Get-Acl -Path $P).Owner
    }

    #-----------------------------------------------------------------------
    # 5. Registry write probe (HKCU) - the module writes here on init
    #-----------------------------------------------------------------------
    if ($SkipWriteProbe) {
        Add-Check -Name 'RegWrite:HKCU' -Category 'RegistryWrite' -Status 'Skipped' -Value $null
    }
    else {
        $ScratchKey = 'HKCU:\Software\__CMContextProbe'
        try {
            $null = New-Item -Path $ScratchKey -Force -EA Stop
            $null = New-ItemProperty -Path $ScratchKey -Name 'Probe' -Value 1 `
                                     -PropertyType DWord -Force -EA Stop
            $Read = (Get-ItemProperty -Path $ScratchKey -Name 'Probe' -EA Stop).Probe
            Remove-Item -Path $ScratchKey -Recurse -Force -EA SilentlyContinue

            Add-Check -Name 'RegWrite:HKCU' -Category 'RegistryWrite' -Status 'Pass' `
                      -Value "write+read ok (value=$Read)"
        }
        catch {
            Remove-Item -Path $ScratchKey -Recurse -Force -EA SilentlyContinue
            Add-Check -Name 'RegWrite:HKCU' -Category 'RegistryWrite' -Status 'Fail' `
                      -Value $ScratchKey -ErrorRecord $_
        }
    }

    #-----------------------------------------------------------------------
    # 6. Console / module file read access
    #-----------------------------------------------------------------------
    $AdminUIPath = $env:SMS_ADMIN_UI_PATH

    Add-Check -Name 'Env:SMS_ADMIN_UI_PATH' -Category 'FileRead' `
              -Status $(if ($AdminUIPath) { 'Pass' } else { 'Fail' }) `
              -Value $AdminUIPath

    if ($AdminUIPath) {
        $ModuleRoot = Split-Path -Path $AdminUIPath -Parent
        $Manifest   = Join-Path $ModuleRoot 'ConfigurationManager.psd1'

        $FileReads = @(
            @{ Name = 'AdminUIBinDir';   Path = $AdminUIPath;  Type = 'Dir'  }
            @{ Name = 'ModuleRootDir';   Path = $ModuleRoot;   Type = 'Dir'  }
            @{ Name = 'ModuleManifest';  Path = $Manifest;     Type = 'File' }
            @{ Name = 'ProviderAssembly'
               Path = (Join-Path $ModuleRoot 'Microsoft.ConfigurationManagement.PowerShell.Provider.dll')
               Type = 'File' }
            @{ Name = 'CmdletAssembly'
               Path = (Join-Path $ModuleRoot 'Microsoft.ConfigurationManagement.PowerShell.Cmdlets.Collections.dll')
               Type = 'File' }
            @{ Name = 'AdminUIWqlAssembly'
               Path = (Join-Path $AdminUIPath 'AdminUI.WqlQueryEngine.dll')
               Type = 'File' }
            @{ Name = 'SmsProviderAssembly'
               Path = (Join-Path $AdminUIPath 'Microsoft.ConfigurationManagement.ManagementProvider.dll')
               Type = 'File' }
        )

        foreach ($F in $FileReads) {
            $Name = $F.Name
            $Path = $F.Path

            try {
                if (-not (Test-Path -Path $Path)) {
                    Add-Check -Name "FileRead:$Name" -Category 'FileRead' `
                              -Status 'Info' -Value "not present: $Path"
                    continue
                }

                if ($F.Type -eq 'Dir') {
                    $Count = @(Get-ChildItem -Path $Path -EA Stop).Count
                    Add-Check -Name "FileRead:$Name" -Category 'FileRead' -Status 'Pass' `
                              -Value "$Path (items=$Count)"
                }
                else {
                    # Open the stream rather than trusting Test-Path - only an actual
                    # read attempt proves read access.
                    $Stream = [System.IO.File]::Open(
                        $Path, [System.IO.FileMode]::Open,
                        [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                    try {
                        $Buffer = New-Object byte[] 2
                        $null = $Stream.Read($Buffer, 0, 2)
                        $Size = $Stream.Length
                    }
                    finally { $Stream.Dispose() }

                    Add-Check -Name "FileRead:$Name" -Category 'FileRead' -Status 'Pass' `
                              -Value "$Path (bytes=$Size)"
                }
            }
            catch {
                Add-Check -Name "FileRead:$Name" -Category 'FileRead' -Status 'Fail' `
                          -Value $Path -ErrorRecord $_
            }
        }

        # ACL read on the module directory.
        Invoke-Probe -Name 'FileAcl:ModuleRoot' -Category 'FileRead' -Test {
            (Get-Acl -Path $ModuleRoot).Access |
                Where-Object { $_.FileSystemRights -match 'Read|FullControl' } |
                Select-Object -First 5 -ExpandProperty IdentityReference |
                ForEach-Object { $_.Value }
        }
    }
    else {
        Add-Check -Name 'FileRead:ModuleFiles' -Category 'FileRead' -Status 'Skipped' `
                  -Value 'SMS_ADMIN_UI_PATH not set - console likely not installed or env not propagated'
    }

    #-----------------------------------------------------------------------
    # 7. WMI / provider read access (known-good control)
    #-----------------------------------------------------------------------
    Invoke-Probe -Name 'Wmi:ProviderLocation' -Category 'ProviderRead' -Test {
        @(Get-CimInstance -Namespace 'root\sms' -ClassName 'SMS_ProviderLocation' -EA Stop |
            ForEach-Object { "$($_.SiteCode)/$($_.Machine)/local=$($_.ProviderForLocalSite)" })
    }

    Invoke-Probe -Name 'Wmi:SiteNamespace' -Category 'ProviderRead' -Test {
        $P = Get-CimInstance -Namespace 'root\sms' -ClassName 'SMS_ProviderLocation' -EA Stop |
             Where-Object { $_.ProviderForLocalSite } | Select-Object -First 1
        if (-not $P) { throw 'No local-site provider instance returned.' }
        $Ns = "root\sms\site_$($P.SiteCode)"
        $null = Get-CimInstance -Namespace $Ns -ClassName 'SMS_Site' -EA Stop
        $Ns
    }

    Invoke-Probe -Name 'Wmi:CollectionRead' -Category 'ProviderRead' -Test {
        $P = Get-CimInstance -Namespace 'root\sms' -ClassName 'SMS_ProviderLocation' -EA Stop |
             Where-Object { $_.ProviderForLocalSite } | Select-Object -First 1
        $Ns = "root\sms\site_$($P.SiteCode)"
        @(Get-CimInstance -Namespace $Ns -ClassName 'SMS_Collection' -EA Stop |
            Select-Object -First 1).Count
    }

    #-----------------------------------------------------------------------
    # 8. Existing session state
    #-----------------------------------------------------------------------
    Invoke-Probe -Name 'ExistingCMSiteDrives' -Category 'SessionState' -Test {
        @(Get-PSDrive -PSProvider CMSite -EA SilentlyContinue |
            Select-Object -ExpandProperty Name)
    }

    Invoke-Probe -Name 'ConfigMgrModuleLoaded' -Category 'SessionState' -Test {
        [bool](Get-Module -Name ConfigurationManager)
    }

    Invoke-Probe -Name 'AllPSDrives' -Category 'SessionState' -Test {
        @(Get-PSDrive | ForEach-Object { "$($_.Name):$($_.Provider.Name)" })
    }

    Invoke-Probe -Name 'KerberosTickets' -Category 'SessionState' -Test {
        # Empty here on a run that otherwise works is not itself proof of anything,
        # but a difference between runs is worth knowing.
        $K = & klist.exe 2>&1 | Out-String
        @($K -split "`n" | Where-Object { $_ -match 'Server:' } | ForEach-Object { $_.Trim() })
    }

    #-----------------------------------------------------------------------
    # 9. WinRM quota state
    #-----------------------------------------------------------------------
    Invoke-Probe -Name 'WinRM:ShellQuotas' -Category 'WinRM' -Test {
        $S = Get-Item WSMan:\localhost\Shell -EA Stop
        @($S | Get-ChildItem | ForEach-Object { "$($_.Name)=$($_.Value)" })
    }

    Invoke-Probe -Name 'WinRM:ActiveShells' -Category 'WinRM' -Test {
        @(Get-WSManInstance -ResourceURI 'shell' -Enumerate -EA Stop |
            Select-Object -ExpandProperty Owner).Count
    }

    #-----------------------------------------------------------------------
    # Assemble result
    #-----------------------------------------------------------------------
    [pscustomobject]@{
        Label        = $Label
        ComputerName = $env:COMPUTERNAME
        TimestampUtc = (Get-Date).ToUniversalTime().ToString('o')
        TotalChecks  = $Checks.Count
        FailCount    = @($Checks | Where-Object Status -eq 'Fail').Count
        Checks       = $Checks
    }
}

#---------------------------------------------------------------------------
# Invocation
#---------------------------------------------------------------------------
$Result = $null

try {
    if ($ComputerName) {
        $SessionParams = @{ ComputerName = $ComputerName; ErrorAction = 'Stop' }
        if ($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
            $SessionParams['Credential'] = $Credential
        }

        $Session = $null
        try {
            $Session = New-PSSession @SessionParams
            $Result = Invoke-Command -Session $Session -ScriptBlock $Probe `
                                     -ArgumentList $Label, ([bool]$SkipWriteProbe) `
                                     -ErrorAction Stop
        }
        finally {
            if ($Session) { Remove-PSSession -Session $Session -EA SilentlyContinue }
        }
    }
    else {
        $Result = & $Probe $Label ([bool]$SkipWriteProbe)
    }
}
catch {
    Write-Error "Probe could not be executed: $($_.Exception.Message)"
    return
}

#---------------------------------------------------------------------------
# Render
#---------------------------------------------------------------------------
Write-Host ""
Write-Host ("Context probe: {0}  [{1}]" -f $Result.ComputerName, $Result.Label) -ForegroundColor Cyan
Write-Host ("UTC: {0}   Checks: {1}   Failures: {2}" -f `
            $Result.TimestampUtc, $Result.TotalChecks, $Result.FailCount) -ForegroundColor Cyan
Write-Host ""

$Result.Checks |
    Sort-Object Category |
    Format-Table -AutoSize -Wrap -GroupBy Category -Property `
        Name,
        @{ Label = 'Status'; Expression = { $_.Status }; Width = 8 },
        @{ Label = 'Value'
           Expression = {
               if ($null -eq $_.Value) { '' }
               elseif ($_.Value -is [array]) { $_.Value -join '; ' }
               else { [string]$_.Value }
           } }

# Failures repeated in full - the table truncates the exception chain.
$Failures = @($Result.Checks | Where-Object Status -eq 'Fail')

if ($Failures.Count) {
    Write-Host ""
    Write-Host "FAILURES ($($Failures.Count))" -ForegroundColor Red
    Write-Host ("-" * 70) -ForegroundColor Red

    foreach ($F in $Failures) {
        Write-Host ""
        Write-Host "  $($F.Name)  [$($F.Category)]" -ForegroundColor Yellow
        if ($F.Value)     { Write-Host "    Target : $($F.Value)" }
        if ($F.ErrorType) { Write-Host "    Type   : $($F.ErrorType)" }
        if ($F.ErrorCode) {
            $Colour = if ($F.ErrorCode -eq '0x80070005') { 'Red' } else { 'Gray' }
            Write-Host "    Code   : $($F.ErrorCode)" -ForegroundColor $Colour
        }
        if ($F.Error)     { Write-Host "    Detail : $($F.Error)" }
    }
    Write-Host ""

    if ($Failures | Where-Object ErrorCode -eq '0x80070005') {
        Write-Host "One or more probes returned 0x80070005 - compare these against a passing run." -ForegroundColor Red
        Write-Host ""
    }
}
else {
    Write-Host ""
    Write-Host "No failures recorded." -ForegroundColor Green
    Write-Host ""
}

if ($OutputPath) {
    try {
        $Result | ConvertTo-Json -Depth 6 | Set-Content -Path $OutputPath -Encoding UTF8 -EA Stop
        Write-Host "Written to $OutputPath" -ForegroundColor Green
    }
    catch {
        Write-Warning "Could not write to '$OutputPath': $($_.Exception.Message)"
    }
}

Write-Output $Result
