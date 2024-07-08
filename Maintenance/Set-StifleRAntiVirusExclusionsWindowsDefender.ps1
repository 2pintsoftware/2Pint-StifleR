# Sample StifleR Server exclusion rules for Windows Defender

# Change the below to match your environment
$ProcessName = "StifleR.Service"
$StiflerDBPath = "E:\StifleRDB"
$SQLHistoryDBPath = "E:\SQLDB"

# Exclude StifleR Process
$ProcessPath = (Get-Process -Name $ProcessName ).Path
Add-MpPreference -ExclusionProcess $ProcessPath

# Exclude installation folders
$InstallationFolder = Split-Path $ProcessPath -Parent
Add-MpPreference -ExclusionPath $InstallationFolder

# Exclude database folders
Add-MpPreference -ExclusionPath $SQLHistoryDBPath 
Add-MpPreference -ExclusionPath $StiflerDBPath

# Show exclusions
(Get-MpPreference).ExclusionPath
(Get-MpPreference).ExclusionProcess


