# Add Subnet
$Description="Added via PowerShell"
$GatewayMAC = "00-11-22-33-44-55"
$LocationName = "Chicago"
$ParentLocationID = ""
$SubnetID = "192.168.189.0"
$TargetBandwidth = "10240"
Invoke-WMIMethod -Namespace root\StifleR -Path Subnets -Name AddSubnet -ArgumentList "$description", "$GatewayMAC", "$LocationName", "$ParentLocationID","$SubnetID", $TargetBandwidth

# Remove Subnet
$Description="Added via PowerShell"
$GatewayMAC = "00-11-22-33-44-55"
$LocationName = "Chicago"
$ParentLocationID = ""
$SubnetID = "192.168.189.0"
$TargetBandwidth = "10240"
Invoke-WMIMethod -Namespace root\StifleR -Path Subnets -Name AddSubnet -ArgumentList "$description", "$GatewayMAC", "$LocationName", "$ParentLocationID","$SubnetID", $TargetBandwidth

# Update MAC Address
$Subnets = Get-WmiObject -Namespace root\stifler -query "Select * from Subnets where subnetid = '192.168.1.0'"

Foreach ($Subnet in $Subnets){
    $SubnetID = $Subnet.SubnetID
    $StifleRSubnet = Get-WmiObject -Namespace root/stifler -query "Select * from Subnets Where SubnetID = '$SubnetID'"
    
    Set-WmiInstance -Path $StifleRSubnet.path -Arguments @{GatewayMAC='00-15-5D-4C-00-41'}
}
