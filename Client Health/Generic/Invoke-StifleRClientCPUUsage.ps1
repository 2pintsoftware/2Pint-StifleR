$TimeInBetweenSamples = 15 # Seconds
$NumberOfTests = '40' # four tests per minute = 10 minutes
$AppName = "StifleR.ClientApp"

$i = 1
[System.Collections.ArrayList]$CPUSamples = @()
do {

    $ProcessID = (Get-Process -Name $AppName).Id
    $ProcessCPUInfo = Get-CimInstance -ClassName Win32_PerfRawData_PerfProc_Process -Filter "IDProcess = '$ProcessID'"
    $StiflerCPU = $ProcessCPUInfo | Select Name, @{Name="PercentProcessorTime";Expression={($_.PercentProcessorTime/100000/100)/60}}

    $obj = [PSCustomObject]@{

        # Add values to arraylist
        AppName = $AppName
        CPUPercentage = $StiflerCPU.PercentProcessorTime
            
    }
        
    # Add the values
    $CPUSamples.Add($obj)|Out-Null

    # Sleep in between tests
    Start-Sleep -Seconds $TimeInBetweenSamples
$i++
}
while ($i -le $NumberOfTests)

$AverageCPUUsage = [math]::Round((($CPUSamples.CPUPercentage | Measure-Object -Average).Average),2)
Write-Host "Average CPU Usage for $AppName is: $AverageCPUUsage percent"
