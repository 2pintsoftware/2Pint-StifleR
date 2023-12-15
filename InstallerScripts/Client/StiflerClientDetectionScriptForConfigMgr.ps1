$ErrorActionPreference = "SilentlyContinue"

# Stifler MSI
$RegistryPathStiflerMSIx64 = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{132A87D5-C9E9-4BBA-A801-7B64986AA448}'
$RegistryPathStiflerMSIx86 = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{F418D102-42EA-4BAC-B979-F785981AADDF}'

# StifleR Service
$serviceStatus = $False
$serviceName = "StifleRClient"
$Installed = $False

$service = Get-Service -Name $serviceName

if ($service.Status -eq "Running")
{
    $serviceStatus = $True
    
}
else
{
    $serviceStatus = $False
}


if (((Test-Path -Path $RegistryPathStiflerMSIx64) -or (Test-Path -Path $RegistryPathStiflerMSIx86)) -and ($serviceStatus -eq $True)) 
{
    write-host "Installed"
    
}
else 
{

}
