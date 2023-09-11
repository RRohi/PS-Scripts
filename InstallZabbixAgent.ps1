#Required -Version 5.1

# This script downloads the latest 64-bit Zabbix Agent 2 MSI package, installs it, removes the binaries and scheduled task afterwards. Logs remain in the path specified in the DeployLogPath variable.
# ValidateSet in this case assumes that you have separate Zabbix instances for live and test environments. Add or remove the environments as needed. Additional changes need to be made in that case in the section where Server variable is being set.
# In this example, a GPO is being used to distribute the script to specified hosts and a scheduled task is being registered that executes the script at boot.

[CmdletBinding()]
Param(
    [Parameter( Position = 0, Mandatory = $True )]
    [ValidateSet( 'Live', 'Test' )]
    [String]$Environment
)

Function Write-VerboseLog {
<#
.SYNOPSIS
Logging Support Function.
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
Output will be formatted as: "DateTime - LogInfo"
.FUNCTIONALITY
Provides Verbose Information for debugging purposes.
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
## Agent script folder.
$Scripts = 'C:\Program Files\Zabbix Agent 2\scripts'
Write-VerboseLog -LogInfo "Scripts variable set to: '$Scripts'." -LogPath $DeployLogPath
## UserParameters folder.
$UserParams = 'C:\Program Files\Zabbix Agent 2\userparams'
Write-VerboseLog -LogInfo "UserParams variable set to: '$Scripts'." -LogPath $DeployLogPath

Write-VerboseLog -LogInfo "Environment parameter value: '$Environment'." -LogPath $DeployLogPath
## Set server variable based on the Environment parameter value.
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

# Construct a FQDN out of computer's hostname.
$FQDN = [System.Net.Dns]::GetHostByName(($env:COMPUTERNAME)).Hostname.ToLower()
Write-VerboseLog -LogInfo "FQDN variable set to: '$FQDN'." -LogPath $DeployLogPath

# Configure PS to use TLS1.2.
Write-VerboseLog -LogInfo 'Setting network protocol to TLS1.2.' -LogPath $DeployLogPath
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Download latest 64-bit Zabbix agent 2 for Windows with OpenSSL.
## Set stable download branch.
$Stable = 'https://cdn.zabbix.com/zabbix/binaries/stable/'
Write-VerboseLog -LogInfo "Zabbix Agent stable branch address variable set to: '$Stable'." -LogPath $DeployLogPath
#endregion

## Get currently available stable versions.
Write-VerboseLog -LogInfo "Getting the initial product listing from: '$Stable'." -LogPath $DeployLogPath
$Request = Invoke-WebRequest -Method Get -UseBasicParsing -Uri $Stable

## Filter out entries that are not agent versions, sort versions with latest version being the first.
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

## Filter out entries that are not agent versions, sort versions with latest version being the first.
Write-VerboseLog -LogInfo "Getting the latest minor version from: '$Stable$LatestMiddleVersion'." -LogPath $DeployLogPath
$LatestMinorVerion = $MinorVersions.Links | Where-Object href -match '^(\d(\.)?){3}/$' | Sort-Object -Descending href | Select-Object -First 1 -ExpandProperty href
Write-VerboseLog -LogInfo "Latest minor version: '$LatestMinorVerion'. Versions found: $(($MinorVersions.Links | Where-Object href -match '^(\d(\.)?){3}/$').Count)." -LogPath $DeployLogPath

# Check if middle version of Zabbix is already installed. Skip install, if yes.
If (!(Get-CimInstance -ClassName Win32_Product -Filter "Caption like 'Zabbix Agent%' AND Version like '$($LatestMiddleVersion -replace '/', $null)%'")) {
    ## Get all the Zabbix agent packages for the latest version.
    Write-VerboseLog -LogInfo "Getting all packages versions from: '$Stable$LatestMiddleVersion$LatestMinorVerion'." -LogPath $DeployLogPath
    $Packages = Invoke-WebRequest -Method Get -UseBasicParsing -Uri "$Stable$LatestMiddleVersion$LatestMinorVerion"

    ## Filter out Zabbix agent 2 MSI package for 64-bit Windows with OpenSSL support.
    Write-VerboseLog -LogInfo "Getting the 64-bit Zabbix Agent 2 OpenSSL package versions from: '$Stable$LatestMiddleVersion$LatestMinorVerion'." -LogPath $DeployLogPath
    $WinPackage = $Packages.Links | Where-Object href -like 'zabbix_agent2-*-amd64-openssl.msi' | Select-Object -ExpandProperty href
    Write-VerboseLog -LogInfo "Latest package: '$WinPackage'." -LogPath $DeployLogPath

    ## Download the latest agent.
    Write-VerboseLog -LogInfo "Downloading package '$WinPackage' to '$DeploySource'." -LogPath $DeployLogPath
    Start-BitsTransfer -Source "$Stable$LatestMiddleVersion$LatestMinorVerion$WinPackage" -Destination "$DeploySource\$WinPackage"

    ## Attempt to determine which kind of server this is.
    Write-VerboseLog -LogInfo 'Looking for AD windows feature.' -LogPath $DeployLogPath
    $AD = Get-WindowsFeature -Name AD-Domain-Services | Select-Object -ExpandProperty InstallState
    Write-VerboseLog -LogInfo "AD windows feature status: '$AD'. (Not present if not installed.)" -LogPath $DeployLogPath

    Write-VerboseLog -LogInfo 'Looking for Certificate Services windows feature.' -LogPath $DeployLogPath
    $CS = Get-WindowsFeature -Name AD-Certificate | Select-Object -ExpandProperty InstallState
    Write-VerboseLog -LogInfo "Certificate services windows feature status: '$CS'. (Not present if not installed.)" -LogPath $DeployLogPath

    Write-VerboseLog -LogInfo 'Looking for Exchange services.' -LogPath $DeployLogPath
    $EX = Get-Service -Name MSExchangeServiceHost -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Status
    Write-VerboseLog -LogInfo "Exchange service status: '$EX'. Not present if null." -LogPath $DeployLogPath

    Write-VerboseLog -LogInfo 'Looking for file server windows feature.' -LogPath $DeployLogPath
    $FS = Get-WindowsFeature -Name FS-Resource-Manager | Select-Object -ExpandProperty InstallState
    Write-VerboseLog -LogInfo "File server windows feature status: '$FS'. (Not present if not installed.)" -LogPath $DeployLogPath
    
    Write-VerboseLog -LogInfo 'Looking for print server windows feature.' -LogPath $DeployLogPath
    $PS = Get-WindowsFeature -Name Print-Server | Select-Object -ExpandProperty InstallState
    Write-VerboseLog -LogInfo "Print server windows feature status: '$PS'. (Not present if not installed.)" -LogPath $DeployLogPath

    Write-VerboseLog -LogInfo 'Looking for SQL Server services.' -LogPath $DeployLogPath
    $SQL = Get-Service -Name MSSQLSERVER -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Status
    Write-VerboseLog -LogInfo "MSSQLSERVER service status: '$SQL'. Not present if null." -LogPath $DeployLogPath

    Write-VerboseLog -LogInfo 'Setting Servertype variable depending on which service or windows feature was found.' -LogPath $DeployLogPath
    ## Assigning server type-specific value to the ServerType variable.
    If ($AD -eq 'Installed') {
    $ServerType = 'Domain Controller'
    }
    ElseIf ($CS -eq 'Installed') {
        $ServerType = 'Certificate Authority'
    }
    ElseIf ($EX -eq 'Running') {
        $ServerType = 'Exchange'
    }
    ElseIf ($SQL -eq 'Running') {
        $ServerType = 'SQL Server'
    }
    ElseIf ($PS -eq 'Installed') {
        $ServerType = 'Print Server'
    }
    ### If you have servers where file server windows role has been installed that aren't actually file servers, add the names in the inotmatch regex string below. Separate values with |
    ElseIf ($FS -eq 'Installed' -and $env:COMPUTERNAME -inotmatch '') {
        $ServerType = 'Fileserver'
    }
    Else {
        $ServerType = 'Basic'
    }

    Write-VerboseLog -LogInfo "ServerType variable set to: '$ServerType'. (Basic if server has no specified role or service present.)" -LogPath $DeployLogPath

    ## Install the client.
    Write-VerboseLog -LogInfo "Installing '$DeploySource\$WinPackage'." -LogPath $DeployLogPath
    Start-Process -FilePath 'C:\Windows\System32\msiexec.exe' -ArgumentList "/qn /l* $DeploySource\ZabbixAgentIntall.log /i $DeploySource\$WinPackage ADDLOCAL=ALL ENABLEPATH=1 LOGTYPE=file LOGFILE=""%INSTALLFOLDER%\logs\zabbix_agentd.log"" HOSTNAME=$FQDN HOSTMETADATA=""Windows - $ServerType"" SERVER=$Server SERVERACTIVE=$Server" -Wait
    Write-VerboseLog -LogInfo 'The package has been installed.' -LogPath $DeployLogPath

    ## Deployment cleanup.
    ### Installation package.
    Write-VerboseLog -LogInfo "Deleting the '$DeploySource\$WinPackage' package." -LogPath $DeployLogPath
    Remove-Item -Path "$DeploySource\$WinPackage" -Force

    ### Scheduled task.
    Write-VerboseLog -LogInfo 'Removing scheduled task.' -LogPath $DeployLogPath
    Unregister-ScheduledTask -TaskName 'Install Zabbix Agent 2' -Confirm:$False

    ### Installation script.
    Write-VerboseLog -LogInfo 'Removing install script.' -LogPath $DeployLogPath
    Remove-Item -Path $MyInvocation.MyCommand.Source

    ## Check if scripts directory exists.
    If (!(Test-Path -Path $Scripts)) {
        ### Create it, if not.
        New-Item -Path $Scripts -ItemType Directory
    }

    ## Check if userparams directory exists.
    If (!(Test-Path -Path $UserParams)) {
        ### Create it, if not.
        New-Item -Path $UserParams -ItemType Directory
    }
    
    ## Download the following files from Bitbucket.
    ### Certificate retrieval script for Windows-based hosts.
    Start-BitsTransfer -Source 'https://git.corp.com/projects/repos/scripts/raw/Get-Certificate.ps1' -Destination $Scripts
    ### Zabbix user parameter configuration file.
    Start-BitsTransfer -Source 'https://git.corp.com/projects/repos/confs/raw/zabbix_userparams/zabbix_agent2.userparams.conf' -Destination $UserParams

    ## The following changes will allow Zabbix to query files/certificates/registry.
    ### Import the configuration file.
    $ImportConfig = Get-Content -Path $Config
    Write-VerboseLog -LogInfo 'Imported the configuration file.' -LogPath $DeployLogPath

    #### Modify the configuration file.
    ##### Get the line number of the UnsafeParameters key.
    $UnsafeParamLN = ( $ImportConfig | Select-String -Pattern '# UnsafeUserParameters=0' ).LineNumber
    Write-VerboseLog -LogInfo "'UnsafeParameters' line number: '$UnsafeParamLN'." -LogPath $DeployLogPath

    ##### Get the next line from the UnsafeParameters key.
    $StepAhead = $UnsafeParamLN + 1
    Write-VerboseLog -LogInfo "Line number after '# UnsafeUserParameters=0': '$StepAhead'." -LogPath $DeployLogPath

    ##### Add the UnsafeUserParameters key.
    $ImportConfig[$StepAhead-1] = "`r`nUnsafeUserParameters=1`r`n"
    Write-VerboseLog -LogInfo "Added 'UnsafeUserParameters=1' to the configuration file." -LogPath $DeployLogPath

    ##### Get the line number of the optional include key.
    $OptionalIncludeLN = ( $ImportConfig | Select-String -Pattern 'Include=C:\\Program Files\\Zabbix Agent 2\\zabbix_agent2\.d\\' ).LineNumber
    Write-VerboseLog -LogInfo "'UnsafeParameters' line number: '$OptionalIncludeLN'." -LogPath $DeployLogPath

    ##### Get the next line from the optional include key.
    $StepAhead = $OptionalIncludeLN + 1
    Write-VerboseLog -LogInfo "Line number after 'Include=C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\': '$StepAhead'." -LogPath $DeployLogPath

    ##### Add the userparameters configuration file path.
    $ImportConfig[$StepAhead-1] = "Include=$UserParams\zabbix_agent2.userparams.conf`r`n"
    Write-VerboseLog -LogInfo "Added 'Include=$UserParams\zabbix_agent2.userparams.conf' to the configuration file." -LogPath $DeployLogPath

    ##### Get the line number of the userparameterdir key.
    $UserParamDirLN = ( $ImportConfig | Select-String -Pattern '# UserParameterDir=' ).LineNumber
    Write-VerboseLog -LogInfo "'UserParameterDir' line number: '$UserParamDirLN'." -LogPath $DeployLogPath

    ##### Get the next line from the userparameterdir key.
    $StepAhead = $UserParamDirLN + 1
    Write-VerboseLog -LogInfo "Line number after '# UserParameterDir=': '$StepAhead'." -LogPath $DeployLogPath

    ##### Add the UserParameterDir key.
    $ImportConfig[$StepAhead-1] = "`r`nUserParameterDir=C:\Program Files\Zabbix Agent 2\scripts\`r`n"
    Write-VerboseLog -LogInfo "Added 'UserParameterDir=C:\Program Files\Zabbix Agent 2\scripts\' to the configuration file." -LogPath $DeployLogPath

    ### Save the modified configuration file.
    Set-Content -Path $Config -Value $ImportConfig -Force
    Write-VerboseLog -LogInfo 'Saved the modified configuration file.' -LogPath $DeployLogPath

    ## Restart the agent.
    Restart-Service -Name 'Zabbix Agent 2'
    Write-VerboseLog -LogInfo 'Restarted ''Zabbix Agent 2'' service.' -LogPath $DeployLogPath
}
Else {
    ## Agent within the current major version already exists.
    Write-VerboseLog -LogInfo 'Current Zabbix Agent already exists.' -LogPath $DeployLogPath
}
