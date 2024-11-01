#Required -Version 5.1

# This script downloads the latest 64-bit NSClient++ MSI package, installs it and removes the binaries and scheduled task afterwards.
# In this example, a GPO was used to distribute the script and a scheduled task was registered that executed the script.

# Configure PS to use TLS1.2.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Set variables.
## Deployment source.
$DeploySource = 'C:\TEMP'

## Nagios server address.
$Server = ''

## Config file path.
$Config = 'C:\Program Files\NSClient++\nsclient.ini'

# NSClient++ deployment script.
## Get the listing of all the packages of the latest release.
$Latest = Invoke-RestMethod -Method Get -Uri 'https://api.github.com/repos/mickem/nscp/releases/latest'

## Sort out the 64-bit version MSI package for Windows.
$Asset = $Latest.assets | Where-Object name -imatch '^NSCP-.*-x64.msi$'

## Download the latest release.
Start-BitsTransfer -Source $Asset.browser_download_url -Destination "$DeploySource\"

## Install the client.
Start-Process -FilePath 'C:\Windows\System32\msiexec.exe' -ArgumentList "/qn /l* $DeploySource\InstallNagiosClient.log /i $DeploySource\$($Asset.name) ADDLOCAL=PythonScript,Plugins,MainProgram,FirewallConfig,DotNetPluginSupport,ProductFeature,CheckPlugins,NRPEPlugins,NSCPlugins,NSCAPlugin,PythonScriptPythonRuntime" -Wait

## Optional: Download the configuration file template from a git project.
#Start-BitsTransfer -Source https://git.repo/project/nsclient.ini -Destination 'C:\Program Files\NSClient++\'

## Optional: Decode password needed for the agent to connect to Nagios server.
#$Pass = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('*REPLACEWITHBASE64ENCODEDPASSWORD*'))

## Edit the configuration file to fill in the blanks.
### Import the current configuration file.
$INI = Get-Content -Path $Config

### Make modifications to the configuration file...
$mINI = $INI -replace 'allowed hosts = ',"allowed hosts = $Server"
# Optional: $mINI = $INI -replace 'allowed hosts = ',"allowed hosts = $Server" -replace 'password = ',"password = $Pass"

### and save it.
Set-Content -Path $Config -Value $mINI -Force

## Modify configuration file ACL to remove access to the default Users group.
$ACL = Get-Acl -Path $Config

### Disable inheritance, remove all ACEs.
$ACL.SetAccessRuleProtection($True, $False)

### Construct new ACEs.
$AdminACE  = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule('Administrators','FullControl','Allow')
$SystemACE = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule('SYSTEM','FullControl','Allow')

### Set and add constructed ACEs.
$ACL.SetAccessRule($AdminACE)
$ACL.AddAccessRule($SystemACE)

Set-Acl -Path $Config -AclObject $ACL

Restart-Service -Name nscp

## Get ports from the config file for the firewall cmdlet below.
[Array]$Ports = ($mINI | Select-String -Pattern ' \d{4,5}$').Matches.Value -replace '\s+', ''

## Make some restrictions to the default firewall rule created at NSClient installation or create a new rule if the rule was not created.
If (Get-NetFirewallRule -DisplayName 'NSClient++ Monitoring Agent*') {
    Set-NetFirewallRule -DisplayName 'NSClient++ Monitoring Agent' -Profile Domain -Protocol TCP -LocalPort $Ports -RemoteAddress $Server
}
Else {
    New-NetFirewallRule -Name 'NSClient-Monitoring-Agent-TCP-In' -DisplayName 'NSClient++ Monitoring Agent' -Description 'Inbound rule to allow Nagios server to communicate with the NSClient++ agent.' -Enabled True -Action Allow -Profile Domain -Protocol TCP -Direction Inbound -LocalPort $Ports -RemoteAddress $Server
}

#region Deployment cleanup.
## Installation package.
Remove-Item -Path $DeploySource\$($Asset.name) -Force

## Scheduled task.
Unregister-ScheduledTask -TaskName 'Install NSClient' -Confirm:$False

## Installation script.
Remove-Item -Path $MyInvocation.MyCommand.Source
#endregion
