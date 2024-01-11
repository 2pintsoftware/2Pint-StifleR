<#
.SYNOPSIS
  Analyze-StiflerEventlogs.ps1

.DESCRIPTION
  Script analyzes any Stifler event logs in the specified path and displays them in a GridView.
  Computer running this script MUST have the stifler client installed to be able to read the logfiles.

.PARAMETER path
  Path to folder containing Stifler .evtx logs exported from a computer with the Stifler client.

.NOTES
  Version:        1.0
  Author:         support@2pintsoftware.com
  Creation Date:  2023-10-18
  Purpose/Change: Initial script development

#>
#Requires -RunAsAdministrator
#region --------------------------------------------------[Script Parameters]------------------------------------------------------
Param (
    [Parameter(Mandatory=$true)]
    [string]$path 
)

#endregion
#region ---------------------------------------------------[Functions]------------------------------------------------------------

#Will serach for Critical, Error and Warnings
$loglevel = 1,2,3

if(!(Test-Path -path $path -PathType Container))
{
    write-error "No such directory found"
    break
}
else{
    $logfiles = Get-ChildItem -Path $path -Filter "*.evtx"
    if($logfiles -eq 0)
    {
        Write-error "No eventlogs found in $path"
        break
    }
}

# Get-WinEvent -Path C:\test\StiflerLogs_202310191454\StifleR.ClientApp-Location_Operational.evtx
# $logfiles = Get-ChildItem -Path C:\test\StiflerLogs_202310191454 -Filter '*.evtx'

$logdata = @()
foreach($logfile in $logfiles)
{
    Write-Host "Processing: $($logfile.Name)"
    $logdata += Get-WinEvent -FilterHashtable @{Path="$($logfile.FullName)";Level=$loglevel} -ErrorAction SilentlyContinue | Select-Object @{Label="LogName";Expression={($logfile.Name -split "\.evtx")[0]}},TimeCreated,Id,LevelDisplayName,Message
}

$logdata | Out-GridView