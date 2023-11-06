# Uninstall Microsoft Local Administrator Password Solution (LAPS) Group Policy Client Side Extension (CSE) in order to replace it with Windows LAPS.

## Check if Microsoft LAPS is installed.
$LAPS = Get-CimInstance -Query 'SELECT * FROM Win32_Product WHERE Name = "Local Administrator Password Solution"'

## Uninstall LAPS instance(s).
ForEach ($Instance in $LAPS) { Invoke-CimMethod -InputObject $Instance -MethodName Uninstall }
    
## Remove script.
Remove-Item -Path $PSCommandPath -Force
