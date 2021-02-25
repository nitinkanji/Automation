
$certificates = Import-Csv E:\PartnersCertificatesAKV\Certificates.csv # Columns in CSV File Certificatename,CertPassword,VaultName,CertPhysicalPath, ResourceGroupName             
$Details = @()                                                           
                                                                         
$i = 1                                                                    
ForEach($certificate in $certificates)                                   
{
    #Export\Download Certificates from Azure's Key Vault
    Try
    {
        $Secret = Get-AzureKeyVaultSecret -VaultName $certificate.VaultName -Name $certificate.Certificatename
        $SecretBytes = [System.Convert]::FromBase64String($Secret.SecretValueText)
        $certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
        $certCollection.Import($SecretBytes,$null,[System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
        $protectedCertificateBytes = $certCollection.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, $certificate.Certificatename)
        $pfxPath = "E:\PartnersCertificatesAKV\ExportedFromAKV\$($certificate.Certificatename).pfx"
        [System.IO.File]::WriteAllBytes($pfxPath, $protectedCertificateBytes)
        
        Write-Host -ForegroundColor Cyan "$($certificate.Certificatename) --> Exported to Physical location."

        $Details += New-Object -TypeName PSObject -Property @{
            CertificateName = $certificate.Certificatename
            CertPassword    = $Tag.CertificatePassword
            ExportedTo      = "E:\PartnersCertificatesAKV\ExportedFromAKV\$($certificate.Certificatename).pfx"
            ExportedDate    = Get-Date 
        }

    }
    catch{
        Write-Host -ForegroundColor Red "Error  : $($Error[0].Exception)"
    }

}

$Details | Format-Table -AutoSize
$Details | Export-Csv 'E:\Report\AKVExportResults.csv' -NoTypeInformation