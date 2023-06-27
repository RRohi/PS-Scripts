#Required -Version 5.1

# This script downloads the latest 64-bit Zabbix Agent 2 MSI package, installs it and removes the binaries and scheduled task afterwards. Logs remain by default.
# ValidateSet in this case assumes that you have separate Zabbix instances for live and test environments. Add or remove the environments as needed. Change the block starting from line 71 if you make changes to environments here.
# In this example, a GPO was used to distribute the script and a scheduled task was registered that executed the script.

[CmdletBinding()]
Param(
    [Parameter( Position = 0, Mandatory = $True )]
    [ValidateSet( 'Live', 'Test' )]
    [String]$Environment
)

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
    [Parameter(Position = 0, Mandatory = $True )]
    [String]$LogInfo,
    [Parameter(Position = 1, Mandatory = $False )]
    [String]$LogPath
)

Begin {
    # Get Current DateTime and store it in a variable.
    Get-Date -Format 'yyyyMMdd_HHmmss' -OutVariable DateStamp | Out-Null
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

} # End of Write-VerboseLog Function.

#region Variables.
## Verbose log path.
$DeployLogPath = 'C:\TEMP\ZabbixAgentDeploy.log'
## Deployment source.
$DeploySource = 'C:\TEMP'
Write-VerboseLog -LogInfo "DeploySource variable set to: '$DeploySource'." -LogPath $DeployLogPath
## Agent config file.
$Config = 'C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf'
Write-VerboseLog -LogInfo "Config variable set to: '$Config'." -LogPath $DeployLogPath

Write-VerboseLog -LogInfo "Environment parameter value: '$Environment'." -LogPath $DeployLogPath
## Server address.
If ($Environment -eq 'Live') {
    $Server = 'live.zabbix.instance'
    Write-VerboseLog -LogInfo "Server variable set to: '$Server'." -LogPath $DeployLogPath
}
ElseIf ($Environment -eq 'Test') {
    $Server = 'test.zabbix.instance'
    Write-VerboseLog -LogInfo "Server variable set to: '$Server'." -LogPath $DeployLogPath
}
Else {
    Write-VerboseLog -LogInfo 'Server variable missing. Exiting.' -LogPath $DeployLogPath
    Exit 1
}

## Construct a FQDN out of computer's hostname.
$FQDN = [System.Net.Dns]::GetHostByName(($env:COMPUTERNAME)).Hostname.ToLower()
Write-VerboseLog -LogInfo "FQDN variable set to: '$FQDN'." -LogPath $DeployLogPath

## Download latest 64-bit Zabbix agent 2 for Windows with OpenSSL.
### Set stable download branch.
$Stable = 'https://cdn.zabbix.com/zabbix/binaries/stable/'
Write-VerboseLog -LogInfo "Zabbix Agent stable branch address variable set to: '$Stable'." -LogPath $DeployLogPath
#endregion

# Configure PS to use TLS1.2.
Write-VerboseLog -LogInfo 'Setting network protocol to TLS1.2.' -LogPath $DeployLogPath
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#region Download the latest Zabbix Agent 2 64-bit MSI package.
## Get currently available stable versions.
Write-VerboseLog -LogInfo "Getting the initial product listing from: '$Stable'." -LogPath $DeployLogPath
$Request = Invoke-WebRequest -Method Get -UseBasicParsing -Uri $Stable

## Filter out links that are not agent versions, sort versions with latest version being the first.
Write-VerboseLog -LogInfo "Getting the latest middle version from: '$Stable'." -LogPath $DeployLogPath
$LatestMiddleVersion = $Request.Links | Where-Object href -match '^\d\.\d/$' | Sort-Object -Descending href | Select-Object -First 1 -ExpandProperty href
$MiddleVersionCount = ($Request.Links | Where-Object href -match '^\d\.\d/$').Count
If ($MiddleVersionCount -ge 1) {
    Write-VerboseLog -LogInfo "Latest middle version: '$LatestMiddleVersion'. Versions found: $MiddleVersionCount." -LogPath $DeployLogPath
}
Else {
    ### For some reason the query failed, exiting the script.
    Write-VerboseLog -LogInfo 'Unable to retrieve data from website. Exiting.' -LogPath $DeployLogPath
    Exit 1
}

## Get minor versions.
Write-VerboseLog -LogInfo "Getting the latest minor versions from: '$Stable$LatestMiddleVersion'." -LogPath $DeployLogPath
$MinorVersions = Invoke-WebRequest -Method Get -UseBasicParsing -Uri "$Stable$LatestMiddleVersion"

## Filter out links that are not agent versions, sort versions with latest version being the first.
Write-VerboseLog -LogInfo "Getting the latest minor version from: '$Stable$LatestMiddleVersion'." -LogPath $DeployLogPath
$LatestMinorVerion = $MinorVersions.Links | Where-Object href -match '^(\d(\.)?){3}/$' | Sort-Object -Descending href | Select-Object -First 1 -ExpandProperty href
Write-VerboseLog -LogInfo "Latest minor version: '$LatestMinorVerion'. Versions found: $(($MinorVersions.Links | Where-Object href -match '^(\d(\.)?){3}/$').Count)." -LogPath $DeployLogPath

## Get all the Zabbix agent packages for the latest version.
Write-VerboseLog -LogInfo "Getting all packages versions from: '$Stable$LatestMiddleVersion$LatestMinorVerion'." -LogPath $DeployLogPath
$Packages = Invoke-WebRequest -Method Get -UseBasicParsing -Uri "$Stable$LatestMiddleVersion$LatestMinorVerion"

## Find 64-bit Zabbix Agent 2 MSI package for Windows with OpenSSL support.
Write-VerboseLog -LogInfo "Getting the 64-bit Zabbix Agent 2 OpenSSL package versions from: '$Stable$LatestMiddleVersion$LatestMinorVerion'." -LogPath $DeployLogPath
$WinPackage = $Packages.Links | Where-Object href -like 'zabbix_agent2-*-amd64-openssl.msi' | Select-Object -ExpandProperty href
Write-VerboseLog -LogInfo "Latest package: '$WinPackage'." -LogPath $DeployLogPath

## Download the latest agent.
Write-VerboseLog -LogInfo "Downloading package '$WinPackage' to '$DeploySource'." -LogPath $DeployLogPath
Start-BitsTransfer -Source "$Stable$LatestMiddleVersion$LatestMinorVerion$WinPackage" -Destination "$DeploySource\$WinPackage"
#endregion

# Attempt to determine which kind of server this is.
Write-VerboseLog -LogInfo 'Looking for AD windows feature.' -LogPath $DeployLogPath
$AD = Get-WindowsFeature -Name AD-Domain-Services | Select-Object -ExpandProperty InstallState
Write-VerboseLog -LogInfo "AD windows feature status: '$AD'. (Not present if not Installed.)" -LogPath $DeployLogPath

Write-VerboseLog -LogInfo 'Looking for Certificate Services windows feature.' -LogPath $DeployLogPath
$CS = Get-WindowsFeature -Name AD-Certificate | Select-Object -ExpandProperty InstallState
Write-VerboseLog -LogInfo "Certificate services windows feature status: '$CS'. (Not present if null.)" -LogPath $DeployLogPath

Write-VerboseLog -LogInfo 'Looking for Exchange services.' -LogPath $DeployLogPath
$EX = Get-Service -Name MSExchangeServiceHost -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Status
Write-VerboseLog -LogInfo "Exchange service status: '$EX'. (Not present if null.)" -LogPath $DeployLogPath

Write-VerboseLog -LogInfo 'Looking for file server windows feature.' -LogPath $DeployLogPath
$FS = Get-WindowsFeature -Name FS-FileServer | Select-Object -ExpandProperty InstallState
Write-VerboseLog -LogInfo "File server windows feature status: '$FS'. (Not present if null.)" -LogPath $DeployLogPath

Write-VerboseLog -LogInfo 'Setting Servertype variable depending on which service or windows feature was found.' -LogPath $DeployLogPath
If ($AD -eq 'Installed') {
    $ServerType = 'Domain Controller'
}
ElseIf ($CS -eq 'Installed') {
    $ServerType = 'Certificate Authority'
}
ElseIf ($EX -eq 'Running') {
    $ServerType = 'Exchange'
}
ElseIf ($FS -eq 'Installed') {
    $ServerType = 'File Server'
}
Else {
    $ServerType = 'Generic'
}

Write-VerboseLog -LogInfo "ServerType variable set to: '$ServerType'. Generic, if server has no specified role or service present. This is used to assign a template for the host." -LogPath $DeployLogPath

# Install the client.
Write-VerboseLog -LogInfo "Installing '$DeploySource\$WinPackage'." -LogPath $DeployLogPath
Start-Process -FilePath 'C:\Windows\System32\msiexec.exe' -ArgumentList "/qn /l* $DeploySource\ZabbixAgentIntall.log /i $DeploySource\$WinPackage ADDLOCAL=ALL ENABLEPATH=1 LOGTYPE=file LOGFILE=""%INSTALLFOLDER%\zabbix_agentd.log"" HOSTNAME=$FQDN HOSTMETADATA=""Windows - $ServerType"" SERVER=$Server SERVERACTIVE=$Server" -Wait
Write-VerboseLog -LogInfo 'The package has been installed.' -LogPath $DeployLogPath

# Deployment cleanup.
## Installation package.
Write-VerboseLog -LogInfo "Deleting the '$DeploySource\$WinPackage' package." -LogPath $DeployLogPath
Remove-Item -Path "$DeploySource\$WinPackage" -Force

## Scheduled task.
Write-VerboseLog -LogInfo 'Removing scheduled task.' -LogPath $DeployLogPath
Unregister-ScheduledTask -TaskName 'Install Zabbix Agent 2' -Confirm:$False

## Installation script.
Write-VerboseLog -LogInfo 'Removing install script.' -LogPath $DeployLogPath
Remove-Item -Path $MyInvocation.MyCommand.Source
