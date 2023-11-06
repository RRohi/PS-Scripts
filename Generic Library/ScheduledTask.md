# A library of task scheduler related cmdlets.

## Register new Scheduled Task where svcaccount$ is a Group Managed Service Account ([gMSA](./Unsorted.md#create-a-new-group-managed-service-account-gmsa)).
```powershell
# Create the new action variable.
$STA = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-Command "Get-Process"'
# Create the new trigger variable.
$STT = New-ScheduledTaskTrigger -Daily -At 11am
# Create the new principal variable with highest privileges.
$STP = New-ScheduledTaskPrincipal -UserId 'DOMAIN\svcaccount$' -LogonType Password -RunLevel Highest
# Create the setting variable setting the compatibility version to the latest Windows version. The Win8 value does not indicate Windows 8. Microsoft just stopped creating new values after that and it now indicates the latest version.
$STS = New-ScheduledTaskSettingsSet -Compatibility Win8
# Create the new task variable using all the previous variables setting a desired description for the scheduled task. This does NOT create the scheduled task yet.
$STD = New-ScheduledTask -Action $STA -Trigger $STT -Principal $STP -Settings $STS -Description 'Get processes.'
# Register the scheduled task. This step creates scheduled task.
Register-ScheduledTask -TaskName 'Processes' -TaskPath \AdminTasks\ -InputObject $STD -User 'DOMAIN\svcaccount$'
```

## Modify the principal of and existing Scheduled Task.
### Using the same logic/pattern, you can change other parts of the scheduled task, for example action, trigger, and settings.
```powershell
# Get the Process scheduled task from AdminTasks folder.
$ST = Get-ScheduledTask -TaskPath '\AdminTasks\' -TaskName Processes
# Create a new principal variable with a new gMSA.
$STP = New-ScheduledTaskPrincipal -UserId 'DOMAIN\SVC.TS$' -RunLevel Highest -LogonType Password
# Set the created principal as the new principal in the $ST object.
$ST.Principal = $STP
# Commit the change to the existing scheduled task.
Set-ScheduledTask -InputObject $ST
```

## [How to create task scheduler folders.](../Functions/New-ScheduledTaskFolder.ps1)
