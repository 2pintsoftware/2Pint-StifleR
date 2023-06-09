<#
    .Synopsis
       This script sets up a Hosted Cache Server with the correct ports for use with 2Pint StifleR clients


    .REQUIREMENTS
       Run from an elevated PS session
       Target server must already be configured as a BranchCache Hosted Cache server
       TODO:
        Logging?
        Full HC server setup?
        Check status on completion (evt log etc)

    .USAGE
   
   .NOTES
    AUTHOR: 2Pint Software
    EMAIL: support@2pintsoftware.com
    VERSION: 1.0.0.1
    DATE:09/06/2023 
    
    CHANGE LOG: 
    1.0.0.0 : 27/04/2023  : Initial version of script 
    1.0.0.1 : 09/06/2023  : Fixed a couple of bugs and optimized some sloppy bits!

   

   .LINK
    https://2pintsoftware.com
#>
  
#-------------------------------------
#Set HC Policy Reg Keys
#-------------------------------------
 
$RegPath = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\PeerDist\DownloadManager\Peers'
$HCRegPath = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\PeerDist\HostedCache'
 
$ShowHttpUrl = netsh http show url
$DeleteResCmd = {netsh http delete urlacl url=$urlToDelete}
# these 2variables below are used to set the HC server ports to correspond with the 2Pint StifleR client ports
$BCPort=1337 #used for content retreival
$HCPort=1339 #used by the client to offer content to the server
 
 
#---------------------------------------------------------------------------------------
# Set the correct BranchCache ConnectPort/ListenPort in the registry
#---------------------------------------------------------------------------------------
# If the key doesn't exist - create it, and set the port, job done
 
if (!(Get-Item -path $RegPath\Connection -ErrorAction SilentlyContinue)){
    New-Item -Path $RegPath -name Connection -force
    New-ItemProperty -Path $RegPath\Connection -Name ListenPort -PropertyType DWORD -Value $BCPort
    New-ItemProperty -Path $RegPath\Connection -Name ConnectPort -PropertyType DWORD -Value $BCPort
}
 
# If the key already exists, check the ListenPort value and change if required
if((Get-ItemProperty -path $RegPath\Connection -Name ListenPort -ErrorAction SilentlyContinue).ListenPort -ne $BCPort){
    Set-ItemProperty -Path $RegPath\Connection -Name ListenPort -Value $BCPort
}
 
# If the key already exists, check the ConnectPort value and change if required
if((Get-ItemProperty -path $RegPath\Connection -Name ConnectPort -ErrorAction SilentlyContinue).ConnectPort -ne $BCPort){
    Set-ItemProperty -Path $RegPath\Connection -Name ConnectPort -Value $BCPort
}
 
# END Set the correct BranchCache ConnectPort/ListenPort in the registry
 
#---------------------------------------------------------------------------------------
# Set the correct BranchCache Hosted Cache  ConnectPort/ListenPort in the registry
#---------------------------------------------------------------------------------------
# If the key doesn't exist - create it, and set the port, job done
 
if (!(Get-Item -path $HCRegPath\Connection -ErrorAction SilentlyContinue)){
    New-Item -Path $HCRegPath -name Connection -force
    New-ItemProperty -Path $HCRegPath\Connection -Name HttpListenPort -PropertyType DWORD -Value $HCPort
    New-ItemProperty -Path $HCRegPath\Connection -Name HttpConnectPort -PropertyType DWORD -Value $HCPort
}
 
# If the key already exists, check the ListenPort value and change if required
if((Get-ItemProperty -path $HCRegPath\Connection -Name HttpListenPort -ErrorAction SilentlyContinue).ListenPort -ne $HCPort){
    Set-ItemProperty -Path $HCRegPath\Connection -Name HttpListenPort -Value $HCPort
}
 
# If the key already exists, check the ConnectPort value and change if required
if((Get-ItemProperty -path $HCRegPath\Connection -Name HttpConnectPort -ErrorAction SilentlyContinue).ConnectPort -ne $HCPort){
    Set-ItemProperty -Path $HCRegPath\Connection -Name HttpConnectPort -Value $HCPort
}
# END Set the correct BranchCache HOSTED CACHE  ConnectPort/ListenPort in the registry
 
 
#Check for old URL reservations and delete if not matching the correct port number
 
# Checking for old obsolete port reservations - first, select all BranchCache url reservations
$ResList = ($ShowHttpUrl | Select-String -SimpleMatch -Pattern "/116B50EB-ECE2-41ac-8429-9F9E963361B7/")
$urlToDelete=$Null
 
ForEach($Res in $ResList){
 
$a = [regex]::Matches($Res, 'http(.*)')
If($a -like "http://+:$BCPort*") {write-host " : Not deleting the current URL: $a"} 
else {$urlToDelete=$a.Value.Trim()
invoke-command -scriptblock $DeleteResCmd
write-host " : Deleting the old URL: $a" }
 
}
 
# Checking for old obsolete port reservations - next, select all Hosted Cache BranchCache url reservations
$ResList = ($ShowHttpUrl | Select-String -SimpleMatch -Pattern "/0131501b-d67f-491b-9a40-c4bf27bcb4d4/")
$urlToDelete=$Null
 
ForEach($Res in $ResList){
 
$a = [regex]::Matches($Res, 'http(.*)')
If($a -like "http://+:$HCPort*") {write-host " : Not deleting the current URL: $a"} 
else {$urlToDelete=$a.Value.Trim()
invoke-command -scriptblock $DeleteResCmd
write-host " : Deleting the old URL: $a" }
 
}
 
# set the new port reservations
 
#Hosted Cache port url
invoke-command -scriptblock {netsh http add urlacl url=http://+:$HCPort/0131501b-d67f-491b-9a40-c4bf27bcb4d4/ user="NT AUTHORITY\NETWORK SERVICE"}
 
#BranchCache port url
invoke-command -scriptblock {netsh http add urlacl url=http://+:$BCPort/116B50EB-ECE2-41ac-8429-9F9E963361B7/ user="NT AUTHORITY\NETWORK SERVICE"}
 
#cycle the BC service
restart-service BranchCache
 
#end script

