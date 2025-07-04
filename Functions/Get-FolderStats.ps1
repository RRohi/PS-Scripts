Function Get-FolderStats {
<#
.SYNOPSIS
Get basic folder stats for a folder.
.DESCRIPTION
Get recursive file count and size of a folder.
.EXAMPLE
Get file count and folder size of C:\TEMP\
Get-FolderStats -Path C:\TEMP\
.PARAMETER Path
Path of a folder.
.FUNCTIONALITY
Support function.
#>
[CmdletBinding()]
Param(
    [Parameter( Mandatory = $True, ValueFromPipeline = $True )]
    [ValidateScript( { Test-Path -Path $PSItem -PathType Container } )]
    [String] $Path,
    [Switch] $Extended
)

Process {
    # Get folder contents recursively.
    $FolderObject = Get-ChildItem -Path $Path -Recurse -File
    $Measure = $FolderObject | Measure-Object -Sum Length

    If ($Extended) {
        $Extensions = $FolderObject | Group-Object Extension -NoElement | Sort-Object Count -Descending
    }

    # Determine folder size and construct a correct unit.
    If ($Measure.Sum -lt '1024') {
        $Size = "$([math]::Round(($Measure.Sum), 1).ToString())B"
    }
    ElseIf ($Measure.Sum -lt '1024000') {
        $Size = "$([math]::Round(($Measure.Sum / 1KB), 1).ToString())KB"
    }
    ElseIf ($Measure.Sum -lt '1024000000') {
        $Size = "$([math]::Round(($Measure.Sum / 1MB), 1).ToString())MB"
    }
    ElseIf ($Measure.Sum -lt '1024000000000') {
        $Size = "$([math]::Round(($Measure.Sum / 1GB), 1).ToString())GB"
    }
    Else {
        $Size = "$([math]::Round(($Measure.Sum), 1).ToString())TB"
    }

    # Output.
    Write-Output -InputObject "Folder Name: $Path
    File Count: $($FolderObject.Count.ToString())
    Folder size: $Size"

If ($Extended) {
    Write-Output -InputObject "Extensions:
    $(ForEach ($Extension in $Extensions.GetEnumerator()) {
        "$($Extension.Name) - $($Extension.Count)`n"
    }
)"
    }
}

} # End of Get-FolderStats function.
