# A library of task scheduler related cmdlets.

## Register a new Scheduled Task.

### Prerequisite: Depending on your AD configuration, you may need to give the principal the ``Log on as batch job`` privilege in order to run scripts.

The following scheduled task follows DST and runs whether user is logged on or not.  

*NOTE: Always follow the principle of least privilege. Do not run the task at highest privilege if it's not necessary. The following example is for demonstration purposes.*

```powershell
$STA = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-Command "Get-Process"'
# OR
$STA = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoLogo -NonInteractive -NoProfile -File "C:\Scripts\DoStuff.ps1"'

$STT = New-ScheduledTaskTrigger -Daily -At 11am

$STP = New-ScheduledTaskPrincipal -UserId 'DOMAIN\svcaccount' -LogonType Password -RunLevel Highest

# The Win8 value does not indicate Windows 8. Microsoft just stopped creating new values after that and it now means the latest version of Windows in the context of scheduled tasks.
$STS = New-ScheduledTaskSettingsSet -Compatibility Win8

# Create a new scheduled task object which brings all the previously created objects together. Set a desired description for the scheduled task. This does NOT create the scheduled task.
$ST = New-ScheduledTask -Action $STA -Trigger $STT -Principal $STP -Settings $STS -Description 'Get processes.'

# This step creates the scheduled task.
## TaskPath assumes there is a folder named AdminTasks in task scheduler.
Register-ScheduledTask -TaskPath \AdminTasks\ -TaskName 'Processes' -InputObject $ST -User 'DOMAIN\svcaccount' -Password (Read-Host)

# NOTE: It is important to use Read-Host to enter the password. You will still enter it plain text, but it won't be stored in your PS ReadLine history. Scheduled Task does not accept a SecureString object as password.
```

## Modify the principal of and existing Scheduled Task.

Using the same logic/pattern, you can change other parts of the scheduled task, for example action, trigger, and settings.

```powershell
# Create a new Scheduled Task principal object, this time don't include the RunLevel parameter thus removing the higher privileges.
$STP = New-ScheduledTaskPrincipal -UserId 'DOMAIN\STUSER' -LogonType Password
# Commit the change to the existing scheduled task.
Set-ScheduledTask -TaskPath \AdminTasks\ -TaskName 'Processes' -Principal $STP -User 'DOMAIN\STUSER' -Password (Read-Host)
```

## Run scheduled task hourly.

When creating a new scheduled task, you can't provide fine-grained repetition details, so you have to modify an existing one.

```powershell
$ST = Get-ScheduledTask -TaskPath '\AdminTasks\' -TaskName 'Processes'
$ST.Triggers.Repetition.Interval = 'PT1H'

Set-ScheduledTask -TaskPath \AdminTasks\ -TaskName 'Processes' -User 'DOMAIN\STUSER' -Password (Read-Host) -Trigger $ST.Triggers
```

## Disable time zone synchronization.

Disabling this will ensure the scheduled task runs by the computer clock and by UTC. The tasks will always be run at the same time.

```powershell
# Set the start date and time in the past if modifying a scheduled task already in use.
$Date = Get-Date -Date '2024-04-29 16:00'

$STT = New-ScheduledTaskTrigger -Daily -At 4pm

# Set the new trigger start boundary date without the timezone part.
$STT.StartBoundary = (Get-Date -Date $Date -Format 'yyyy-MM-ddTHH:mm:ss')

# Commit the change to the existing scheduled task.
Set-ScheduledTask -TaskPath \AdminTasks\ -TaskName 'Processes' -User 'DOMAIN\STUSER' -Password (Read-Host) -Trigger $STT
```

## [How to create task scheduler folders.](../Functions/New-ScheduledTaskFolder.ps1)
