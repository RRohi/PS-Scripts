Function Write-VerboseLog {
<#
.SYNOPSIS
Logging Support Function.
.DESCRIPTION
Shows verbose info when -Verbose switch is used, showing extensive info on executed cmdlets.
.EXAMPLE
A simple example:
Write-VerboseLog -LogInfo 'This is a debug message.'
.EXAMPLE
Send verbose log to file as well:
Write-VerboseLog -LogPath C:\TEMP\debug.log -LogInfo 'This is a debug message.'
.PARAMETER LogInfo
Specify Log Info.
.PARAMETER LogPath
Specify Log Path.
.NOTES
Output will be formatted as: 'DateTime - LogInfo'
.FUNCTIONALITY
Verbose Information
#>
[CmdletBinding()]
Param(
    [Parameter( Mandatory = $True )]
    [String]$LogInfo,
    [String]$LogPath
)

Begin {
    # Get Current DateTime and store it in a variable.
    Get-Date -Format 'dd.MM.yyyy HH:mm:ss' -OutVariable DateStamp | Out-Null
} # End of Begin block.
Process {
    # Output Verbose Log Text.
    Write-Verbose -Message "$DateStamp - $LogInfo"

    # Check if LogPath parameter was used and Debugging is enabled.
    If ($LogPath) {
        # Send verbose log to file.
        Add-Content -Path $LogPath -Value "$DateStamp - $LogInfo" -Encoding Unicode
    }
} # End of Process block.

} # End of Write-VerboseLog function.

Function Start-NetworkProfileCheck {
<#
.SYNOPSIS
Check network profile.
.DESCRIPTION
Check whether network profile is DomainAuthenticated. If not, wait for connection with another DC and restart the network adapter.
.EXAMPLE
Check network profile.
Start-NetworkProfileCheck
.EXAMPLE
Check network profile and leave a log behind.
Start-NetworkProfileCheck -LogPath C:\TEMP\NetworkProfileCheck.log
.FUNCTIONALITY
Support function.
#>
[CmdletBinding()]
Param(
    [Parameter( Mandatory = $True )]
    [String]$LogPath
)

Begin {
    # Get the first other DC.
    Write-VerboseLog -LogInfo 'Get another Domain Controller from AD.' -LogPath $LogPath
    (Get-ADDomain).ReplicaDirectoryServers | Where-Object { $PSItem -ne "$env:COMPUTERNAME.$env:USERDNSDOMAIN" } | Select-Object -First 1 -OutVariable DC | Out-Null
    Write-VerboseLog -LogInfo "Other DC: '$DC'." -LogPath $LogPath
} # End of Begin block.
Process {
    Write-VerboseLog -LogInfo 'Check if network category is DomainAuthenticated.' -LogPath $LogPath
    If ((Get-NetConnectionProfile).NetworkCategory -ne 'DomainAuthenticated') {
        Write-VerboseLog -LogInfo 'Network adapter profile is not domain authenticated.' -LogPath $LogPath
        
        Write-VerboseLog -LogInfo 'Wait for two minutes for the DC to settle down.' -LogPath $LogPath
        Start-Sleep -Seconds 120

        Write-VerboseLog -LogInfo "Do a preemptive network adapter restart." -LogPath $LogPath
        Get-NetAdapter -Physical | Restart-NetAdapter -Confirm:$False

        Write-VerboseLog -LogInfo 'Trying to connect to another DC.' -LogPath $LogPath
        While ((Test-NetConnection -ComputerName $DC -CommonTCPPort SMB).TcpTestSucceeded -ne $True) {
            Write-VerboseLog -LogInfo "SMB on $DC is unreachable, waiting for 10 seconds and trying again..." -LogPath $LogPath
            Start-Sleep -Seconds 10
        }

        Write-VerboseLog -LogInfo "SMB test on $DC was successful, restarting all physical network adapters." -LogPath $LogPath
        Get-NetAdapter -Physical | Restart-NetAdapter -Confirm:$False

        Write-VerboseLog -LogInfo "Network adapter was restarted. Current network profile: $((Get-NetConnectionProfile).NetworkCategory)" -LogPath $LogPath
    }
    Else {
        Write-VerboseLog -LogInfo 'Network adapter profile is domain authenticated.' -LogPath $LogPath
    } # End of network category check.
} # End of Process block.

} # End of Start-NetworkProfileCheck function.
