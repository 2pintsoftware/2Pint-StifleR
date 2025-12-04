# Get Client info from WMI

$class = "Connections"
$Connection = Get-CimInstance -Namespace root\StifleR -Query "SELECT * FROM $class WHERE AgentID = '3f8e9e54-e8be-432f-9d9d-d3d624ebe461'"
$Connection 
$Connection | Select-Object -Property ComputerName, ConnectionID, AgentId, Connected, IPAddress

