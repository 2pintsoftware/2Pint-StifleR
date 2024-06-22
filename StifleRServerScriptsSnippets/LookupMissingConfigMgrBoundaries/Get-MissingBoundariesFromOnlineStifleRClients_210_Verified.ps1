<# 
    .DISCLAIMER 
    Use at your own risk. Test it in a lab first, and modify to suit your setup. 
   
    .SYNOPSIS 
    Sample script for looking up boundaries in ConfigMgr based on StifleR information, and report any missing boundaries.

    .DESCRIPTION
    Set the required Port Number for P2P transfers
    This script is tested with StifleR version 2.10

    AUTHOR: 2Pint Software
    EMAIL: support@2pintsoftware.com
    VERSION: 1.0.0.0
    DATE: 23 March 2021 
    
    CHANGE LOG: 
    1.0.0.0 : 03/23/2021  : Initial version of script 

   .LINK
    https://2pintsoftware.com
#>

# Generic variables
$SiteServer = "cm01.corp.viamonstra.com"
$StifleRServer = "stifler02.corp.viamonstra.com"
$ExportPath = "E:\HealthCheck\Results"
If (!(Test-Path $ExportPath)){ New-Item -Path $ExportPath -ItemType Directory -Force}

# Log file
$ts = $(get-date -f MMddyyyy_hhmmss)
$ExportFile = "$ExportPath\ConfigMgrBoundariesReportFromStifleRClients_$ts.csv"

# Get active connections, and enumerate unique default gateway IP addresses
$Connections = Get-CimInstance -ComputerName $StifleRServer -Namespace root\StifleR -ClassName Connections
$Gateway = $Connections.GatewayWMI
$IPAddresses = $Gateway | Select -Unique

# Get ConfigMgr IP Range type boundaries via WMI
$Boundary = Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS\site_$(Get-CMSiteCode)" -Class SMS_Boundary -Filter "BoundaryType = 3"
$BoundaryCount = ($Boundary | Measure-Object).Count
if ($BoundaryCount -gt 0) {

    [System.Collections.ArrayList]$NetworkInfo = @()
    foreach ($IP in $IPAddresses){
        $Results = 0
        $IPAddress = $IP

        # Validate the IP
        $ValidIP=$IPAddress -as [ipaddress] -as [Bool]
        if ($ValidIP -eq $false){
                write-host "IP address: $IPAddress is an invalid IP Address. Skipping"
        }
        Else{
            $Boundary | ForEach-Object {
                $BoundaryName = $_.DisplayName
                $BoundaryNameLength = $_.DisplayName.Length
                $BoundaryFullRange = $_.Value 
                $BoundaryValue = $_.Value.Split("-")
                $IPStartRange = $BoundaryValue[0]
                $IPEndRange = $BoundaryValue[1]
                $ParseIP = [System.Net.IPAddress]::Parse($IPAddress).GetAddressBytes()
                [Array]::Reverse($ParseIP)
                $ParseIP = [System.BitConverter]::ToUInt32($ParseIP, 0)
                $ParseStartIP = [System.Net.IPAddress]::Parse($IPStartRange).GetAddressBytes()
                [Array]::Reverse($ParseStartIP)
                $ParseStartIP = [System.BitConverter]::ToUInt32($ParseStartIP, 0)
                $ParseEndIP = [System.Net.IPAddress]::Parse($IPEndRange).GetAddressBytes()
                [Array]::Reverse($ParseEndIP)
                $ParseEndIP = [System.BitConverter]::ToUInt32($ParseEndIP, 0)
                if (($ParseStartIP -le $ParseIP) -and ($ParseIP -le $ParseEndIP)) {
                    if ($BoundaryName.Length -ge 1) {
                        $Results = 1
                        #Write-Output "`nIP address '$($IPAddress)' is within the following boundary:"
                        #Write-Output "Description: $($BoundaryName)`n"
                        #Write-Output "IPRange: $($BoundaryFullRange)`n"

                        $obj = [PSCustomObject]@{
                            IPAddress = $IPAddress
                            BoundaryName = $BoundaryName
                            IPRange = $BoundaryFullRange
                        }

                        # Add all the values
                        $NetworkInfo.Add($obj)|Out-Null
                    }
                    else {
                        $Results = 1
                        #Write-Output "`nIP address '$($IPAddress)' is within the following boundary:"
                        #Write-Output "Range: $($BoundaryFullRange)`n"
                        $obj = [PSCustomObject]@{
                            IPAddress = $IPAddress
                            BoundaryName = $BoundaryName
                            IPRange = $BoundaryFullRange
                        }

                        # Add all the values
                        $NetworkInfo.Add($obj)|Out-Null
                    }
                }
            }
            if ($Results -eq 0) {
                #Write-Output "`nIP address '$($IPAddress)' was not found in any boundary`n"

                $obj = [PSCustomObject]@{
                    IPAddress = $IPAddress
                    BoundaryName = "MISSING"
                    IPRange = "MISSING"
                }

                # Add all the values
                $NetworkInfo.Add($obj)|Out-Null

            }
        }
    }
}
else {
    Write-Output "`nNo IP range boundaries was found`n"
}

# Export the report to a CSV file
$NetworkInfo | Export-Csv -LiteralPath $ExportFile -NoTypeInformation