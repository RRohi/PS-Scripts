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

## Remove unnecessary stuff from a clean Windows Server installation. The crap to be removed differs in Windows from version to version.

```powershell
Get-WindowsOptionalFeature -Online | Where-Object { $PSItem.State -eq 'Enabled' -and $PSItem.FeatureName -imatch 'V2|print|Explorer|Media|XPS' -and $PSItem.FeatureName -notlike '*Premium*' } | ForEach-Object { Disable-WindowsOptionalFeature -Online -Feature $PSItem.FeatureName -NoRestart }
Get-WindowsCapability -Online | Where-Object { $PSItem.State -eq 'Installed' -and $PSItem.Name -imatch 'Steps|Explorer|Hand|OCR|Speech|Math|Media|Paint|Word' } | Remove-WindowsCapability -Online
```

## Display local disk information.

```powershell
Get-Disk -OutVariable Disks | Out-Null
$Output = ForEach ($Disk in $Disks) {
    $Partitions = Get-Partition -DiskNumber $Disk.DiskNumber | Where-Object Type -eq 'Basic'
    $Volumes    = $Partitions | Get-Volume
    $FreeSpace  = Get-CimInstance -Class CIM_LogicalDisk | Where-Object DeviceID -eq "$($Partitions | Select-Object -ExpandProperty DriveLetter):"
    
    $Disk | Select-Object -Property `
        @{ Name = 'Disk #';          Expression = { $PSItem.DiskNumber } },
        @{ Name = 'Disk name';       Expression = { $PSItem.FriendlyName } },
        @{ Name = 'Status';          Expression = { $PSItem.OperationalStatus } },
        @{ Name = 'Bus Type';        Expression = { $PSItem.BusType } },
        @{ Name = 'Drive Letter';    Expression = { $Partitions | Select-Object -ExpandProperty DriveLetter } },
        @{ Name = 'Drive Name';      Expression = { $Volumes | Select-Object -ExpandProperty FileSystemLabel } },
        @{ Name = 'File System';     Expression = { $Volumes | Select-Object -ExpandProperty FileSystem } },
        @{ Name = 'Boot drive';      Expression = { $PSItem.IsBoot } },
        @{ Name = 'System drive';    Expression = { $PSItem.IsSystem } },
        @{ Name = 'Partition Style'; Expression = { $PSItem.PartitionStyle } },
        @{ Name = 'Allocated space'; Expression = { ($PSItem.AllocatedSize / 1GB).ToString( '# GB' ) } },
        @{ Name = 'Total space';     Expression = { ($PSItem.Size / 1GB).ToString( '# GB' ) } },
        @{ Name = 'Free space';      Expression = { (($FreeSpace | Select-Object -ExpandProperty FreeSpace) / 1GB).ToString( '# GB' ) } }
}

$Output | Format-Table -Property *
```

## Display total memory.

```powershell
((Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).Sum / 1GB).ToString('# GB')
```

## Create a custom multi-columned table in PowerShell.

```powershell
# Create an empty array.
$Table = @()
# Add a custom PS Object into the array.
$Table += [PSCustomObject]@{ column1 = 'data'; column2 = 'data2'; column3 = 'data3' }
```

## Create a new WinRM HTTPS listener.

In this scenario, you have a certificate template for WinRM in ADCS, which you have to request if you didn't have it already. Hostname has to match the CN of the certificate.

```powershell
# Request a new certificate from ADCS for WinRM.
$NewCert = Get-Certificate -Template 'WindowsRemoteManagementTemplate' -CertStoreLocation Cert:\LocalMachine\My\

# Create a new HTTPS listener using the requested certificate.
New-WSManInstance -ResourceURI 'winrm/config/Listener' -SelectorSet @{ Transport = 'HTTPS'; Address = '*' } -ValueSet @{ Hostname = "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN)"; CertificateThumbprint = "$($NewCert.Certificate.Thumbprint)" }

# Restart the WinRM service.
Restart-Service -Name WinRM
```

## Change certificate of the WinRM HTTPS listener.

```powershell
Set-WSManInstance -ResourceURI winrm/config/Listener -SelectorSet @{ Address = '*'; Transport = 'HTTPS' } -ValueSet @{ CertificateThumbprint = 'thumbprint' }
```

## Uninstall an application using CIM.

```powershell
# A single application.
$App = Get-CimInstance -Query 'SELECT * FROM Win32_Product WHERE Name = "ExactApplicationName"'

## Uninstall the app.
Invoke-CimMethod -InputObject $App -MethodName Uninstall

# Multiple applications.
$Apps = Get-CimInstance -Query 'SELECT * FROM Win32_Product WHERE Name = "PartialApplicationName"'

## Uninstall the apps.
ForEach ($Instance in $Apps) {
    Invoke-CimMethod -InputObject $Instance -MethodName Uninstall
}
```

## AD group-managed service account (gMSA).

### Create the gMSA on a DC.

```powershell
New-ADServiceAccount -Name 'serviceaccountname' -Description 'Descriptive text.' -DisplayName 'Display name' -DNSHostName 'server01.domain.tld' -Enabled $True -Path 'OU=Service Accounts,OU=Accounts,DC=domain,DC=tld' -PrincipalsAllowedToRetrieveManagedPassword SERVER01$ -SamAccountName 'serviceaccountname'
```

### Test the service account on the SERVER01.
```powershell
Test-ADServiceAccount -Identity serviceaccountname$
```

### If the test was successful, install it on the SERVER01.
```
Install-ADServiceAccount -Identity serviceaccountname$
```
