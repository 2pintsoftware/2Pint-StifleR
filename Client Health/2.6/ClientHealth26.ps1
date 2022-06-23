#The StifleR server
$stifleRServer = "sms01.2PSTEST2.LOCAL"
$signalrport = 1414

#Typically a FSP server with BITS server extensions on
$reportServer = "sms01.2PSTEST2.LOCAL"
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
$RegistryPath = "$($RegistryBasePath)\Connection"
$actions = [PSCustomObject]@{ Restart = 1;Stop = 2;Kill = 3 }


#check if we even have a service
$serviceStatus = Get-Service -Name $serviceName

if($serviceStatus -eq $null)
{
    #Service not installed - exit out
    return 1060
}
else
{
    Write-Debug "Service detected, proceeding..."
}

if($serviceStatus.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running -or  $serviceStatus.Status -eq [System.ServiceProcess.ServiceControllerStatus]::StartPending)
{
    $stifleRserviceRunning = $true;
}
elseif($serviceStatus.StartType -eq [System.ServiceProcess.ServiceStartMode]::Automatic -and $serviceStatus.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running)
{
    #All stopped/crashed states
    $stifleRserviceRunning = $false;

    #Read if we stopped the service
    #TBD

}
elseif($serviceStatus.StartType -eq [System.ServiceProcess.ServiceStartMode]::Manual -or $serviceStatus.StartType -eq [System.ServiceProcess.ServiceStartMode]::Disabled)
{
    $stifleRserviceRunning = $false;
}
else
{
    #Any issues? Or let below .exe tracking find the error?
    #$issueToReport = $true
    $stifleRserviceRunning = $false;
}

try {
    
    $process = Get-Process -Name $processName -ErrorAction Stop
    
    #We should only have one
    [DateTime]$processStart = $process[0].StartTime;
    
    #Catch a service failing and restarting?

    #get key data
    #$process.CPU

    $stifleRprocessRunning = $true;
} 
catch {
    Write-Host "No Process"
    $stifleRprocessRunning = $false;
}


$shouldConnectNetwork = $false

#Write a registry to determine if we stopped it?
#Get all connected networks if possible
Add-type -path Microsoft.WindowsAPICodePack.dll
[Microsoft.WindowsAPICodePack.Net.NetworkCollection]$networkCollection = [Microsoft.WindowsAPICodePack.Net.NetworkListManager]::GetNetworks([Microsoft.WindowsAPICodePack.Net.NetworkConnectivityLevels]::Connected)

#Any network that is domain auth or authenticated is considered managed
foreach($network in $networkCollection)
{
    if($network.Category -eq [Microsoft.WindowsAPICodePack.Net.NetworkCategory]::Authenticated -or $network.DomainType -eq [Microsoft.WindowsAPICodePack.Net.DomainType]::DomainAuthenticated)
    {
            
            $shouldConnectNetwork = $true;
    }
}



if($stifleRprocessRunning -eq $true)
{

    $connection = Get-NetTCPConnection -RemotePort $signalrport -OwningProcess $process.Id

    if($connection -eq $null)
    {
     
        #Check if we are about to connect, save this time and the last success to registry and then check it again next time
             
        # Create the key if it does not exist
        If (-NOT (Test-Path $RegistryPath)) {
            New-Item -Path $RegistryPath -Force | Out-Null
        }
        else
        {

            $NextConnectionAttemptSaved = Get-ItemProperty -Path $RegistryPath -Name 'NextConnectionAttemptSaved' 
            $NextConnectionAttempt = Get-ItemProperty -Path $RegistryPath -Name 'NextConnectionAttempt' 
            $LastConnectionSuccess = Get-ItemProperty -Path $RegistryPath -Name 'LastConnectionSuccess' 

            if($NextConnectionAttemptSaved -ne $null)
            {
                #We have a stored time, check if we should kill the service/report

                if($LastConnectionSuccess -ne $null)
                {
                    $LastConnectionSuccessDateTime = [DateTime]::Parse($LastConnectionSuccess);
                    $NextConnectionAttemptSavedDateTime = [DateTime]::Parse($NextConnectionAttemptSaved);
                    
                    if($LastConnectionSuccessDateTime -gt $NextConnectionAttemptSavedDateTime)
                    {
                        Write-Debug "Connected after last run, assuming OK state"
                        return 0;
                    }
                    else
                    {
                        Write-Debug "No connection since last review"
                        $action = $actions.Restart
                        $issueToReport = $true;
                    }

                }
            }
            else
            {
                Set-ItemProperty -Path $RegistryPath -Name 'NextConnectionAttemptSaved' -Value $NextConnectionAttempt
            }
        }  


        
        $nettest = Test-NetConnection -ComputerName $stifleRServer -Port $signalrport
        if($nettest.NameResolutionSucceeded -eq $false)
        {
            #We cant resolve, what about home networks etc?
            $issueToReport = $true;
            $mainIssue = "DNS"
            if($shouldConnectNetwork -eq $true)
            {
                $action = $actions.Stop;
            }

        }
        elseif($nettest.TcpTestSucceeded -eq $false)
        {
            #We cant connect, what is the issue, just server down? Poke it on port 80?
            $mainIssue = "FIREWALL"
            if($shouldConnectNetwork -eq $true)
            {
                $action = $actions.Stop;
                $issueToReport = $true;
            }
        }
        else
        {
            #We can connect fine, but are not conneccted, check the registry keys to see if we have not connected for a long time
            $mainIssue = "CONLOST"
            $issueToReport = $true;
        }
        #Have we been trying for a long time?

    }
    else
    {
        #Connected, TBD is ensure server can talk to us, wait for 2.7 to be released for that
        return 0;
    }
}
else
{
    if($shouldConnectNetwork -eq $false)
    {
        #return 0x00000042 as we dont want to be running on this network anyway
        return 66
    }
    
    
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
}
elseif($action -eq $actions.Restart)
{
    Restart-Service -Name $serviceName -Force
}
elseif($action -eq $actions.Kill)
{
    Stop-Process -pid $PID
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
            $LastReportDateTime = [DateTime]::Parse($LastReport);
            if($LastReportDateTime -ge [DateTime]::UtcNow.AddDays(-1))
            {
                Write-Debug "Already reported issues today"
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
    
    $job = Start-BitsTransfer -TransferType Upload -Description "Report connections issues for StifleR client" -DisplayName StifleRHealthReport -Source $reportFullFile -Destination $destinationUrl -Asynchronous
    
    Start-Sleep -Seconds 15
    if($job.JobState -eq "Transferred")
    {
        Write-Debug "Completing transferred job"
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

return 0;

