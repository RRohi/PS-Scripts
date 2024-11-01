# This script collects all the VMs from a Hyper-V host and outputs a JSON report with attributes listed below.

Get-VM | Select-Object * -OutVariable VMs | Out-Null

# Create an empty hashtable array for the output.
$VMsArrayHT = (@())

ForEach ($VM in $VMs) {
    ## String manipulation.
    ### The following attributes output non-desirable data without forcing them into strings first.
    [String] $State = $VM.State
    [String] $VMID  = $VM.VMId
    
    ## Network.
    ### Get IP addresses of all network adapters except the hearbeat ones.
    $VM.NetworkAdapters | Select-Object -ExpandProperty IPAddresses -OutVariable VMNIC | Out-Null

    ### Extract IPv4 addresses.
    $NICs = $VMNIC -imatch '^([1-9]\d?|1\d{2}|2([0-4]\d|5[0-5]))\.((0|\d{1,2}|1\d{2}|2([0-4]\d|5[0-5]))\.){2}([1-9]\d?|1\d{2}|2([0-4]\d|5[0-5]))$'

    ## VM info.
    ### Get detailed information about the VM.
    $VMDetails = Get-CimInstance -Namespace 'root\virtualization\v2' -Query "SELECT * FROM Msvm_ComputerSystem WHERE ElementName = '$($VM.Name)'"
    
    ### Get associated information of the VM.
    Get-CimAssociatedInstance -InputObject $VMDetails | Where-Object GuestOperatingSystem -ne $null -OutVariable VMInfo | Out-Null

    ## Disks.
    $VMDisks = $VM.HardDrives | Get-VHD
    
    ### Create an empty hashtable array for VM disks.
    $DiskArrayHT = (@{})
    
    ## Iterate the disks and add disk name and its total size to the disks hashtable array.
    ForEach ($Disk in $VMDisks) {
        $DiskArrayHT += @{ $($Disk.Path -split '\\')[-1] = $Disk.Size }
    }

    $VMStructure = $VM | Select-Object `
        @{ Name = 'VMHost';      Expression = { "$env:COMPUTERNAME.$env:USERDNSDOMAIN" } },
        @{ Name = 'VMHostname';  Expression = { $env:COMPUTERNAME } },
        @{ Name = 'VMCoreCount'; Expression = { $PSItem.ProcessorCount } },
        @{ Name = 'VMMemory';    Expression = { $PSItem.MemoryAssigned / 1GB } },
        @{ Name = 'VMIP';        Expression = { $NICs -join ', ' } },
        @{ Name = 'VMName';      Expression = { $PSItem.Name } },
        @{ Name = 'VMState';     Expression = { $State } },
        @{ Name = 'VMOS';        Expression = { $VMInfo | Select-Object -ExpandProperty GuestOperatingSystem } },
        @{ Name = 'VMDiskTotal'; Expression = { $DiskArrayHT } },
        @{ Name = 'VMID';        Expression = { $VMID } },
        @{ Name = 'VMLongName';  Expression = { "$($VM.Name).$env:USERDNSDOMAIN" } }

    $VMsArrayHT += $VMStructure
}

ConvertTo-Json -InputObject $VMsArrayHT -Depth 4
