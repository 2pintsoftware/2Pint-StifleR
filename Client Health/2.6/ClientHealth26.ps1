
<# 
   .SYNOPSIS 
    Checks the StifleR Client connectivity and reports/remediates where possible
    Tries to figure out what is causing connectivity issues if possible and takes the appropriate action
    which could be stopping or restarting the svc etc.
    Logs to a file in c:\windows\temp\ClientHealth26.log - check that file to better understand the flow!
    Designed to work with the 2.6.x client - 2.7 will probably get a new version

   .DESCRIPTION
    1. Populate the server name etc
    2. Will report JSON file as a BITS upload (requires server configured for BITS Uploads)
    3. Can/will stop/restart/kill the StifleR Client/Process as required

   .USAGE
    Run in SYSTEM context as a scheduled task every xx hrs

NOTES
    AUTHOR: 2Pint Software
    EMAIL: support@2pintsoftware.com
    CLIENTHEALTH VERSION: 1.0.0.2
    DATE: 15 July 2022
    
    CHANGE LOG: 
    1.0.0.0 : 23/06/2022  : Initial version of script 
    1.0.0.1 : 24/06/2022  : Added logging and fixed a couple of bugs - PW
    1.0.0.2 : 15/07/2022  : Added more logging and fixed a ton of minor bugs. BITS Upload always should work now - PW

TODO
    Check the logic in several places - more testing required of diff scenarios


   .LINK
    https://github.com/2pintsoftware/StifleRScripting/tree/master/Client%20Health/2.6
#>



$Logfile = "C:\Windows\Temp\ClientHealth26.log"

# Delete any existing logfile if it exists
If (Test-Path $Logfile){Remove-Item $Logfile -Force -ErrorAction SilentlyContinue -Confirm:$false}


Function Write-Log
{
	param (
    [Parameter(Mandatory = $true)]
    [string]$Message
   )

   $TimeGenerated = $(Get-Date -UFormat "%D %T")
   $Line = "$TimeGenerated : $Message"
   Add-Content -Value $Line -Path $LogFile -Encoding Ascii
}


#The StifleR server
$stifleRServer = "2PS2PXE.2PINT.LOCAL"
$signalrport = 1414

#Typically a FSP server with BITS server extensions on
$reportServer = "2PS2PXE.2PINT.LOCAL" # TODO potentially get this from the client config xml
$reportServerPort = 80

#Section below should not require any changes

$serviceDisabled = $false;
$processName = "StifleR.ClientApp"
$serviceName = "StifleRClient"

#if we should upload the report data to the server or not
$report = $true;
$issueToReport = $false;
$mainIssue = "Unknown";

$encryptkey = "123456789"

#Is StifleR Started?
$stifleRprocessRunning = $false;
$stifleRserviceRunning = $false;
$stopService = $false;

$RegistryBasePath = 'HKLM:\Software\2Pint Software\StifleR\Client\'
$RegistryPath = "$($RegistryBasePath)Connection"
$actions = [PSCustomObject]@{ Restart = 1;Stop = 2;Kill = 3 }

#-------------------------------
#check if we even have a service
#-------------------------------
$serviceStatus = Get-Service -Name $serviceName

if($serviceStatus -eq $null)
{
    #Service not installed - exit out
    Write-Debug "StifleR Client svc not installed - quitting"
    Write-Log "StifleR Client svc not installed - quitting"
    return 1060
}
else
{
    Write-Debug "Service detected, proceeding..."
    Write-Log "StifleR Client Service detected, proceeding"
}


#if svc exists, check status
if($serviceStatus.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running -or  $serviceStatus.Status -eq [System.ServiceProcess.ServiceControllerStatus]::StartPending)
{
    $stifleRserviceRunning = $true;
    Write-Log "StifleR Client svc is running"
}
elseif($serviceStatus.StartType -eq [System.ServiceProcess.ServiceStartMode]::Automatic -and $serviceStatus.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running)
{
    #All stopped/crashed states
    $stifleRserviceRunning = $false;
    Write-Log "StifleR Client svc is set to Autostart but is NOT running"
    #Read if we stopped the service
    #TBD

}
elseif($serviceStatus.StartType -eq [System.ServiceProcess.ServiceStartMode]::Manual -or $serviceStatus.StartType -eq [System.ServiceProcess.ServiceStartMode]::Disabled)
{
    $stifleRserviceRunning = $false;
    Write-Log "StifleR Client svc is NOT running and startup type is Manual or Disabled"
}
else
{
    #Any issues? Or let below .exe tracking find the error?
    #$issueToReport = $true
    $stifleRserviceRunning = $false;
    Write-Log "StifleR Client svc is  NOT running - unsure why.."
}

#-------------------------------
#SVC CHECK END
#-------------------------------


#-------------------------------
#Get some StifleRClient process info
#-------------------------------

try {
    
    $process = Get-Process -Name $processName -ErrorAction Stop
    #get the path for Add-type later
    $processPath = $process | Select-Object -ExpandProperty Path | split-path

    #We should only have one
    [DateTime]$processStart = $process[0].StartTime;
    
    #Catch a service failing and restarting?

    #get key data
    #$process.CPU

    $stifleRprocessRunning = $true;
    Write-Log "StifleR Client proccess is running"
} 
catch {
    Write-debug "No StifleR Client Process"
    Write-Log "Failed to get the StifleR Client process - svc may be stopped"
    $stifleRprocessRunning = $false;
}
Write-Log "Completed svc and process checks"

#-------------------------------
#PROCESS CHECK END
#-------------------------------


#-------------------------------
#Check network connectivity
#-------------------------------
$shouldConnectNetwork = $false

#Write a registry to determine if we stopped it?
#Get all connected networks if possible

Write-Debug "Checking network connections"
Write-Log "Checking network connections"
Add-type  -path $processPath\Microsoft.WindowsAPICodePack.dll
[Microsoft.WindowsAPICodePack.Net.NetworkCollection]$networkCollection = [Microsoft.WindowsAPICodePack.Net.NetworkListManager]::GetNetworks([Microsoft.WindowsAPICodePack.Net.NetworkConnectivityLevels]::Connected)

#Any network that is domain auth or authenticated is considered managed
foreach($network in $networkCollection)
{
    if($network.Category -eq [Microsoft.WindowsAPICodePack.Net.NetworkCategory]::Authenticated -or $network.DomainType -eq [Microsoft.WindowsAPICodePack.Net.DomainType]::DomainAuthenticated)
    {
            
            $shouldConnectNetwork = $true;
            Write-Log "We should be able to connect - so will test connectivity"
            Write-Log "Testing for connectivity to: $($network.name) as Category is $($network.Category) and Type is $($network.DomainType) "
 
    }
 } 

 # hmm this section will always return a failure if we stopped the svc previously - maybe we should restart it first?
if($shouldConnectNetwork -eq $true)
{

    $connection = Get-NetTCPConnection -RemotePort $signalrport -OwningProcess $process.Id -ErrorAction SilentlyContinue
    Write-Log "Connection Info: LocalIP: $($connection.localaddress) RemoteIP: $($connection.remoteaddress) State: $($connection.state) "

    if($connection -eq $null)
    {
     Write-Log "Get-NetTCPConnection returned a NUll here so checking a few things.."
     Write-Log "Check if we are about to connect, save the time and the last success to registry and then check it again next runtime"
        #Check if we are about to connect, save this time and the last success to registry and then check it again next time
             
        # Create the key if it does not exist
        If (-NOT (Test-Path $RegistryPath)) {
            New-Item -Path $RegistryPath -Force | Out-Null
        }
        else
        {
 
            $NextConnectionAttemptSaved = Get-ItemProperty -Path $RegistryPath -Name 'NextConnectionAttemptSaved' -ErrorAction SilentlyContinue
            # $NextConnectionAttempt = Get-ItemProperty -Path $RegistryPath -Name 'NextConnectionAttempt' -ErrorAction SilentlyContinue = removed as only in 2.7 cli
            $LastConnectionSuccess = Get-ItemProperty -Path $RegistryPath -Name 'LastConnectionSuccess'  -ErrorAction SilentlyContinue

            if($NextConnectionAttemptSaved.NextConnectionAttemptSaved)
            {
                #We have a stored time, check if we should kill the service/report

                if($LastConnectionSuccess.LastConnectionSuccess -ne $null) # we have been able to connect at some point
                {
                    $LastConnectionSuccessDateTime = [DateTime]::Parse($LastConnectionSuccess.LastConnectionSuccess)
                    $NextConnectionAttemptSavedDateTime = [DateTime]::Parse($NextConnectionAttemptSaved.NextConnectionAttemptSaved)
                    
                    # if we connected AFTER the last connection attempt then we're ok?
                    if($LastConnectionSuccessDateTime -gt $NextConnectionAttemptSavedDateTime)
                    {
                        Write-Debug "Connected after last run, assuming OK state"
                        Write-Log "Connected after last run, assuming OK state, will remove NextConnectionAttemptSaved value"
                        Remove-ItemProperty  -Path $RegistryPath -Name $NextConnectionAttemptSaved

                        return 0;
                    }
                    else
                    {
                        Write-Debug "No connection since last review"
                        Write-Log "No connection since last runtime"
                        write-log "setting svc action to RESTART"
                        $action = $actions.Restart
                        $issueToReport = $true;
                    }

                }
            }
            else
            {
                # if no NextConnectionAttemptSaved - we can get that from the evt log
                Write-Log "Updating NexConnectionAttempt using evt log"
                $evt = get-winevent -FilterHashtable @{Logname='Stifler';ID=7613}  -MaxEvents 1
                $msec = $evt.message -replace '\D+([0-9]*).*','$1'
                $NextConnectionAttemptEvt = ($e.TimeCreated).AddMilliseconds($msec)
                Set-ItemProperty -Path $RegistryPath -Name 'NextConnectionAttemptSaved' -Value $NextConnectionAttemptEvt.ToString()
            }
        }  


        Write-Log "Using Test-NetConnection to test connectivity to StifleR Server $stiflerserver"
        $nettest = Test-NetConnection -ComputerName $stifleRServer -Port $signalrport
        if($nettest.NameResolutionSucceeded -eq $false)
        {
            #We cant resolve, what about home networks etc?
            Write-Log "Failed to resolve the Server name - reporting main issue as DNS"
            $issueToReport = $true;
            $mainIssue = "DNS"
            if($shouldConnectNetwork -eq $true)
            {
                write-log "setting svc action to STOP"
                $action = $actions.Stop;
                $issueToReport = $true;
            }

        }
        elseif($nettest.TcpTestSucceeded -eq $false)
        {
            Write-Log "Can't connect - reporting main issue as FIREWALL"
            #We cant connect, what is the issue, just server down? Poke it on port 80?
            #We end up here if the server svc is stopped so should flag that somehow?
            $mainIssue = "FIREWALL"
            if($shouldConnectNetwork -eq $true)
            {
                write-log "setting svc action to STOP"
                $action = $actions.Stop;
                $issueToReport = $true;
            }
        }
        else
        {
            Write-Log "We can connect but are not connected - reporting main issue as CONLOST"
            #We can connect fine, but are not conneccted, check the registry keys to see if we have not connected for a long time
            $mainIssue = "CONLOST"
            $issueToReport = $true;
        }
        #Have we been trying for a long time?

    }
    else
    {
        #Connected, TBD is ensure server can talk to us, wait for 2.7 to be released for that
        
        Write-Log "Connected, all done! - Returning 0"
        return 0;
    }
}
else
{
    if($shouldConnectNetwork -eq $false)
    {
        #return 0x00000042 as we dont want to be running on this network anyway
        Write-log "Returning 66 as we don't want to be on this network anyway!"
        return 66
    }

    $reportObject = [PSCustomObject]@{}
 
    
    #Get start errors from Eventlog to see if we have any 1026 events that are ours
    $netEventXpath = '*[System[(Level=2) and (EventID=1026 or EventID=1023) and TimeCreated[timediff(@SystemTime) <= 86400000]]]'
    $appCrashEvents = Get-WinEvent -LogName "Application" -FilterXPath $netEventXpath -Oldest
    
    $AppReportEvents = @{};
    $AppConnectionCrashReportEvents = @{};

    #Add one enttry (lates 
    foreach($event in $appCrashEvents)
    {
        if($event.Message.StartsWith("Application: StifleR") -eq $true)
        {
            $AppReportEvents[$event.Id] = $event.Message
        }
    }

    #Get start errors from Eventlog as we should be running here, maybe we 737 error events
    $netEventXpath = '*[System[((EventID=737) or EventID=63)) and TimeCreated[timediff(@SystemTime) <= 86400000]]]'
    $badStifleREvents = Get-WinEvent -LogName "StifleR" -FilterXPath $netEventXpath -Oldest

    foreach($event in $badStifleREvents)
    {
        $AppReportEvents[$event.Id] = $event.Message
    }


    $netEventXpath = '*[System[(Level=1 or Level=2) and TimeCreated[timediff(@SystemTime) <= 86400000]]]'
    $stiflErrorsAndCritical = Get-WinEvent -LogName "StifleR" -FilterXPath $netEventXpath -Oldest

    foreach($event in $stiflErrorsAndCritical)
    {
        $AppReportEvents[$event.Id] = $event.Message
    }

}


if($action -eq $actions.Stop)
{
    Stop-Service -Name $serviceName -Force
    write-log "Stopping Service"
}
elseif($action -eq $actions.Restart)
{
    Restart-Service -Name $serviceName -Force
    write-log "Restarting Service"
}
elseif($action -eq $actions.Kill)
{
    Stop-Process -pid $PID
    write-log "Killing the process"
}




if($report -eq $true -and $shouldConnectNetwork -eq $true)
{

    #We only allow one report per day, so we store that in registry
    $reportTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
    $reportTimeString = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd-HHmm")
    

    # Set variables to indicate value and key to set
    $Name         = 'LastFailReport'
    $Value        = $reportTime 

    # Create the key if it does not exist
    If (-NOT (Test-Path $RegistryPath)) {
        New-Item -Path $RegistryPath -Force | Out-Null
    }
    else
    {

        $LastReport = Get-ItemProperty -Path $RegistryPath -Name $Name 
        if($LastReport -ne $null)
        {
            $LastReportDateTime = [DateTime]::Parse($LastReport.LastFailReport)
            if($LastReportDateTime -ge [DateTime]::UtcNow.AddDays(-1))
            {
                Write-Debug "Already reported issues today"
                Write-log "Already reported issues today - exiting"
                return 89
            }
        }
    }  
    
    # Now set the value
    New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType string -Force

    $AgentId = Get-ItemProperty -Path $RegistryBasePath -Name "AgentId" 

    $reportObject = [PSCustomObject]@{
        StifleRAgentId = $AgentId.AgentId
        ComputerName = $nettest.ComputerName
        PingSucceded = $nettest.PingSucceeded
        NameResolutionSucceeded = $nettest.NameResolutionSucceeded
        AllNameResolutionResults = $nettest.AllNameResolutionResults
        NetRoute = $nettest.TraceRoute
        TcpTestSucceeded = $nettest.TcpTestSucceeded
        StifleRKeyEvents =  $AppReportEvents
        
        Networks = Get-NetIPConfiguration;
        NetworkInfo = $networkCollection
    }

    $reportFile = "$($reportTimeString)_$($env:ComputerName)_$($mainIssue)_health.json"
    $reportFullFile = "$($env:ProgramData)\2Pint Software\StifleR\Client\$reportFile"
    $destinationUrl = "http://$($reportServer):$($reportServerPort)/StifleRHealth/$reportFile";

    #ConvertTo-Json -InputObject $reportObject | ConvertTo-SecureString -Key $encryptkey | ConvertFrom-SecureString | Out-File -FilePath $reportFullFile -Force
    ConvertTo-Json -InputObject $reportObject | Out-File -FilePath $reportFullFile -Force
    
    Compress-Archive -Path $reportFullFile -DestinationPath "$($reportFullFile).zip" -CompressionLevel Optimal -Force

    #before we upload the file, make sure that BITS is running in own process..
    sc.exe config bits type= own
    
    $job = Start-BitsTransfer -TransferType Upload -Description "Report connections issues for StifleR client" -DisplayName StifleRHealthReport -Source "$($reportFullFile).zip" -Destination "$($destinationUrl).zip" -Asynchronous
    
    Start-Sleep -Seconds 15
    if($job.JobState -eq "Transferred")
    {
        Write-Debug "Completing transferred job"
        Write-log "Completing transferred job"
        Complete-BitsTransfer -BitsJob $job
        return 18
    }
    else
    {
        #If job is transferring, we wait a bit longer, then kill it
        if($job.JobState -eq "Transferring")
        {
            Start-Sleep 60
        }

        Complete-BitsTransfer -BitsJob $job
        return 1222
    }
}
write-log "FIN"
return 0;
