#WMI Method parameters can change at any given time, as they are sorted automagically alphabetically, the order can change.
#Before freaking out, here is you figure our the order, Get a StifleR class using Get-CimClass
$class = Get-CimClass -Namespace root\StifleR -ClassName Subnets

#Then run
$class.CimClassMethods

#returns
#PS C:\Windows\system32> $class.CimClassMethods
#Name                                                                                             ReturnType Parameters                                            Qualifiers                                          
#----                                                                                             ---------- ----------                                            ----------                                          
#AddSubnet                                                                                            SInt32 {description, GatewayMAC, locationName, ParentLoca... {implemented, static}                               
#RemoveSubnet                                                                                         SInt32 {deletechildren}                                      {implemented}                                       
#LinkWithSubnet                                                                                       SInt32 {parentGUID}                                          {implemented}                                       

#Dig into a special WMI method using its name
$class.CimClassMethods["AddSubnet"].Parameters

#Then returns the following order:
#PS C:\Windows\system32> $class.CimClassMethods["AddSubnet"].Parameters
#Name                                                                                                CimType Qualifiers                                            ReferenceClassName                                  
#----                                                                                                ------- ----------                                            ------------------                                  
#description                                                                                          String {Description, ID, in}                                                                                     
#GatewayMAC                                                                                           String {Description, ID, in}                                                                                     
#locationName                                                                                         String {Description, ID, in}                                                                                     
#ParentLocationId                                                                                     String {Description, ID, in}                                                                                     
#subnet                                                                                               String {Description, ID, in}                                                                                     
#TargetBandwidth                                                                                      UInt32 {Description, ID, in}                                                                                     

#So to create a location, run the following:
#Invoke-WmiMethod -Namespace root\StifleR -Path Subnets -Name AddSubnet -ArgumentList "Description","00-11-22-33-44-55", "Name", "", "192.168.13.0", 2048

$hardsites = @{"Washington" = "10.0.1.0"; "Oregon" = "10.0.2.0"; California = "10.0.3.0"}

write-host $hardsites.Count;

$autosites = @{}

for($i=1; $i -le 254;$i++)
{
   for($j=1; $j -le 254; $j++)
   {
       $autosites.Add("Autosite 192.$i.$j.0", "192.$i.$j.0")
   }
}

#Count
write-host $autosites.Count;

#Display the name
foreach ($loc in $hardsites.Keys) {
    Write-Host "${loc}: $($hardsites.Item($loc))"
}

#Display the name of 65k sites
foreach ($loc in $autosites.Keys) {
    Write-Host "${loc}: $($autosites.Item($loc))"
}

#Create Locations from sample CSV
$csv = Import-Csv .\samples.csv -Delimiter ','
foreach ($line in $csv) {
   Write-Host Adding StifleR location $line.CapitalName in $line.CountryName

   #CountryName,CapitalName,State,Latitude,Longitude,CountryCode,ContinentName,Subnet,GatewayMAC 
   #workaround to avoid getting param list to WMI
   [string]$name = $line.CapitalName

   $subnet = $line.Subnet
   $subnet = $subnet + ".0"

   $locreturn = Invoke-WmiMethod -Namespace root\StifleR -Path Subnets -Name AddSubnet -ArgumentList "My Demo Description",$line.GatewayMAC, $name, "", $subnet, 2048
   Write-Host $locreturn

   $x = New-CimInstance -Namespace root\StifleR -ClassName Subnets -Property @{ "subnetId"="$subnet" } -Key subnetId -ClientOnly
   $location_tmp = Get-CimInstance -CimInstance $x

   $location_tmp
    
   #Set a new value - Note: WMI is not updated until you pipe it to Set-CimInstance
   $address = $line.CapitalName
   $address = "Some street in $address"

   $location_tmp.Address =  $address
   $location_tmp.Town = $line.CapitalName
   $location_tmp.Country = $line.CountryName
   $location_tmp.Latitude = $line.Latitude
   $location_tmp.Longitude = $line.Longitude 

   #Write the value changed back again
   $location_tmp | Set-CimInstance 

}


#Create 65k locations
foreach ($loc in $autosites.Keys) {
	Invoke-WmiMethod -Namespace root\StifleR -Path Subnets -Name AddSubnet -ArgumentList "Description of $loc", "N/A", "StifleR location $loc", "", $($autosites.Item($loc)), 2048
    #Of course you could set stuff on the newly created object, but for this demonstration we do the upating later
}

#Create the StifleR locations
foreach ($loc in $hardsites.Keys) 
{
    Write-Host "Creating the location for ${loc}, with Subnet $($hardsites.Item($loc))"
	Invoke-WmiMethod -Namespace root\StifleR -Path Subnets -Name AddSubnet -ArgumentList "Description of $loc", "N/A", "StifleR location $loc", "", $($hardsites.Item($loc)), 2048
}

$alllocs = gwmi -namespace root\StifleR -Query "Select * from Subnets" 

$allparents = gwmi -namespace root\StifleR -Query "Select * from ParentLocations" 

Write-Host "We have $alllocs.Count subnets and $allparents.Count parent locations"

if ($alllocs -ne $allparents)
{
    Write-Host "We have a mismatch on the subnet side. Wonder why, server to busy?"
}

#Link up the 65k locations into 250 parent locations, could probably be done nicer
foreach ($loc in $autosites.Keys) 
{
    
    $currentSubnet = $($autosites.Item($loc))
    $currentSubnetids = $currentSubnet.split(".")
    $parentSubnet = "192." + $currentSubnetids[1] + ".1.0"
    
    $child = gwmi -namespace root\StifleR -Query "Select * from Subnets WHERE subnetID =`"$currentSubnet`""
    
    #You can also do direct access with PowerShell like if you want to work directly with a particular service through WMI, 
    # specify its path and do a type conversion. Use either the [wmi] type accelerator or the underlying [System.Management.ManagementObject] .NET type:
    
    #Every WMI instance has its own unique path. This path is important if you want to access a particular instance directly. 
    #The path of a WMI object is located in the __PATH property. First use a "traditional" query to list this property and find out what it looks like:
    $parent = gwmi -namespace root\StifleR -Query "Select * from Subnets WHERE subnetID =`"$parentSubnet`""

    #Below is sick WMI/Powershell awesomeness
    #$myPath = $parent.__PATH
    #$parent = [wmi]$myPath

    #So the faster method is then of course to do it like this:
    #$child = [wmi]"\root\StifleR:Subnets.subnetID='192.168.138.0'"

    #Execute the method on the child
    $child.LinkWithSubnet($parent.id)
    
}

#Check that we have moved them all into parent/child, start by getting all the parents and count them.
$allparents = gwmi -namespace root\StifleR -Query "Select * from ParentLocations" 

$allparents.count

if($allparents.Count -ne 254)
{
    Write-Host "Something is not right... server to busy?"
}

#Give us a table
$alllocs | ft LocationName, SubnetId, TargetBandwidth
#Reorder by date added
$alllocs | Sort-Object -Property DateAdded | ft LocationName, SubnetId, TargetBandwidth

foreach ($loc in $alllocs)
{
    Write-Host $loc
    
    Write-Host $loc.DateAdded
    
    #Reset the name to somethin better
    #NOTE: Make sure you set variables otherwise WMI seems to funk with the names

    $newnamepart = $loc.subnetID
    $newname = "Location with ip $newnamepart" 
    
    swmi -path $loc.path -Arguments @{LocationName="Better Name $newname"}
}


#Simple way of linking two subnets:
$childSubnet = [wmi]"\root\StifleR:Subnets.subnetID='192.168.138.0'"
$parentSubnet = [wmi]"\root\StifleR:Subnets.subnetID='192.168.137.0'"
#Execute the method on the child
$childSubnet.LinkWithSubnet($parentSubnet.id)


#Find locations with odd TargetBandwith
$badlocs = gwmi -namespace root\StifleR -Query "Select * from Subnets WHERE TargetBandwidth = 99999 OR TargetBandwidth = 0" 

#Whatch out here is we only got one from above $badlocs is not an array but the actual item, so the below items would fail and $badlocsrd woulde be null
$badlocsnr = $badlocs.Count

#Work around this by:

IF ($badlocs -isnot [array])
{ <error message> }
ELSE
{ <proceed> }

#Or add [array] before, forcing PowerShell to return one array

[array]$badlocs = gwmi -namespace root\StifleR -Query "Select * from Subnets WHERE TargetBandwidth = 99999 OR TargetBandwidth = 0" 
$badlocsnr = $badlocs.Count

#Now below will work
Write-host "We have $badlocsnr number of bad locations"

foreach ($loc in $badlocs)
{
    $badBandwidth = $loc.TargetBandwidth
    Write-host "Updating $loc.LocationName with new bandwith from $badBandwidth to 2028"
    swmi -path $loc.path -Arguments @{TargetBandwidth=2048}
}


#Manually create one location
Invoke-WmiMethod -Namespace root\StifleR -Path Subnets -Name AddSubnet -ArgumentList "StifleR description of test1", "N/A", "Location Name", "", "192.164.0.0", 2048
$location_test1 = Get-CimInstance -Namespace root\StifleR -ClassName Subnets -Filter "LocationName like 'Stifle%'" -Property Address

#Set a new value - Note: WMI is not updated until you pipe it to Set-CimInstance
$location_test1.Address = "My Address"

#Write the value changed back again
$location_test1 | Set-CimInstance 

#create lots of locations from .csv sample
$csv = Import-Csv .\Locations.csv
foreach ($line in $csv) {
    
    $name = $line.Country + ", " + $line.Capital
    $address = "Street in " + $line.Capital

    Invoke-WmiMethod -Namespace root\StifleR -Path Subnets -Name AddSubnet -ArgumentList "Description...", "N/A", $name, "", $line.NetworkId, $line.Targetbandwidth
    
    $subnet = $line.NetworkId;

    $x = New-CimInstance -Namespace root\StifleR -ClassName Subnets -Property @{ "subnetId"="$subnet" } -Key subnetId -ClientOnly
    $location_tmp = Get-CimInstance -CimInstance $x

    $location_tmp
    
    #Set a new value - Note: WMI is not updated until you pipe it to Set-CimInstance
    $location_tmp.Address =  $address
    $location_tmp.Town = $line.Capital
    $location_tmp.Country = $line.Country
    $location_tmp.Latitude = $line.Latitude
    $location_tmp.Longitude = $line.Longitude 

    #Write the value changed back again
    $location_tmp | Set-CimInstance 
    
}    



#Get lots of locations and change names of them all
$locs = gwmi -namespace root\StifleR -Query "Select * from Subnets" ; foreach ($loc in $locs) { $bepa = $loc.subnetID ; $bepa = "Location with ip $bepa" ; swmi -path $loc.path -Arguments @{LocationName=$bepa}}


Invoke-WmiMethod -Namespace root\StifleR -Path Jobs -Name AddJob -ArgumentList 1,"Install.exe /s","Override.exe","Description of Install My Software","Install My Software Again",("http://myserver/myfile.fil c:\myown\executionpath","http://myserver/myfile2.fil c:\myown\executionpath2"), "Passw0rd","True",3,"domain\user"

$job = [wmi]"\root\StifleR:Jobs.DisplayName='Install My Software Again'"
$job.DeployJob("ALL")

#Create a BITS Job
Invoke-WmiMethod -Namespace root\StifleR -Path Jobs -Name AddJob -ArgumentList "Start Notepad","Download and run Notepad",("http://192.168.10.30/data/1.wim c:\temp\1.wim")

#THis works great to get values, but cant pipe $job to Set-CimInstance
$job = [wmi]"\root\StifleR:Jobs.DisplayName='Download and run Notepad'"

#So instead we get it like this
$job = Get-CimInstance -Namespace root\StifleR -ClassName Jobs -Filter "DisplayName like 'Download and run Notepad%'"

$job.Program = "C:\windows\system32\notepad.exe"
$job.BITSPriority = "Normal"

$job.ProgramOverride = "%windir%\system32\cmd.exe"
$job.ProgramOverride = ""

$job.Parameters = "c:\Temp\2pxebeta.csv"

$job.Password = "my Secure Password3"
$job.Username = "2pstest1\administrator"
$job.AuthScheme = "NTLM"

$job.ProxyPassword = "my Secure Password3"
$job.ProxyUsername = "2pstest1\administrator"
$job.ProxyAuthScheme = "NTLM"

#Putting invoke turns it into a list, great trick
$morefiles = {$job.Files}.Invoke()

#with simple add
$morefiles.Add("http://192.168.10.30/data/2.wim c:\temp\2.wim")

#Turn anything into an array with set-variable
$morefiles | set-variable newfilesarray

#This is the array
$newfilesarray
#Now set the files array to the original

$job.Files = $morefiles 

#Pipe it to set to update the item
$job | Set-CimInstance

#But then this wont work, as its not a real instance, but a referenced one, so would have to pipe it to invoke 
#$job.DeployJob("192.168.138.0")

#But this works
$job = [wmi]"\root\StifleR:Jobs.DisplayName='Download and run Notepad'"
$job.DeployJob("192.168.138.0")


#Deploy a cmdline to enable BranchCache in distributed mode in Subnet 192.168.137.0
Invoke-WmiMethod -Namespace root\StifleR -Path StifleREngine.Id='1' -Name RunCmdLine -ArgumentList "branchcache set service mode=distributed", "%windir%\system32\netsh.exe", "192.168.137.0"

#Flush the cache on clients in subnet 192.168.137.0
Invoke-WmiMethod -Namespace root\StifleR -Path StifleREngine.Id='1' -Name RunCmdLine -ArgumentList "branchcache flush", "%windir%\system32\netsh.exe", "192.168.137.0"

#Create a job with some sample data to send to 192.168.137.0
Invoke-WmiMethod -Namespace root\StifleR -Path StifleREngine.Id='1' -Name RunCmdLine -ArgumentList "/c md C:\DownloadData", "%windir%\system32\cmd.exe", "192.168.137.0"
Invoke-WmiMethod -Namespace root\StifleR -Path Jobs -Name AddJob -ArgumentList "Download 300MB","Download a large file",("http://192.168.10.30/data/1.wim C:\DownloadData\1.wim")
$job = [wmi]"\root\StifleR:Jobs.DisplayName='Download a large file'"
$job.DeployJob("192.168.137.0")

Invoke-WmiMethod -Namespace root\StifleR -Path StifleREngine.Id='1' -Name RunCmdLine -ArgumentList "/complete ""Download a large file""", "%windir%\system32\bitsadmin.exe", "ALL"
Invoke-WmiMethod -Namespace root\StifleR -Path StifleREngine.Id='1' -Name RunCmdLine -ArgumentList "branchcache flush", "%windir%\system32\netsh.exe", "192.168.138.0"


#Get an entry from DB backed class Clients
$client = gwmi -namespace root\StifleR -Query "Select * from Clients where Computername = 'DESKTOP-B2SDT6D'" 

#This is the link from Client -> Connection classes
[string]$connId = $client.ConnectionID
$connections = gwmi -namespace root\StifleR -Query "Select * from Connections where ConnectionID=""$connId"""

#Alternative Invoke cmd if you know the connection Id
#Invoke-WmiMethod -Path 'root\StifleR:Connections.ConnectionID="76e674b7-5ed1-4360-ae0e-c7d2cb708711"' -Name Disconnect

#Execute the method on an instance of Connections
[string]$json = $connections.GetDOConfig().Returnvalue

#Get back as an object
$object = ConvertFrom-Json -InputObject $json
Write-Host $object.currentStatus.cbCacheSize

#Get the method parameters of a class
$classQuery = [wmiclass]"root\StifleR:StifleRengine"
$classQuery.GetMethodParameters("GetErrorDescription")

#Get the parameters needed for a method that requires some parameters
(gwmi -namespace root\StifleR -Class StifleRengine -Filter "Id='1'").GetMethodParameters("Notify")

#Get the parameters to a method that does NOT have any parameters
(gwmi -namespace root\StifleR -Class Connections -Filter "ConnectionID='76e674b7-5ed1-4360-ae0e-c7d2cb708711'").GetMethodParameters("Disconnect")

#Get any error as text
Invoke-WmiMethod -Path root\StifleR:StifleRengine -Name GetErrorDescription -ArgumentList 5

#Loop through all clients in a csv with the header of 'ComputerName' and stop all jobs on them
$textfile = Import-Csv .\Machines.txt
foreach ($line in $textfile) {
	
	$machine = $line.ComputerName;
	$connections = gwmi -namespace root\StifleR -Query "Select ConnectionID from Connections where ComputerName=""$machine""";
	$connId = $connections.ConnectionID;

	Invoke-WmiMethod -Namespace root\StifleR -Path StifleREngine.Id=1 -Name ModifyJobs -ArgumentList "Suspend", $true, "*", "", $connId
}


#Find machines that have not reported in
#Start by getting the
$connections = gwmi -namespace root\StifleR -Query "Select * from Connections" 
foreach($client in $connections)
{
	if(($client.ClientFlags -band 4194304) -ne 0) 
	{
		write-host $client.ComputerName + " does have not reported in correctly " + $client.NetworkId
	}
}


#Get sites usage and verify leaders
$leaders = Get-CimInstance -namespace root\StifleR -Query "Select * from RedLeaders"
 foreach ( $rl in $leaders ) {
	$rlNetworkID = $rl.networkid
	$RLBandwidth = $rl.bandwidthallowed
	$RLBandwidthUsed = $rl.MinuteBandwidthUsed

    $sub = Get-CimInstance -namespace root\StifleR -Query "Select * from Subnets where subnetID = '$rlNetworkID'"
	$SubnetBandwidth = $sub.targetbandwidth

	If ($rl.bandwidthallowed -ne $sub.targetbandwidth)
	{
		write-host "NetworkID:$rlNetworkID RL Bandwidth = $RLBandwidth BWUsed = $RLBandwidthUsed Subnet Bandwidth = $SubnetBandwidth"
	}  
 }