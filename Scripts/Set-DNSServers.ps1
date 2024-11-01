#Required -Version 5.1

# This script sets DNS servers to selected computers in an environment where a 3rd-party DNS solution is being used as authoritative DNS server and MS DNS is being used as secondaries. If the client DNS servers were not configured before, the script will not add them either.
# In this example, a GPO was used to distribute the script and a scheduled task was registered that executed the script.

# DNS Server arrays.
## 3rd-party DNS servers.
[Array]$MainDNSServers = @( '1.1.1.1', '2.2.2.2' )

## Microsoft DNS servers.
[Array]$SecondaryDNSServer = @( '3.3.3.3', '4.4.4.4' )

[Array]$CombinedDNS = $MainDNSServers + $SecondaryDNSServer

Get-NetAdapter -Physical -OutVariable NICs | Out-Null

ForEach ($NIC in $NICs) {
    Get-NetIPAddress -InterfaceIndex $NIC.InterfaceIndex -AddressFamily IPv4 -OutVariable IP | Out-Null

    Get-DnsClientServerAddress -InterfaceIndex $NIC.InterfaceIndex -AddressFamily IPv4 -OutVariable CurrentDNSServers | Out-Null

    ## Check if IP address is in the forbidden range or empty.
    If ($IP.Address -notlike '5.4.3.*' -or $null -ne $CurrentDNSServers.ServerAddresses) {
        ### Set the previously listed DNS servers as client DNS servers if the server is not in the excluded subnet or the server didn't have any DNS servers configured.
        Set-DnsClientServerAddress -InterfaceIndex $NIC.InterfaceIndex -ServerAddresses $CombinedDNS
    }
}

# Remove the script.
Remove-Item -Path "$PSScriptRoot\$($MyInvocation.MyCommand)"
