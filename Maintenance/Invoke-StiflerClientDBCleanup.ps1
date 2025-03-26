<# 

   .SYNOPSIS 
    Maintenance task that removes 'stale' clients from the StifleR DB  - that haven't checked in for xx days

   .DESCRIPTION
   See above :)
   Outputs results to a logfile

   .REQUIREMENTS
   Run on the StifleR Server

   .USAGE
   Set the path to the logfile
   .\ClientDBCleanup.ps1

   .NOTES
    AUTHOR: 2Pint Software
    EMAIL: support@2pintsoftware.com
    VERSION: 1.0.0.2
    DATE: 03/03/2023 
    
    CHANGE LOG: 
    1.0.0.0 : 02/22/2018  : Initial version of script 
    1.0.0.1 : 11/27/2020  : Updated logging, and switched to Get-CimInstance for better performance and compatibility with PowerShell core
    1.0.0.2 : 03/03/2023  : Changes to support Stifler v2.10+

   .LINK
    https://2pintsoftware.com

#>

# Change these two variables to match your environment!
$LogPath = "I:\2Pint_Maintenance\Logs\ClientDBCleanup" 
$NumberOfDays = 30 

# Ok, lets do this...
$Date = $(get-date -f MMddyyyy_hhmmss)
$Logfile = "$LogPath\ClientDBCleanup_$Date.log"

Function Write-Log{
	param (
    [Parameter(Mandatory = $true)]
    [string]$Message
   )

   $TimeGenerated = $(Get-Date -UFormat "%D %T")
   $Line = "$TimeGenerated : $Message"
   Add-Content -Value $Line -Path $LogFile -Encoding Ascii

}

Write-Log "Starting Client Cleanup." 

$Clients = Get-CimInstance -Namespace root\StifleR -Class "Clients"
$TotalClients = ($Clients | Measure-Object).Count
Write-Log "There are currently $TotalClients Clients in the DB." 

Write-Log "About to enumerate clients not being online the past $NumberOfDays days." 
$DateFilter = ([wmi]"").ConvertFromDateTime((get-date).AddDays(-$NumberOfDays))
$ClientsToRemove = Get-CimInstance -Namespace root\StifleR -Class "Clients" -Filter "DateOnline < '$DateFilter'"
$TotalToRemove = ($ClientsToRemove | Measure-Object).Count
Write-Log "Enumeration completed."

Write-Log "About to remove $TotalToRemove Clients from the DB" 

ForEach ($Client in $ClientsToRemove){

    $ClientName = $Client.ComputerName
    $LastCheckin = $Client.DateOnline
    Write-Log "Removing Client from DB Name: $ClientName, Last Checkin: $LastCheckin" 

    Try{
        Invoke-CimMethod -InputObject $Client -MethodName RemoveFromDB | Out-Null
    }
    Catch{
        Write-Log "Failed to remove Client $ClientName, $LastCheckin"
        Write-Log $_.Exception 
        throw  $_.Exception
    }

    Write-Log "Removed Client from DB Name: $ClientName, Last Checkin: $LastCheckin" 
}

Write-Log "Removed $TotalToRemove Clients"