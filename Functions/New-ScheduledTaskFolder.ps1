Function New-ScheduledTaskFolder {
<#
.SYNOPSIS
Create new Scheduled Task folder.
.DESCRIPTION
Create a new folder in Task Scheduler.
.EXAMPLE
Create a folder named Network in the root folder.
New-ScheduledTaskFolder -FolderName 'Network'
.EXAMPLE
Create a folder named Users in a custom folder.
New-ScheduledTaskFolder -TaskPath '\Daily Tasks\Update' -FolderName 'Users'
.PARAMETER TaskPath
Specify path for the folder.
.PARAMETER FolderName
Sepcify name for the folder.
.NOTES
https://devblogs.microsoft.com/scripting/use-powershell-to-create-scheduled-tasks-folders/
.FUNCTIONALITY
Task Scheduler support function.
#>
[CmdletBinding()]
Param(
    [Parameter( Position = 0, Mandatory = $False, HelpMessage = 'Provide path for the folder.' )]
    [ValidatePattern('^\\.+(\\.+)?$')]
    [String]$TaskPath,
    [Parameter( Position = 1, Mandatory = $True, HelpMessage = 'Provide name for the folder.' )]
    [String]$FolderName
)

# Create new Task Scheduler service object.
$TS = New-Object -ComObject Schedule.Service

# Connect to the created Task Scheduler object.
$TS.Connect()

# Check if TaskPath was specified.
If ($null -eq $TaskPath) {
    ## Create the new folder in the root folder.
    $TSPath = $TS.GetFolder('\')
}
Else {
    ## Create the new folder in the specified path.
    $TSPath = $TS.GetFolder("$TaskPath")
}

# Create the new folder.
$TSPath.CreateFolder("$FolderName")

} # End of New-ScheduledTaskFolder function.
