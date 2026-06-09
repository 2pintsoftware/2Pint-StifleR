<#
.SYNOPSIS
  Remove Stifler Networks from IP Range
  This script requires Stifler 3.0 or later.

.DESCRIPTION
  This script removes Stifler Networks from within a specified IP range.

.PARAMETER startIP
  The starting IP address of the range from which Stifler Networks will be removed.
.PARAMETER endIP
  The ending IP address of the range from which Stifler Networks will be removed.

.NOTES
  Version:        1.0
  Author:         MB @ 2Pint Software
  Creation Date:  2026-06-09
  Purpose/Change: Initial script development

.EXAMPLE
    .\Remove-StiflerNetworksFromIPRange.ps1 -StartIP 192.169.97.0 -EndIP 192.169.100.0 -StiflerServer "dp01.corp.2pintsoftware.com"
#>
#region --------------------------------------------------[Script Parameters]------------------------------------------------------
param(
    [string]$StartIP,
    [string]$EndIP,
    [string]$StiflerServer,
    [switch]$verbose
)
#endregion -----------------------------------------------[Script Parameters]------------------------------------------------------
#region --------------------------------------------------[Initialisations]--------------------------------------------------------

#Convert StartIP and EndIP to ipaddress objects for easier manipulation
$StartIP = [ipaddress]::Parse($StartIP)
$EndIP = [ipaddress]::Parse($EndIP)
#endregion -----------------------------------------------[Initialisations]--------------------------------------------------------
#region --------------------------------------------------[Declarations]-----------------------------------------------------------

#Any Global Declarations go here
$maxlogfilesize = 5Mb
try{
  $Verbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent
}
catch {}

#endregion -----------------------------------------------[Declarations]-----------------------------------------------------------
#region --------------------------------------------------[Functions]--------------------------------------------------------------

#region Logging: Functions used for Logging, do not edit!
Function Start-Log {
    [CmdletBinding()]
    param (
        [ValidateScript({ Split-Path $_ -Parent | Test-Path })]
        [string]$FilePath
    )

    try {
        if (!(Test-Path $FilePath)) {
            ## Create the log file
            New-Item $FilePath -Type File | Out-Null
        }
  
        ## Set the global variable to be used as the FilePath for all subsequent Write-Log
        ## calls in this session
        $global:ScriptLogFilePath = $FilePath
    }
    catch {
        Write-Error $_.Exception.Message
    }
}

Function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
  
        [Parameter()]
        [ValidateSet(1, 2, 3)]
        [int]$LogLevel = 1
    )    
    $TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
    $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'
  
    if ($MyInvocation.ScriptName) {
        $LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), "$($MyInvocation.ScriptName | Split-Path -Leaf):$($MyInvocation.ScriptLineNumber)", $LogLevel
    }
    else {
        #if the script havn't been saved yet and does not have a name this will state unknown.
        $LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), "Unknown", $LogLevel
    }
    $Line = $Line -f $LineFormat

    If ($Verbose) {
        switch ($LogLevel) {
            2 { $TextColor = "Yellow" }
            3 { $TextColor = "Red" }
            Default { $TextColor = "Gray" }
        }
        Write-Host -nonewline -f $TextColor "$Message`r`n" 
    }

    #Make sure the logfile do not exceed the $maxlogfilesize
    if (Test-Path $ScriptLogFilePath) { 
        if ((Get-Item $ScriptLogFilePath).length -ge $maxlogfilesize) {
            If (Test-Path "$($ScriptLogFilePath.Substring(0,$ScriptLogFilePath.Length-1))_") {
                Remove-Item -path "$($ScriptLogFilePath.Substring(0,$ScriptLogFilePath.Length-1))_" -Force
            }
            Rename-Item -Path $ScriptLogFilePath -NewName "$($ScriptLogFilePath.Substring(0,$ScriptLogFilePath.Length-1))_" -Force
        }
    }

    $stream = [System.IO.StreamWriter]::new($ScriptLogFilePath, $true, ([System.Text.Utf8Encoding]::new()))
    $stream.WriteLine("$Line")
    $stream.close()

    # Remove above 3 lines with $stream and uncomment line below if you want to use Out-File instead of StreamWriter as log write metod
    # Out-File -InputObject $Line -FilePath $ScriptLogFilePath -Encoding UTF8 -Append 
}
#endregion

# Add functions Here


#endregion -----------------------------------------------[Functions]--------------------------------------------------------------
#region---------------------------------------------------[Execution]--------------------------------------------------------------
Start-Log -FilePath "$($env:TEMP)\$([io.path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)).log"

$headers = @{
     'Accept' = 'application/json'
}

#Get all networks from Stifler
$uri = "https://$($StiflerServer):9000/api/network"
$networks = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -UseDefaultCredentials -UseBasicParsing

# Convert IPv4 address to UInt32 in network-order comparable form.
$ConvertIPv4ToUInt32 = {
  param([ipaddress]$Address)
  $bytes = $Address.GetAddressBytes()
  [Array]::Reverse($bytes)
  return [BitConverter]::ToUInt32($bytes, 0)
}

# Convert StartIP and EndIP to numeric values for range comparison.
$startIPNumeric = [uint32](& $ConvertIPv4ToUInt32 $StartIP)
$endIPNumeric   = [uint32](& $ConvertIPv4ToUInt32 $EndIP)

# Array to hold networks that fall within the specified IP range
$networksToRemove = @()

foreach ($network in $networks) {
  # Parse network base IP and mask using explicit byte-order conversion.
  $networkBaseIP = [uint32](& $ConvertIPv4ToUInt32 ([ipaddress]::Parse($network.networkId)))
  $maskNumeric   = [uint32](& $ConvertIPv4ToUInt32 ([ipaddress]::Parse($network.networkMask)))

    # Calculate the network's broadcast/end IP: broadcast = networkBase | (~mask)
  $networkEndNumeric = [uint32]($networkBaseIP -bor ((-bnot $maskNumeric) -band 0xFFFFFFFF))

    # Check if the entire network range falls within the specified IP range
    if (($networkBaseIP -ge $startIPNumeric) -and ($networkEndNumeric -le $endIPNumeric)) {
        $networksToRemove += [PSCustomObject]@{
            Id             = $network.id
            NetworkId      = $network.networkId
            NetworkMask    = $network.networkMask
            ActiveClients  = $network.activeClients
            MaxClients     = $network.maxClients
        }
        Write-Log "Network $($network.networkId)/$($network.networkMask) is within range $($StartIP) - $($EndIP) (ID: $($network.id))"
    }
}

Write-Log "Found $($networksToRemove.Count) network(s) to remove within the specified IP range."

$selection = $networksToRemove | Out-GridView -Title "Following networks was found withing the IPRange, select those to be deleted. Ctrl+A for all -> OK" -PassThru

$Deletedcount = 0
if ($selection.Count -eq 0) {
    Write-Log "No networks selected for removal. Exiting."
    break
} else {
    Write-Log "Selected $($selection.Count) network(s) for removal. Proceeding with deletion."
    foreach ($network in $selection) {
        $deleteuri = "https://$($StiflerServer):9000/api/network/$($network.Id)?force=true"
        try {
            Invoke-RestMethod -Uri $deleteUri -Method Delete -Headers $headers -UseDefaultCredentials -UseBasicParsing
            Write-Log "Successfully removed network ID: $($network.Id) (Network: $($network.NetworkId)/$($network.NetworkMask))"
            $Deletedcount++
        }
        catch {
            Write-Log "Failed to remove network ID: $($network.Id). Error: $_" -LogLevel 3
        }
    }
    Write-Log "Completed network removal. Total networks deleted: $Deletedcount out of $($selection.Count) selected."
}
