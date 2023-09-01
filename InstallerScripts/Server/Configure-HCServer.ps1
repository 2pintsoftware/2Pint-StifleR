<#
    .Synopsis
       This script sets up a Hosted Cache Server with the correct ports for use with 2Pint StifleR clients


    .REQUIREMENTS
       Run from an elevated PS session
       Target server must already be configured as a BranchCache Hosted Cache server
       TODO:
        Logging?
        Check status on completion (evt log etc)

    .USAGE
   
   .NOTES
    AUTHOR: 2Pint Software
    EMAIL: support@2pintsoftware.com
    VERSION: 1.0.0.4
    DATE:01/09/2023 
    
    CHANGE LOG: 
    1.0.0.0 : 27/04/2023  : Initial version of script 
    1.0.0.1 : 09/06/2023  : Fixed a couple of bugs and optimized some sloppy bits!
    1.0.0.2 : 16/06/2023  : Added bits to setup BC and enable Hosted Server mode if not enabled
    1.0.0.3 : 24/07/2023  : Fix for WinPE clients
    1.0.0.4 : 24/07/2023  : Added support to set TTL for BC Content
   

   .LINK
    https://2pintsoftware.com
#>
#requires -runasadministrator

#-------------------------------------
#Set HC Policy Reg Keys
#-------------------------------------
 
$RegPath = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\PeerDist\DownloadManager\Peers'
$HCRegPath = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\PeerDist\HostedCache'
$TTLRegPath = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\PeerDist'

$ShowHttpUrl = netsh http show url
$DeleteResCmd = { netsh http delete urlacl url=$urlToDelete }
# these 2variables below are used to set the HC server ports to correspond with the 2Pint StifleR client ports
$BCPort = 1337 #used for content retreival
$HCPort = 1339 #used by the client to offer content to the server
$HCAuth = 'None' #If the Hosted Cache server will be used from WinPE this must be set to 'None' otherwise it should be set to 'Domain'. If not set it will default to "Domain"
$TTL = 365 # Number of Days content should stay in the BC Cache before being purged for being old.

#-------------------------------------
# Make sure PreReqs are set up
#-------------------------------------

if ((Get-WindowsFeature -Name BranchCache).Installed -eq $false) {
    Write-Host "Installing BranchCache feature"
    Install-WindowsFeature BranchCache -IncludeManagementTools -Verbose
    # Start BC in distributed mode to complete setup.
    invoke-command -scriptblock { netsh branchcache set service mode=DISTRIBUTED }
    $reboot = $true
}


if ((Get-BCHostedCacheServerConfiguration).HostedCacheServerIsEnabled -eq $false) {
    Write-Host "Enabling BC Hosted Cache Server"
    Enable-BCHostedServer -Verbose
    if ("None", "Domain" -contains $HCAuth) {
        Write-Host "Setting BC Hosted Cache Server Authentication to '$HCAuth'" 
        Set-BCAuthentication -Mode $HCAuth
    }

    $reboot = $true
}

$BCStatus = Get-BCStatus

if (-not $BCStatus.BranchCacheIsEnabled -eq $true) { Write-Error "BranchCache is not enabled!"; break }
if (-not $BCStatus.BranchCacheServiceStatus -eq "Running") { Write-Error "BranchCache is not running!"; break }
if (-not $BCStatus.HostedCacheServerConfiguration.HostedCacheServerIsEnabled -eq $true) { Write-Error "HostedCacheServerIsEnabled is not enabled!"; break }

$BCStatus = $null


#---------------------------------------------------------------------------------------
# Set the number of days to keep content in the cache in the registry
#---------------------------------------------------------------------------------------
# If the key doesn't exist - create it, and set the value, job done

if ((Get-ItemProperty -path '$TTLRegPath\Retrieval' -Name SegmentTTL -ErrorAction SilentlyContinue).SegmentTTL -eq $TTL) {
    Write-Host "BC Cache TTL setup correctly" 
}
else {
    Write-Host "BC Cache TTL not setup correctly"

    if (!(Get-Item -path $TTLRegPath\Retrieval -ErrorAction SilentlyContinue)) {
        New-Item -Path $TTLRegPath -name Retrieval -force  
        New-ItemProperty -Path $TTLRegPath\Retrieval -Name SegmentTTL -PropertyType DWORD -Value $TTL  
    }
    # If the key already exists, check the value and change if required
    if (((Get-ItemProperty -path $TTLRegPath\Retrieval -Name SegmentTTL -ErrorAction SilentlyContinue).SegmentTTL) -ne $TTL) {
        Set-ItemProperty -Path $TTLRegPath\Retrieval -Name SegmentTTL -Value $TTL  
    }
    Write-Host "BranchCache TTL Remediation Complete"
}

# END Set the number of days to keep content in the cache in the registry

#---------------------------------------------------------------------------------------
# Set the correct BranchCache ConnectPort/ListenPort in the registry
#---------------------------------------------------------------------------------------
# If the key doesn't exist - create it, and set the port, job done
 
if (!(Get-Item -path $RegPath\Connection -ErrorAction SilentlyContinue)) {
    New-Item -Path $RegPath -name Connection -force
    New-ItemProperty -Path $RegPath\Connection -Name ListenPort -PropertyType DWORD -Value $BCPort
    New-ItemProperty -Path $RegPath\Connection -Name ConnectPort -PropertyType DWORD -Value $BCPort
}
 
# If the key already exists, check the ListenPort value and change if required
if ((Get-ItemProperty -path $RegPath\Connection -Name ListenPort -ErrorAction SilentlyContinue).ListenPort -ne $BCPort) {
    Set-ItemProperty -Path $RegPath\Connection -Name ListenPort -Value $BCPort
}
 
# If the key already exists, check the ConnectPort value and change if required
if ((Get-ItemProperty -path $RegPath\Connection -Name ConnectPort -ErrorAction SilentlyContinue).ConnectPort -ne $BCPort) {
    Set-ItemProperty -Path $RegPath\Connection -Name ConnectPort -Value $BCPort
}
# END Set the correct BranchCache ConnectPort/ListenPort in the registry
 
#---------------------------------------------------------------------------------------
# Set the correct BranchCache Hosted Cache  ConnectPort/ListenPort in the registry
#---------------------------------------------------------------------------------------
# If the key doesn't exist - create it, and set the port, job done
 
if (!(Get-Item -path $HCRegPath\Connection -ErrorAction SilentlyContinue)) {
    New-Item -Path $HCRegPath -name Connection -force
    New-ItemProperty -Path $HCRegPath\Connection -Name HttpListenPort -PropertyType DWORD -Value $HCPort
    New-ItemProperty -Path $HCRegPath\Connection -Name HttpConnectPort -PropertyType DWORD -Value $HCPort
}
 
# If the key already exists, check the ListenPort value and change if required
if ((Get-ItemProperty -path $HCRegPath\Connection -Name HttpListenPort -ErrorAction SilentlyContinue).ListenPort -ne $HCPort) {
    Set-ItemProperty -Path $HCRegPath\Connection -Name HttpListenPort -Value $HCPort
}
 
# If the key already exists, check the ConnectPort value and change if required
if ((Get-ItemProperty -path $HCRegPath\Connection -Name HttpConnectPort -ErrorAction SilentlyContinue).ConnectPort -ne $HCPort) {
    Set-ItemProperty -Path $HCRegPath\Connection -Name HttpConnectPort -Value $HCPort
}
# END Set the correct BranchCache HOSTED CACHE  ConnectPort/ListenPort in the registry
 
#---------------------------------------------------------------------------------------
#Check for old URL reservations and delete if not matching the correct port number
#---------------------------------------------------------------------------------------
 
# Checking for old obsolete port reservations - first, select all BranchCache url reservations
$ResList = ($ShowHttpUrl | Select-String -SimpleMatch -Pattern "/116B50EB-ECE2-41ac-8429-9F9E963361B7/")
$urlToDelete = $Null
 
ForEach ($Res in $ResList) {
 
    $a = [regex]::Matches($Res, 'http(.*)')
    If ($a -like "http://+:$BCPort*") { write-host " : Not deleting the current URL: $a" } 
    else {
        $urlToDelete = $a.Value.Trim()
        invoke-command -scriptblock $DeleteResCmd
        write-host " : Deleting the old URL: $a" 
    }
 
}
 
# Checking for old obsolete port reservations - next, select all Hosted Cache BranchCache url reservations
$ResList = ($ShowHttpUrl | Select-String -SimpleMatch -Pattern "/0131501b-d67f-491b-9a40-c4bf27bcb4d4/")
$urlToDelete = $Null
 
ForEach ($Res in $ResList) {
 
    $a = [regex]::Matches($Res, 'http(.*)')
    If ($a -like "http://+:$HCPort*") { write-host " : Not deleting the current URL: $a" } 
    else {
        $urlToDelete = $a.Value.Trim()
        invoke-command -scriptblock $DeleteResCmd
        write-host " : Deleting the old URL: $a" 
    }
 
}
 
# set the new port reservations
 
#Hosted Cache port url
invoke-command -scriptblock { netsh http add urlacl url=http://+:$HCPort/0131501b-d67f-491b-9a40-c4bf27bcb4d4/ user="NT AUTHORITY\NETWORK SERVICE" }
 
#BranchCache port url
invoke-command -scriptblock { netsh http add urlacl url=http://+:$BCPort/116B50EB-ECE2-41ac-8429-9F9E963361B7/ user="NT AUTHORITY\NETWORK SERVICE" }
 
#cycle the BC service
restart-service BranchCache

if ($reboot) { Write-host "Please reboot the server" -ForegroundColor Yellow }
#end script

