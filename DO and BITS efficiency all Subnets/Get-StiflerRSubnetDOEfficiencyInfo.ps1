$Date = $(get-date -f MMddyyyy_hhmm)
$DateForCSVTimeStamp = $(Get-Date -UFormat "%D %T")
$ExportPath = "E:\2Pint_Installation\HealthCheck\Results\DONetworkInfo_$Date.csv"

$Subnets = Get-WmiObject -Namespace root\stifler -query "Select * from Subnets where clients > 0 and VPN = 'False'"

[System.Collections.ArrayList]$DONetWorkInfo = @()
foreach ($Subnet in $Subnets){
    $DOSourceHistory = $Subnet.DOSourceHistory
    $DOSourceHistoryInGB = $([math]::Round(($DOSourceHistory/1GB),2))
    
    $DOPeerToPeerHistory = $Subnet.DOPeerToPeerHistory
    $DOPeerToPeerHistoryInGB = $([math]::Round(($DOPeerToPeerHistory/1GB),2))

    If ($DOPeerToPeerHistory -eq 0){
        $DOEfficiency = 0
    }
    Else {
        $DOEfficiency = $DOPeerToPeerHistory/($DOSourceHistory + $DOPeerToPeerHistory)
        $DOEfficiency = $([math]::Round(($DOEfficiency*100),2))
        
    }

    $obj = [PSCustomObject]@{

        # Add values to arraylist
        SubnetID  =  $Subnet.SubnetID
        DataCollectDate = $DateForCSVTimeStamp
        Clients = $Subnet.clients
        DOSourceHistoryInGB = $DOSourceHistoryInGB
        DOPeerToPeerHistoryInGB = $DOPeerToPeerHistoryInGB
        DOEfficiency = $DOEfficiency 
        ID = $subnet.id
    }

    # Add all the values
    $DONetWorkInfo.Add($obj)|Out-Null


}

$DONetWorkInfo | Export-Csv -Path $ExportPath -NoTypeInformation