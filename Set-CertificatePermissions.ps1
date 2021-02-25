$Pass = "*********" | ConvertTo-SecureString -AsPlainText -Force; $Account='domain\account'
$Cred = [System.Management.Automation.PSCredential]::new($Account, $Pass)

$computers=@("Server1")

#$cred=Get-Credential
foreach($computer in $computers)
{
    Invoke-Command -ComputerName $computer -ScriptBlock {
    
        Import-Module webadministration
        #Param ([System.Collections.Hashtable]$certCNs)

        # $certCN is the identifiying CN for the certificate you wish to work with
        # The selection also sorts on Expiration date, just in case there are old expired certs still in the certificate store.
        # Make sure we work with the most recent cert 
        
     [System.Collections.Hashtable]$certCNs =@{
            "oemoaclientprodust"="domain\account1,domain\account2"
            }
        #[System.Collections.Hashtable]$certCNs = @{"microsoftoem.com"="northamerica\pdoaprm"} # Web Servers

        ForEach($certCN in $certCNs.Keys)
        { 
            Try
            {
                $WorkingCert = Get-ChildItem CERT:\LocalMachine\my|where {$_.DnsNameList.unicode  -match $certCN} | sort $_.NotAfter -Descending  
                
                ForEach ($a in $WorkingCert)
                {
                    if($tprint  -ne $null) {Clear-Variable TPrint }
                    if($rsaFile -ne $null) {Clear-Variable rsaFile}

                    If($a.DnsNamelist.unicode -like "$certCN")
                    {
                        $TPrint = $a.Thumbprint
                        $rsaFile = $a.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName

                        $list=($certCNs["$certCN"])
                        $members=@();
                        $members=$list.split(",",[System.StringSplitOptions]::RemoveEmptyEntries)

                        foreach($member in $members)
                        {
                        
                            $keyPath = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\"
                            $fullPath=$keyPath+$rsaFile
                            $acl=Get-Acl -Path $fullPath
                            $permission="$member","Full","Allow"
                            $accessRule=new-object System.Security.AccessControl.FileSystemAccessRule $permission
                            $acl.AddAccessRule($accessRule)
  
                            Try 
                            {
                                Set-Acl $fullPath $acl
                                Write-host -ForegroundColor Cyan "Success: ACL set on certificate $($certCN) on $($env:computername)."
                            }
                            Catch
                            {
                                Write-Host -ForegroundColor Red  "Error: unable to set ACL on certificate $($certCN) on $($env:computername), Details {$($Error[0].Exception)}."
                            }
                        }
                    }
                }
            }
            Catch
            {
                Write-host -ForegroundColor Red "Error: unable to locate certificate on on $($env:computername) for $($CertCN) - Details $($Error[0].Exception)."
                Exit
            }
        }
    } -credential $cred 
}
