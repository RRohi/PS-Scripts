# Support function: verbose logging utility.

Function Write-VerboseLog {
<#
.SYNOPSIS
Logging support function.
.DESCRIPTION
Shows verbose info when -Verbose switch is used, showing extensive info on executed cmdlets.
.EXAMPLE
A simple example:
Write-VerboseLog -LogInfo "This is a debug message."
.EXAMPLE
Send verbose log to file as well:
Write-VerboseLog -LogPath C:\TEMP\debug.log -LogInfo "This is a debug message."
.PARAMETER LogInfo
Specify log info.
.PARAMETER LogPath
Specify log path.
.NOTES
Output will be formatted as: "DateTime - LogInfo" or "20230627_154633 - This is a debug message."
.FUNCTIONALITY
Custom verbose logging utility.
#>
[CmdletBinding()]
Param(
    [Parameter(Position = 0, Mandatory = $True, HelpMessage = 'Enter Log info.' )]
    [String]$LogInfo,
    [Parameter(Position = 1, Mandatory = $False, HelpMessage = 'Enter path for the log file.' )]
    [String]$LogPath
)

Begin {
    # Get Current DateTime and store it in a variable.
    Get-Date -Format $Config.DateFormats.'Human-readable' -OutVariable DateStamp | Out-Null
} # End of Begin block.
Process {
    # Output Verbose Log Text.
    Write-Verbose -Message "$DateStamp - $LogInfo"

    # Check if LogPath parameter was used and Debugging is enabled.
    If ($LogPath -and $Config.Debug.Enabled -eq 1) {
        # Send verbose log to file.
        Add-Content -Path $LogPath -Value "$DateStamp - [$($MyInvocation.MyCommand.Name)] $LogInfo" -Encoding Unicode
    }
} # End of Process block.

} # End of Write-VerboseLog function.

# This script restarts network adapter if the network profile is not Domain Authenticated. This issue seems to be with older OS's (2012 R2 and older) in virtual environment,
# where VM boot ups and network wasn't ready for the handshake with the DC and the host, which is why the network adapter profile will be set to Private or Public introducing network-related issues.

# Set DC FQDN.
$DC = ''

# Set log file path.
$LogFilePath = 'C:\TEMP\NetAdapterProfile.log'

# Check if current network adapter profile is DomainAuthenticated.
If ((Get-NetConnectionProfile).NetworkCategory -ne 'DomainAuthenticated') {
    ## Network adapter profile is not DomainAuthenticated.
    Write-VerboseLog -LogInfo 'Network adapter profile is not domain authenticated.' -LogPath $LogFilePath

    ## Wait for SMB connection to the DC to succeed.
    While ((Test-NetConnection -ComputerName $DC -CommonTCPPort SMB).TcpTestSucceeded -ne $True) {
        Write-VerboseLog -LogInfo "SMB on $DC is unreacble, waiting for 10 seconds and trying again..." -LogPath $LogFilePath
        Start-Sleep -Seconds 10
    }

    ## Connection to DC was successful, restarting the network adapter, which should fix the network profile issue.
    Write-VerboseLog -LogInfo "$DC is reachable, restarting network adapter." -LogPath $LogFilePath
    Get-NetAdapter -Physical | Restart-NetAdapter -Confirm:$False

    Write-VerboseLog -LogInfo "Network adapter was restarted. Current network profile: $((Get-NetConnectionProfile).NetworkCategory)" -LogPath $LogFilePath
}
