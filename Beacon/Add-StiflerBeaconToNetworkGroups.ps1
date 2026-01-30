# StifleR 3.0 Verified
# Script to add a Beacon Server to one or more network groups
# Note, this is not a script that is meant to be run in full, but rather as a set of code snippets to be used as needed 

# List all Beacon Servers - Run first to get the Id of the Beacon you want to add, then update line 10 below
$BeaconServers = Get-CimInstance -Namespace root\stifler -ClassName InfrastructureServices -Filter "Type = 'Beacon'"
$BeaconServers | Select Hostname, Id

# Set Beacon Server to add
$BeaconServerId = "81072007-c468-4e13-8dcd-e967284fc786"


#region Add Beacon to a specific Network Group
# Get a specific network group
$NetworkGroupName = "Seattle"  #<-- Change to your desired Network Group name, look this up in the dashboard
$NetworkGroup = Get-CimInstance -Namespace root\stifler -ClassName NetworkGroups -Filter "Name = '$NetworkGroupName'" | Select -First 1
$NetworkGroup.id

# Add Beacon to a specific Network Group
$params = @{ InfrastructureServiceId = $BeaconServerId}
$Return = Invoke-CimMethod -InputObject $NetworkGroup -Name AddInfrastructureService -Arguments $params
#endregion


#Region Add Beacon to all Network Groups
$NetworkGroups = Get-CimInstance -Namespace root\stifler -ClassName NetworkGroups
$NetworkGroupsCount = ($NetworkGroups | Measure-Object).Count
Write-Host "Working on $NetworkGroupsCount network groups"

foreach ($NetworkGroup in $NetworkGroups) {

    $Name = $NetworkGroup.Name
    $Id = $NetworkGroup.id
    
    Write-Host "Working on NG: $Name with Id: $Id"

    $params = @{ InfrastructureServiceId = $BeaconServerId}
    $Return = Invoke-CimMethod -InputObject $NetworkGroup -Name AddInfrastructureService -Arguments $params

    Write-Host "Return values was: $($Return.ReturnValue)"

}

#endregion

#region Get Beacon Server from all Network Groups
$NetworkGroups = Get-CimInstance -Namespace root\stifler -ClassName NetworkGroups
$NetworkGroupsCount = ($NetworkGroups | Measure-Object).Count
Write-Host "Working on $NetworkGroupsCount network groups"

foreach ($NetworkGroup in $NetworkGroups) {

    $Name = $NetworkGroup.Name
    $Id = $NetworkGroup.id
    
    Write-Host "Working on NG: $Name with Id: $Id"

    $Return = Invoke-CimMethod -InputObject $NetworkGroup -Name GetInfrastructureServices
    $JSON = $Return.ReturnValue | ConvertFrom-Json

    If ($Json.typeDescription -eq "Beacon") {
        Write-Host "Beacon found with infrastructureServiceId: $($Json.infrastructureServiceId)"
    }
    Else {
        Write-Host "No Beacon found"
    }

    Write-Host ""

}
#endregion