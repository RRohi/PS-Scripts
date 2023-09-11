# ScriptsAndStuff
#### Helpful script(let)s for daily administration.

* FixDFSReplication.ps1 - When you find that GPO versions mismatch between DCs.
* InstallNSClient.ps1 - Downloads the latest NSClient++, installs it, makes changes to the configuration files, protects the configuration file from regular users and creates new firewall rules for the client. NSClient++ is used to monitor Windows hosts with Nagios.
* InstallZabbixAgent.ps1 - Downloads the latest 64-bit Zabbix Agent 2, tries to determine which role the server plays, based on installed roles and services. This is used to assign a template to the host. This assumes that specifc templates are already present in Zabbix. The agent gets installed with the template name as hostmetadata.
* NetworkAdapterProfileCheck.ps1 - Windows Server 2012 R2 VMs boot up before the network is ready and the network category will be set as either Private or Public. This script, when added to a scheduled task (at boot), is supposed to help fix that. If the network category is incorrect at boot, it will wait for a successful connection to specified DC and then restarts the network adapter after which the network category profile should be domain authenticated. Not extensively tested.
