# Credit goes to https://powershell.one who made this code available under Attribution-NoDerivatives 4.0 International (CC BY-ND 4.0) 
# https://creativecommons.org/licenses/by/4.0/ 

$AppName = "StifleR.ClientApp"
$ProcessID = (Get-Process -Name $AppName).Id

function Start-MeasureCpu {
  [CmdletBinding()]
  param
  (
    # default process id to powershells own process id:
    [int]
    $id = $pid
  )
  
  # get snapshot and return it:
  return Get-CimInstance -ClassName Win32_PerfRawData_PerfProc_Process -Filter "IDProcess=$id"
}

function Stop-MeasureCpu{
  param
  (
    # submit the previously taken snapshot
    [Parameter(Mandatory)]
    [ciminstance]
    $StartSnapshot
  )
  
    # get the process id the initial snapshot was taken on:
    $id = $StartSnapshot.IDProcess
  
    # get a second snapshot
    $EndSnapshot = Get-CimInstance -ClassName Win32_PerfRawData_PerfProc_Process -Filter "IDProcess=$id"

    # determine the time interval between the two snapshots in 100ns units:
    $time = $EndSnapshot.Timestamp_Sys100NS - $StartSnapshot.Timestamp_Sys100NS
   
    # get the number of logical cpus
    $cores = [Environment]::ProcessorCount
   
    # calculate cpu time
    # NOTE: CPU time is per CORE, so divide by available CORES to get total average CPU time
    [PSCustomObject]@{
        TotalPercent = [Math]::Round(($EndSnapshot.PercentProcessorTime - $StartSnapshot.PercentProcessorTime)/$time*100/$cores,2)
        UserPercent = [Math]::Round(($EndSnapshot.PercentUserTime - $StartSnapshot.PercentUserTime)/$time*100/$cores,2)
        PrivilegedPercent = [Math]::Round(($EndSnapshot.PercentPrivilegedTime - $StartSnapshot.PercentPrivilegedTime)/$time*100/$cores,2)
    }
}

# get a first snapshot
$snap = Start-MeasureCpu -id $ProcessID

# Wait 10 minutes
Start-Sleep -Seconds 600

# Once done, take a second snapshot and compare to the first
$Result = Stop-MeasureCpu -StartSnapshot $snap
$Result.TotalPercent | Out-File -FilePath "C:\Windows\Temp\StiflerClientUsage.txt"