<# 
   .SYNOPSIS 
    Takes a snapshot backup of the StifleR Server configuration and Databases

   .DESCRIPTION
   Creates a backup folder under the current StifleR data folder - using Time/Date stamp for the folder name
   Backs up the StifleR Databases using ESENTUTL.EXE
   Backs up the .config XML configuration file
   Backs up the SQL History database

   NOTE: After restoring an EDB file from online backup, it must repaired, sample syntax: ESENTUTL.EXE /p database.edb /o

   .REQUIREMENTS
   Must be run as Admin
   The StifleR Databases backup will only work on Windows Server 2016 or higher - contact us for Windows Server 2012 backups

   .USAGE
   .\StifleR_Backup.ps1


   .NOTES
    AUTHOR: 2Pint Software
    EMAIL: support@2pintsoftware.com
    VERSION: 1.0.0.6
    DATE:12/22/2023
    
    CHANGE LOG: 
    1.0.0.0 : 02/22/2018 : Initial version of script  - not much error checking - USE AT OWN RISK
    1.0.0.1 : 10/01/2019 : Modified backup location to archive on data disk
    1.0.0.2 : 11/25/2019 : Added logging and automatic logging
    1.0.0.3 : 08/18/2023 : Added backup of SQL History database
    1.0.0.4 : 11/03/2023 : Added Archiving and backup of maintenance solution
    1.0.0.5 : 12/21/2023 : Added script/instructions for creating the scheduled task with a service account
    1.0.0.6 : 12/22/2023 : Major rework, additional logging and error handling. Added support for Stifler 2.10
    1.0.0.7 : 04/03/2023 : Minor naming and logic improvements, added custom scripts backup, and additional config file backup

   .LINK
    https://2pintsoftware.com

    Sample Code to schedule this script with a service account
    $Cred = Get-Credential
    $UserName = $Cred.UserName
    $Password = $Cred.GetNetworkCredential().password
    & schtasks /create /ru $UserName /rp $Password /sc DAILY /ST 02:00  /tn "2Pint Software\Stifler Backup" /TR "PowerShell.exe -ExecutionPolicy ByPass -File E:\2Pint_Maintenance\Scripts\StifleR_Backup.ps1"

#>

# Maintenance Solution Scripts Location
$MaintenancePath = "E:\2Pint_Maintenance"

# HealthCheck Solution Scripts Location (Optional)
$HealthCheckPath = "E:\2Pint_HealthCheck"

# Log file
$LogDate = Get-Date
$ts = $LogDate.ToString("MMddyyyyHHmmss")
$LogFile = "$MaintenancePath\Logs\StifleR_Backup_$($ts).log"
If (!(Test-Path $MaintenancePath\Logs)){New-Item -ItemType Directory -Force -Path $MaintenancePath\Logs}

# Backup Locations - please edit these to reflect the correct path to the installation/data folder
$DataPath = "E:\StifleRDB"
$MainBackupPath = "E:\2Pint_Backup\StifleR_Backup"
$BackupPath = "$MainBackupPath\StifleRBackup.$ts.bak"
$serviceName = "StifleRServer"
$StiflerPath = (Split-Path -Parent (Get-CimInstance -ClassName win32_service | Where-object {$_.Name -eq $serviceName}).PathName).Substring(1)
$ConfigFile = "$StiflerPath\StifleR.Service.exe.config"
$OverrideConfigFile = "$StiflerPath\appSettings-override.xml"
[array]$CustomScripts = Get-ChildItem "C:\ProgramData\2Pint Software\StifleR" -Filter *.ps1 -Recurse # Change this if not using default locations

# How long to keep local backups (folder and zip archives)
$maxDaystoKeep = 7

# Backup Archive locations (local and remote)
$2PintBackupArchive = "E:\2Pint_Backup_Archive"
$RemoteDestination = "\\FS01\Backup\2Pint"

# SQL History Database
$BackupSQLHistory = $True # Not all customers are using SQL History
$SQLHistoryInstance = "$env:COMPUTERNAME\SQLEXPRESS"
$SQLHistoryDatabase = "StifleR" 


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

#--------------------------------
###Take a backup
#--------------------------------

$BackupDate = Get-Date -Format "MM-dd-yyyy HH:mm:ss"
Write-Log "Backup started on $BackupDate"

# Check for supported StifleR Version
Write-Log "Checking for supported StifleR Version"
$StifleRVersion = [version](Get-CimInstance -namespace root\StifleR -ClassName StifleREngine).version
If (($StifleRVersion.Major -eq 2 ) -and (($StifleRVersion.Minor -eq 6) -or ($StifleRVersion.Minor -eq 10))) {
    Write-Log "Supported version detected: $StifleRVersion"
}
Else {
    Write-Log "Unsupported version detected: $StifleRVersion. Aborting script..."
    Break
}

# First, create the backup folders
Write-Log "Creating backup folders"
If (!(Test-Path $BackupPath\Databases)){New-Item -ItemType Directory -Force -Path $BackupPath\Databases}
If (!(Test-Path $BackupPath\StifleRSQLHistoryBackup)){New-Item -ItemType Directory -Force -Path $BackupPath\StifleRSQLHistoryBackup}
If (!(Test-Path $BackupPath\2Pint_Maintenance)){New-Item -ItemType Directory -Force -Path $BackupPath\2Pint_Maintenance}
If (!(Test-Path $2PintBackupArchive)){New-Item -ItemType Directory -Force -Path $2PintBackupArchive}
If (!(Test-Path $BackupPath\HealthCheck)){New-Item -ItemType Directory -Force -Path $BackupPath\HealthCheck}

# Backup of the ESE Databases (the Location database in 2.10 is only used during migration, no need to backup)
If (($StifleRVersion.Major -eq 2 ) -and ($StifleRVersion.Minor -eq 10)) {
    # 2.10 Databases
    $Databases = @(
        "History"
        "Main"
        "Locations"
        "NewLocations"
    )
}
Else {
    # Assuming 2.6 Databases
    $Databases = @(
        "Clients"
        "History"
        "Jobs"
        "Locations"
        "SRUM"
    )
}



foreach ($Database in $Databases) {

    $SourcePath = "$DataPath\$Database\$Database.edb"
    $DestinationPath = "$BackupPath\Databases\$Database"
    $DestinationDatabaseName = "$DestinationPath\$Database.edb"
    If (Test-Path $SourcePath) {
        
        # Create folder
        If (!(Test-path $DestinationPath)){ New-Item -Path $DestinationPath -ItemType Directory -Force}
        
        Write-Log "$Database.edb found, file size is: $((Get-Item $SourcePath).length) bytes"
        Write-Log "Backing up $Database database:"

        # Request temporary files for RedirectStandardOutput and RedirectStandardError
        $RedirectStandardOutput = [System.IO.Path]::GetTempFileName()
        $RedirectStandardError = [System.IO.Path]::GetTempFileName()

        $ESENTUTL = Start-Process ESENTUTL.EXE "/y ""$($SourcePath)"" /vssrec epc . /d ""$($DestinationDatabaseName)""" -NoNewWindow -Wait -PassThru -RedirectStandardOutput $RedirectStandardOutput -RedirectStandardError $RedirectStandardError

        # Log the ESENTUTL Standard Output, skip the empty lines diskpart creates
        If ((Get-Item $RedirectStandardOutput).length -gt 0){
            Write-Log "----------- ESENTUTL: Begin Standard Output -----------"
            $CleanedRedirectStandardOutput = Get-Content $RedirectStandardOutput | Where-Object {$_.trim() -ne "" } 
            foreach ($row in $CleanedRedirectStandardOutput){
                 Write-Log $row
            }
            Write-Log "----------- ESENTUTL: End Standard Output -----------"
        }

        # Log the ESENTUTL Standard Error, skip the empty lines diskpart creates
        If ((Get-Item $RedirectStandardError).length -gt 0){
            Write-Log "----------- ESENTUTL: Begin Standard Error -----------"
            $CleanedRedirectStandardError = Get-Content $RedirectStandardError | Where-Object {$_.trim() -ne "" } 
            foreach ($row in $CleanedRedirectStandardError){
                 Write-Log $row
            }
            Write-Log "----------- ESENTUTL: End Standard Error -----------"
        }

        # ESENTUTL Error handling
        if ($ESENTUTL.ExitCode -eq 0) {
	        Write-Log "Backup of History.edb completed successfully"
        } elseif ($ESENTUTL.ExitCode -gt 0 -or $ESENTUTL.ExitCode -lt 0) {
	        Write-Log "An error occurred. Exit code is $($ESENTUTL.ExitCode). Aborting Script..."
            #Break
        } else {
	        Write-Log "An unknown error occurred. Aborting Script..."
            #Break
        }
    }
    Else {
        Write-Log "$Database.edb not found, continue to the next.."
    }
}

# Create Config folder
New-Item -Path "$BackupPath\Config" -ItemType Directory -Force

# Backup the StifleR Server configuration XML
If (Test-Path $ConfigFile) {Copy-Item $ConfigFile "$BackupPath\Config" -Force}

# Backup the StifleR Server configuration XML
If (Test-Path $OverrideConfigFile) {Copy-Item $OverrideConfigFile "$BackupPath\Config" -Force}

# Backup custom scripts 
If ($CustomScripts){
    New-Item -Path "$BackupPath\Scripts" -ItemType Directory -Force
    foreach ($Script in $CustomScripts){
        Copy-Item $Script.FullName "$BackupPath\Scripts" -Force
    }
}

# Backup of HealthCheck Scripts (if exist)
If (Test-Path $HealthCheckPath\Scripts){
    Copy-Item "$HealthCheckPath\Scripts" $BackupPath\HealthCheck -Recurse -Force
}

# Backup 2Pint Maintenance Solutions
Write-Log "Backup 2Pint HealthCheck Solutions"
Copy-Item $MaintenancePath\* $BackupPath\2Pint_Maintenance -Recurse -Force

# Backup of SQL History database
# Note: SQL Express does not support compression on database backup
If ($BackupSQLHistory -eq $True) {
    Write-Log "BackupSQLHistory set to $BackupSQLHistory. Starting SQL History Backup"
    $SQLBackupFile = "StifleR.bak"
    $SQLBackupPath = "$BackupPath\StifleRSQLHistoryBackup"
    $Result = Backup-SqlDatabase -ServerInstance $SQLHistoryInstance -Database $SQLHistoryDatabase -BackupFile $SQLBackupPath\$SQLBackupFile -PassThru
    try {
        Write-Log "Backing up database: $SQLHistoryDatabase"
        Backup-SqlDatabase -ServerInstance $SQLHistoryInstance -Database $SQLHistoryDatabase -BackupFile $SQLBackupPath\$SQLBackupFile -ErrorAction Stop
        Write-Log "SQL History Backup completed successfully."
    } catch {
        Write-Log "$("Backup of database: {0} failed. Reason: {1}" -f $SQLHistoryDatabase, $_.exception.message) Aborting script..."
        Break
    }
}
Else {
    Write-Log "BackupSQLHistory set to $BackupSQLHistory. Skipping SQL History Backup"
}

# Zip the StifleR Backups to the backup folder
Write-Log "Archive the StifleR Backups in ZIP format to the backup archive folder: $2PintBackupArchive"
$StifleRBackupName = "StifleR_Backup_$($ts).zip"
$StifleRBackupArchiveFile = Join-Path -Path $2PintBackupArchive -ChildPath $StifleRBackupName
If(Test-path $StifleRBackupArchiveFile) {Remove-item $StifleRBackupArchiveFile}
Add-Type -assembly "system.io.compression.filesystem"
[io.compression.zipfile]::CreateFromDirectory($BackupPath, $StifleRBackupArchiveFile)
Write-Log "Archive completed. $StifleRBackupArchiveFile size is: $((Get-Item $StifleRBackupArchiveFile).length) bytes"

# Copy the Stifler Backup Archive to remote file server 
Write-Log "Copy the Stifler Backup Archive to remote file server: $RemoteDestination"
If (Test-Path $RemoteDestination -PathType Container){
    Write-Log "$RemoteDestination is a valid folder"
    Write-Log "Copying $StifleRBackupArchiveFile to $RemoteDestination"
    
    Try {
        Copy-Item -Path $StifleRBackupArchiveFile -Destination $RemoteDestination -Force -ErrorAction Stop
    }
    Catch {
        Write-Log "An Error Occured on copying file: $($_.Exception.Message) Aborting Script..."
        break
    }
}
Else {
    Write-Log "$RemoteDestination is not valid. Aborting script..."
    Break
}

# Remove local backup folders older than maxDaystoKeep
Write-Log "Removing local backup folders older than $maxDaystoKeep days"
$itemsToDelete = Get-ChildItem $MainBackupPath -Directory *.bak | Where-Object LastWriteTime -lt ((get-date).AddDays(-$maxDaystoKeep))

if ($itemsToDelete.Count -gt 0){
    ForEach ($item in $itemsToDelete){
        Write-Log "$($item.Name) is older than $((get-date).AddDays($maxDaystoKeep)) and will be deleted" 
        Remove-Item $item.FullName -Recurse -Force
        
    }
}
else{
    Write-Log "No items to be deleted today $($(Get-Date).DateTime)" 
    }

Write-Log "Cleanup of backup folders older than $((get-date).AddDays($maxDaystoKeep)) completed..."


# Remove local backup archives older than 7 days
Write-Log "Removing local backup archives older than $maxDaystoKeep days"
$itemsToDelete = Get-ChildItem $2PintBackupArchive -Filter "*.zip" | Where-Object LastWriteTime -lt ((get-date).AddDays(-$maxDaystoKeep))

if ($itemsToDelete.Count -gt 0){
    ForEach ($item in $itemsToDelete){
        Write-Log "$($item.Name) is older than $((get-date).AddDays($maxDaystoKeep)) and will be deleted" 
        Remove-Item $item.FullName -Recurse -Force
        
    }
}
else{
    Write-Log "No items to be deleted today $($(Get-Date).DateTime)"
}
Write-Log "Cleanup of backup folders older than $((get-date).AddDays($maxDaystoKeep)) completed..."
$BackupDate = Get-Date -Format "MM-dd-yyyy HH:mm:ss"
Write-Log "Backup completed on $BackupDate"

Write-Host "Backup completed!" -ForegroundColor Green
Write-Host "Review the backup log file: $LogFile" 