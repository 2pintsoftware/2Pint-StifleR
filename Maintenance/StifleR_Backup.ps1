<# 
   .SYNOPSIS 
    Takes a snapshot or offline backup of the StifleR Server configuration and Databases

   .DESCRIPTION
   Creates a backup folder under the current StifleR data folder - using Time/Date stamp for the folder name
   Backs up the StifleR Databases using ESENTUTL.EXE
   Backs up the .config XML configuration file


   .REQUIREMENTS
   Must be run as Admin
   The DB backup will only work on Server 2016 or higher - contact us for 2012 backups

   .USAGE
   .\StifleR-Backup.ps1 -Mode Online/Offline


   .NOTES
    AUTHOR: 2Pint Software
    EMAIL: support@2pintsoftware.com
    VERSION: 1.0.0.0
    DATE:22/05/2019 
    
    CHANGE LOG: 
    1.0.0.0 : 02/22/2018  : Initial version of script
    1.0.0.1 : 10/1/2019  : Modified backup location to archive on data disk
    1.0.0.2 : 8/5/2020  : Added Offline option, simplified path handling, added logging, and added logic to only keep backups for a week

   .LINK
    https://2pintsoftware.com

#>

#Requires -RunAsAdministrator
[CmdletBinding()]
param(
	[Parameter(HelpMessage = "Use this parameter to specify whether to run the backup in Online or Offline Mode.",Mandatory=$True)]
    [ValidateSet("Online","Offline”)]
	[string]$Mode
)

# Modify locations to match your environment
$DataPath = "C:\ProgramData\2Pint Software\StifleR\Server"
$BackupPath = "E:\2Pint_Backup\StifleR_Backup"
$StifleRInstallDir = "C:\Program Files\2Pint Software\StifleR"
$GenerateLocationScript = "C:\ProgramData\2Pint Software\StifleR\Server\GenerateLocation.ps1"

$Date = $(get-date -f MMddyyyy)
$LogFile = "E:\2Pint_Maintenance\StifleR_Backup$Date.log"

Function Write-Log{
	param (
    [Parameter(Mandatory = $true)]
    [string]$Message
   )

   $TimeGenerated = $(Get-Date -UFormat "%D %T")
   $Line = "$TimeGenerated $Message"
   Add-Content -Value $Line -Path $LogFile -Encoding Ascii

}

# Start logging (remove todays log if exist)
Write-Log -Message "Starting backup of StifleR Databases and Configuration" 

# Validate critical locations
If (!(Test-Path $DataPath)){
    Write-Log -Message "$DataPath does exist not, aborting..."
    Write-Warning -Message "$DataPath does not exist, aborting..."
    Break
}

If (!(Test-Path $StifleRInstallDir)){
    Write-Log -Message "$StifleRInstallDir does exist not, aborting..."
    Write-Warning -Message "$StifleRInstallDir does not exist, aborting..."
    Break
}


#-----------------------------------------------------------
# Make a backup of the StifleR Data
#-----------------------------------------------------------

$ts = $(get-date -f MMddyyyy)+$(get-date -f HHmmss)

# First, create the backup folders
If (!(Test-Path "$BackupPath\StifleRBackup.$ts.bak\Databases")){New-Item -ItemType Directory -Path "$BackupPath\StifleRBackup.$ts.bak\Databases" -Force}

If ($Mode -eq "Online"){

    # Take an online backup of the ESE Databases
    Write-Log -Message "Online Backup requested, running ESENTUTL.exe.."
    If (Test-Path $DataPath\Databases\Clients\Clients.edb) {ESENTUTL.EXE /y $DataPath\Databases\Clients\Clients.edb /vssrec epc . /d $BackupPath\StifleRBackup.$ts.bak\Databases\Clients.edb}
    If (Test-Path $DataPath\Databases\History\History.edb) {ESENTUTL.EXE /y $DataPath\Databases\History\History.edb /vssrec epc . /d $BackupPath\StifleRBackup.$ts.bak\Databases\History.edb}
    If (Test-Path $DataPath\Databases\Jobs\Jobs.edb) {ESENTUTL.EXE /y $DataPath\Databases\Jobs\Jobs.edb /vssrec epc . /d $BackupPath\StifleRBackup.$ts.bak\Databases\Jobs.edb}
    If (Test-Path $DataPath\Databases\Locations\locations.edb) {ESENTUTL.EXE /y $DataPath\Databases\Locations\locations.edb /vssrec epc . /d $BackupPath\StifleRBackup.$ts.bak\Databases\Locations.edb}
    If (Test-Path $DataPath\Databases\SRUM\SRUM.edb) {ESENTUTL.EXE /y $DataPath\Databases\SRUM\SRUM.edb /vssrec epc . /d $BackupPath\StifleRBackup.$ts.bak\Databases\SRUM.edb}

}

If ($Mode -eq "Offline"){

    $ServiceName = "StifleRServer"
    $StifleRProc = "stifler.service"

    # Take an offline backup of the ESE Databases
    Write-Log -Message "Offline Backup requested"

    # Stop the Service
    $s = Get-Service $ServiceName -ErrorAction SilentlyContinue
    If ($s){
        Write-Log -Message "Attempting to Stop the StifleR Server Service"
        Stop-Service $s.name -Force -WarningAction SilentlyContinue
    }
    Else{
        Write-Log -Message "The StifleR Server service was not found, aborting..."
        Break
    }

    # If for some reason the service didn't stop correctly - force it.
    $stiflerProcess = Get-Process $StifleRProc -ErrorAction SilentlyContinue
    if ($stiflerProcess){
        Write-Log -Message "StifleR Server process is still running - will attempt to stop it"
        $stiflerProcess  | stop-process -Force
    }

    Write-Log -Message "Making an offline backup of the database files"

    If (Test-Path $DataPath\Databases\Clients\Clients.edb) {Copy-Item -Path $DataPath\Databases\Clients -Destination $BackupPath\StifleRBackup.$ts.bak\Databases\Clients -Recurse}
    If (Test-Path $DataPath\Databases\History\History.edb) {Copy-Item -Path $DataPath\Databases\History -Destination $BackupPath\StifleRBackup.$ts.bak\Databases\History -Recurse}
    If (Test-Path $DataPath\Databases\Jobs\Jobs.edb) {Copy-Item -Path $DataPath\Databases\Jobs -Destination $BackupPath\StifleRBackup.$ts.bak\Databases\Jobs -Recurse}
    If (Test-Path $DataPath\Databases\Locations\locations.edb) {Copy-Item -Path $DataPath\Databases\Locations -Destination $BackupPath\StifleRBackup.$ts.bak\Databases\Locations -Recurse}
    If (Test-Path $DataPath\Databases\SRUM\SRUM.edb) {Copy-Item -Path $DataPath\Databases\SRUM -Destination $BackupPath\StifleRBackup.$ts.bak\Databases\SRUM -Recurse}

    # Start the StifleR Server service again
    $Status = (get-service -name $ServiceName).Status

    If($Status -ne "Running"){
        Write-Log -Message "Starting StifleR Server Service"
        net start $ServiceName
        Write-Log -Message "Sleeping 30 seconds" 
        Start-sleep -s 30
    }

    # Just in case service didnt get started on first try
    $Status = (get-service -name $ServiceName).Status

    If($Status -ne "Running"){
        Write-Log -Message "WARNING: Starting StifleR Server Service did not start in previous attempt, trying one more time" 
        net start $ServiceName
        Write-Log -Message "Sleeping 30 seconds" 
        Start-sleep -s 30
    }

    # Checking the service status
    If($Status -ne "Running"){
        Write-Log -Message "WARNING: StifleR Server Service could not be started, continuing to backup remaining configuration files" 
    }
}

# Take a backup of the configuration XML
Write-Log -Message "Take a backup of the configuration XML"
If (Test-Path $StifleRInstallDir\StifleR.Service.exe.config) {copy-item $StifleRInstallDir\StifleR.Service.exe.config $BackupPath\StifleRBackup.$ts.bak -Force}

# Take a backup of the License
Write-Log -Message "Take a backup of the License"
If (Test-Path $StifleRInstallDir\License.cab) {copy-item $StifleRInstallDir\License.cab $BackupPath\StifleRBackup.$ts.bak -Force}

# Take a backup of the generate location script
Write-Log -Message "Take a backup of the generate location script"
If (Test-Path $GenerateLocationScript) {copy-item $GenerateLocationScript $BackupPath\StifleRBackup.$ts.bak -Force}

# Remove backups older than seven days (always keep seven copies)
$maxDaystoKeep = -7

$itemsToDelete = dir $BackupPath -Recurse -Directory *.bak | Where LastWriteTime -lt ((get-date).AddDays($maxDaystoKeep))

if ($itemsToDelete.Count -gt 0){
    ForEach ($item in $itemsToDelete){
        Write-Log -Message "$($item.Name) is older than $((get-date).AddDays($maxDaystoKeep)) and will be deleted" 
        Remove-Item $item.FullName -Recurse -Force
        
    }
}
else{
    Write-Log -Message "No items to be deleted today $($(Get-Date).DateTime)"  
    }

Write-Log -Message "Cleanup of log files older than $((get-date).AddDays($maxDaystoKeep)) completed..."
