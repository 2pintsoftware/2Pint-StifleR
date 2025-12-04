# POST Examples (Do stuff)

$headers = @{
    'Content-Type' = 'application/json'
    'Accept' = 'application/json'
}

# Create a Location WebAPI
$Locationurl = "https://dp01.corp.2pintsoftware.com:9000/api/location"

$Locationbodyjson = '{"name":"test","description":"test"}'
$LocationResponse = Invoke-WebRequest -uri $Locationurl -method Post -Body $Locationbodyjson -Headers $headers -UseDefaultCredentials



$LocationBody = @{
    name = "ScriptLocation"
    description = "my Description"
}

$LocationBody = $LocationBody |ConvertTo-Json
$LocationResponse = Invoke-WebRequest -uri $Locationurl -method Post -Body $LocationBody -Headers $headers -UseDefaultCredentials
($LocationResponse.Content |ConvertFrom-Json).id

$NGUrl = "https://dp01.corp.2pintsoftware.com:9000/api/networkgroup"
$NetworkGroupBody = @{
  "locationId" = ($LocationResponse.Content |ConvertFrom-Json).id
  "name" = "ScriptNG"
  "description" = "Made by script"
  "directRoute" = $true
}

$NetworkGroupBody = $NetworkGroupBody |ConvertTo-Json
$NGResponse = Invoke-WebRequest -uri $NGUrl -method Post -Body $NetworkGroupBody -Headers $headers -UseDefaultCredentials
($NGResponse.Content |ConvertFrom-Json)


$NetworkUrl = "https://dp01.corp.2pintsoftware.com:9000/api/network"
$NetworkBody = @{
    "id" = $null
    "latencyThreshold" = 0
    "networkMask" = "255.255.255.0"
    "gatewayMAC" = $null
    "networkId" = "192.168.99.0"
    "description" = $null
    "networkGroupId" = ($NGResponse.Content |ConvertFrom-Json).id
    "locationId" = ($LocationResponse.Content |ConvertFrom-Json).id
}

$NetworkBody = $NetworkBody |ConvertTo-Json
$NetResponse = Invoke-WebRequest -uri $NetworkUrl -method Post -Body $NetworkBody -Headers $headers -UseDefaultCredentials
($NetResponse.Content |ConvertFrom-Json)


$NetworkWMIUrl = "https://dp01.corp.2pintsoftware.com:9000/wmi-api/network"
$NetworkWMIBody = @{
    "networkId" = "192.168.98.0" 
    "networkGroupId" = ($NGResponse.Content |ConvertFrom-Json).id
    "networkMask" = "255.255.255.0"
    "gatewayMAC" = $null
    "description" = $null
}

$NetworkWMIBody = $NetworkWMIBody |ConvertTo-Json
$NetWMIResponse = Invoke-WebRequest -uri $NetworkWMIUrl -method Post -Body $NetworkWMIBody -Headers $headers -UseDefaultCredentials
$NetWMIResponse.Content

# PATCH
$NetGuid = $NetWMIResponse.Content -replace '"', ''
$NetPATCHUrl = "https://dp01.corp.2pintsoftware.com:9000/wmi-api/network/$NetGuid"

$NetworkPatchBody = @(
    @{
        "op" = "replace"
        "path" = "/description"
        "value" = "WiFi"
    }
)
# Do NOT do this!
$NetworkPatchBody = $NetworkPatchBody | ConvertTo-Json 

# Do this!
$NetworkPatchBody = ConvertTo-Json $NetworkPatchBody 
$NetWMIResponse = Invoke-WebRequest -uri $NetPATCHUrl -method PATCH -Body $NetworkPatchBody -Headers $headers -UseDefaultCredentials
$NetWMIResponse

$NetWMIResponse = Invoke-WebRequest -uri $NetPATCHUrl -method Get -Headers $headers -UseDefaultCredentials
$NetWMIResponse.Content |ConvertFrom-Json

# DELETE
$locid = ($LocationResponse.Content |ConvertFrom-Json).id
$LocationDELUrl = "https://dp01.corp.2pintsoftware.com:9000/api/location/$($locid)?force=true"
$LocationDELResponse = Invoke-WebRequest -uri $LocationDELUrl -method Delete -Headers $headers -UseDefaultCredentials
$LocationDELResponse
$LocationDELResponse.Content |ConvertFrom-Json

# -- Run PowerShell command on remote connection

$headers = @{
    'Content-Type' = 'application/json'
    'Accept' = 'application/json'
}

$uri = 'https://dp01.corp.2pintsoftware.com:9000/wmi-api/connections/invoke-powershell-command'

$body = @{
    targets = @(
        "d9143b73-dfcf-4443-87d6-7daf5c75ccc4"
    )
    script = @'
get-computerinfo |convertto-json
'@
    parameters = @(
        ""
    )
    flags = 0
    timeOut = 60000
} | ConvertTo-Json


Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -UseDefaultCredentials -UseBasicParsing

# Test connection to remote machine

$uri = "https://dp01.corp.2pintsoftware.com:9000/wmi-api/connections/measure-to-target-from-client"

$Body = @{
  "connectionId" = "d9143b73-dfcf-4443-87d6-7daf5c75ccc4"
  "target" = "192.168.1.109:7281"
  "ttl"= 100
  "msTimeOut" = 2000
} | ConvertTo-Json

Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -UseDefaultCredentials -UseBasicParsing
