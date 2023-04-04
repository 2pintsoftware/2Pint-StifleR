

#Changeables
$ClassNames = ("Connections", "Networks", "Locations", "Areas", "Clients", "NetworkGroups", "TaskSequenceProgress", "Downloads", "Applications", "Beacons", "NetworkGroupTemplates", "DataEngine", "StifleREngine")
$outDir = "c:\temp\StifleR"
$Namespace = "root\StifleR"

If (!(Test-Path c:\temp\Stifler))
{
    mkdir c:\temp\stifler
}
 

#Loopie
foreach ($ClassName in $ClassNames)
{ 
    Write-Host $ClassName 
    $class = Get-CimClass -Namespace $Namespace -ClassName $ClassName 
    $hash = @{}; 
    $filename = "$($outDir)\$($ClassName)_Properties.csv" 
    
    "Type`tName`tOData Type`tDescription`tWrite" | Out-File "$($outDir)\$($ClassName)_Properties.csv" 
    
    foreach ($prop in $class.CimClassProperties) 
    { 
        [boolean]$write = $prop.Qualifiers["write"].Value -eq $true 
        $hash.Add($($prop.Name), "Property`t$($prop.Name)`t$($prop.CimType)`t$($prop.Qualifiers["Description"].Value)`t$($write)") 
    } 
    
    $hash.Values | Out-File "$($outDir)\$($ClassName)_Properties.csv" -Append 
    $hash = @{}; $filename = "$($outDir)\$($ClassName)_Methods.csv" 
    "Type`tStatic`tName`tReturn Type`tDescription`tWrite" | Out-File $filename 
    
    foreach ($prop in $class.CimClassMethods) 
    { 
        [boolean]$static = $prop.Qualifiers["static"].Value -eq $true 
        $hash.Add($($prop.Name), "Method`t$($static)`t$($prop.Name)`t$($prop.ReturnType)`t$($prop.Qualifiers["Description"].Value)`tN/A") 
    } 
    
    if($hash.Count -gt 0) 
    { 
        $hash.Values | Out-File "$($outDir)\$($ClassName)_Methods.csv" -Append 
    }
}