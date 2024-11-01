Function Get-Certificate2 {
<#
.SYNOPSIS
Output a certificate or a list of certificates.
.DESCRIPTION
Displays a certificate object or a list of certificates.
.PARAMETER Certificate
A X509Certificate2 object
.PARAMETER Path
Path for the container of the certificates or a specific certificate.
.PARAMETER Subject
The subject of the certificate is in the form of 'CN=FQDN' or 'FQDN'.
.PARAMETER Template
Name of the Microsoft CA certificate template from which the certificate was created.
.EXAMPLE
Get certificate data using the full path.
Get-Certificate2 -Path Cert:\LocalMachine\My\DD4400000E823BC58AD86CD111118F670D922222
.EXAMPLE
Get certificate data from an X509Certificate2 object.
Get-Certificate2 -Certificate (Get-Item -Path Cert:\LocalMachine\My\DD4400000E823BC58AD86CD111118F670D922222)
Get-Item -Path Cert:\LocalMachine\My\DD4400000E823BC58AD86CD111118F670D922222 | Get-Certificate2
.EXAMPLE
Get certificate data using the provided path, subject, and template.
Get-Certificate2 -Path Cert:\LocalMachine\My -Subject host.domain.tld -Template 'Kerberos Authentication'
.EXAMPLE
Get certificate data using the provided path and subject.
Get-Certificate2 -Path Cert:\LocalMachine\My -Subject host.domain.tld
.INPUTS
Any X509Certificate2 object, full path to an X509Certificate2 object.
.OUTPUTS
[PSCustomObject] @{ Subject=FQDN; Template=<template name>; Thumbprint=<thumbprint string>; Expires on=<datetime value>; Issuer=<Issueing CA>; Enhanced Key Usage=<list of EKU's>; Signature algorithm=<signature algorithm string>; Key size=<key size string> }
.NOTES
The initial base for this function came from the Slogmeister Extraordinaire's answer in Stack Overflow listed under links.
.LINK
https://stackoverflow.com/questions/43327855/identifying-certificate-by-certificate-template-name-in-powershell
#>
[CmdletBinding( DefaultParameterSetName = 'Default' )]
Param (
    [Parameter( Mandatory = $True, ValueFromPipeline = $True, ParameterSetName = 'Certificate' )]
    [Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
    [Parameter( Mandatory = $True, ParameterSetName = 'Subject' )]
    [Parameter( ParameterSetName = 'Path' )]
    [ValidatePattern( '^Cert:\\LocalMachine\\[A-Za-z\s]{2,}\\?([A-Z0-9]{40})?$' )]
    [String]$Path,
    [Parameter( Mandatory = $True, ParameterSetName = 'Subject' )]
    [String]$Subject,
    [Parameter( Mandatory = $False, ParameterSetName = 'Subject' )]
    [String]$Template
)

Begin {
    # Set static variables.
    ## Create a variable for the RegEx match pattern for the certificate Template string.
    $TemplatePattern = [System.Text.RegularExpressions.Regex]::new( '(?:Template=)([\w\s\d\.-_]+)((?:\(\d.+))', [System.Text.RegularExpressions.RegexOptions]::None )

    ## Create a delimiter variable, necessary for external tools that have difficulties parsing spaces in paths, subjects, and template names. For example, the template name 'Corp!Signing!Cert' will be converted to 'Corp Signing Cert' in the function.
    $Delimiter = '!'
} # End of Begin block.
Process {
    # Check which parameters were used, set Certificates variable path, iterate through certificate objects, and display output.
    ## Parameter usage check.
    If ($Path -and $Subject) {
        ### Path and subject parameters were used.
        $Certificates = Get-ChildItem -Path "$($Path -replace $Delimiter, ' ')"
        
        ### Check if the certificate object has Subject attribute.
        If ($null -ne $Certificates.Subject) {
            $CertificateFilter = $Certificates | Where-Object Subject -like "*$($Subject -replace $Delimiter, ' ')*"
        }
        ### The certificate object doesn't have a Subject attribute, check if it has DnsNameList attribute populated.
        ElseIf ($null -ne $Certificates.DnsNameList[0]) {
            $CertificateFilter = $Certificates | Where-Object { $PSItem.Subject -like "*$($Subject -replace $Delimiter, ' ')*" -or $PSItem.DnsNameList[0].Unicode -icontains $Subject }
        }
        Else {
            #### All failed, exit.
            Throw 'The certificate does not have subject or DnsNameList attributes.'
        }
    }
    ElseIf ($Path) {
        ### The Path parameter was used.
        $CertificateFilter = Get-ChildItem -Path "$($Path -replace $Delimiter, ' ')"
    }
    ElseIf ($Certificate) {
        ### The Certificate parameter was used.
        $CertificateFilter = $Certificate
    }
        
    ## Iterate through certificates.
    ForEach ($Cert in $CertificateFilter) {
        ### Store certificate extensions into a variable, and filter out extension that contains certificate template information.
        $CertExts = $Cert.Extensions | Where-Object { $PSItem.Oid.Value -eq '1.3.6.1.4.1.311.21.7' }
        
        ### Check whether there are any extensions on the certificate.
        If ($null -ne $CertExts) {
            #### Create a variable containing the certificate template match using the provided regex pattern.
            $Matches = $TemplatePattern.Matches($CertExts.Format($False))
        }
        
        ### Check if the Subject Name is empty.
        If ($Cert.SubjectName.Name -eq '') {
            #### Create a variable containing the first Unicode entry in the DnsNameList array, since the Subject Name attribute is empty (not null).
            $SubjectName = $Cert.DnsNameList[0].Unicode
        }
        Else {
            #### Create a variable containing the Subject name.
            $SubjectName = $Cert.SubjectName.Name
        }

        ### Check if there were any matches for the certificate template information.
        If ($null -ne $Matches) {
            #### Create a variable containing the certificate template name.
            $TemplateValue = $Matches[0].Groups[1].Value
        }
        Else {
            #### The certificate doesn't have a template.
            $TemplateValue = 'N/A'
        }

        ### Create a hashtable containing the certificate information.
        $CertObjects = @{
            Subject               = $SubjectName
            Template              = $TemplateValue
            Thumbprint            = $Cert.Thumbprint
            'Expires on'          = $Cert.NotAfter
            Issuer                = $Cert.Issuer
            'Enhanced Key Usage'  = $Cert.EnhancedKeyUsageList
            'Signature algorithm' = $Cert.SignatureAlgorithm.FriendlyName
            'Key size'            = $Cert.PublicKey.Key.KeySize
        }

        ### Check if the Template parameter was used.
        If ($Template) {
            #### Displaying certificate information as PSCustomObject, filtered by Template name.
            [PSCustomObject]$CertObjects | Where-Object Template -eq $($Template -replace $Delimiter, ' ')
        }
        Else {
            #### Displaying certificate information as PSCustomObject.
            [PSCustomObject]$CertObjects
        }
    }
} # End of Process block.

} # End of Get-Certificate2 function.

# Zabbix certificate check.
## Replace spaces in Path, Subject, Template with delimiter specified in the function above in the Delimiter variable.
## Specify LocalMachine certificate folder or full path (e.g Cert:\LocalMachine\My or Cert:\LocalMachine\My\0029FDD2664660F89E62B00F4D7AC56BC939D244 or Cert:\LocalMachine\Microsoft!Monitoring!Agent).
$Path = $args[0] 

## Full name of the cert subject (e.g "CN=server.post.ee,!DC=domain,!dc=tld").
$Subject = $args[1]

## Template name. (e.g Omniva!Signing!Certificate!Template)
$Template = $args[2]

## Get the specified certificate.
If ($Path -and $Subject -and $Template) {
    Get-Certificate2 -Path $Path -Subject $Subject -Template $Template | Select-Object -First 1 'Expires on' | ConvertTo-Json
}
ElseIf ($Path -and $Subject) {
    Get-Certificate2 -Path $Path -Subject $Subject | Select-Object -First 1 'Expires on' | ConvertTo-Json
}
