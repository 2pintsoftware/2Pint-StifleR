function Get-StifleRClientByOnlineStatus {
    <#
    .SYNOPSIS
        Returns all StifleR clients with their Online/Offline status.
    .DESCRIPTION
        Queries the StifleR WMI Clients class (all known clients) and the ClientsManaged 
        class (currently connected clients). Cross-references the two to determine each 
        client's online status.
    .PARAMETER ComputerName
        The StifleR server to query. Default is localhost.
    .PARAMETER Status
        Filter results by status: 'Online', 'Offline', or 'All'. Default is 'All'.
    .PARAMETER CountOnly
        Returns just the count(s) instead of client details.
    .EXAMPLE
        Get-StifleRClientByOnlineStatus -ComputerName "DR"
        Returns all clients with their Online/Offline status.
    .EXAMPLE
        Get-StifleRClientByOnlineStatus -ComputerName "DR" -Status Online
        Returns only currently online clients.
    .EXAMPLE
        Get-StifleRClientByOnlineStatus -ComputerName "DR" -CountOnly
        Returns a summary count of online and offline clients.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [string]$ComputerName = 'localhost',

        [Parameter(Position = 1)]
        [ValidateSet('All', 'Online', 'Offline')]
        [string]$Status = 'All',

        [switch]$CountOnly
    )

    # Get all known clients
    try {
        $allClients = Get-CimInstance -Namespace 'ROOT\StifleR' -ClassName 'Clients' -ComputerName $ComputerName -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to query StifleR Clients class on ${ComputerName}: $_"
        return
    }

    # Get currently connected (online) clients
    try {
        $onlineClients = Get-CimInstance -Namespace 'ROOT\StifleR' -ClassName 'ClientsManaged' -ComputerName $ComputerName -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to query ClientsManaged class. Treating all clients as Offline."
        $onlineClients = @()
    }

    if (-not $allClients) {
        Write-Warning "No clients found in StifleR WMI."
        return
    }

    # Build a hashset of online computer names for fast lookup
    $onlineLookup = @{}
    foreach ($managed in $onlineClients) {
        if ($managed.ComputerName) {
            $onlineLookup[$managed.ComputerName] = $managed
        }
    }

    # Build results with status
    $results = foreach ($client in $allClients) {
        $isOnline = $onlineLookup.ContainsKey($client.ComputerName)
        $clientStatus = if ($isOnline) { 'Online' } else { 'Offline' }

        # Apply status filter
        if ($Status -ne 'All' -and $clientStatus -ne $Status) { continue }

        [PSCustomObject]@{
            ComputerName  = $client.ComputerName
            DomainName    = $client.DomainName
            Status        = $clientStatus
            ClientVersion = $client.ClientVersion
            OsVersion     = $client.OsVersion
            LastConnected = $client.DateConnected
            MacAddress    = $client.MacAddress
            AgentId       = $client.AgentId
        }
    }

    $results = $results | Sort-Object Status, ComputerName

    $onlineCount = ($results | Where-Object { $_.Status -eq 'Online' }).Count
    $offlineCount = ($results | Where-Object { $_.Status -eq 'Offline' }).Count

    if ($CountOnly) {
        Write-Host "Total Clients: $($allClients.Count)" -ForegroundColor Cyan
        Write-Host " Online:  $onlineCount" -ForegroundColor Green
        Write-Host " Offline: $offlineCount" -ForegroundColor Yellow
        return [PSCustomObject]@{
            Total   = $allClients.Count
            Online  = $onlineCount
            Offline = $offlineCount
        }
    }

    Write-Host "Total: $($results.Count) | Online: $onlineCount | Offline: $offlineCount" -ForegroundColor Cyan
    return $results
}
