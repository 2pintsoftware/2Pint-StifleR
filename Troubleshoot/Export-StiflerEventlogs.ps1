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
  [string]$outpath = "C:\Windows\Temp",
  [string]$LogSearch = "TwoPintSoftware-*"
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

#Dynamically discover all event logs matching the search pattern.
$logfiles = (Get-WinEvent -ListLog $LogSearch -ErrorAction SilentlyContinue).LogName


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
 