<#
.SYNOPSIS
  Export-StiflerEventlogs.ps1

.DESCRIPTION
  Script exports any Stifler event logs from the local computer so they can be shared with 2Pint software support upon request.

.PARAMETER outpath
  Folder where a zip will be created containing the export on any Stifler logs from the local computer.
  In the format StiflerLogs_yyyyMMddHHmm.zip

.NOTES
  Version:        1.0
  Author:         support@2pintsoftware.com
  Creation Date:  2023-10-18
  Purpose/Change: Initial script development

#>
#Requires -RunAsAdministrator
#region --------------------------------------------------[Script Parameters]------------------------------------------------------
Param (
  [string]$outpath = "C:\Windows\Temp"
)

#endregion
#region --------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
#$ErrorActionPreference = 'SilentlyContinue'

#Import Modules & Snap-ins
#endregion

#region ---------------------------------------------------[Functions]------------------------------------------------------------



$tempGuid = [guid]::NewGuid()
$temppath = (new-item "$outpath\$tempGuid" -ItemType Directory -Force).FullName

#Stifler Logs Files to be exported if they exists.
$logfiles = @(
  "TwoPintSoftware-StifleR.Service-BandwidthWatchdog/Debug",
  "TwoPintSoftware-StifleR.Service-BandwidthWatchdog/Operational",
  "TwoPintSoftware-StifleR.Service-DataEngine/Analytic",
  "TwoPintSoftware-StifleR.Service-DataEngine/Debug",
  "TwoPintSoftware-StifleR.Service-DataEngine/Operational",
  "TwoPintSoftware-StifleR.Service-LocationService/Admin",
  "TwoPintSoftware-StifleR.Service-LocationService/Debug",
  "TwoPintSoftware-StifleR.Service-LocationService/Operational",
  "TwoPintSoftware-StifleR.Service-Leaders/Analytic",
  "TwoPintSoftware-StifleR.Service-Leaders/Debug",
  "TwoPintSoftware-StifleR.Service-Leaders/Operational",
  "TwoPintSoftware-StifleR.Service-Security/Admin",
  "TwoPintSoftware-StifleR.Service-Security/Debug",
  "TwoPintSoftware-StifleR.Service-Security/Operational",
  "TwoPintSoftware-StifleR.Service-SignalR/Debug",
  "TwoPintSoftware-StifleR.Service-SignalR/Operational",
  "TwoPintSoftware-StifleR.Service-StifleREngine/Debug",
  "TwoPintSoftware-StifleR.Service-StifleREngine/Operational",
  "TwoPintSoftware-StifleR.Service-WebApi/Admin",
  "TwoPintSoftware-StifleR.Service-WebApi/Debug",
  "TwoPintSoftware-StifleR.Service-WebApi/Operational",
  "TwoPintSoftware-StifleR.Service-WinService/Debug"
  "TwoPintSoftware-StifleR.Service-WinService/Operational",
  "TwoPintSoftware-StifleR.Service-WMI/Operational"
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
  "TwoPintSoftware-StifleR.ClientApp-BITSBranchCache/Operational",
  "TwoPintSoftware-StifleR.ClientApp-Bandwidth/Analytic",
  "TwoPintSoftware-StifleR.ClientApp-Bandwidth/Debug",
  "TwoPintSoftware-StifleR.ClientApp-Bandwidth/Operational",
  "TwoPintSoftware-StifleR.ClientApp-DeliveryOptimization/Debug",
  "TwoPintSoftware-StifleR.ClientApp-DeliveryOptimization/Operational",
  "TwoPintSoftware-StifleR.ClientApp-Jobs/Debug",
  "TwoPintSoftware-StifleR.ClientApp-Jobs/Operational",
  "TwoPintSoftware-StifleR.ClientApp-Leader/Debug",
  "TwoPintSoftware-StifleR.ClientApp-Leader/Operational",
  "TwoPintSoftware-StifleR.ClientApp-Location/Analytic",
  "TwoPintSoftware-StifleR.ClientApp-Location/Debug",
  "TwoPintSoftware-StifleR.ClientApp-Location/Operational",
  "TwoPintSoftware-StifleR.ClientApp-MainLoop/Debug",
  "TwoPintSoftware-StifleR.ClientApp-MainLoop/Operational",
  "TwoPintSoftware-StifleR.ClientApp-Program/Debug",
  "TwoPintSoftware-StifleR.ClientApp-Program/Operational",
  "TwoPintSoftware-StifleR.ClientApp-SignalR/Debug",
  "TwoPintSoftware-StifleR.ClientApp-SignalR/Operational",
  "TwoPintSoftware-StifleR.ClientApp-SignalRMessages/Operational",
  "TwoPintSoftware-StifleR.ClientApp-TSHelper/Operational",
  "TwoPintSoftware-StifleR.ClientApp-TriggersAndEvents/Debug",
  "TwoPintSoftware-StifleR.ClientApp-TriggersAndEvents/Operational",
  "TwoPintSoftware-StifleR.ClientApp-TypeDetection/Debug",
  "TwoPintSoftware-StifleR.ClientApp-TypeDetection/Operational"
)


# Export logs
foreach ($logfile in $logfiles) {
  $outname = ($logfile -split "-", 2)[1] -replace "/", "_"
  try {
    . wevtutil epl $logfile "$temppath\$outname.evtx" 2>&1 | Out-Null
  }
  catch {}
}

$filepath = "$outpath\StiflerLogs_$(get-date -f yyyyMMddHHmm).zip"

Compress-Archive -Path "$temppath\*.*" $filepath -CompressionLevel Optimal

Remove-Item $temppath -Recurse -Force

Invoke-Expression "explorer '/select,""$filePath""'"
Write-Host "Log export completed.  File created at: $filepath" -ForegroundColor Green