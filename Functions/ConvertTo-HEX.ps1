Function ConvertTo-HEX {
<#
.SYNOPSIS
Convert string to HEX.
.DESCRIPTION
Converts a provided string to a HEX value.
.EXAMPLE
Convert the word 'Terminator' into a HEX value.
ConvertTo-HEX -String 'Terminator'
.PARAMETER String
Enter string to be converted.
.NOTE
Conversion code was copied from Mathias R. Jessen's answer in https://stackoverflow.com/questions/69207636/converting-a-large-hexadecimal-string-to-decimal.
.FUNCTIONALITY
Support function.
#>
[CmdletBinding()]
Param(
    [Parameter( Mandatory = $True, ValueFromPipeline = $True )]
    [String] $String
)

# Turn the string into a character array.
$CharArray = $String.ToCharArray()

# Go over each character and turn them to their HEX value.
Foreach ($Char in $CharArray) {
    $TOHEX = $TOHEX + [String]::Format( "{0:X2}", [Convert]::ToUInt64($Char) )
}

Write-Output -InputObject $TOHEX

} # End of ConvertTo-HEX function.
