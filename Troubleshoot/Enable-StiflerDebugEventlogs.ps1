<#
.SYNOPSIS
  Enable-StiflerDebugEventlogs.ps1

.DESCRIPTION
  Script can enable or disable Stifler Eventlogs, it can also be used to set the size of evenlogs or reset them back to the default value

.PARAMETER enableDebugLogs
  Switch to enable debug logs

.PARAMETER disableDebugLogs
  Switch to disable debug logs

.PARAMETER EventLogs
  Select one or more eventlogs to manipulate, depending if the script is running on a client or server the valid options may differ. Also SetLogMAXSize or ResetLogMAXSize can be used on all eventlogs, not just debug ones.
  If nothing is specified it defaults to "All"

.PARAMETER clearEventLogs
  Clear Stifler eventlogs

.PARAMETER SetLogMAXSize
  Sets the Max size for Stifler logs to specified value

.PARAMETER ResetLogMAXSize
  Resets Stifler logs to their defaul value.

.NOTES
  Version:        1.1
  Author:         support@2pintsoftware.com
  Creation Date:  2023-10-20
  Purpose/Change: Initial script development
  
  CHANGE LOG: 
  1.1             2024/03/21 Added option to enable/disble individualy logs. Fixed so that the SetLogMAXSize works on already enabled debug logs.

#>
#Requires -RunAsAdministrator
Param (
    [Switch]$clearEventLogs,
    [Switch]$enableDebugLogs,
    [Switch]$disableDebugLogs,
    [Parameter(HelpMessage = "Select one or more eventlogs to manipulate, depending if the script is running on a client or server the valid options may differ. Also SetLogMAXSize or ResetLogMAXSize can be used on all eventlogs, not just debug ones.")]
    [ValidateSet("All", "BITSBranchCache", "Bandwidth", "DeliveryOptimization", "Jobs", "Leader", "Location", "MainLoop", "Program", "SignalR", "TriggersAndEvents", "TypeDetection", "BandwidthWatchdog", "DataEngine", "LocationService", "Leaders", "LocationService", "Security", "SignalR", "StifleREngine", "WebApi", "WinService")]
    [string[]]$EventLogs = "All",
    [Int]$SetLogMAXSize,
    [Switch]$ResetLogMAXSize
)

$IsStiflerServer = $false
$IsStiflerClient = $false

if (Get-service -name StifleRServer -ErrorAction SilentlyContinue) {
    $IsStiflerServer = $true
}

if (Get-Service -Name StifleRClient -ErrorAction SilentlyContinue) {
    $IsStiflerClient = $true
}

If (!$IsStiflerServer -and !$IsStiflerClient) {
    Write-error "No Stifler installed in this machine"
    break
}

if ($enableDebugLogs -and $disableDebugLogs) {
    Write-Warning "You can't both enable and disable the eventlogs!! Make up your mind please!"
    break
}

if ($SetLogMAXSize -and $ResetLogMAXSize) {
    Write-Warning "You can't both change and reset the eventlogs size!! Make up your mind please!"
    break
}

if ($EventLogs -contains "All" -and $EventLogs.Count -gt 1) {
    Write-Warning "You can't select All debug logs and at the same time specify specific ones!! Make up your mind please!"
    break
}

$serverdebuglogfiles = @(
    "TwoPintSoftware-StifleR.Service-BandwidthWatchdog/Debug",
    "TwoPintSoftware-StifleR.Service-DataEngine/Analytic",
    "TwoPintSoftware-StifleR.Service-DataEngine/Debug",
    "TwoPintSoftware-StifleR.Service-LocationService/Debug",
    "TwoPintSoftware-StifleR.Service-Leaders/Analytic",
    "TwoPintSoftware-StifleR.Service-Leaders/Debug",
    "TwoPintSoftware-StifleR.Service-LocationService/Admin",
    "TwoPintSoftware-StifleR.Service-Security/Admin",
    "TwoPintSoftware-StifleR.Service-Security/Debug",
    "TwoPintSoftware-StifleR.Service-SignalR/Debug",
    "TwoPintSoftware-StifleR.Service-StifleREngine/Debug",
    "TwoPintSoftware-StifleR.Service-WebApi/Admin",
    "TwoPintSoftware-StifleR.Service-WebApi/Debug",
    "TwoPintSoftware-StifleR.Service-WinService/Debug"
)

$serverstandardlogfiles = @(
    "TwoPintSoftware-StifleR.Service-BandwidthWatchdog/Operational",
    "TwoPintSoftware-StifleR.Service-DataEngine/Operational",
    "TwoPintSoftware-StifleR.Service-Leaders/Operational",
    "TwoPintSoftware-StifleR.Service-LocationService/Operational",
    "TwoPintSoftware-StifleR.Service-Security/Operational",
    "TwoPintSoftware-StifleR.Service-SignalR/Operational",
    "TwoPintSoftware-StifleR.Service-StifleREngine/Operational",
    "TwoPintSoftware-StifleR.Service-WebApi/Operational",
    "TwoPintSoftware-StifleR.Service-WinService/Operational",
    "TwoPintSoftware-StifleR.Service-WMI/Operational"
)

$clientdebuglogfiles = @(
    "TwoPintSoftware-StifleR.ClientApp-Bandwidth/Analytic",
    "TwoPintSoftware-StifleR.ClientApp-Bandwidth/Debug",
    "TwoPintSoftware-StifleR.ClientApp-DeliveryOptimization/Debug",
    "TwoPintSoftware-StifleR.ClientApp-Jobs/Debug",
    "TwoPintSoftware-StifleR.ClientApp-Leader/Debug",
    "TwoPintSoftware-StifleR.ClientApp-Location/Analytic",
    "TwoPintSoftware-StifleR.ClientApp-Location/Debug",
    "TwoPintSoftware-StifleR.ClientApp-MainLoop/Debug",
    "TwoPintSoftware-StifleR.ClientApp-Program/Debug",
    "TwoPintSoftware-StifleR.ClientApp-SignalR/Debug",
    "TwoPintSoftware-StifleR.ClientApp-TriggersAndEvents/Debug",
    "TwoPintSoftware-StifleR.ClientApp-TypeDetection/Debug"
)

$clientstandardlogfiles = @(
    "TwoPintSoftware-StifleR.ClientApp-BITSBranchCache/Operational",
    "TwoPintSoftware-StifleR.ClientApp-Bandwidth/Operational",
    "TwoPintSoftware-StifleR.ClientApp-DeliveryOptimization/Operational",
    "TwoPintSoftware-StifleR.ClientApp-Jobs/Operational",
    "TwoPintSoftware-StifleR.ClientApp-Leader/Operational",
    "TwoPintSoftware-StifleR.ClientApp-Location/Operational",
    "TwoPintSoftware-StifleR.ClientApp-MainLoop/Operational",
    "TwoPintSoftware-StifleR.ClientApp-Program/Operational",
    "TwoPintSoftware-StifleR.ClientApp-SignalR/Operational",
    "TwoPintSoftware-StifleR.ClientApp-SignalRMessages/Operational",
    "TwoPintSoftware-StifleR.ClientApp-TSHelper/Operational",
    "TwoPintSoftware-StifleR.ClientApp-TriggersAndEvents/Operational",
    "TwoPintSoftware-StifleR.ClientApp-TypeDetection/Operational"
)

if ($IsStiflerServer) {
    if ($EventLogs -contains "All" ) {
        $debuglogfiles += $serverdebuglogfiles
        $standardlogfiles += $serverstandardlogfiles 
    }
    else {
        foreach ($log in $EventLogs) {
            $debuglogfiles += $serverdebuglogfiles -match "-$log/"
            $standardlogfiles += $serverstandardlogfiles -match "-$log/"
        }
    }
}
if ($IsStiflerClient) {
    if ($EventLogs -contains "All" ) {
        $debuglogfiles += $clientdebuglogfiles
        $standardlogfiles += $clientstandardlogfiles
    }
    else {
        foreach ($log in $EventLogs) {
            $debuglogfiles += $clientdebuglogfiles -match "-$log/"
            $standardlogfiles += $clientstandardlogfiles -match "-$log/"
        }
    }
}
 
$logfiles = $debuglogfiles + $standardlogfiles

$debugLogsMax = 28

function Set-EventLogSize($eventLogNames, $SetLogMAXSize) {
    foreach ($eventLogName in $eventLogNames) {
        $error.clear()

        try {
            $session = New-Object Diagnostics.Eventing.Reader.EventLogSession ($machine)
            $eventLog = New-Object Diagnostics.Eventing.Reader.EventLogConfiguration ($eventLogName, $session)
        }
        catch {
            Write-warning "warning:unable to open eventlog $($eventLogName) $($error)"
            $error.clear()
        }

        if($eventLog.IsEnabled -eq $true -and ($eventLog.LogType -ieq "Analytic" -or $eventLog.LogType -ieq "Debug"))
        {
            $eventLog.LogName
            $eventLog.IsEnabled = $false
            $eventLog.SaveChanges()
            $eventLog.MaximumSizeInBytes = $SetLogMAXSize
            $eventLog.SaveChanges()
            $eventLog.IsEnabled = $true
            $eventLog.SaveChanges()
    
        }
        else {
            $eventLog.LogName
            $eventLog.MaximumSizeInBytes = $SetLogMAXSize
            $eventLog.SaveChanges()
        }

        $eventLog.Dispose()
        $session.Dispose()

    }
}

function enable-logs($eventLogNames) {
    Write-host "enabling / disabling logs on localhost)."
    [Text.StringBuilder] $sb = new-object Text.StringBuilder
    $debugLogsEnabled = New-Object Collections.ArrayList
    [void]$sb.Appendline("event logs:")

    try {
        foreach ($eventLogName in $eventLogNames) {
            $error.clear()

            try {
                $session = New-Object Diagnostics.Eventing.Reader.EventLogSession ($machine)
                $eventLog = New-Object Diagnostics.Eventing.Reader.EventLogConfiguration ($eventLogName, $session)
            }
            catch {
                Write-host "warning:unable to open eventlog $($eventLogName) $($error)"
                $error.clear()
            }

            if ($clearEventLogs) {
                [void]$sb.AppendLine("clearing event log: $($eventLogName)")
            
                if ($eventLog.IsEnabled -and !$eventLog.IsClassicLog) {
                    $eventLog.IsEnabled = $false
                    $eventLog.SaveChanges()
                    $eventLog.Dispose()

                    $session.ClearLog($eventLogName)

                    $eventLog = New-Object Diagnostics.Eventing.Reader.EventLogConfiguration ($eventLogName, $session)
                    $eventLog.IsEnabled = $true
                    $eventLog.SaveChanges()
                }
                elseif ($eventLog.IsClassicLog) {
                    $session.ClearLog($eventLogName)
                }
            }

            if ($enableDebugLogs -and $eventLog.IsEnabled -eq $false) {
                if ($VerbosePreference -ine "SilentlyContinue" -or $listEventLogs) {
                    [void]$sb.AppendLine("enabling debug log for $($eventLog.LogName) $($eventLog.LogMode)")
                }
         
                $eventLog.IsEnabled = $true
                $eventLog.SaveChanges()
                #$global:debugLogsCount++
            }

            if ($disableDebugLogs -and $eventLog.IsEnabled -eq $true -and ($eventLog.LogType -ieq "Analytic" -or $eventLog.LogType -ieq "Debug")) {
                if ($VerbosePreference -ine "SilentlyContinue" -or $listEventLogs) {
                    [void]$sb.AppendLine("disabling debug log for $($eventLog.LogName) $($eventLog.LogMode)")
                }

                $eventLog.IsEnabled = $false
                $eventLog.SaveChanges()
                #$global:debugLogsCount--

                if ($debugLogsEnabled.Contains($eventLog.LogName)) {
                    $debugLogsEnabled.Remove($eventLog.LogName)
                }
            }

            if ($eventLog.LogType -ieq "Analytic" -or $eventLog.LogType -ieq "Debug") {
                if ($eventLog.IsEnabled -eq $true) {
                    [void]$sb.AppendLine("$($eventLog.LogName) $($eventLog.LogMode): ENABLED")
                    $debugLogsEnabled.Add($eventLog.LogName) | Out-Null

                    if ($debugLogsMax -le $debugLogsEnabled.Count) {
                        Write-Error "Error: too many debug logs enabled ($($debugLogsMax))."
                        Write-Error "Error: this can cause system performance / stability issues as well as inability to boot!"
                        Write-Error "Error: rerun script again with these switches: .\event-log-manager.ps1 -listeventlogs -disableDebugLogs"
                        Write-Error "Error: this will disable all debug logs."
                        Write-Error "Warning: exiting script."
                        exit 1
                    }
                }
                else {
                    [void]$sb.AppendLine("$($eventLog.LogName) $($eventLog.LogMode): DISABLED")
                }
            }
            else {
                [void]$sb.AppendLine("$($eventLog.LogName)")
            }
        }

        Write-host $sb.ToString()
        Write-host "-----------------------------------------"

        if ($debugLogsEnabled.Count -gt 0) {
            foreach ($eventLogName in $debugLogsEnabled) {
                Write-host $eventLogName
            }

            Write-host "Enabled $($debugLogsEnabled.Count) Debug logs"
        }

    }
    catch {
        Write-host "enable logs exception: $($error | out-string)"
        $error.Clear()
    }
}

if ($SetLogMAXSize) {
    Set-EventLogSize -eventLogNames $logfiles -SetLogMAXSize $SetLogMAXSize
}

if ($ResetLogMAXSize) {
    Set-EventLogSize -eventLogNames $logfiles -SetLogMAXSize 1052672 # 1028Kb
}

if ($enableDebugLogs -or $disableDebugLogs) {
    enable-logs -eventLogNames $debuglogfiles
}
if ($clearEventLogs) {
    enable-logs -eventLogNames $logfiles
}