$Date = $(get-date -f MMddyyyy_hhmm)
$DateForCSVTimeStamp = $(Get-Date -UFormat "%D %T")
$ExportPath = "E:\2Pint_Installation\HealthCheck\Results\BITSNetworkInfo_$Date.csv"

$Subnets = Get-WmiObject -Namespace root\stifler -query "Select * from Subnets where clients > 0 and VPN = 'False'"

[System.Collections.ArrayList]$BITSNetworkInfo = @()
foreach ($Subnet in $Subnets){
    $BITSSourceHistory = $Subnet.BITSSourceHistory
    $BITSSourceHistoryInGB = $([math]::Round(($BITSSourceHistory/1GB),2))
    
    $BITSPeerToPeerHistory = $Subnet.BITSPeerToPeerHistory
    $BITSPeerToPeerHistoryInGB = $([math]::Round(($BITSPeerToPeerHistory/1GB),2))

    If ($BITSPeerToPeerHistory -eq 0){
        $BITSEfficiency = 0
    }
    Else {
        $BITSEfficiency = $BITSPeerToPeerHistory/($BITSSourceHistory + $BITSPeerToPeerHistory)
        $BITSEfficiency = $([math]::Round(($BITSEfficiency*100),2))
        
    }

    $obj = [PSCustomObject]@{

        # Add values to arraylist
        SubnetID  =  $Subnet.SubnetID
        DataCollectDate = $DateForCSVTimeStamp
        Clients = $Subnet.clients
        BITSSourceHistoryInGB = $BITSSourceHistoryInGB
        BITSPeerToPeerHistoryInGB = $BITSPeerToPeerHistoryInGB
        BITSEfficiency = $BITSEfficiency 
        ID = $subnet.id
    }

    # Add all the values
    $BITSNetworkInfo.Add($obj)|Out-Null


}

$BITSNetworkInfo | Export-Csv -Path $ExportPath -NoTypeInformation