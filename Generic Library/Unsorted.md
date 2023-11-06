# A library of random cmdlets. Examples can be moved to their dedicated markdown file when more than a couple of examples have accumulated here.

## Get printer's SDDL and convert it to a readable object.
```powershell
Get-Printer -Name printername -Full | Select-Object -ExpandProperty PermissionSDDL | ConvertFrom-SddlString
```

## Get certificate information from all of the certificates in the specified path.
```powershell
Get-ChildItem -Path Cert:\LocalMachine\My | Select-Object -Property `
    @{ Name = 'Issuer';    Expression = { $PSItem.Issuer.Split(',')[0] } },
    @{ Name = 'Issued';    Expression = { $PSItem.NotBefore } },
    @{ Name = 'Expires';   Expression = { $PSItem.NotAfter } },
    HasPrivateKey, ThumbPrint, SerialNumber,
    @{ Name = 'Algorithm'; Expression = { $PSItem.SignatureAlgorithm.FriendlyName } },
    @{ Name = 'Key Size';  Expression = { $PSItem.PublicKey.Key.KeySize } } | Sort-Object Expires -Descending | Format-Table -AutoSize
```

## Remove unnecessary stuff from a clean Windows Server installation.
```powershell
Get-WindowsOptionalFeature -Online | Where-Object { $PSItem.State -eq 'Enabled' -and $PSItem.FeatureName -imatch 'V2|print|Explorer|Media|XPS' -and $PSItem.FeatureName -notlike '*Premium*' } | ForEach-Object { Disable-WindowsOptionalFeature -Online -Feature $PSItem.FeatureName -NoRestart }
Get-WindowsCapability -Online | Where-Object { $PSItem.State -eq 'Installed' -and $PSItem.Name -imatch 'Steps|Explorer|Hand|OCR|Speech|Math|Media|Paint|Word' } | Remove-WindowsCapability -Online
```

## Display local disk information.
```powershell
Get-CimInstance -Class CIM_LogicalDisk | Where-Object DriveType -eq 3 | Select-Object -Property `
    Name, VolumeName,
    @{ Name = 'Size';       Expression = { $(($PSItem.size / 1GB).ToString('#GB')) } },
    @{ Name = "Free Space"; Expression = { $(($PSItem.freespace / 1GB).ToString('#GB')) } },
    FileSystem
```

## Display total memory.
```powershell
((Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).Sum / 1GB).ToString('#GB')
```

## Create a new group Managed Service Account (gMSA).
```powershell
New-ADServiceAccount -Name 'SVC-ST$' -Description 'Service Account for SRV1 server high-privileged Scheduled Tasks.' -DisplayName 'Scheduled Task Service Account - High' -DNSHostName 'SRV1.DOMAIN.TLD' -Enabled $True -Path 'OU=Service Accounts,DC=DOMAIN,DC=TLD' -PrincipalsAllowedToRetrieveManagedPassword SRV1$ -SamAccountName 'SVC-ST'
```

## Test the gMSA on the SRV1 server and install it if the test succeeds.
```powershell
Test-ADServiceAccount -Identity 'SVC-ST$'
Install-ADServiceAccount -Identity 'SVC-ST$'
```

## Create a custom multi-columned table in PowerShell.
```powershell
# Create an empty array.
$Table = @()
# Add a custom PS Object into the array.
$Table += [PSCustomObject]@{ column1 = 'data'; column2 = 'data2'; column3 = 'data3' }
```

## Change certificate of the WinRM HTTPS listener.
Set-WSManInstance -ResourceURI winrm/config/Listener -SelectorSet @{ Address = '*'; Transport = 'HTTPS' } -ValueSet @{ CertificateThumbprint = 'thumbprint' }
