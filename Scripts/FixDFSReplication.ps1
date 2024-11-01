# DC with correct GPOs/Source: DC01.
# DC with incorrect GPOs/Target: DC02.

## Disable DC01 as Replication Partner in AD and set it as Primary Member.
Get-ADObject -Identity "CN=SYSVOL Subscription,CN=Domain System Volume,CN=DFSR-LocalSettings,CN=DC01,OU=Domain Controllers,DC=Domain,DC=com" -Properties msDFSR-Enabled, msDFSR-Options | Set-ADObject -Replace @{ 'msDFSR-Enabled' = $False; 'msDFSR-Options' = 1 }

## Disable DC02 as Replication Partner in AD.
Get-ADObject -Identity "CN=SYSVOL Subscription,CN=Domain System Volume,CN=DFSR-LocalSettings,CN=DC02,OU=Domain Controllers,DC=Domain,DC=com" -Properties msDFSR-Enabled | Set-ADObject -Replace @{ 'msDFSR-Enabled' = $False }

## Replicate everything from DC01 to DC02. If you want to know, what /AdeP does, type: repadmin.exe /syncall /?
repadmin /syncall /AdeP

## Stop DFS Replication Service on DC01.
Stop-Service -Name DFSR

## Stop DFS Replication Service on DC02.
Invoke-Command -ComputerName DC02 -ScriptBlock { Stop-Service -Name DFSR }

## Start DFS Replication Service on DC01.
Start-Service -Name DFSR

## Enable DC01 as Replication Partner in AD.
Get-ADObject -Identity "CN=SYSVOL Subscription,CN=Domain System Volume,CN=DFSR-LocalSettings,CN=DC01,OU=Domain Controllers,DC=Domain,DC=com" -Properties msDFSR-Enabled | Set-ADObject -Replace @{ 'msDFSR-Enabled' = $True }

## Replicate everything from DC01 to DC02.
repadmin /syncall /AdeP

## Trigger sync with DFS Replication Diagnostics Utility on DC01. If you want to know, what PollAD does, type: dfsrdiag.exe /?
.\dfsrdiag.exe PollAD

## Start DFS Replication Service on DC02.
Invoke-Command -ComputerName DC02 -ScriptBlock { Start-Service -Name DFSR }

## Enable DC02 as Replication Partner in AD.
Get-ADObject -Identity "CN=SYSVOL Subscription,CN=Domain System Volume,CN=DFSR-LocalSettings,CN=DC02,OU=Domain Controllers,DC=Domain,DC=com" -Properties msDFSR-Enabled | Set-ADObject -Replace @{ 'msDFSR-Enabled' = $True }

## Trigger sync with DFS Replication Diagnostics Utility on DC02.
Invoke-Command -ComputerName DC02 -ScriptBlock { & dfsrdiag.exe PollAD }

## Wait a couple of minutes, or more, depending on the amount to replicate. It will not be instant.
