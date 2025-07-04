# A library of EventLog-related cmdlets.

## Find events where user failed to log in in the past three days.

```powershell
# Turn the clock back three days.
$Start = (Get-Date).AddDays(-3)

# Query events.
Get-WinEvent -FilterHashtable @{ ID = 4625; LogName = 'Security'; StartTime = $Start; Data = 'user.name' }
```

## Look for who installed/uninstalled something. Translate user SID to readable username.

```powershell
# Application installed events.
Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ID = 11707 } -MaxEvents 5 | Select-Object TimeCreated, Id, @{ Name = 'Owner'; Expression = { ConvertFrom-SIDToNT -SID $PSItem.UserId } }, Message

# Application uninstalled events.
Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ID = 11724 } -MaxEvents 5 | Select-Object TimeCreated, Id, @{ Name = 'Owner'; Expression = { ConvertFrom-SIDToNT -SID $PSItem.UserId } }, Message
```

## Export an event log.
```powershell
Invoke-CimMethod -Query 'SELECT * FROM Win32_NTEventlogFile WHERE LogfileName = "Security"' -MethodName BackupEventlog -Arguments @{ ArchiveFileName = 'C:\TEMP\security.evtx' }
```
