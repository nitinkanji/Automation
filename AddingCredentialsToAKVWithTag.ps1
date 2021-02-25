
Import-Module C:\PasswordMaintenance\ECPasswordMaintenance.psm1

#ECOEMCredentialsProdRG   westus21
#ECOEMCredentialsUATRG    westus21

$Vault = 'ECOEMProdServiceAccounts'
$Accouts = Import-Csv "D:\AKVCredentials_additional.csv"
$AccountError=@()
$VaultError=@()

$i=1

Foreach($account in $Accouts)
{
    If ($account.AccountName -match "_"){ $AccountName = $account.AccountName -replace "_","-"}
    else{$AccountName = $account.AccountName}
    
    Write-Host "$i. - Capturing {$AccountName}"

    Try
    {
        if($account.Domain)
        {
            $Expirydate = (Get-ADUser -identity $account.AccountName -Server $account.Domain -Properties msds-userpasswordexpirytimecomputed | Select samaccountname,
            @{Name = "Expiration Date"; Expression={[datetime]::fromfiletime($_."msds-userpasswordexpirytimecomputed")}}) 
        }
    }
    catch
    {
        $AccountError ="Account {$($account.DomainAccount)} Doesn't exist\failed - Error {$($Error[0].Exception)}"
        $AccountError | Out-File "D:\AccountError.txt" -Append
    }

    if($Expirydate)
    {
        $ConnectUser = (Get-WMIObject -class Win32_ComputerSystem | select username).UserName
        $Tag = @{'ServiceAccount'=$account.DomainAccount; 'ModifiedBy'=$ConnectUser; 'Comment'=$account.Comment}
        $secret = $account.'Current Password' | ConvertTo-SecureString -AsPlainText -Force

        Try
        {
            Set-AzureKeyVaultSecret -VaultName $Vault -Name $AccountName -SecretValue $secret -ContentType 'ServiceAccount' -Expires $Expirydate.'Expiration Date'.ToString() -Tag $Tag
        }
        catch
        {
            $VaultError="Failed for Account {$($account.DomainAccount)} - Error {$($Error[0].Exception)}"
            $VaultError | Out-File "D:\VaultError.txt" -Append
        }
    }

    $i+=1
}


#Reading Tag Keys
$Secrets = @(Get-AzureKeyVaultSecret -VaultName ECOEMProdServiceAccounts | Select name, Expires, tags)  

ForEach($secret in $Secrets)
{
    Foreach($tag in $secret.Tags)
    {
        $Key = (Get-AzureKeyVaultSecret -VaultName ECOEMProdServiceAccounts -Name $($Secret.name))
        Write-host "$($tag.ServiceAccount) : $($Secret.name) {$($key.SecretValueText)}"
    }

}


