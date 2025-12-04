# GET Examples

#Get CacheR CacheTracks Example
$url = "https://dp01.corp.2pintsoftware.com:9000/api/cache-tracks?pageNumber=1&pageSize=20&cacheRVersion=&target=a92ddffb-b545-4259-803e-3cf479196094"
$CacheRresponse = Invoke-WebRequest -uri $url -method get -UseBasicParsing -UseDefaultCredentials
($CacheRresponse.Content |ConvertFrom-Json).result.results |Out-GridView

# Client from WebApi
$url = "https://dp01.corp.2pintsoftware.com:9000/api/client/agentId/028f38e0-549a-488c-bafb-14438684b1e2/"
$ClientAPIresponse = Invoke-WebRequest -uri $url -method get -UseBasicParsing -UseDefaultCredentials
($ClientAPIresponse.Content |ConvertFrom-Json)
(($ClientAPIresponse.Content |ConvertFrom-Json).PSObject.Properties.Name).Count

# Client from WMIApi
$url = "https://dp01.corp.2pintsoftware.com:9000/wmi-api/client/getClient/028f38e0-549a-488c-bafb-14438684b1e2"
$ClientWMIAPIresponse = Invoke-WebRequest -uri $url -method get -UseBasicParsing -UseDefaultCredentials
($ClientWMIAPIresponse.Content |ConvertFrom-Json)
(($ClientWMIAPIresponse.Content |ConvertFrom-Json).PSObject.Properties.Name).Count

Compare-Object ($ClientAPIresponse.Content |ConvertFrom-Json).PSObject.Properties.Name ($ClientWMIAPIresponse.Content |ConvertFrom-Json).PSObject.Properties.Name

# Find Connected client by name WebApi (WildCard)
$clientName = "micache-001"

$searchurl = "https://dp01.corp.2pintsoftware.com:9000/api/search/clientByValue/$($clientName)"
$ClientSearchWMIAPIresponse = Invoke-WebRequest -uri $searchurl -method get -UseBasicParsing -UseDefaultCredentials
($ClientSearchWMIAPIresponse.Content |ConvertFrom-Json)

($ClientSearchWMIAPIresponse.Content |ConvertFrom-Json).Matches