<#
.SYNOPSIS
  Enable-StiflerDebugEventlogs.ps1

.DESCRIPTION
  Script analyzes any Stifler event logs in the specified path and displays them in a GridView.
  Computer running this script MUST have the stifler client installed to be able to read the logfiles.

.PARAMETER enableDebugLogs
  Path to folder containing Stifler .evtx logs exported from a computer with the Stifler client.

.PARAMETER disableDebugLogs

.PARAMETER clearEventLogs
  Clear all Stifler eventlogs

.PARAMETER SetLogMAXSize
  Sets the Max size for all Stifler logs to specified value

.PARAMETER ResetLogMAXSize
  Resets all Stifler logs to their defaul value.

.NOTES
  Version:        1.0
  Author:         support@2pintsoftware.com
  Creation Date:  2023-10-20
  Purpose/Change: Initial script development

#>
#Requires -RunAsAdministrator
Param (
    [string]$outpath = "C:\Windows\Temp",
    [Switch]$clearEventLogs,
    [Switch]$enableDebugLogs,
    [Switch]$disableDebugLogs,
    [Int]$SetLogMAXSize,
    [Switch]$ResetLogMAXSize
)



if($enableDebugLogs -and $disableDebugLogs)
{
    Write-Warning "You can't both enable and disable the eventlogs!! Make up your mind please!"
    break
}

if($SetLogMAXSize -and $ResetLogMAXSize)
{
    Write-Warning "You can't both change and reset the eventlogs size!! Make up your mind please!"
    break
}

$debuglogfiles = @(
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

$standardlogfiles = @(
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

$logfiles = $debuglogfiles + $standardlogfiles

$debugLogsMax = 20

function Set-EventLogSize($eventLogNames, $SetLogMAXSize)
{
    foreach ($eventLogName in $eventLogNames)
    {
        $error.clear()

        try
        {
            $session = New-Object Diagnostics.Eventing.Reader.EventLogSession ($machine)
            $eventLog = New-Object Diagnostics.Eventing.Reader.EventLogConfiguration ($eventLogName,$session)
        }
        catch
        {
            Write-host "warning:unable to open eventlog $($eventLogName) $($error)"
            $error.clear()
        }

        $eventLog.LogName
        $eventLog.MaximumSizeInBytes = $SetLogMAXSize
        $eventLog.SaveChanges()

        $eventLog.Dispose()
        $session.Dispose()

    }
}

if($SetLogMAXSize)
{
    Set-EventLogSize -eventLogNames $logfiles -SetLogMAXSize $SetLogMAXSize
}

if($ResetLogMAXSize)
{
    Set-EventLogSize -eventLogNames $logfiles -SetLogMAXSize 1052672 # 1028Kb
}

function enable-logs($eventLogNames)
{
    Write-host "enabling / disabling logs on localhost)."
    [Text.StringBuilder] $sb = new-object Text.StringBuilder
    $debugLogsEnabled = New-Object Collections.ArrayList
    [void]$sb.Appendline("event logs:")

    try
    {
        foreach ($eventLogName in $eventLogNames)
        {
            $error.clear()

            try
            {
                $session = New-Object Diagnostics.Eventing.Reader.EventLogSession ($machine)
                $eventLog = New-Object Diagnostics.Eventing.Reader.EventLogConfiguration ($eventLogName,$session)
            }
            catch
            {
                Write-host "warning:unable to open eventlog $($eventLogName) $($error)"
                $error.clear()
            }

            if ($clearEventLogs)
            {
                [void]$sb.AppendLine("clearing event log: $($eventLogName)")
            
                if ($eventLog.IsEnabled -and !$eventLog.IsClassicLog)
                {
                    $eventLog.IsEnabled = $false
                    $eventLog.SaveChanges()
                    $eventLog.Dispose()

                    $session.ClearLog($eventLogName)

                    $eventLog = New-Object Diagnostics.Eventing.Reader.EventLogConfiguration ($eventLogName, $session)
                    $eventLog.IsEnabled = $true
                    $eventLog.SaveChanges()
                }
                elseif ($eventLog.IsClassicLog)
                {
                    $session.ClearLog($eventLogName)
                }
            }

            if ($enableDebugLogs -and $eventLog.IsEnabled -eq $false)
            {
                if ($VerbosePreference -ine "SilentlyContinue" -or $listEventLogs)
                {
                    [void]$sb.AppendLine("enabling debug log for $($eventLog.LogName) $($eventLog.LogMode)")
                }
         
                $eventLog.IsEnabled = $true
                $eventLog.SaveChanges()
                $global:debugLogsCount++
            }

            if ($disableDebugLogs -and $eventLog.IsEnabled -eq $true -and ($eventLog.LogType -ieq "Analytic" -or $eventLog.LogType -ieq "Debug"))
            {
                if ($VerbosePreference -ine "SilentlyContinue" -or $listEventLogs)
                {
                    [void]$sb.AppendLine("disabling debug log for $($eventLog.LogName) $($eventLog.LogMode)")
                }

                $eventLog.IsEnabled = $false
                $eventLog.SaveChanges()
                $global:debugLogsCount--

                if ($debugLogsEnabled.Contains($eventLog.LogName))
                {
                    $debugLogsEnabled.Remove($eventLog.LogName)
                }
            }

            if ($eventLog.LogType -ieq "Analytic" -or $eventLog.LogType -ieq "Debug")
            {
                if ($eventLog.IsEnabled -eq $true)
                {
                    [void]$sb.AppendLine("$($eventLog.LogName) $($eventLog.LogMode): ENABLED")
                    $debugLogsEnabled.Add($eventLog.LogName)

                    if ($debugLogsMax -le $debugLogsEnabled.Count)
                    {
                        Write-host "Error: too many debug logs enabled ($($debugLogsMax))."
                        Write-host "Error: this can cause system performance / stability issues as well as inability to boot!"
                        Write-host "Error: rerun script again with these switches: .\event-log-manager.ps1 -listeventlogs -disableDebugLogs"
                        Write-host "Error: this will disable all debug logs."
                        Write-host "Warning: exiting script."
                        exit 1
                    }
                }
                else
                {
                    [void]$sb.AppendLine("$($eventLog.LogName) $($eventLog.LogMode): DISABLED")
                }
            }
            else
            {
                [void]$sb.AppendLine("$($eventLog.LogName)")
            }
        }

        Write-host $sb.ToString()
        Write-host "-----------------------------------------"

        if ($debugLogsEnabled.Count -gt 0)
        {
            foreach ($eventLogName in $debugLogsEnabled)
            {
                Write-host $eventLogName
            }

            Write-host "Enabled $($debugLogsEnabled.Count) Debug logs"
        }

    }
    catch
    {
        Write-host "enable logs exception: $($error | out-string)"
        $error.Clear()
    }
}

if($enableDebugLogs -or $disableDebugLogs)
{
    enable-logs -eventLogNames $debuglogfiles
}
if($clearEventLogs)
{
    enable-logs -eventLogNames $logfiles
}