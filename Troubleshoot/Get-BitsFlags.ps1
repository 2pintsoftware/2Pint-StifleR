<#
.SYNOPSIS
  Get-BitsFlags

.DESCRIPTION
  <Brief description of script>

.PARAMETER number
  This is the decimal number that should be converted into bit flags

.PARAMETER flagset
  Precreated set of flags, if used the numbers will be converted to matching values in the specified set.
  Valid options: Stifler, StifleRUserFlags, BranchCache, DO, 

.NOTES
  Version:        1.0
  Author:         MB @ 2Pint Software
  Creation Date:  2024-04-17
  Purpose/Change: Initial script development

.EXAMPLE
    Get-BitsFlags -flagset Stifler -number 2178206993954
#>
#---------------------------------------------------------[Script Parameters]------------------------------------------------------
param(
    [int64]$number,
    [ValidateSet("StiflerClientFlags", "StifleRUserFlags", "BranchCache", "DO")]
    $flagset
)
#----------------------------------------------------------[Declarations]----------------------------------------------------------

$BCflags = [Ordered]@{
    PREFERRED_CONTENTINFORMATION_VERSION_IS_V1      = 1
    PREFERRED_CONTENTINFORMATION_VERSION_IS_V2      = 2
    PEERDIST_RUNNING                                = 32
    PEERDIST_INJECT_OK                              = 64
    PEERDIST_STATUS_DISABLED                        = 128
    PEERDIST_STATUS_UNAVAILABLE                     = 256
    PEERDIST_STATUS_AVAILABLE                       = 512
    BRANCHCACHE_IS_ENABLED                          = 1024
    SERVICE_STARTUP_MANUAL                          = 2048
    SERVICE_STARTUP_AUTOMATIC                       = 4096
    SERVICE_STARTUP_DISABLED                        = 8192
    PEERDIST_CURRENT_MODE_DISABLED                  = 16384
    PEERDIST_CURRENT_MODE_LOCAL                     = 32768
    PEERDIST_CURRENT_MODE_DISTRIBUTED               = 65536
    PEERDIST_CURRENT_MODE_HOSTEDSERVER              = 131072
    PEERDIST_CURRENT_MODE_HOSTEDCLIENT              = 262144
    PEERDIST_WIFI_MC_OK                             = 524288
    DISTRIBUTED_CACHING_IS_ENABLED                  = 4194304
    HOSTED_CACHE_DISCOVERY_ENABLED                  = 8388608
    SERVE_DISTRIBUTED_CACHING_PEERS_ON_BATTERYPOWER = 16777216
    PEERDIST_REDLEADER_REACHED_V1                   = 33554432
    PEERDIST_REDLEADER_REACHED_V2                   = 67108864
    PEERDIST_GREENLEADER_REACHED                    = 134217728
    FW_ERROR_EVENTS_DETECTED                        = 268435456
    CONTENTDOWNLOAD_PORTS_MATCH                     = 536870912
    HOSTEDCACHE_HTTP_PORTS_MATCH                    = 1073741824
    HOSTEDCACHE_HTTPS_PORTS_MATCH                   = 2147483648
    CONTENTRETRIEVAL_FIREWALL_RULES_ENABLED         = 4294967296
    CONTENTRETRIEVAL_URL_RESERVATION_ENABLED        = 8589934592
    HOSTEDCACHE_CLIENT_FIREWALL_RULES_ENABLED       = 17179869184
    HOSTEDCACHE_HTTPS_URL_RESERVATION_ENABLED       = 34359738368
    HOSTEDCACHE_HTTP_URL_RESERVATION_ENABLED        = 68719476736
    HOSTEDCACHE_SERVER_FIREWALL_RULES_ENABLED       = 137438953472
    PEERDISCOVERY_FIREWALL_RULES_ENABLED            = 274877906944
    CONTENTDOWNLOAD_PORT_CUSTOM                     = 549755813888
    PEERDIST_CORRECT_SID                            = 1099511627776
    PEERDIST_EVENT_MAJOR_ERROR                      = 2199023255552
    PEERDIST_EVENT_MINOR_ERROR                      = 4398046511104
}

$DOFlags = [Ordered]@{
    DO_RUNNING                  = 32
    DO_STATUS_DISABLED          = 128
    DO_STATUS_UNAVAILABLE       = 256
    DO_STATUS_AVAILABLE         = 512
    DO_IS_ENABLED               = 1024
    SERVICE_STARTUP_MANUAL      = 2048
    SERVICE_STARTUP_AUTOMATIC   = 4096
    SERVICE_STARTUP_DISABLED    = 8192
    DO_CURRENT_MODE_DISABLED    = 16384
    DO_CURRENT_MODE_HTTP_ONLY   = 32768
    DO_CURRENT_MODE_LAN         = 65536
    DO_CURRENT_MODE_GROUP       = 131072
    DO_CURRENT_MODE_INTERNET    = 262144
    DO_CURRENT_MODE_SIMPLE      = 524288
    DO_CURRENT_MODE_BYPASS      = 4194304
    DO_REDLEADER_REACHED_V1     = 33554432
    DO_DNS_MSG_RECIEVED         = 67108864
    DO_DNS_MSG_RECIEVED_BRIDGED = 134217728
    DO_IS_PINK_LEADER           = 268435456
    DO_EVENT_MAJOR_ERROR        = 2199023255552
    DO_EVENT_MINOR_ERROR        = 4398046511104
}

$Stiflerflags = [Ordered]@{
    NotLeader                       = 1
    RedLeader                       = 2
    BlueLeader                      = 4
    OnBattery                       = 8
    LowDiskSpace                    = 16
    HighCpuUsage                    = 32
    LowRAM                          = 64
    Laptop                          = 128
    Desktop                         = 256
    Server                          = 512
    Tablet                          = 1024
    UserLoggedOn                    = 2048
    ActiveUser                      = 4096
    HighPowerProfile                = 8192
    WiredNIC                        = 16384
    E100Mb                          = 32768
    E1000Mb                         = 65536
    E10000Mb                        = 131072
    WinPE                           = 262144
    iPXE                            = 524288
    ServerSKU                       = 1048576
    ServerAsClient                  = 2097152
    LocationIdentificationCompleted = 4194304
    LowBattery                      = 8388608
    OnVPN                           = 16777216
    OnLTE                           = 33554432
    OnWIFI                          = 67108864
    OnOtherNetwork                  = 134217728
    BITSPolicyInPlay                = 268435456
    DOPolicyInPlay                  = 536870912
    BCPolicyInPlay                  = 1073741824
    GreenLeader                     = 2147483648
    CurrentLocationRoamingForever   = 4294967296
    SSD                             = 8589934592
    NVME                            = 17179869184
    FastChannel                     = 34359738368
    NomessageFromServerInPeriod     = 68719476736
    SkipLeaderElection              = 137438953472
}

$StifleRUserFlags = [Ordered]@{
    IsGuest                                     = 1
    IsSystem                                    = 2
    IsAuthenticated                             = 4
    UACDisabled                                 = 8
    IsElevated                                  = 16
    CanElevate                                  = 32
    UACLevel0                                   = 64
    UACLevel1                                   = 128
    UACLevel2                                   = 256
    UACLevel3                                   = 512
    UACLevel4                                   = 1024
    UACLevel5                                   = 2048
    Reserved                                    = 4096
    UserIsLocal                                 = 8192
    UserIsDomain                                = 16384
    IsDirectAdmin                               = 32768
    IsLocalGroupAdmin                           = 65536
    IsActiveDirectoryAdmin                      = 131072
    HasTerminalServicesEnabled                  = 262144
    HasTSUser                                   = 524288
    WasElevated                                 = 1048576
    MatchDomainAdminPrefix                      = 2097152
    SecureDesktop                               = 4194304
    Session0InUse                               = 8388608
    Session1InUse                               = 16777216
    Session2InUse                               = 33554432
    ConsoleIsLocked                             = 67108864
    NoConsoleUser                               = 134217728
    EnforceAdminCodeSignatures                  = 268435456
    Session1ElevatedWellKnownSIDOutsideSession0 = 536870912
    AuthenticationTypeCloudAP                   = 1073741824
    AuthenticationTypeKerberos                  = 2147483648
    AuthenticationTypeNTLM                      = 4294967296
    LocalAdminsGroupExist                       = 8589934592
    LocalAdminActive                            = 17179869184
    OtherLocalAdminsActive                      = 34359738368
    OtherLocalAdminAccountsExist                = 68719476736
    ConsoleIsUnlocked                           = 137438953472
    ConsoleLockIsUnknown                        = 274877906944
    HasOutlookOpenAsAdmin                       = 549755813888
    HasPrefixAdmin                              = 1099511627776
    HasBrowserOpenAsAdmin                       = 2199023255552
    HasBrowserToInternet                        = 4398046511104
    TSDisconnected                              = 8796093022208
    HighestPossibleAccountLoggedOn              = 17592186044416
    HasNonLoggedOnUserAdminProcess              = 35184372088832
}

#-----------------------------------------------------------[Functions]------------------------------------------------------------
$NoFlagset = $false
# Define flags and their values
switch ($flagset) {
    "StifleRClientFlags" { $flags = $Stiflerflags }
    "StifleRUserFlags" { $flags = $StifleRUserFlags }
    "BranchCache" { $flags = $BCflags }
    "DO" { $flags = $DOFlags }
    Default { $NoFlagset = $true }
}            

if ($NoFlagset) {
    $bitPosition = 0
    $results = @()  # An array to hold the results
            
    while ($number -ne 0) {
        $currentBit = $number -band 1
        if ($currentBit -eq 1) {
            # Calculate the power of two for the current bit position and add to results
            $results += [math]::Pow(2, $bitPosition)
        }
        $number = $number -shr 1
        $bitPosition++
    }
            
    # Return results sorted
    return $results
}
else {
    # Array to collect set flags
    $setFlags = New-Object System.Collections.ArrayList

    # Check each flag
    foreach ($flag in $flags.Keys) {
        $flagValue = $flags[$flag]
        if (($number -band $flagValue) -eq $flagValue) {
            $setFlags.Add("$flag ($flagValue)") | Out-Null
        }
    }

    # Return the list of set flags
    return $setFlags
}