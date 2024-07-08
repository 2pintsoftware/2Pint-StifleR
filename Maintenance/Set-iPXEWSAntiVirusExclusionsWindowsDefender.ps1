# Sample iPXE Anywhere exclusion rules for Windows Defender

# Change the below to match your environment
$ProcessName = "iPXEAnywhere.Service"
$SQLDBPath = "E:\SQLDB"

# Exclude StifleR Process
$ProcessPath = (Get-Process -Name $ProcessName ).Path
Add-MpPreference -ExclusionProcess $ProcessPath

# Exclude installation folder
$InstallationFolder = Split-Path $ProcessPath -Parent
Add-MpPreference -ExclusionPath $InstallationFolder

# Exclude 2PXE program data folder
Add-MpPreference -ExclusionPath "C:\ProgramData\2Pint Software\iPXEWS"

# Exclude database folder
Add-MpPreference -ExclusionPath $SQLDBPath 

# Show exclusions
(Get-MpPreference).ExclusionPath
(Get-MpPreference).ExclusionProcess

