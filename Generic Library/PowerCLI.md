# A library of PowerCLI-related cmdlets.

## Disable certificate check when self-signed certificate is being used in vCenter.
```powershell
Set-PowerCLIConfiguration -Scope AllUsers -InvalidCertificateAction Ignore
```

## Disable CEIP.
```powershell
Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCeip $False
```

## Connect to vCenter.
```powershell
Connect-VIServer -Server vcenter.domain.tld
```

## Query Windows VMs that have less than 2GB memory.
```powershell
Get-VM | Where-Object { $PSItem.MemoryGB -le 2 -and $PSItem.Guest -like "*Windows Server*" } | Format-Table -AutoSize
```

## Query running VMs that have old VMTools and don't have 'exchange' in their names.
```powershell
Get-VM | Where-Object { $PSItem.ExtensionData.Guest.ToolsStatus -ne 'ToolsOk' -and $PSItem.Name -notlike 'exchange*' -and $PSItem.PowerState -eq 'PoweredOn' } | Format-Table -AutoSize
```

## Query running Windows VMs that have old VMTools, have 'test-' in their names and don't have 'exchange' in their names.
```powershell
Get-VM | Where-Object { $PSItem.Guest -like "*Windows Server*" -and $PSItem.Name -like "test-*" -and $PSItem.ExtensionData.Guest.ToolsStatus -ne 'ToolsOk' -and $PSItem.Name -notlike 'exchange*' -and $PSItem.PowerState -eq 'PoweredOn' } | Format-Table -AutoSize
```

## Update VMTools on running Windows VMs that don't have 'exchange' in their names.
```powershell
Get-VM | Where-Object { $PSItem.Guest -like "*Windows Server*" -and $PSItem.ExtensionData.Guest.ToolsStatus -ne 'ToolsOk' -and $PSItem.Name -notlike 'exchange*' -and $PSItem.PowerState -eq 'PoweredOn' } | Update-Tools
```

## Get VM with all its properties.
```powershell
$vm = Get-VM -Name *vmname* | Select-Object *
```

## Get VM tags.
```powershell
Get-TagAssignment -Entity $vm.Name
```
