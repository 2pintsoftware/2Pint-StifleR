# Sample 2PXE exclusion rules for Windows Defender

# Change the below to match your environment
$ProcessName = "2Pint.2pxe.Service"

# Exclude StifleR Process
$ProcessPath = (Get-Process -Name $ProcessName ).Path
Add-MpPreference -ExclusionProcess $ProcessPath

# Exclude installation folder
$InstallationFolder = Split-Path $ProcessPath -Parent
Add-MpPreference -ExclusionPath $InstallationFolder

# Exclude 2PXE program data folder
Add-MpPreference -ExclusionPath "C:\ProgramData\2Pint Software\2PXE"

# Show exclusions
(Get-MpPreference).ExclusionPath
(Get-MpPreference).ExclusionProcess

