﻿$Pass = "C9sKv!xMi#84gH5gY2" | ConvertTo-SecureString -AsPlainText -Force; $Account='redmond\lpoaasvc'
$Cred = [System.Management.Automation.PSCredential]::new($Account, $Pass)

$computers=@("I07OPDBOAAPP1.partners.extranet.microsoft.com","I07OPDBOAAPP2.partners.extranet.microsoft.com","I07OPDBOAAPP3.partners.extranet.microsoft.com","I07OPDBOAAPP4.partners.extranet.microsoft.com","I07OPDBOAAPP5.partners.extranet.microsoft.com")
$certdetails=@();

#$cred=Get-Credential
foreach($computer in $computers)
{
    if($certinfo -ne $null)
        {
            Clear-Variable certinfo }
            
            $certinfo=Invoke-Command -ComputerName $computer -ScriptBlock{
                param ( $certCNs)
                $certinfo=@();
                #$certCNs=@("OEM Activation Service")

                foreach($certCN in $certCNs)
                {
                    $certnames=@{};
                    $a = Get-ChildItem CERT:\LocalMachine\my|where {$_.DnsNameList.unicode  -like $certCN}

                    $rsaFile = $a.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName
                    $keyPath = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\"
                    $fullPath=$keyPath+$rsaFile
                    $perm=(Get-Acl $fullPath).Access

                    ForEach($acl in $perm)
                    {
                        $certnames.servername=$env:COMPUTERNAME
                        $certnames.certificatename=$a.DnsNameList.unicode
                        $certnames.perm=$ACL.IdentityReference.ToString()+','  +$ACL.AccessControlType.ToString()+',' +$ACL.FileSystemRights.ToString()
                        $value=New-Object Psobject -Property $certnames
                        
                        $certinfo=$certinfo+$value
                    }
                }
            return $certinfo
            } -Credential $cred -ArgumentList "OEM Activation Service" #Certificate Name as argument 
            $certdetails+=$certinfo

}

$certdetails|Select ServerName, CertificateName, Perm | ft -AutoSize