#Checks Memory and avg CPU utilization and restarts stifler service if high utilization
# 1.0.0.2 - Added active client counts and versions
# 1.0.0.3 - Added StifleR Counters
# 1.0.0.4 - Added check for starting the StifleR Server service, and added more accurate timestamp
# 1.0.0.5 - Changed to create daily logs rather than one large log
# 1.0.0.6 - Updated logging function, and Added logic to delete logs older than 180 days
# 1.0.0.7 - Updated logic to create logs folder and to toggle performance counters

$Date = $(get-date -f MMddyyyy)

# Update below to reflect customer environment
$LogPath = "E:\2Pint_Maintenance\Logs\StifleR_Resource_Manager"
$LogFile = "$LogPath\HighCPUMemServiceRestarts-$Date.log"
$CleanupLog = "$LogPath\ResourceManagerCleanup.log"
$DaystoKeepLogFiles = 180
$IncludePerformanceCounters = $False

function Write-Log {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        $Message,
        [Parameter(Mandatory=$false)]
        $ErrorMessage,
        [Parameter(Mandatory=$false)]
        $Component = "Script",
        [Parameter(Mandatory=$false)]
        [int]$Type
    )
    <#
    Type: 1 = Normal, 2 = Warning (yellow), 3 = Error (red)
    #>
   $Time = Get-Date -Format "HH:mm:ss.ffffff"
   $Date = Get-Date -Format "MM-dd-yyyy"
   if ($ErrorMessage -ne $null) {$Type = 3}
   if ($Component -eq $null) {$Component = " "}
   if ($Type -eq $null) {$Type = 1}
   $LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
   $LogMessage.Replace("`0","") | Out-File -Append -Encoding UTF8 -FilePath $LogFile
}

# Create folders if needed
If (!(Test-path $LogPath)){ New-Item -Path $LogPath -ItemType Directory -Force }

Write-Log "INIT: Resource Manager Script started"

# Start the StifleR Server service if not started
$Status = (get-service -name "StifleRServer").Status

If($Status -ne "Running"){
    Write-Log "WARNING: Starting StifleR Server Service was not started, trying to start it."
    net start StifleRServer
    Write-Log "Sleeping 60 seconds" 
    Start-sleep -s 60
}

# Just in case service didnt get started on first try
$Status = (get-service -name "StifleRServer").Status

If($Status -ne "Running"){
    Write-Log "WARNING: Starting StifleR Server Service did not start in previous attempt, trying one more time"
    net start StifleRServer
    Write-Log "WARNING: Sleeping 60 seconds"
    Start-sleep -s 60
}

# Checking the service status, no point in continuing if service is not started
If($Status -ne "Running"){
    Write-Log "WARNING: StifleR Server Service could not be started, aborting script"
    Break
}

# Starting Resource Usage Check
Write-Log "Starting Resource Usage Check, will run for 1 minute"

$CPU1 = (Get-WmiObject win32_processor | Measure-Object -property LoadPercentage -Average | Select Average).average

start-sleep -s 30

$CPU2 = (Get-WmiObject win32_processor | Measure-Object -property LoadPercentage -Average | Select Average).average

start-sleep -s 30

$CPU3 = (Get-WmiObject win32_processor | Measure-Object -property LoadPercentage -Average | Select Average).average

$Mem = (Get-Counter '\Memory\Available MBytes').countersamples
$Mem1 = $Mem.cookedvalue
$MemInGB = [Math]::Round($Mem1/1024,2)

$CPUAverage = [math]::Round(($CPU1+$CPU2+$CPU3)/3)

$PrivateMemorySizeInGB = [Math]::Round((Get-Process -Name StifleR.Service).PrivateMemorySize64/1GB,2)
$VirtualMemorySizeInGB = [Math]::Round((Get-Process -Name StifleR.Service).VirtualMemorySize64/1GB,2)

# Some server stats are available via https://stifler01.corp.viamonstra.com:9000/api/serverstats too
$NumberOfClientConnections = (Get-WmiObject -namespace root\StifleR -Query "Select NumberOfClients from StifleREngine").NumberOfClients

If ($IncludePerformanceCounters){
    Write-Log "IncludePerformanceCounters parameter set to True, including performance counters"
    #Get StifleR DataEngine counters
    $CounterList = Get-Counter -ListSet "StifleR DataEngine","SignalR"
    $Data = Get-Counter -Counter $CounterList.Counter | ForEach {
        $_.CounterSamples | ForEach {
            [pscustomobject]@{
                #TimeStamp = $(TimeStamp)
                Counter = $_.Path
                CookedValue = $_.CookedValue
            }
        }
    }
}

If($MemInGB -lt '5'){

    # Server utilization too high, log this
    Write-Log "WARNING: Usage too high, restarting service: Available memory: $MemInGB GB, Average CPU utilization: $CPUAverage percent"
    Write-Log "WARNING: StifleR Server Process Private Memory Size: $PrivateMemorySizeInGB GB, Virtual Memory size: $VirtualMemorySizeInGB GB"
    Write-Log "WARNING: Total number of StifleR client connections: $NumberOfClientConnections"
    
    <#
    Foreach($Version in $UniqueVersions){
        $VersionCount = (((Get-WmiObject -Namespace root\StifleR -Query "Select * from Connections Where Version = '$Version' ") | Measure-Object).Count)
        Write-Log "WARNING: StifleR Client $Version connection count is $VersionCount"
    }
    #>

If ($IncludePerformanceCounters){    
    Foreach($Line in $Data){
        Write-Log "ALL OK: StifleR Server Counter: $($Line.Counter) has value: $($Line.CookedValue)"
    }
}


    "--------------------------------------------------------------------------------------------------------------------"
    

    # Continuing to stop and start service
    Write-Log "WARNING: Stopping StifleR Server Service"
    net stop StifleRServer
    Write-Log "Sleeping 60 seconds"
    Start-Sleep -Seconds 60

    # If for some reason the service didn't stop correctly - force it.
    Write-Log "WARNING: Verifying that the StifleR Service actually stopped"
    $stiflerproc = Get-Process stifler.service -ErrorAction SilentlyContinue
    if ($stiflerproc) {
    Write-Log "WARNING: Service could not be stopped, stopping its process instead"
    $stiflerproc  | stop-process -Force
    }

    Start-Sleep -Seconds 10

    Write-Log "WARNING: Starting StifleR Server Service"
    net start StifleRServer

    Write-Log "Sleeping 60 seconds"
    Start-sleep -s 60

    #Just in case service didnt get started on first try or if service has stopped unexpectedly
    $Status = (get-service -name "StifleRServer").Status

    If($Status -ne "Running"){
        Write-Log "WARNING: Starting StifleR Server Service did not start in previous attempt, trying one more time"
        net start StifleRServer
    }

}
Else{
    # Utilization ok, just log the value
    Write-Log "ALL OK: Available memory: $MemInGB GB, Average CPU utilization: $CPUAverage percent"
    Write-Log "ALL OK: StifleR Server Process Private Memory Size is $PrivateMemorySizeInGB GB, Virtual Memory size is $VirtualMemorySizeInGB GB"
    Write-Log "ALL OK: Total number of StifleR client connections: $NumberOfClientConnections"
    <#
    Foreach($Version in $UniqueVersions){
        $VersionCount = (((Get-WmiObject -Namespace root\StifleR -Query "Select * from Connections Where Version = '$Version' ") | Measure-Object).Count)
        Write-Log "ALL OK: StifleR Client $Version connection count is $VersionCount"
    }
    #>

    If ($IncludePerformanceCounters){    
        Foreach($Line in $Data){
            Write-Log "ALL OK: StifleR Server Counter: $($Line.Counter) has value: $($Line.CookedValue)"
        }
    }


    "--------------------------------------------------------------------------------------------------------------------"
}


# Cleanup older log files
$itemsToDelete = dir $LogPath -Recurse -File HighCPUMemServiceRestarts*.log | Where LastWriteTime -lt ((get-date).AddDays(-$DaystoKeepLogFiles))

if ($itemsToDelete.Count -gt 0){
    ForEach ($item in $itemsToDelete){
        "$($item.BaseName) is older than $((get-date).AddDays(-$DaystoKeepLogFiles)) and will be deleted" | Add-Content $CleanupLog
        Remove-Item $item.FullName -Force
    }
}
else{
    "No items to be deleted today $($(Get-Date).DateTime)"  | Add-Content $CleanupLog
    }

Write-Log "Cleanup of log files older than $((get-date).AddDays(-$DaystoKeepLogFiles)) completed..."
start-sleep -Seconds 10

