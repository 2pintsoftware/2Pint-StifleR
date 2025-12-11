param(
    [Parameter(Mandatory=$true)]
    [string]$Target
)

function Get-AdapterForTarget {
    param([string]$TargetAddress)
    
    try {
        $resolvedIP = $null
        
        if ($TargetAddress -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
            $resolvedIP = $TargetAddress
            Write-Host "Using IP address: $resolvedIP"
        } else {
            Write-Host "Resolving DNS name: $TargetAddress"
            $dnsResult = [System.Net.Dns]::GetHostAddresses($TargetAddress)
            $resolvedIP = $dnsResult[0].IPAddressToString
            Write-Host "Resolved to IP: $resolvedIP"
        }
        
        $route = Find-NetRoute -RemoteIPAddress $resolvedIP | Select-Object -First 1
        
        if ($route) {
            $adapter = Get-NetAdapter -InterfaceIndex $route.InterfaceIndex
            
            Write-Host "`nNetwork Adapter Information:"
            Write-Host "=============================="
            Write-Host "Adapter Name: $($adapter.Name)"
            Write-Host "Description: $($adapter.InterfaceDescription)"
            Write-Host "Status: $($adapter.Status)"
            Write-Host "MAC Address: $($adapter.MacAddress)"
            Write-Host "Link Speed: $($adapter.LinkSpeed)"
            
            $ipConfig = Get-NetIPAddress -InterfaceIndex $route.InterfaceIndex | Where-Object { $_.AddressFamily -eq 'IPv4' }
            if ($ipConfig) {
                Write-Host "IP Address: $($ipConfig.IPAddress)"
                Write-Host "Prefix Length: $($ipConfig.PrefixLength)"
            }
            
            Write-Host "`nRoute Information:"
            Write-Host "=============================="
            Write-Host "Next Hop: $($route.NextHop)"
            Write-Host "Route Metric: $($route.RouteMetric)"
            Write-Host "Interface Metric: $($route.InterfaceMetric)"
            
            return $adapter
        } else {
            Write-Host "No route found for $resolvedIP" -ForegroundColor Red
            return $null
        }
        
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
        return $null
    }
}

Get-AdapterForTarget -TargetAddress $Target
