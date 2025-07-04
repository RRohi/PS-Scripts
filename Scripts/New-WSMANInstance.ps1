# Support function:

Function Write-VerboseLog {
<#
.SYNOPSIS
Logging Support Function.
.DESCRIPTION
Shows verbose info when -Verbose switch is used, showing extensive info on executed cmdlets.
.EXAMPLE
A simple example:
Write-VerboseLog -LogInfo "This is a debug message."
.EXAMPLE
Send verbose log to file as well:
Write-VerboseLog -LogPath C:\TEMP\debug.log -LogInfo "This is a debug message."
.PARAMETER LogInfo
Specify Log Info.
.PARAMETER LogPath
Specify Log Path.
.NOTES
Output will be formatted as: "DateTime - LogInfo"
.FUNCTIONALITY
Provides Verbose Information for debugging purposes.
#>
[CmdletBinding()]
Param(
    [Parameter( Mandatory = $True )]
    [String]$LogInfo,
    [String]$LogPath
)

Begin {
    # Get Current DateTime and store it in a variable.
    Get-Date -Format 'yyyyMMdd-hhmmss' -OutVariable DateStamp | Out-Null
} # End of Begin block.
Process {
    # Output Verbose Log Text.
    Write-Verbose -Message "$DateStamp - $LogInfo"

    # Send verbose log to file.
    Add-Content -Path $LogPath -Value "$DateStamp - $LogInfo" -Encoding Unicode
} # End of Process block.

} # End of Write-VerboseLog Function.

# Description: This script does the following:
## * Requests a new certificate for the HTTPS listener if one doesn't exist already.
## * Creates a new HTTPS WSMan listener if one doesn't exist already.
### + Replaces an invalid/expired certificate for the HTTPS listener, if necessary.
## * Creates a firewall rule that restricts where the connections are allowed from (like a jump host and some trusted machine).
### + Enables encryption for the firewall rule.

# Variables
## Log
$LogLocation = "C:\TEMP\$(Get-Date -Format 'yyyyMMdd-hhmmss')_WinRM_configuration.log"

## Certificate template.
### Enter the template name (no spaces), not template display name (can be with spaces).
$TemplateName = 'ADCS_WINRM_TEMPLATE_NAME'
Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-CERT] Certificate template set as '$TemplateName'."
$ADCSTemplateName = $TemplateName -replace '\s', $null
Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-CERT] Command-line-friendly template name set as '$ADCSTemplateName'."

## Firewall
$WinRMDisplayGroup = 'Windows Remote Management*'
$WinRMHTTPSRule = 'WINRM-HTTPS-In-TCP'

#region CHECKS
# Check if HTTPS listener exists.
Write-VerboseLog -LogPath $LogLocation -LogInfo '[SETUP-WSMAN] Querying for HTTPS WSMan listener.'
Get-ChildItem -Path WSMan:\localhost\Listener | Where-Object Keys -like '*HTTPS' -OutVariable WINRMSListenerCheck | Out-Null

# Check if a certificate made from that template exists, is not expired and has Server and Client Authentication EKUs.
Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-CERT] Querying valid certificates that are created from the $TemplateName and have Client and Server Authentication EKUs."
Get-ChildItem -Path Cert:\LocalMachine\My\ | Where-Object -FilterScript { ($PSItem.Extensions | Where-Object -FilterScript { $PSItem.Format(0) -like "*$TemplateName*" }) -and (Get-Date) -lt $PSItem.NotAfter -and ($PSItem.EnhancedKeyUsageList.FriendlyName -contains 'Client Authentication' -and $PSItem.EnhancedKeyUsageList.FriendlyName -contains 'Server Authentication') } -OutVariable RMCertCheck | Out-Null

# Check if the firewall rule exists.
Get-NetFirewallRule -Name $WinRMHTTPSRule -ErrorAction SilentlyContinue -OutVariable FWRuleCheck | Out-Null
#endregion

# If all the checks are good, skip the following modifications.
If (-not $WINRMSListenerCheck -and -not $RMCert -and -not $FWRuleCheck) {
#region CERTIFICATE
    # Navigate to Local Machine Certificate Store, otherwise you won't be able to request the certificate later.
    Set-Location -Path Cert:\LocalMachine\My
    Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-CERT] Current path set to: '$((Get-Location).Path)'."

    # If there are no certificates from the template, request a new certificate.
    If ($null -eq $RMCertCheck) {
        Write-VerboseLog -LogPath $LogLocation -LogInfo '[SETUP-CERT] No certificates were found.'

        ## Request new certificate using the template, store it in a variable.
        Write-VerboseLog -LogPath $LogLocation -LogInfo '[SETUP-CERT] Requesting a new certificate.'
        $WinRMCertCheck = Get-Certificate -Template $ADCSTemplateName

        If ($null -eq $WinRMCertCheck) {
            Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-CERT] Unable to request a certificate using the '$ADCSTemplateName'. Exiting."
            Write-Output -InputObject "Didn't find a certificate from the '$ADCSTemplateName' and couldn't get one from the PKI either, exiting."
            Break
        }
        Else {
            Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-CERT] Requesting a new certificate from '$ADCSTemplateName' was successful."

            ### Remove the existing RMCertCheck variable, just in case.
            Write-VerboseLog -LogPath $LogLocation -LogInfo '[SETUP-CERT] Removing "RMCertCheck" variable.'
            Remove-Variable -Name RMCertCheck
            Write-VerboseLog -LogPath $LogLocation -LogInfo '[SETUP-CERT] "RMCertCheck" variable removed.'

            ### Store the new certificate into the same variable.
            Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-CERT] Getting the '$($WinRMCertCheck.Certificate.Thumbprint)' certificate object from the certificate store."
            Get-Item -Path Cert:\LocalMachine\My\$($WinRMCertCheck.Certificate.Thumbprint) -OutVariable RMCertCheck | Out-Null

            $Output = $RMCertCheck | Select-Object -Property `
                @{ Name = 'Issuing CA';   Expression = { ($PSItem.Issuer -split ',')[0] -replace 'CN=','' } },
                @{ Name = 'Template';     Expression = { $PSItem.Extensions[0].Format(0) } },
                @{ Name = 'DNSNames';     Expression = { $PSitem.DnsNameList -join ',' } },
                @{ Name = 'Subject Name'; Expression = { $PSItem.SubjectName[0].Name -replace 'CN=',''} },
                @{ Name = 'EKUs';         Expression = {
                    $EKUList = ForEach ($EKU in $PSItem.EnhancedKeyUsageList) {
                        $EKU
                    }

                    $EKUList -join ', '
                } },
                NotBefore, NotAfter, Thumbprint,
                @{ Name = 'Algorithm';    Expression = { $PSItem.SignatureAlgorithm.FriendlyName } },
                HasPrivateKey, SerialNumber

            Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-CERT] '$($RMCertCheck.Thumbprint)' data: $($Output -join '; ')."
        }
    }
#endregion

#region WSMAN HTTPS LISTENER
    # Construct FQDN from computer name.
    Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP] Constructing FQDN from local host name ($($env:COMPUTERNAME))."
    $LocalFQDN = [System.Net.Dns]::GetHostByName($env:COMPUTERNAME).Hostname
    Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP] FQDN of $($env:COMPUTERNAME) is $LocalFQDN."

    If (-not $WINRMSListenerCheck) {
        Write-VerboseLog -LogPath $LogLocation -LogInfo '[SETUP-WSMAN] HTTPS listener didn''t exist, creating a new one.'

        ## Create a HTTPS listener if it doesn't exist.
        New-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{ Address = "*"; Transport = "https" } -ValueSet @{ Hostname = "$LocalFQDN"; CertificateThumbprint = "$($RMCertCheck.Thumbprint)" }

        ## Query for the new HTTPS listener info.
        Get-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{ Address = "*"; Transport = "https" } | Select-Object Address, Transport, Port, Hostname, Enabled, CertificateThumbprint, ListeningOn -OutVariable HTTPSListener | Out-Null
        Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-WSMAN] New HTTPS listener - Addresses: $($HTTPSListener.Address); Transport: $($HTTPSListener.Transport); Port: $($HTTPSListener.Port); Hostname: $($HTTPSListener.Hostname); Enabled: $($HTTPSListener.Enabled); Certificate thumbprint: $($HTTPSListener.CertificateThumbprint); Listening on addresses: $($HTTPSListener.ListeningOn -join ',')."
    }
    Else {
        ## Query for the new HTTPS listener info.
        Get-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{ Address = "*"; Transport = "https" } | Select-Object Address, Transport, Port, Hostname, Enabled, CertificateThumbprint, ListeningOn -OutVariable HTTPSListener | Out-Null
        Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-WSMAN] HTTPS listener - Addresses: $($HTTPSListener.Address); Transport: $($HTTPSListener.Transport); Port: $($HTTPSListener.Port); Hostname: $($HTTPSListener.Hostname); Enabled: $($HTTPSListener.Enabled); Certificate thumbprint: $($HTTPSListener.CertificateThumbprint); Listening on addresses: $($HTTPSListener.ListeningOn -join ',')."

        Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-WSMAN] Found certificate '$($HTTPSListener.CertificateThumbprint)', checking if it's valid."
        
        ## HTTPS listener exists, check if the certificate is correct.
        If ($HTTPSListener.CertificateThumbprint -ne $RMCertCheck.Thumbprint) {
            Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-WSMAN] Certificate '$($HTTPSListener.CertificateThumbprint)' is incorrect, setting '$($RMCertCheck.Thumbprint)' as HTTPS listener certificate."

            ### Set a correct certificate if it doesn't match.
            Set-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{ Address = "*"; Transport = "https" } -ValueSet @{ CertificateThumbprint = "$($RMCertCheck.Thumbprint)" }
            Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-WSMAN] Certificate '$($RMCertCheck.Thumbprint)' is now bound to HTTPS listener."
        }
    }

    # Enable certificate authentication.
    Write-VerboseLog -LogPath $LogLocation -LogInfo '[SETUP-WSMAN] Enabling certificate authentication.'
    Set-Item -Path WSMan:\localhost\Service\Auth\Certificate -Value $True
    ## Get all authentication settings.
    Write-VerboseLog -LogPath $LogLocation -LogInfo '[SETUP-WSMAN] Querying for all WSMan authentication settings.'
    Get-ChildItem -Path WSMan:\localhost\Service\Auth\ -OutVariable AuthSettings | Out-Null

    ## Iterate through the settings to save them to file later.
    Write-VerboseLog -LogPath $LogLocation -LogInfo '[SETUP-WSMAN] Iterating through WSMan authentication settings.'
    $Settings = ForEach ($Auth in $AuthSettings) {
        "$($Auth.Name): $($Auth.Value)"
    }

    Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-WSMAN] Authentication settings: $($Settings -join '; ')."

    # And for good measure, restart the service.
    Write-VerboseLog -LogPath $LogLocation -LogInfo '[SETUP-WSMAN] Restarting WinRM service.'
    Restart-Service -Name WinRM -Force
    #endregion

    #region FIREWALL
    # Disable default Windows Remote Management firewall rules.
    Write-VerboseLog -LogPath $LogLocation -LogInfo '[SETUP-FW] Querying Windows Remote Management group firewall rules.'
    Get-NetFirewallRule -DisplayGroup $WinRMDisplayGroup -OutVariable FWRules | Out-Null
    Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-FW] Current WinRM firewall rule status: $(($FWRules | ForEach-Object { "$($PSItem.Name): $($PSItem.Enabled)" }) -join '; ')."

    Write-VerboseLog -LogPath $LogLocation -LogInfo '[SETUP-FW] Iterating through WinRM firewall rules and setting ''Action'' value to ''Block''.'
    ForEach ($FWRule in $FWRules) {
        If ($FWRule.Name -ne $WinRMHTTPSRule) {
            Set-NetFirewallRule -Name $FWRule.Name -Action Block
            Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-FW] '$($FWRule.Name)' firewall rule set to block traffic."
        }
    }

    # Create a HTTPS Windows Remote Management firewall rule.
    ## Collect IP address of all DCs that are not current DC.
    Write-VerboseLog -LogPath $LogLocation -LogInfo '[SETUP] Getting IP address of the DCs.'
    $DCs = (Get-ADDomainController -Filter * | Where-Object Hostname -notlike "*$($env:ComputerName)*" | Select-Object -ExpandProperty IPv4Address) -join ','
    Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP] DC IP addresses: '$DCs'."

    ## Construct an access list of remote hosts that are allowed to connect over WinRM. The access list has to be a comma-delimited list of IP addresses in a single string.
    $AccessList = ""
    Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP] Contructing the entire access list: '$AccessList'."

    ## Check if the firewall rule already exists.
    Write-VerboseLog -LogPath $LogLocation -LogInfo '[SETUP-FW] Checking if the WSMan HTTPS listener firewall rule already exists.'
    If (-not (Get-NetFirewallRule -Name $WinRMHTTPSRule -ErrorAction SilentlyContinue)) {
        ### Create the firewall rule.
        Write-VerboseLog -LogPath $LogLocation -LogInfo '[SETUP-FW] Creating a new firewall rule for the WSMan HTTPS listener.'
        New-NetFirewallRule -Name $WinRMHTTPSRule -DisplayName 'Windows Remote Management (HTTPS-In)' -Description 'Inbound rule for Windows Remote Management via WS-Management. [TCP 5986]' -Group 'Windows Remote Management' -Enabled True -Profile Domain -Direction Inbound -Action Allow -RemoteAddress ($AccessList -split ',') -Protocol TCP -LocalPort 5986 -Service winrm -OutVariable NewFWRule | Out-Null
        Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-FW] Created the new firewall rule for the HTTPS listener: Name: $($NewFWRule.Name), Enabled: $($NewFWRule.Enabled), Profile: $($NewFWRule.Profile), Direction: $($NewFWRule.Direction), Action: $($NewFWRule.Action), Status: $($NewFWRule.PrimaryStatus)."

        ### Get initial firewall rule security filter.
        Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-FW] Get security filter of $($NewFWRule.Name) firewall rule."
        $FWRuleSec = Get-NetFirewallRule -Name $NewFWRule.Name | Get-NetFirewallSecurityFilter
        Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-FW] $($NewFWRule.Name) firewall rule security filter settings: Authentication: $($FWRuleSec.Authentication), Encryption: $($FWRuleSec.Encryption), OverrideBlockRules: $($FWRuleSec.OverrideBlockRules), LocalUser: $($FWRuleSec.LocalUser), RemoteUser: $($FWRuleSec.RemoteUser), RemoteMachine: $($FWRuleSec.RemoteMachine)."

        ### Enable encryption on the connection.
        Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-FW] Enable encryption in $($NewFWRule.Name) firewall rule security filter."
        Set-NetFirewallSecurityFilter -InputObject $FWRuleSec -Encryption $FWRuleSec -OutVariable NewFWSec | Out-Null
        Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-FW] Encryption enabled in $($NewFWRule.Name) firewall rule security filter."

        ### Get modified firewall rule security filter.
        Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-FW] Get modified security filter of $($NewFWRule.Name) firewall rule."
        $ModFWRuleSec = Get-NetFirewallRule -Name $NewFWRule.Name | Get-NetFirewallSecurityFilter
        Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP-FW] $($NewFWRule.Name) firewall rule modified security filter settings: Authentication: $($ModFWRuleSec.Authentication), Encryption: $($ModFWRuleSec.Encryption), OverrideBlockRules: $($ModFWRuleSec.OverrideBlockRules), LocalUser: $($ModFWRuleSec.LocalUser), RemoteUser: $($ModFWRuleSec.RemoteUser), RemoteMachine: $($ModFWRuleSec.RemoteMachine)."
    }
    Else {
        Write-VerboseLog -LogPath $LogLocation -LogInfo '[SETUP-FW] Firewall rule already exists.'
    }
#endregion
}
Else {
    Write-VerboseLog -LogPath $LogLocation -LogInfo "[SETUP] WSMan HTTPS instance is running and valid."
}
