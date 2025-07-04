Function ConvertFrom-HEX {
<#
.SYNOPSIS
Convert HEX to string.
.DESCRIPTION
Converts a provided string from a HEX value.
.EXAMPLE
Convert a HEX string into a string. Leading 0x in the HEX string is optional.
ConvertFrom-HEX -HEX 0x53706F6E6765426F62
.PARAMETER HEX
Enter the HEX value, with or without the leading 0x.
.NOTE
Conversion code was copied from Mathias R. Jessen's answer in https://stackoverflow.com/questions/69207636/converting-a-large-hexadecimal-string-to-decimal.
.FUNCTIONALITY
Support function.
#>
[CmdletBinding()]
Param(
    [Parameter( Mandatory = $True, ValueFromPipeline = $True )]
    [String] $HEX
)

# If 0x is present, remove it.
$String = '0{0}' -f ($HEX -replace '^0x', $null)

# Convert the HEX value to a decimal value.
$FromHEX = [Decimal][BigInt]::Parse($String, [System.Globalization.NumberStyles]::AllowHexSpecifier)

Write-Output -InputObject $FromHEX

} # End of ConvertFrom-HEX function.
