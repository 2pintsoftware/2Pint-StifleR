<# 
   .SYNOPSIS 
    Auto-generate a new location when a Client connects from a previously unknown NetowrkID/Gateway MAC

   .DESCRIPTION
   Returns a set of session data from the incoming client that you can then query and/or manipulate to
   create a custom Subnet/Location. For example you could set the target bandwidth depending on IP Address
   etc


   .NOTES
    AUTHOR: 2Pint Software
    EMAIL: support@2pintsoftware.com
    VERSION: 1.0.0.0
    DATE:22/02/2018 
    
    CHANGE LOG: 
    1.0.0.0 : 22/02/2018  : Initial version of script 
    1.0.0.1 : 27/02/2018  : Added check for Null Gateway MAC in sessiondata - PW
    1.0.0.2 : 30/1/2018   : No logic change from 1.0.0.1, only Beacon Tuning settings added and DO settings disabled - JA

   .LINK
    https://2pintsoftware.com

#>

#always get the parameter data from the request
param($SessionData)

#Next, instantiate the boot object, which is what you return back from this PowerShell Session
$Location = new-object StifleR.Service.LocationItem.RootLocation

#Optional Logging component - useful for debugging
$Logfile = "C:\ProgramData\2Pint Software\StifleR\Server\GenerateLocationStaples.log"

Function LogWrite
{
   Param ([string]$logstring)

   Add-content $Logfile -value $logstring
}

#Check if the GWMac or exists already and exit if true
$GWMac = $SessionData["GatewayMAC"]
$NetworkID = $SessionData["networkId"]
If ($GWMac -eq $null)
{
Logwrite "Aborting as no Gateway MAC supplied by $CompName for  $NetworkID"
Exit 0 
}

#The SessionData typically returned by a client is;

#clientProtocol;1.4
#transport;webSockets
#connectionData;[{"Name":"StiflerHub"}]
#connectionToken;AQAAANCMnd8BFdERjHoAwE/Cl+sBAAAAmrQEwkrg
#networkId;192.168.138.0
#GatewayMAC;B8-AE-ED-73-49-A6 ***USE THIS FOR A LOCATION GWMAC***
#OSBuild;Microsoft Windows NT 6.3.9600.0
#version;1.6.1.5
#ComputerName;NUC5
#MachineGUID;28ac4bb5-97a9-4af2-8c45-f3668d3528ce
#NotLeaderMaterial;False
#ServerType;false
#ServerAndClient;False
#NetworkName;2PSTEST1.LOCAL
#Status;Connected
#Category;Authenticated
#ConnectedTime;2018-02-18 10:47:22
#CreatedTime;2015-05-20 14:42:24
#Connectivity;IPv6NoTraffic, IPv4Internet
#Description;2PSTEST1.LOCAL
#DomainType;DomainAuthenticated
#IsConnectedToInternet;True
#Managed;True
#Signature;010103000F0000F0A00000000F0000F0967D2CE4D1530F00FE1094B93C821F374E91CA96D62BE8BEF8B7174D15FD45FD
#MSGatewayMAC;04-DA-D2-84-AE-42 ***DONT USE THIS FOR A LOCATION Gateway MAC***
#Type;Ethernet
#GeoPosition;11.9516:57.6967 

#Loop through the variables and write to the logfile
foreach ($key in $SessionData)
{
	$data = "$key" + ";" + $SessionData["$key"]
    LogWrite $data 
}

#This section sets the variables from the SessionData

LogWrite $Location

#Once this data is returned you can then write some new data back to the new location

$locationId = [guid]::NewGuid() # The new location must have a unique GUID so this is generated here
LogWrite "Generated new GUID "$locationId
#$Location.TargetBandwidth = 4096 #sets a default target bandwidth
$Location.MaxBandwidthDownstream = 2048 
$Location.BandwidthTuning = 24 
$Location.PercentOfMaxDownstream = 60 
$Location.GenerateV1Content = 1
$Location.DateAdded = [System.DateTime]::Now
$Location.Subnet = $SessionData["networkId"] #REQUIRED NO NOT REMOVE
$Location.GatewayMAC = $SessionData["GatewayMAC"] #REQUIRED NO NOT REMOVE
$Location.id = $locationId
$Location.LocationName = "Auto Added by PowerShell"
$Location.BeaconAddress = "dp01.corp.viamonstra.com"

#These Delivery Optimization parameters are set
#So that DO will only P2P within this subnet
#This should be changed for multiple subnet sites
#Do NOT set these DO params if you are managing DO via GPO/DHCP/SCCM etc
#$Location.DOGroupID = $locationId #sets the DO GroupID to the same GUID as the location
#$Location.DODownloadMode = 2 #Set the DO Download mode to 'Group'

#then - some final debug logging
$RealLocation = $Location.LocationName
            
LogWrite "Complete We have set new parameters for $RealLocation"

#Return the location object - job done!
return $Location
