# Import Certificates to AKV
$certificates = Import-Csv E:\PartnersCertificatesAKV\Certificates.csv # Columns in CSV File Certificatename,CertPassword,VaultName,CertPhysicalPath, ResourceGroupName        
$Details = @()

$i = 1
ForEach($certificate in $certificates)
{
    $Tag = @{'CertificateName'=$certificate.Certificatename;'CertificatePassword'=$certificate.CertPassword} 
    
    #Upload PFX Certificate to Azure's Key Vault
    $securepfxpwd =  $certificate.CertPassword | ConvertTo-SecureString –AsPlainText –Force # Password for the private key PFX certificate
    
    Try{
        $cer = Import-AzureKeyVaultCertificate -VaultName $certificate.VaultName -Name $certificate.Certificatename -FilePath $certificate.CertPhysicalPath -Password $securepfxpwd -Tag $Tag
        $Details+=New-Object -TypeName PSObject -Property @{
            Certificate     = $certificate.Certificatename
                CertPassword    = $certificate.CertPassword
                    VaultName       = $certificate.VaultName
                        ResourceGP      = $certificate.ResourceGroupName
                            Status          = "MigratedToAKV"
        }

        Write-Host -ForegroundColor Cyan "$($i). Migrated To AKV Sucessfully --> {$($certificate.Certificatename)} "

    }
    Catch{
        $Details+=New-Object -TypeName PSObject -Property @{
            Certificate     = $certificate.Certificatename
                CertPassword    = $certificate.CertPassword
                    VaultName       = 'NA'
                        ResourceGP      = 'NA'
                            Status          = 'FailedToMove'

    }
        Write-Host -ForegroundColor Cyan "$($i). Failed to Migrate --> {$($certificate.Certificatename)} "
        Write-Host -ForegroundColor Red "Error : $($Error[0].Exception)"
    }

    $i+=1
}

$Details | Format-Table -AutoSize
$Details | Export-Csv "E:\Report\AKVImportResults.csv" -NoTypeInformation

