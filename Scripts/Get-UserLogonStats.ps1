#Required -Version 7.5

# Query all successful logins from all DCs and add location based on subnet.
# The script requires PowerShell 7+ to query all DCs in parallel. The script is extremely slow in Windows PowerShell 5.1. Even for short time spans.
# Change RegEx patterns in the script to suit your environment.

Get-ADDomainController -Filter * | ForEach-Object -Parallel {
    Get-WinEvent -ComputerName $PSItem -FilterHashtable @{
            LogName = 'Security'
            ID = 4624
            StartTime = ([DateTime]::Today).AddHours(-1).ToString('s')
    } -ErrorAction SilentlyContinue
} -OutVariable OneHourSecurityEvents | Out-Null

$SubnetCheck = $OneHourSecurityEvents | Where-Object -Property Message -match '10\.\1\.(1|2|254)\.'

$Report = $SubnetCheck | Select-Object -Property RecordId, TimeCreated, MachineName,
    @{ Name = 'Location'; Expression = {
            $PSItem.Message -match 'Source Network Address:\s+10\.\d{2}\.\d{1,3}\.' | Out-Null
            $SubnetPart = ($Matches.Values -split '\s')[-1]
                    
            Switch ($SubnetPart) {
                '10.1.1.'   { $Location = 'Office 1' }
                '10.1.2.'   { $Location = 'Office 2' }
                '10.1.254.' { $Location = 'Office wifi' }
            }

            $Location
        }
    },
    @{ Name = 'Host'; Expression = {
            $PSItem.Message -match 'Source Network Address:\s+10\.\d{2}(\.\d{1,3}){2}' | Out-Null
            [System.Net.Dns]::GetHostByAddress("$(($Matches.Values -split '\s')[-1])") | Select-Object -ExpandProperty HostName
        }
    },
    @{ Name = 'IP'; Expression = {
            $PSItem.Message -match 'Source Network Address:\s+10\.\d{2}(\.\d{1,3}){2}' | Out-Null
            ($Matches.Values -split '\s')[-1]
        }
    },
    @{ Name = 'User'; Expression = {
            $PSItem.Message -match 'Account\sName:\s+[a-zA-Z][a-zA-Z0-9-]{0,30}(\.[a-zA-Z-]+)?' | Out-Null
            ($Matches.Values -split '\s')[-1]
        }
    },
    @{ Name = 'Logon Type'; Expression = {
            $PSItem.Message -match 'Logon Type:\s+\d{1,2}' | Out-Null
            $LogonType = ($Matches.Values -split '\s')[-1]

            Switch ($LogonType) {
                2  { $LogonTypeName = 'Local' }
                3  { $LogonTypeName = 'Network' }
                4  { $LogonTypeName = 'Batch' }
                5  { $LogonTypeName = 'Service' }
                8  { $LogonTypeName = 'ClearTextAuth' }
                9  { $LogonTypeName = 'RunAsNetwork' }
                10 { $LogonTypeName = 'Remote' }
            }

            $LogonTypeName
        }
    },
    @{ Name = 'Restricted Admin Mode'; Expression = {
            $PSItem.Message -match 'Restricted\sAdmin\sMode:\s+.+' | Out-Null
            ($Matches.Values -split '\s')[-2]
        }
    },
    @{ Name = 'Virtual Account'; Expression = {
            $PSItem.Message -match 'Virtual\sAccount:\s+.+' | Out-Null
            ($Matches.Values -split '\s')[-2]
        }
    },
    @{ Name = 'Elevated Token'; Expression = {
            $PSItem.Message -match 'Elevated\sToken:\s+.+' | Out-Null
            ($Matches.Values -split '\s')[-2]
        }
    }

$Report

<# Optional: Get unique user count in each location:
$LocationGrouping = $Report | Group-Object -Property Location
$UniqueUsers = $LocationGrouping | ForEach-Object { $Report | Where-Object Location -eq $PSItem.Name | Sort-Object -Unique User }
$UniqueUsers | Group-Object -Property Location -NoElement | Select-Object Name, Count
#>
