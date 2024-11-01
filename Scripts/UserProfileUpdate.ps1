# Requires AD RSAT to be installed on local machine! Otherwise you need to get the SID from AD and do the remap manually.
# Update the user profile after a name change in AD.

## Create a hashtable with the old and new name.
$NameChange = @{ Old = 'old.account'; New = 'new.account' }

## Rename the user account folder.
Rename-Item -Path "C:\Users\$($NameChange['Old'])" -NewName "C:\Users\$($NameChange['New'])"

## Remap user profile to the new account folder location.
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$((Get-ADUser -Identity $NameChange['Old'] -Properties SID).SID)" -Name ProfileImagePath -Value "C:\Users\$($NameChange['New'])"
