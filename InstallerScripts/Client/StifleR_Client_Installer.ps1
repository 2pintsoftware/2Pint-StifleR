<#
    .Synopsis
        Checks to see if we are running on x64 or x86 and selects the correct MSI
        Stops the StifleR service (if present)
        Remove the StifleR Client. 
        Cleans up the environment (event log/logs etc)
        Istalls the new version
        Logs to a file in \Windows\Temp
        TODO:
        Maybe parameterize the server fqdn etc


    .REQUIREMENTS
       Must be run from the same folder as the .MSI(s) that you want to install

    .USAGE
       Set the server name etc in the #Optional MSIEXEC params section below



   .NOTES
    AUTHOR: 2Pint Software
    EMAIL: support@2pintsoftware.com
    VERSION: 2.0.0.4
    DATE:08/09/2023
    
    CHANGE LOG: 
    1.0.0.0 : 22/02/2018  : Initial version of script 
    1.0.0.2 : 27/04/2018  : Changed the uninstall detection and execution 
    1.0.0.3 : 28/04/2018  : Added more cleanup & logging                            
    1.0.0.4 : 02/05/2018  : Included local policy check    
    1.0.0.5 : 10/12/2018  : Removed local policy check, fixed a couple of bugs, changed order of things
    1.0.0.6 : 21/05/2019  : Removed reg cleanup as that causes duplicate client instances in 2.x client
    1.0.0.7 : 22/08/2019  : Minor changes to pre-install cleanup
    1.0.0.8 : 30/08/2019  : Added better MSI error handling and logging. Only exit with 0 if install is a success
    1.0.0.9 : 30/08/2019  : Removed the warning during service stop, cleaned up logging
    1.0.1.0 : 11/10/2019  : Discovers the install path and if installed gets values from the .config for data/logs folders etc
    1.0.1.1 : 25/10/2019  : Minor tweaks to logging
	1.0.1.2 : 26/11/2019  : Enabled MSI logging by default, set default debuglevel to 0, set rules interval to 86400, and added check for elevation
	1.0.1.3 : 25/01/2020  : Added support for 'VPNStrings' and custom install folder, 
                            now uses defaults.ini for install settings (required on cmd line) new cmd line params -FullDebugMode (true/false) and Debug option
    1.0.1.4 : 16/04/2020  : Added support for ForceVPN in the settings .ini and app config. Removed -VerbosePreference switch
    1.0.1.5 : 12/05/2020  : Added support for adding new Features via the settings .ini -EnableBetaFeatures (default is false/0)
    1.0.2.0 : 27/05/2020  : changed the svc stop to using Net Stop and added a check for the service state, backup the .config file, better error checking for service stop/start
                            Checks for running MSI installs
    1.0.2.1 : 30/05/2020  : Stops if the svc is marked for deletion - checks in 2 places. Only tries to remove logs etc if there is an old version installed
    1.0.2.2 : 06/06/2020  : Added Uninstall option EXAMPLE: .\StifleR_Client_Installer.ps1 -Uninstall 1 -DebugPreference Continue
    2.0.0.0 : 15/09/2021  : Updated for V2.7 Client Install. Supports upgrade from 2.6.x to 2.7.x
    2.0.0.1 : 26/10/2022  : Creates subfolder(s) to logfile if they are missing
    2.0.0.2 : 26/10/2022  : Bugfixes + check if the client is installed under C:\Windows\temp during OSD and skip eventlog queries.
    2.0.0.3 : 05/06/2023  : Bugfixes + Removed Install Stifler ETW Logic, handle by installer. 
    2.0.0.4 : 08/09/2023  : Bugfix
    2.0.0.5 : 12/15/2023  : Added support for configuring BranchCache Ports
    2.0.0.6 : 12/15/2023  : Added custom hook for detecting between production and preproduction environments

   EXAMPLE: .\StifleR_Client_Installer.ps1 -Defaults .\StifleRDefaults.ini -FullDebugMode 1 -ForceVPN 1 -EnableBetaFeatures 1 -DebugPreference Continue
   

   .LINK
    https://2pintsoftware.com
#>
param (
    [string]$Defaults,
    [bool] $Uninstall = $false, #set to true for uninstall only
    [bool]$FullDebugMode = $false, #set to $true to turn on all debug logging to the max
    [bool]$EnableBetaFeatures = $false, #set to $true to turn on any new features (added in the defaults .ini) 
    [bool]$EnableSiteDetection = $false, # Set to $true to turn on any new features (added in the defaults .ini) 
    [Parameter(Mandatory = $false)][ValidateSet("SilentlyContinue", "Continue")][string]$DebugPreference
)
Function TimeStamp { $(Get-Date -UFormat "%D %T") }
Function Get-IniContent {
    <#
    .Synopsis
        Gets the content of an INI file
        
    .Description
        Gets the content of an INI file and returns it as a hashtable
        
    .Notes
        Author    : Oliver Lipkau <oliver@lipkau.net>
        Blog      : http://oliver.lipkau.net/blog/
        Date      : 2010/03/12
        Version   : 1.0
        
      #>
    
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ (Test-Path $_) -and ((Get-Item $_).Extension -eq ".ini") })]
        [Parameter(ValueFromPipeline = $True, Mandatory = $True)]
        [string]$FilePath
    )
    
    Begin
    { Write-Debug "$($MyInvocation.MyCommand.Name):: Function started" }
        
    Process {
        Write-Debug "$($MyInvocation.MyCommand.Name):: Processing file: $Filepath"
            
        $ini = @{}
        switch -regex -file $FilePath {
            "^\[(.+)\]$" {
                # Section
                $section = $matches[1]
                $ini[$section] = @{}
                $CommentCount = 0
            }
            "^(;.*)$" {
                # Comment
                if (!($section)) {
                    $section = "No-Section"
                    $ini[$section] = @{}
                }
                $value = $matches[1]
                $CommentCount = $CommentCount + 1
                $name = "Comment" + $CommentCount
                $ini[$section][$name] = $value
            } 
            "^\s*([^#].+?)=(.*)" {
                # Key
                if (!($section)) {
                    $section = "No-Section"
                    $ini[$section] = @{}
                }
                $name, $value = $matches[1..2]
                $ini[$section][$name] = $value
            }
        }
        Write-Debug "$($MyInvocation.MyCommand.Name):: Finished Processing file: $path"
        Return $ini
    }
        
    End
    { Write-Debug "$($MyInvocation.MyCommand.Name):: Function ended" }
}

Write-Debug "Starting Install"
if (!$PSScriptRoot) { $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }
#if the stifler version is 2.7 or higher we need a slightly different evt log query
If (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\StifleRClient"-ErrorAction SilentlyContinue) {
    $ClientAppPath = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\StifleRClient").ImagePath -replace """", ""
    if ($ClientAppPath -eq "C:\Windows\Temp\StifleR\StifleR.ClientApp.exe") { 
        $StifleRClientTempInstallation = $true 
        Write-Debug "`$StifleRClientTempInstallation = $StifleRClientTempInstallation"
        }
    $VerMajor = (Get-Command $ClientAppPath ).FileVersionInfo.FileMajorPart
    $VerMinor = (Get-Command $ClientAppPath ).FileVersionInfo.FileMinorPart
}
Write-Debug "Getting .INI file content"
If (($Uninstall -eq $false) -and (!$Defaults)) {
    Write-Error "No Default .ini file specified - exiting"
    Exit 1
}
If ($Defaults) {
    $FileContent = Get-IniContent $Defaults

    #MSI Defaults
    $INSTALLFOLDER = $FileContent["MSIPARAMS"]["INSTALLFOLDER"]
    $STIFLERSERVERS = $FileContent["MSIPARAMS"]["STIFLERSERVERS"]
    $STIFLERULEZURL = $FileContent["MSIPARAMS"]["STIFLERULEZURL"]
    $DEBUGLOG = $FileContent["MSIPARAMS"]["DEBUGLOG"]
    $RULESTIMER = $FileContent["MSIPARAMS"]["RULESTIMER"]
    $MSILOGFILE = $FileContent["MSIPARAMS"]["MSILOGFILE"]

    #Config defaults
    $VPNStrings = $FileContent["CONFIG"]["VPNStrings"]
    $ForceVPN = $FileContent["CONFIG"]["ForceVPN"]
    $Logfile = $FileContent["CONFIG"]["Logfile"]
    $Features = $FileContent["CONFIG"]["Features"]
    $BranchCachePort = $FileContent["CONFIG"]["BranchCachePort"]
    $BlueLeaderProxyPort = $FileContent["CONFIG"]["BlueLeaderProxyPort"]
    $GreenLeaderOfferPort = $FileContent["CONFIG"]["GreenLeaderOfferPort"]
    $BranchCachePortForGreenLeader = $FileContent["CONFIG"]["BranchCachePortForGreenLeader"]

    # Read Prod and PreProd Servers if EnableSiteDetection is set to true
    If($EnableSiteDetection -eq $true){
        $ProductionStifleRServers = $FileContent["CONFIG"]["ProductionStifleRServers"]
        $ProductionStifleRulezUrl = $FileContent["CONFIG"]["ProductionStifleRulezUrl"]
        $PreProductionStifleRServers = $FileContent["CONFIG"]["PreProductionStifleRServers"]
        $PreProductionStifleRulezUrl = $FileContent["CONFIG"]["PreProductionStifleRServers"]

        # ---------------------------
        # BEGIN CUSTOM SITE DETECTION
        # --------------------------- 
        $Domain = (Get-ChildItem env:USERDOMAIN).value

        if ($Domain -eq "DOMAIN"){
            $Production = $true
            Write-Debug "Production variable set to true"
        }
        Else{
            $Production = $false
            Write-Debug "Production variable set to false"
        } 

        # ---------------------------
        # END CUSTOM SITE DETECTION
        # --------------------------- 

        If ($Production -eq $true){
            $STIFLERSERVERS = $ProductionStifleRServers 
            $STIFLERULEZURL = $ProductionStifleRulezUrl
        }
        Else{
            $STIFLERSERVERS = $PreProductionStifleRServers
            $STIFLERULEZURL = $PreProductionStifleRulezUrl
        }

    }

    Write-Debug "Installation Folder: $INSTALLFOLDER"
    Write-Debug "StifleR Server(s): $STIFLERSERVERS"
    Write-Debug "StifleR Rules URL: $STIFLERULEZURL"
    Write-Debug "StifleR Debug Level: $DEBUGLOG"
    Write-Debug "StifleR Rules download timer: $RULESTIMER"
    Write-Debug "MSI Logfile: $MSILOGFILE"
    Write-Debug "Custom VPN Strings: $VPNStrings"
    Write-Debug "Force VPN?: $ForceVPN"
    Write-Debug "This script logs to: $Logfile"
    Write-Debug "New features will be added: $Features"
    Write-Debug "BranchCachePort: $BranchCachePort"
    Write-Debug "BlueLeaderProxyPort: $BlueLeaderProxyPort"
    Write-Debug "GreenLeaderOfferPort: $GreenLeaderOfferPort"
    Write-Debug "BranchCachePortForGreenLeader: $BranchCachePortForGreenLeader"
}
If ($Uninstall -eq $true) { $Logfile = "C:\Windows\Temp\StifleRClient.log" }
write-debug $Uninstall
# Check for elevation (admin rights)
if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Debug "Running elevated - PASS"
}
else {
    Write-Warning "This script needs to be run with admin rights..."
    Exit 1
}

#Check .NET Framework version is 4.6.2 or higher - if not - exit
If ((Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full").Release -ge 394802 -eq $False) {
    Write-Error "This System does not have .NET Framework 4.6.2 or higher installed. Exiting"
    Exit 1
}

#----------------------------------------------------------- 
#Setup some variables
#-----------------------------------------------------------
if (!$PSScriptRoot) { $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }
If ($env:PROCESSOR_ARCHITECTURE -eq "x86") { $msifile = "$PSScriptRoot\StifleR.ClientApp.Installer.msi" } 
Else {
    $msifile = "$PSScriptRoot\StifleR.ClientApp.Installer64.msi"
}

$SName = "StifleRClient"
$EventLogName = "StifleR"
$StifleRConfig = "$INSTALLFOLDER\StifleR.ClientApp.exe.Config"
$SCStartCmd = { sc.exe start $Sname }
$SCQueryCmd = { SC.exe query $Sname }
$SCStopCmd = { sc.exe stop $Sname }
Write-Debug "StifleR app config file: $StifleRConfig" 
Write-Debug "MSI installer File: $msifile"

#-----------------------------------------------------------
#Check if service is marked for deletion and exit if it is
#-----------------------------------------------------------
If (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\StifleRClient"-ErrorAction SilentlyContinue) {
    If ((Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\StifleRClient").DeleteFlag -eq 1 -eq $True) {
        Write-Error "StifleR Client Service is marked for deletion so can't proceed. Exiting"
        $(TimeStamp) + "StifleR Client Service is marked for deletion so can't proceed. Exiting" | Out-File -FilePath $Logfile -Append -Encoding ascii
        Exit 1
    }
}
#----------------------------------------------------------- 
#FUNCTIONS
#-----------------------------------------------------------

Function Uninstall-App ($SearchString) {
    $path = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
                    
    $StifCli = Get-ChildItem $path -ErrorAction SilentlyContinue -Force |
    Get-ItemProperty |
    Where-Object { $_.DisplayName -match $SearchString } |
    Select-Object -Property DisplayName, UninstallString, Displayversion

    ForEach ($ver in $StifCli) {

        If ($ver.UninstallString) {                                
                                    
            $uninstallString = ([string]$ver.UninstallString).ToLower().Replace("/i", "").Replace("msiexec.exe", "")
            $(TimeStamp) + " Uninstalling StifleR Client Version:" + $ver.Displayversion | Out-File -FilePath $Logfile -Append -Encoding ascii
                                    
            start-process "msiexec.exe" -arg "$uninstallString /qn" -Wait 
            Return $True
        }
        Else { Return $False }
    }
}

function New-AppSetting
	([string]$PathToConfig = $(throw 'Configuration file is required'),
[string]$Key = $(throw 'No Key Specified'), 
[string]$Value = $(throw 'No Value Specified')
          ) {
    if (Test-Path $PathToConfig) {	
        $x = [xml] (Get-Content $PathToConfig)
        $el = $x.CreateElement("add")
        $kat = $x.CreateAttribute("key")
        $kat.psbase.value = $Key
        $vat = $x.CreateAttribute("value")
        $vat.psbase.value = $Value
        $el.SetAttributeNode($kat)
        $el.SetAttributeNode($vat)
        $x.configuration.appSettings.Appendchild($el)
        $x.Save($PathToConfig)
    }
}

function Get-AppSetting #returns app settings from the .xml config

([string]$PathToConfig = $(throw 'Configuration file is required')) {
    if (Test-Path $PathToConfig) {
        $x = [Xml] (Get-Content $PathToConfig)
        $x.configuration.appSettings.add
    }
    else {
        throw "Configuration File $PathToConfig Not Found"
    }
}

function Set-AppSetting

    ([string]$PathToConfig = $(throw 'Configuration file is required'),
[string]$Key = $(throw 'No Key Specified'),
[string]$Value = $(throw 'No Value Specified')) {
    if (Test-Path $PathToConfig) {
        $x = [xml] (Get-Content $PathToConfig)
        $node = $x.configuration.SelectSingleNode("appSettings/add[@key='$Key']")
        $node.value = $Value
        $x.Save($PathToConfig)
    }
}

#----------------------------------------------------------- 
# END Functions
#-----------------------------------------------------------   
If (Test-Path $Logfile) { Remove-Item $Logfile -Force -ErrorAction SilentlyContinue -Confirm:$false } 
else { New-Item -Path $Logfile -ItemType File -Force }

$(TimeStamp) + " Running on: " + $env:PROCESSOR_ARCHITECTURE | Out-File -FilePath $Logfile -Append -Encoding ascii
Write-Debug "Running on:    $env:PROCESSOR_ARCHITECTURE"
#-----------------------------------------------------------
#     Check that we got a valid MSI to install - or exit
#----------------------------------------------------------- 
If (!(Test-Path $msiFile)) {
    $(TimeStamp) + " No MSI file found - Exiting" | Out-File -FilePath $Logfile -Append -Encoding ascii
    write-error " No MSI file found - Exiting"
    Exit 1
}
#-----------------------------------------------------------
#     Check if StifleR Server is installed
#----------------------------------------------------------- 

$IsStifleRServer = ((Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*).DisplayName -Match "Stifler Server").Length -gt 0

$(TimeStamp) + "StifleR Server Installed? =" + $IsStifleRServer | Out-File -FilePath $Logfile -Append -Encoding ascii
Write-Debug "StifleR Server Installed? = $IsStifleRServer"

#-----------------------------------------------------------
#     # Try to get the current path (for backup etc)
#----------------------------------------------------------- 

$svcpath = (Get-CimInstance -ClassName Win32_service -Filter "Name = 'StifleRClient'").PathName

If ($svcpath) {
    $svcpath = (Split-Path -Path $svcpath).Trim('"')
    Write-Debug "Found an existing installation"
    #Then we can get the datapath/DeguglogPath from the .config
    $Configpath = "$svcpath\StifleR.ClientApp.exe.Config"
    $xml = [xml](Get-Content $Configpath)
    $DataPath = ($xml.Configuration.appsettings.add | Where-Object { $_.key -eq "DataPath" }).Value
    If ($datapath.StartsWith("%")) { $datapath = [System.Environment]::ExpandEnvironmentVariables($datapath) }

    $DebugLogPath = ($xml.Configuration.appsettings.add | Where-Object { $_.key -eq "DebugLogPath" }).Value
    If ($DebugLogPath.StartsWith("%")) { $DebugLogPath = [System.Environment]::ExpandEnvironmentVariables($DebugLogPath) }

    #-----------------------------------------------------------
    #        Check for other MSI Installs in progress
    #        and wait for up to 10 mins
    #-----------------------------------------------------------

    $(TimeStamp) + " Checking for other MSI Installs in progress" | Out-File -FilePath $Logfile -Append -Encoding ascii
    Write-Debug "Checking for other MSI Installs in progress"
    $LoopCounter = 0
    $MSIInProgress = $True
    do {
        try {
            $Mutex = [System.Threading.Mutex]::OpenExisting("Global\_MSIExecute");
            $Mutex.Dispose();
            Write-Debug "Another installer is currently running!"
            Write-Debug "sleeping for 5 secs - We have been waiting for $($loopcounter * 5) Seconds"
            start-sleep -seconds 5
            $MSIInProgress = $True
            $LoopCounter++
            If ($loopcounter -eq 120) {
                write-warning "Timeout waiting for MSI Mutex - Exiting"
                Exit 1
            }
        }
        catch {
            Write-Debug "No other MSI running - Continue"
            $(TimeStamp) + "No other MSI running - Continue" | Out-File -FilePath $Logfile -Append -Encoding ascii
            $MSIInProgress = $False
        }
    } until(($MSIInProgress -eq $False) -or $LoopCounter -eq 120)
    # quit after 10 mins
    #-----------------------------------------------------------
    #        END - Check for MSI Installs
    #-----------------------------------------------------------

    #-----------------------------------------------------------
    #        Remove the StifleR Client by running the Uninstall
    #----------------------------------------------------------- 
    #First - Stop the Service as this can cause the uninstall to fail on occasion if it takes too long
    $(TimeStamp) + " Stopping Existing Services" | Out-File -FilePath $Logfile -Append -Encoding ascii
    Write-Debug "Stopping Existing Services"
    #----------------------------------------------------------
    #       Attempt to stop the StifleRClient service
    #----------------------------------------------------------
    #get the current svc state
    $SvcStatus = Invoke-Command -ScriptBlock $SCQueryCmd

    If (@($SvcStatus | Select-String -SimpleMatch -Pattern "STATE")[0].ToString() -match "STOPPED") {
        write-debug "Service was already stopped"
        $(TimeStamp) + " Service was already stopped" | Out-File -FilePath $Logfile -Append -Encoding ascii
    }
    #if not stopped - continue
    Else {
        Invoke-Command -ScriptBlock $SCStopCmd | Out-Null
        $loopcounter = 0
        do { 
            $SvcStatus = Invoke-Command -ScriptBlock $SCQueryCmd

            write-debug "Waiting for Service to stop: $($loopcounter * 5) Seconds Elapsed"
            $(TimeStamp) + "Waiting for Service to stop: $($loopcounter * 5) Seconds Elapsed" | Out-File -FilePath $Logfile -Append -Encoding ascii
            write-debug ($SvcStatus | Select-String -SimpleMatch -Pattern "STATE")[0].ToString()
            Start-Sleep -Seconds 5
            $loopCounter++

        } until ((@($SvcStatus | Select-String -SimpleMatch -Pattern "STATE")[0].ToString() -match "STOPPED") -or $loopcounter -eq 12)

        if ($StifleRClientTempInstallation) {
            # if the client is installed under c:\Windows\Temp there will be no eventlog so waiting some extra time to make sure.
            $(TimeStamp) + " Client is installed under c:\Windows\Temp there will be no eventlog so waiting some extra time to make sure." | Out-File -FilePath $Logfile -Append -Encoding ascii
            Start-Sleep -Seconds 15
        }
        else {
            If (@($SvcStatus | Select-String -SimpleMatch -Pattern "STATE")[0].ToString() -match "STOPPED") {
                #if the service stopped - check the StifleR event log for Service Shutdown Event

            
                $loopcounter = 0
                $TSpan = (Get-Date) - (New-TimeSpan -Second 20)


                If (($vermajor -eq 2) -and ($verminor -ge 7)) {
                    $query = @"
<QueryList>
 <Query Id="0" Path="TwoPintSoftware-StifleR.ClientApp-Program/Operational">
   <Select Path="TwoPintSoftware-StifleR.ClientApp-Program/Operational">*[System[(EventID=295)]]</Select>
 </Query>
</QueryList>
"@
                }
                else {
                    $query = @"
<QueryList>
 <Query Id="0" Path="StifleR">
   <Select Path="StifleR">*[System[(EventID=0)]] and *[EventData[Data='Service Shutdown Completed.']]</Select>
 </Query>
</QueryList>
"@
                }


                do { 

                    $evt = Get-WinEvent -FilterXml $query | Select-Object -First 1 | Where-Object { $_.TimeCreated -ge $TSpan }

                    write-debug "Waiting for shutdown event: $loopcounter"
                    Start-Sleep -Seconds 2
                    $loopCounter++

                } until (($evt) -or $loopcounter -eq 15)
                If (!$evt) {
                    Write-Error "StifleR Service Stop Timed out - Continue to second check"
                    $(TimeStamp) + "StifleR Service Stop Timed out - Continue to second check" | Out-File -FilePath $Logfile -Append -Encoding ascii
                    # Exit 1
                }
            }
            Else {
                Write-Error "StifleR Service Stop Timed out - Continue to second check"
                $(TimeStamp) + "StifleR Service Stop Timed out - Continue to second check" | Out-File -FilePath $Logfile -Append -Encoding ascii
                #Exit 1
            }
            write-debug "Shutdown Event detected - safe to continue"
            $(TimeStamp) + "Shutdown Event detected - safe to continue" | Out-File -FilePath $Logfile -Append -Encoding ascii
        }
    }

    # Second check - Stop the service
    $SvcStatus = Invoke-Command -ScriptBlock $SCQueryCmd
    $State = $SvcStatus | Select-String "STATE" | ForEach-Object { ($_ -replace '\s+', ' ').trim().Split(" ") | Select-Object -Last 1 }
    $(TimeStamp) + "The current state of the service is: $State"
    If($State -eq "STOPPED"){
        $(TimeStamp) + "Service is already stopped, continue to next section." | Out-File -FilePath $Logfile -Append -Encoding ascii
    }
    Else {
        $(TimeStamp) + "Service is running, trying to stop it." | Out-File -FilePath $Logfile -Append -Encoding ascii
        Invoke-Command -ScriptBlock $SCStopCmd | Out-Null
        $loopCounter=0
        do 
        { 
            $SvcStatus = Invoke-Command -ScriptBlock $SCQueryCmd
            $State = $SvcStatus | Select-String "STATE" | ForEach-Object { ($_ -replace '\s+', ' ').trim().Split(" ") | Select-Object -Last 1 }
            Start-Sleep -Seconds 5
            $loopCounter++
            $(TimeStamp) + "Waiting for Service to stop: $($loopcounter * 5) Seconds Elapsed" | Out-File -FilePath $Logfile -Append -Encoding ascii

        } until (($State -eq "STOPPED") -or $loopcounter -eq 12)
    
        # Service should be stopped now, kill the process if its not
        If($State -eq "STOPPED"){
            $(TimeStamp) + "Second Check: Service is already stopped, continue to next section." | Out-File -FilePath $Logfile -Append -Encoding ascii
        }
        Else{
            $(TimeStamp) + "Service could not be stopped, stop the process." | Out-File -FilePath $Logfile -Append -Encoding ascii
            Get-Process StifleR.ClientApp | Stop-Process -Force
        }
    }

    # Final Check: Service should be stopped now, abort the script if its not
    If($State -eq "STOPPED"){
        $(TimeStamp) + "Final Check: Service is already stopped, continue to next section." | Out-File -FilePath $Logfile -Append -Encoding ascii
    }
    Else{
        $(TimeStamp) + "Service could not be stopped, aborting script." | Out-File -FilePath $Logfile -Append -Encoding ascii
        Break
    }




    #-------------------------------------------
    #   END - Service shutdown
    #-------------------------------------------




}
Else {
    Write-Debug "StifleR Service not found, possible new install"
    $(TimeStamp) + " StifleR Service not found, possible new install" | Out-File -FilePath $Logfile -Append -Encoding ascii
}

#-------------------------------------------
#DETECT EXISTING INSTALL(s) AND REMOVE
#-------------------------------------------
$(TimeStamp) + " Checking for existing Installation" | Out-File -FilePath $Logfile -Append -Encoding ascii


If ((Uninstall-App "StifleR Client") -eq $True) {
    $(TimeStamp) + " Successfully removed old version" | Out-File -FilePath $Logfile -Append -Encoding ascii;
    Write-Debug "Successfully removed old version" 

    #-------------------------------------------
    #Remove the Logs and Client data folders
    #-------------------------------------------

    $(TimeStamp) + " Removing Logs folders" | Out-File -FilePath $Logfile -Append -Encoding ascii
    Write-Debug "Removing Logs folders"
    If (Test-Path $DebugLogPath) { Remove-Item $DebugLogPath -Recurse -Force -ErrorAction SilentlyContinue -Confirm:$false }

    $(TimeStamp) + " Removing Client Data folders" | Out-File -FilePath $Logfile -Append -Encoding ascii
    Write-Debug "Removing Client Data folders"
    If (Test-Path $DataPath) { Remove-Item $DataPath -Recurse -Force -ErrorAction SilentlyContinue -Confirm:$false }
    #-------------------------------------------
    #clear the event log if not running on a StifleR Server
    #-------------------------------------------
    If ($IsStifleRServer = "False") {

        $(TimeStamp) + " Removing old event log" | Out-File -FilePath $Logfile -Append -Encoding ascii
        Write-Debug "Removing the old Event log"
        $log = try {
            Get-WinEvent -Log $EventLogName -ErrorAction Stop
        }
        catch [Exception] {
            if ($_.Exception -match "There is not an event log") {
                $(TimeStamp) + " No event log found to remove" | Out-File -FilePath $Logfile -Append -Encoding ascii;
                Write-Debug " No event log found to remove"
            }
        }

        if ($log) { Remove-EventLog -LogName $EventLogName }
        #-------------------------------------------
    } # End Clear evt log
    #-------------------------------------------
    #-------------------------------------------
    #If Uninstall only specified - Exit here
    #-------------------------------------------

    If ($Uninstall -eq $true) {
        Write-Debug "Uninstall Complete - exiting"
        $(TimeStamp) + "Uninstall Complete - exiting" | Out-File -FilePath $Logfile -Append -Encoding ascii;
        Exit 0
    }




}
Else {
    $(TimeStamp) + " Failed to remove old version - or it wasn't installed" | Out-File -FilePath $Logfile -Append -Encoding ascii;
    Write-Debug " Failed to remove old version - or it wasn't installed?"
    If ($Uninstall -eq $true) {
        Write-Debug "Uninstall Complete - exiting"
        $(TimeStamp) + "Uninstall Complete - exiting" | Out-File -FilePath $Logfile -Append -Encoding ascii;
        Exit 0
    } 
}


$(TimeStamp) + " Installing New Version" | Out-File -FilePath $Logfile -Append -Encoding ascii
Write-Debug "Installing New Version"

#-----------------------------------------------------------
#Check if service is marked for deletion and exit if it is
#-----------------------------------------------------------

If (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\StifleRClient"-ErrorAction SilentlyContinue) {
    If ((Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\StifleRClient").DeleteFlag -eq 1 -eq $True) {
        Write-Error "StifleR Client Service is marked for deletion so can't proceed. Exiting"
        $(TimeStamp) + "StifleR Client Service is marked for deletion so can't proceed. Exiting" | Out-File -FilePath $Logfile -Append -Encoding ascii
        Exit 1
    }
}
#-----------------------------------------------------------
#END check for service deletion
#-----------------------------------------------------------


#-----------------------------------------------------------
#        Check for other MSI Installs in progress
#        and wait for up to 10 mins
#-----------------------------------------------------------

$(TimeStamp) + " Checking for other MSI Installs in progress" | Out-File -FilePath $Logfile -Append -Encoding ascii
Write-Debug "Checking for other MSI Installs in progress"
$LoopCounter = 0
$MSIInProgress = $True
do {
    try {
        $Mutex = [System.Threading.Mutex]::OpenExisting("Global\_MSIExecute");
        $Mutex.Dispose();
        Write-Debug "Another installer is currently running!"
        Write-Debug "sleeping for 5 secs - We have been waiting for $($loopcounter * 5) Seconds"
        start-sleep -seconds 5
        $MSIInProgress = $True
        $LoopCounter++
        If ($loopcounter -eq 120) {
            write-warning "Timeout waiting for MSI Mutex - Exiting"
            Exit 1
        }
    }
    catch {
        Write-Debug "Still No other  MSI running - Cleared for takeoff"
        $(TimeStamp) + "Still No other  MSI running - Cleared for takeoff" | Out-File -FilePath $Logfile -Append -Encoding ascii
        $MSIInProgress = $False
    }
} until(($MSIInProgress -eq $False) -or $LoopCounter -eq 120)
#quit after 10 mins
#-----------------------------------------------------------
#        END - Check for MSI Installs
#-----------------------------------------------------------


$msiArgumentList = @(
    #--------------------------------
    #Mandatory msiexec Arguments - DO NOT CHANGE
    #--------------------------------

    "/i"

    "`"$msiFile`""

    #--------------------------------
    #Optional MSIEXEC params
    #--------------------------------
    "/qn" #Quiet - /qb with basic interface - for NO interface use /qn instead

    # "/norestart"

    "/l*v `"$MSILOGFILE`""    #Optional logging for the MSI install

    "INSTALLFOLDER=`"$INSTALLFOLDER`""

    "DEBUGLOG=`"$DEBUGLOG`"" #Set to 1-6 to enable logging

    "STIFLERSERVERS=`"$STIFLERSERVERS`"" 

    "STIFLERULEZURL=`"$STIFLERULEZURL`"" 

    "UPDATERULESTIMERINSEC=$RULESTIMER" 

    #--------------------------------
    #END Optional MSIEXEC params
    #--------------------------------
)

write-Debug "MSI Cmd line Arguments: $arguments" 
write-Debug "$msiArgumentList" 
#--------------------------------
#Execute the Install
#--------------------------------

$return = Start-Process msiexec -ArgumentList $msiArgumentList -Wait -passthru
If (@(0, 3010) -contains $return.exitcode) {

    #--------------------------------
    #Update the log before we do any .config edits
    #--------------------------------

    $path = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
                    
    $StifCli = Get-ChildItem $path -ErrorAction SilentlyContinue -Force |
    Get-ItemProperty |
    Where-Object { $_.DisplayName -match "StifleR Client" } |
    Select-Object -Property DisplayName, UninstallString, Displayversion

    ForEach ($ver in $StifCli) {                  
        $(TimeStamp) + " Installed StifleR Client Version:" + $ver.Displayversion | Out-File -FilePath $Logfile -Append -Encoding ascii
        Write-Debug "Installed StifleR Client Version: $($ver.Displayversion)"
    }
}# END MSI Install

else {
    $(TimeStamp) + " MSI failed with Error" + $return.exitcode | Out-File -FilePath $Logfile -Append -Encoding ascii
    Write-Error "MSI install failed with Error  $($return.exitcode) "
    Exit 1
}

#Finally, edit the .Config with any custom VPNStrings or debug settings
#First we need to stop the service
#if we updated any VPN stuff we will restart so that the connection can be updated with that info
If (($VPNStrings) -or ($ForceVPN -eq 1) -or ($EnableBetaFeatures -eq $true) -or ($FullDebugMode -eq $true)) {
    Write-Debug "Sleeping 30 secs please wait..."
    $(TimeStamp) + "Sleeping 30 secs please wait...:" | Out-File -FilePath $Logfile -Append -Encoding ascii
    Start-Sleep -s 30 #wait for 30 secs to let the svc start correctly before restarting
    Write-Debug "Stopping the service for .config file changes"
    $(TimeStamp) + "Stopping the service for .config file changes:" | Out-File -FilePath $Logfile -Append -Encoding ascii

    #----------------------------------------------------------
    #       Attempt to stop the StifleRClient service
    #----------------------------------------------------------
    #get the current svc state
    $SvcStatus = Invoke-Command -ScriptBlock $SCQueryCmd

    If (@($SvcStatus | Select-String -SimpleMatch -Pattern "STATE")[0].ToString() -match "STOPPED") {
        write-debug "Service was already stopped"
        $(TimeStamp) + " Service was already stopped" | Out-File -FilePath $Logfile -Append -Encoding ascii
    }
    #if not stopped - continue
    Else {
        Invoke-Command -ScriptBlock $SCStopCmd | Out-Null
        $loopcounter = 0
        do { 
            $SvcStatus = Invoke-Command -ScriptBlock $SCQueryCmd

            write-debug "Waiting for Service to stop: $($loopcounter * 5) Seconds Elapsed"
            $(TimeStamp) + "Waiting for Service to stop: $($loopcounter * 5) Seconds Elapsed" | Out-File -FilePath $Logfile -Append -Encoding ascii
            write-debug ($SvcStatus | Select-String -SimpleMatch -Pattern "STATE")[0].ToString()
            Start-Sleep -Seconds 5
            $loopCounter++

        } until ((@($SvcStatus | Select-String -SimpleMatch -Pattern "STATE")[0].ToString() -match "STOPPED") -or $loopcounter -eq 12)


        If (@($SvcStatus | Select-String -SimpleMatch -Pattern "STATE")[0].ToString() -match "STOPPED") {
            #if the service stopped - check the StifleR event log for Service Shutdown Event
            $loopcounter = 0
            $TSpan = (Get-Date) - (New-TimeSpan -Second 20)
            If (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\StifleRClient"-ErrorAction SilentlyContinue) {
                $VerMajor = (Get-Command 'C:\Program Files\2Pint Software\StifleR Client\stifler.clientapp.exe' ).FileVersionInfo.FileMajorPart
                $VerMinor = (Get-Command 'C:\Program Files\2Pint Software\StifleR Client\stifler.clientapp.exe' ).FileVersionInfo.FileMinorPart
            }

            If (($vermajor -eq 2) -and ($verminor -ge 7)) {
                $query = @"
<QueryList>
 <Query Id="0" Path="TwoPintSoftware-StifleR.ClientApp-Program/Operational">
   <Select Path="TwoPintSoftware-StifleR.ClientApp-Program/Operational">*[System[(EventID=295)]]</Select>
 </Query>
</QueryList>
"@
            }
            else {
                $query = @"
<QueryList>
 <Query Id="0" Path="StifleR">
   <Select Path="StifleR">*[System[(EventID=0)]] and *[EventData[Data='Service Shutdown Completed.']]</Select>
 </Query>
</QueryList>
"@
            }


            do { 

                $evt = Get-WinEvent -FilterXml $query | Select-Object -First 1 | Where-Object { $_.TimeCreated -ge $TSpan }

                write-debug "Waiting for shutdown event: $loopcounter"
                Start-Sleep -Seconds 2
                $loopCounter++

            } until (($evt) -or $loopcounter -eq 15)
            If (!$evt) {
                Write-Error "StifleR Service Stop Timed out - Exiting"
                $(TimeStamp) + "StifleR Service Stop Timed out - Exiting" | Out-File -FilePath $Logfile -Append -Encoding ascii
                Exit 1
            }
        }
        Else {
            Write-Error "StifleR Service Stop Timed out - Exiting"
            $(TimeStamp) + "StifleR Service Stop Timed out - Exiting" | Out-File -FilePath $Logfile -Append -Encoding ascii
            Exit 1
        }
        write-debug "Shutdown Event detected - safe to continue"
        $(TimeStamp) + "Shutdown Event detected - safe to continue" | Out-File -FilePath $Logfile -Append -Encoding ascii
    }
    #-------------------------------------------
    #   END - Service shutdown
    #-------------------------------------------

    #Backup the .config file before we fiddle with it
    $xml = $null
    $StiflerConfigItems = 0
    $xml = [xml](Get-Content $StifleRConfig -ErrorAction SilentlyContinue)
    $StiflerConfigItems = ($xml.Configuration.appsettings.add ).count

    write-debug "Number of Config Items in the App Config is $StiflerConfigItems"

    #backup the .config XML
    $svcpath = (Get-CimInstance -ClassName Win32_service -Filter "Name = 'StifleRClient'").PathName
    If ($svcpath) { $svcpath = (Split-Path -Path $svcpath).Trim('"') }
    If (Test-Path $svcpath\StifleR.ClientApp.exe.Config) { copy-item $svcpath\StifleR.ClientApp.exe.Config C:\Windows\temp\StifleRConfigdata.bak -Force }


    Try {
        $error.clear()
        #Edits the Stifler App.Config XML

        #Only add VPNStrings if there is a value there - if not skip
        If ($VPNStrings) { 
            New-AppSetting $StifleRConfig "VPNStrings" "$VPNStrings"    
            Write-Debug "Adding custom VPN Strings to the app config"
            $(TimeStamp) + "Adding custom VPN Strings to the app config:" | Out-File -FilePath $Logfile -Append -Encoding ascii
        }
        #Add ForceVPN if required
        If ($ForceVPN -eq 1) { 
            New-AppSetting $StifleRConfig "ForceVPN" "$ForceVPN"    
            Write-Debug "Adding Force VPN to the app config"
            $(TimeStamp) + "Adding Force VPN to the app config:" | Out-File -FilePath $Logfile -Append -Encoding ascii
        }

        #enable Beta features if that switch is $true
        If ($EnableBetaFeatures -eq $true) {
            Write-Debug "Enabling Beta features: $Features"
            $(TimeStamp) + "Enabling beta features in the app config:" | Out-File -FilePath $Logfile -Append -Encoding ascii
            $key = "Features"
            $v = (Get-Appsetting $StifleRConfig | Where-Object { $_.key -eq $key }).value #return the current value of features
            $a = $v + "," + $Features
            Set-AppSetting $StifleRConfig $key $a
        }

        If ($BranchCachePort) {
            Set-AppSetting $StifleRConfig "BranchCachePort" "$BranchCachePort"    
            Write-Debug "Setting BranchCachePort in the app config"
            $(TimeStamp) + "Setting BranchCachePort in the app config:" | Out-File -FilePath $Logfile -Append -Encoding ascii
        }

        If ($BlueLeaderProxyPort) {
            Set-AppSetting $StifleRConfig "BlueLeaderProxyPort" "$BlueLeaderProxyPort"    
            Write-Debug "Setting BlueLeaderProxyPort in the app config"
            $(TimeStamp) + "Setting BlueLeaderProxyPort in the app config:" | Out-File -FilePath $Logfile -Append -Encoding ascii
        }

        If ($GreenLeaderOfferPort) {
            Set-AppSetting $StifleRConfig "GreenLeaderOfferPort" "$GreenLeaderOfferPort"    
            Write-Debug "Setting GreenLeaderOfferPort in the app config"
            $(TimeStamp) + "Setting GreenLeaderOfferPort in the app config:" | Out-File -FilePath $Logfile -Append -Encoding ascii
        }

        If ($BranchCachePortForGreenLeader) {
            New-AppSetting $StifleRConfig "BranchCachePortForGreenLeader" "$BranchCachePortForGreenLeader"    
            Write-Debug "Adding BranchCachePortForGreenLeader to the app config"
            $(TimeStamp) + "Adding BranchCachePortForGreenLeader to the app config:" | Out-File -FilePath $Logfile -Append -Encoding ascii
        }

        #enable all debug logging if that switch is $true
        If ($FullDebugMode -eq $true) {
            $xml = [xml](Get-Content $StifleRConfig)
            Write-Debug "Enabling all debug options in the app config"
            $(TimeStamp) + "Enabling all debug options in the app config:" | Out-File -FilePath $Logfile -Append -Encoding ascii
            $node2 = $xml.Configuration.appsettings.add | Where-Object { $_.key -eq "EnableDebugLog" }
            $node2.Value = "6"
            $node3 = $xml.Configuration.appsettings.add | Where-Object { $_.key -eq "EnableDebugTelemetry" }
            $node3.Value = "1"
            $node4 = $xml.Configuration.appsettings.add | Where-Object { $_.key -eq "SignalRLogging" }
            $node4.Value = "1"
            $xml.Save($StifleRConfig) #save the config

        }




        Write-Debug "Updated and saved the App.Config"
        $(TimeStamp) + "Updated and saved the App.Config:" | Out-File -FilePath $Logfile -Append -Encoding ascii
        #pause for debug if required
        # [void](Read-Host 'Press Enter to continue.')
    }
    Catch {
        $(TimeStamp) + "Failed to edit the StifleR.Config:" + $_.Exception | Out-File -FilePath $Logfile -Append -Encoding ascii
        Write-Error "Failed to Configure the App.Config"
        Write-Error $_.Exception 
        throw  $_.Exception
        Exit 1
    }

    #If we made it to here - we just need to restart the service
    #----------------------------------------------------------
    #       Attempt to start the StifleRClient service
    #----------------------------------------------------------
    $(TimeStamp) + "Service Startup" | Out-File -FilePath $Logfile -Append -Encoding ascii
    $SCQueryCmd = { SC.exe query $Sname }

    $SCStartCmd = { sc.exe start $Sname }

    $SvcStatus = Invoke-Command -ScriptBlock $SCQueryCmd
    If (@($SvcStatus | Select-String -SimpleMatch -Pattern "STATE")[0].ToString() -match "RUNNING") {
        $(TimeStamp) + "Service was already started" | Out-File -FilePath $Logfile -Append -Encoding ascii
        write-debug "Service was already started"
        Exit 0 
    }
    Else { Invoke-Command -ScriptBlock $SCStartCmd  | Out-File -FilePath $Logfile -Append -Encoding ascii }

    $loopcounter = 0
    do { 
        $SvcStatus = Invoke-Command -ScriptBlock $SCQueryCmd
        write-debug "Waiting for Service to start:  $($loopcounter * 2) Seconds Elapsed"
        $(TimeStamp) + "Waiting for Service to start:  $($loopcounter * 2) Seconds Elapsed" | Out-File -FilePath $Logfile -Append -Encoding ascii
        write-debug ($SvcStatus | Select-String -SimpleMatch -Pattern "STATE")[0].ToString()
        Start-Sleep -Seconds 2
        $loopCounter++

    } until ((@($SvcStatus | Select-String -SimpleMatch -Pattern "STATE")[0].ToString() -match "RUNNING") -or $loopcounter -eq 15)


    If (@($SvcStatus | Select-String -SimpleMatch -Pattern "STATE")[0].ToString() -match "RUNNING") {
        #if the service startedd - we are good to go
        write-debug "StifleR Client service started - Install Completed"
        $(TimeStamp) + "StifleR Client service started - Install Completed" | Out-File -FilePath $Logfile -Append -Encoding ascii
    }
    Else {
        write-warning "StifleR Service Start Timed out - Retry"
        $(TimeStamp) + "StifleR Service Start Timed out - Retry" | Out-File -FilePath $Logfile -Append -Encoding ascii

        $SvcStatus = Invoke-Command -ScriptBlock $SCStartCmd
        #try to start the service and if we get an error we will look at the .config XML
        If ($SvcStatus | Select-String -SimpleMatch -Pattern "StartService FAILED") {

            try {
                #try to load the XML and if it throws an error we will assume it's corrupt
                $xml = $null
                $StiflerConfigItems = 0
                $xml = [xml](Get-Content $StifleRConfig -ErrorAction SilentlyContinue)
                $StiflerConfigItems = ($xml.Configuration.appsettings.add ).count
                write-debug "Number of config items in the App Config is:$StiflerConfigItems"
                $(TimeStamp) + "Number of config items in the App Config is:$StiflerConfigItems" | Out-File -FilePath $Logfile -Append -Encoding ascii
            }# try end

            catch {
                #Restore the .config in case it was corrupted
                write-warning "Number of config items in the App Config is:$StiflerConfigItems"
                $(TimeStamp) + "Number of config items in the App Config is:$StiflerConfigItems" | Out-File -FilePath $Logfile -Append -Encoding ascii 
                write-warning "Looks like the config XML is corrupt - restoring"
                $(TimeStamp) + "Looks like the config XML is corrupt - restoring" | Out-File -FilePath $Logfile -Append -Encoding ascii
                If (Test-Path C:\Windows\temp\StifleRConfigdata.bak) { copy-item C:\Windows\temp\StifleRConfigdata.bak $svcpath\StifleR.ClientApp.exe.Config -Force }
                $xml = $null
                $StiflerConfigItems = 0
                $xml = [xml](Get-Content $StifleRConfig -ErrorAction SilentlyContinue)
                $StiflerConfigItems = ($xml.Configuration.appsettings.add ).count
                write-debug "Number of config items in the App Config is now:$StiflerConfigItems"
                $(TimeStamp) + "Number of config items in the App Config is now:$StiflerConfigItems" | Out-File -FilePath $Logfile -Append -Encoding ascii
                write-debug "Will attempt to start the service again"
                $(TimeStamp) + "Will attempt to start the service again" | Out-File -FilePath $Logfile -Append -Encoding ascii
                #If the config looks ok now we should try to start the svc again
                If ($StiflerConfigItems -ge 35) {
                    # DOn't restart for now - early testing                                $SvcStatus = Invoke-Command -ScriptBlock $SCStartCmd
                }

            } #catch end

        } 

        write-warning "Exiting with an error as the .config edit failed"
        $(TimeStamp) + "Exiting with an error as the .config edit failed" | Out-File -FilePath $Logfile -Append -Encoding ascii
        write-debug "Service status is: $SvcStatus"
        $(TimeStamp) + "Service status is: $SvcStatus" | Out-File -FilePath $Logfile -Append -Encoding ascii
 

        Exit 1
    }

}
#--------------------------------
#Install Stifler ETW - REMOVED as client installs ETW by default
#--------------------------------



write-debug "Exiting - install complete"
$(TimeStamp) + "Exiting - install complete" | Out-File -FilePath $Logfile -Append -Encoding ascii
Exit 0
                                  
#--------------------------------
#END
#--------------------------------
