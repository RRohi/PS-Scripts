# A library of OnPrem Exchange related cmdlets.

## Get Public Folder Mailbox.
```powershell
$PFM = Get-MailPublicFolder -Identity pf@domain.tld | Select-Object Alias, PrimarySmtpAddress, ContentMailbox, Identity
```

## Get Public Folder Mailbox Path.
```powershell
Get-PublicFolder -Recurse | Where-Object Name -eq $PFM.Identity.Name
```

## Get Dynamic Distribution Group Members.
```powershell
$DDG = Get-DynamicDistributionGroup -Identity 'OUPath'
Get-Recipient -RecipientPreviewFilter $DDG.RecipientFilter -OrganizationalUnit $DDG.RecpientContainer | Sort-Object Name | Select-Object Name
```

## Check mail traffic from an address to an address since 14 days ago.
```powershell
$DT = Get-Date

$servers = Get-ExchangeServer
$servers | ForEach-Object { Get-MessageTrackingLog -Server $PSItem -Start $DT.AddDays(-14) -End $DT -Sender "from@domain.tld" -Recipients "to@domain.tld" -ResultSize Unlimited -Source SMTP } | Sort-Object MessageSubject
```
