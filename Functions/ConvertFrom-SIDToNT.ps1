Function ConvertFrom-SIDToNT {
<#
.SYNOPSIS
Convert Security Identifier to a readable account name.
.DESCRIPTION
Converts Security Identifier to a readable NT account name.
.EXAMPLE
Convert S-1-5-21-0000000000-1226727633-2350061136-00000 to a username.
ConvertFrom-SIDToNT -SID 'S-1-5-21-0000000000-1226727633-2350061136-00000'
.FUNCTIONALITY
Support function
#>
[CmdletBinding()]
[OutputType( [String] )]
Param (
    [Parameter( Mandatory = $True, ValueFromPipeline = $True )]
    $SID
)

Process {
    $SIDObject = New-Object -TypeName System.Security.Principal.SecurityIdentifier($SID)
    $SIDObject.Translate([System.Security.Principal.NTAccount])
} # End of Process block.

} # End of ConvertFrom-SIDToNT function.
