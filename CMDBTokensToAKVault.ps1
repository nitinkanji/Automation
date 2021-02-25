$Vault = 'Tokens'
$Accouts = Import-Csv "D:\Desktop\CMDBTokensHOF.csv"
$AccountError=@()
$VaultError=@()

$i=1
$ConnectUser = (Get-WMIObject -class Win32_ComputerSystem | select username).UserName

Foreach($account in $Accouts)
{
    $Tag = @{'ServiceAccount'=$account.Account; 'ModifiedBy'=$ConnectUser; 'Comment'=$account.Comment}
    $secret = ($account.TokenValue).trim() | ConvertTo-SecureString -AsPlainText -Force

    If ($account.account -match "_"){ $AccountName = $account.account -replace "_","-"}
    else{$AccountName = $account.account}

    Set-AzureKeyVaultSecret -VaultName $Vault -Name $Account.TokenName -SecretValue $secret -ContentType 'CMDBTokens' -Tag $Tag 

}
