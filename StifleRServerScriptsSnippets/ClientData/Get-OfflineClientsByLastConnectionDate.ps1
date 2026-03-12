function Get-StifleROfflineClients {
    <#
    .SYNOPSIS
        Returns StifleR clients that haven't connected within a specified number of days.
    .DESCRIPTION
        Queries the StifleR WMI Clients class and filters for clients whose last 
        connected date is older than the specified number of days.
    .PARAMETER DaysSinceLastContact
        Number of days since last contact. Clients not seen in this many days will be returned.
        Default is 30.
    .PARAMETER ComputerName
        The StifleR server to query. Default is localhost.
    .EXAMPLE
        Get-StifleROfflineClients -DaysSinceLastContact 7
        Returns all clients that haven't connected in the last 7 days.
    .EXAMPLE
        Get-StifleROfflineClients -DaysSinceLastContact 90 -ComputerName "DR"
        Returns clients offline for 90+ days from the server named DR.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [int]$DaysSinceLastContact = 30,

        [Parameter(Position = 1)]
        [string]$ComputerName = 'localhost',

        [switch]$CountOnly
    )

    $cutoffDate = (Get-Date).AddDays(-$DaysSinceLastContact)

    try {
        $clients = Get-CimInstance -Namespace 'ROOT\StifleR' -ClassName 'Clients' -ComputerName $ComputerName -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to query StifleR Clients WMI class on ${ComputerName}: $_"
        return
    }

    if (-not $clients) {
        Write-Warning "No clients found in StifleR WMI."
        return
    }

    $offlineClients = foreach ($client in $clients) {
        # DateConnected is WMI datetime string e.g. "20260312005028.825000-300"
        $lastConnected = $null
        if ($client.DateConnected) {
            try {
                # Handle WMI datetime format (CIM_DATETIME)
                if ($client.DateConnected -is [string]) {
                    $lastConnected = [System.Management.ManagementDateTimeConverter]::ToDateTime($client.DateConnected)
                }
                else {
                    $lastConnected = $client.DateConnected
                }
            }
            catch {
                # Try parsing as standard date string
                try { $lastConnected = [datetime]::Parse($client.DateConnected) } catch {}
            }
        }

        if ($null -eq $lastConnected -or $lastConnected -lt $cutoffDate) {
            [PSCustomObject]@{
                ComputerName     = $client.ComputerName
                DomainName       = $client.DomainName
                ClientVersion    = $client.ClientVersion
                OsVersion        = $client.OsVersion
                LastConnected    = $lastConnected
                DaysSinceContact = if ($lastConnected) { [math]::Round(((Get-Date) - $lastConnected).TotalDays, 1) } else { 'Never' }
                MacAddress       = $client.MacAddress
                AgentId          = $client.AgentId
            }
        }
    }

    $offlineClients = $offlineClients | Sort-Object LastConnected

    Write-Host "Found $($offlineClients.Count) client(s) not seen in the last $DaysSinceLastContact day(s)" -ForegroundColor Cyan

    if ($CountOnly) {
        return $offlineClients.Count
    }
    return $offlineClients
}
