$Pass = "C9sKv!xMi#84gH5gY2" | ConvertTo-SecureString -AsPlainText -Force; $Account='redmond\lpoaasvc'
$Cred = [System.Management.Automation.PSCredential]::new($Account, $Pass)

$computers=@("I07OPDFOAWEB1.partners.extranet.microsoft.com","I07OPDFOAWEB2.partners.extranet.microsoft.com","I07OPDFOAWEB3.partners.extranet.microsoft.com")

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
            "oemoaclientprodust"="Northamerica\pdoacbr,Northamerica\pdoadoc,Northamerica\pdoaord,Northamerica\pdoapbr,Northamerica\pdoapng,Northamerica\pdospba,Northamerica\pdoaprd,Northamerica\pdoaprm,Northamerica\pdhkmss,Northamerica\pdhkbusn,Northamerica\pdhkrsi,Northamerica\pdoartn,NorthAmerica\pdhkrson,Partners\pdhkrev,Northamerica\pdoaful,Northamerica\pdoahwr,Northamerica\pdoaint";
            "provisioningproddbencryptioncert"="Northamerica\pdoacbr,Northamerica\pdoadoc,Northamerica\pdoaord,Northamerica\pdoapbr,Northamerica\pdoapng,Northamerica\pdospba,Northamerica\pdoaprd,Northamerica\pdoaprm,Northamerica\pdhkmss,Northamerica\pdhkbusn,Northamerica\pdhkrsi,Northamerica\pdoartn,NorthAmerica\pdhkrson,Partners\pdhkrev,Northamerica\pdoaful,Northamerica\pdoahwr,Northamerica\pdoaint";
            "prodoaappsts.gtm.corp.microsoft.com"="Northamerica\pdoacbr,Northamerica\pdoadoc,Northamerica\pdoaord,Northamerica\pdoapbr,Northamerica\pdoapng,Northamerica\pdospba,Northamerica\pdoaprd,Northamerica\pdoaprm,Northamerica\pdhkmss,Northamerica\pdhkbusn,Northamerica\pdhkrsi,Northamerica\pdoartn,NorthAmerica\pdhkrson,Partners\pdhkrev,Northamerica\pdoaful,Northamerica\pdoahwr,Northamerica\pdoaint";
            "client.oemis.sls.phx.gbl"="Northamerica\pdoacbr,Northamerica\pdoadoc,Northamerica\pdoaord,Northamerica\pdoapbr,Northamerica\pdoapng,Northamerica\pdospba,Northamerica\pdoaprd,Northamerica\pdoaprm,Northamerica\pdhkmss,Northamerica\pdhkbusn,Northamerica\pdhkrsi,Northamerica\pdoartn,NorthAmerica\pdhkrson,Partners\pdhkrev,Northamerica\pdoaful,Northamerica\pdoahwr,Northamerica\pdoaint";
            "OEM Agreementr Prod Web Service Account"="Northamerica\pdoacbr,Northamerica\pdoadoc,Northamerica\pdoaord,Northamerica\pdoapbr,Northamerica\pdoapng,Northamerica\pdospba,Northamerica\pdoaprd,Northamerica\pdoaprm,Northamerica\pdhkmss,Northamerica\pdhkbusn,Northamerica\pdhkrsi,Northamerica\pdoartn,NorthAmerica\pdhkrson,Partners\pdhkrev,Northamerica\pdoaful,Northamerica\pdoahwr,Northamerica\pdoaint";
            "i07opdboaappv.partners.extranet.microsoft.com"="Northamerica\pdoacbr,Northamerica\pdoadoc,Northamerica\pdoaord,Northamerica\pdoapbr,Northamerica\pdoapng,Northamerica\pdospba,Northamerica\pdoaprd,Northamerica\pdoaprm,Northamerica\pdhkmss,Northamerica\pdhkbusn,Northamerica\pdhkrsi,Northamerica\pdoartn,NorthAmerica\pdhkrson,Partners\pdhkrev,Northamerica\pdoaful,Northamerica\pdoahwr,Northamerica\pdoaint";
            "oemoaclientprodmcapi"="Northamerica\pdoacbr,Northamerica\pdoadoc,Northamerica\pdoaord,Northamerica\pdoapbr,Northamerica\pdoapng,Northamerica\pdospba,Northamerica\pdoaprd,Northamerica\pdoaprm,Northamerica\pdhkmss,Northamerica\pdhkbusn,Northamerica\pdhkrsi,Northamerica\pdoartn,NorthAmerica\pdhkrson,Partners\pdhkrev,Northamerica\pdoaful,Northamerica\pdoahwr,Northamerica\pdoaint";
            "oemnosqlprod.partners.extranet.microsoft.com"="Northamerica\pdoacbr,Northamerica\pdoadoc,Northamerica\pdoaord,Northamerica\pdoapbr,Northamerica\pdoapng,Northamerica\pdospba,Northamerica\pdoaprd,Northamerica\pdoaprm,Northamerica\pdhkmss,Northamerica\pdhkbusn,Northamerica\pdhkrsi,Northamerica\pdoartn,NorthAmerica\pdhkrson,Partners\pdhkrev,Northamerica\pdoaful,Northamerica\pdoahwr,Northamerica\pdoaint"
            "OEM Activation Service"="Northamerica\pdoacbr,Northamerica\pdoadoc,Northamerica\pdoaord,Northamerica\pdoapbr,Northamerica\pdoapng,Northamerica\pdospba,Northamerica\pdoaprd,Northamerica\pdoaprm,Northamerica\pdhkmss,Northamerica\pdhkbusn,Northamerica\pdhkrsi,Northamerica\pdoartn,NorthAmerica\pdhkrson,Partners\pdhkrev,Northamerica\pdoaful,Northamerica\pdoahwr,Northamerica\pdoaint"
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