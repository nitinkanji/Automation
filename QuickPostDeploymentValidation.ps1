
$Pass = "****************" | ConvertTo-SecureString -AsPlainText -Force; $Account='redmond\lpoaasvc'
$credential = [System.Management.Automation.PSCredential]::new($Account, $Pass)


#Get App pool Status 
$servers = ('I07OPDFOAWEB2.partners.extranet.microsoft.com','I07OPDFOAWEB3.partners.extranet.microsoft.com','I07OPDFOASVC2.partners.extranet.microsoft.com','I07OPDFOASVC3.partners.extranet.microsoft.com','I07OPDBOAAPP3.partners.extranet.microsoft.com','I07OPDBOAAPP4.partners.extranet.microsoft.com','I07OPDBOAAPP5.partners.extranet.microsoft.com')

Foreach($server in $servers)
{
    Invoke-Command -ComputerName $server -ScriptBlock {
    Import-Module WebAdministration
    $Details=@()
    $applicationPools = Get-ChildItem IIS:\AppPools 
    $Tab = [char]9
    foreach($applicationPool in $applicationPools)
    {
        
            $Details += New-Object -TypeName PSObject -Property @{
                Server  = $env:COMPUTERNAME
                AppPool = $($applicationPool.Name)
                Status  = $($applicationPool.State)
                Account = $($applicationPool.ProcessModel.UserName)
                Password= $($applicationPool.ProcessModel.Password)
                PasswordLength =  $(($applicationPool.ProcessModel.Password).length)
             }
         
    }
    $Details | Ft -AutoSize
    } -Credential $Credential
}



#Update App Pool Password in case missing
$servers = ('I07OPDFOAWEB2.partners.extranet.microsoft.com','I07OPDFOAWEB3.partners.extranet.microsoft.com')
Foreach($server in $servers)
{
    Invoke-Command -ComputerName $server -ScriptBlock {
    Import-Module WebAdministration
    $Details=@()
    $applicationPools = Get-ChildItem IIS:\AppPools |? {$_.Name -eq "Promotions"}
    
    foreach($applicationPool in $applicationPools)
    {
        $applicationPool.processModel.userName = 'Northamerica\pdoaprm'
        $applicationPool.processModel.password = '***************'
        $applicationPool.processModel.identityType = 3
        $applicationPool | Set-Item
    }
    Restart-WebAppPool -name "Promotions"

    } -Credential $Credential
}


#Service Validation

$servers = ('I07OPDFOAWEB2.partners.extranet.microsoft.com','I07OPDFOAWEB3.partners.extranet.microsoft.com','I07OPDFOASVC2.partners.extranet.microsoft.com','I07OPDFOASVC3.partners.extranet.microsoft.com','I07OPDBOAAPP3.partners.extranet.microsoft.com','I07OPDBOAAPP4.partners.extranet.microsoft.com','I07OPDBOAAPP5.partners.extranet.microsoft.com')
$Details=@()
Foreach($server in $servers)
{
    Invoke-Command -ComputerName $server -ScriptBlock {
    write-host $env:COMPUTERNAME
    $Details = Get-WMIObject Win32_Service | Where-Object {$_.startname -ne "localSystem" }| Where-Object {$_.startname -ne $null } |Where-Object {$_.startname -ne "NT Service\MSSQLFDLauncher"} `
                            | Where-Object {$_.startname -ne "NT AUTHORITY\LocalService" }| Where-Object {$_.startname -ne "NT AUTHORITY\NetworkService"}| Where-Object {$_.startname -ne "NT Service\SQLTELEMETRY"}`
                            | select startname, name, state

    $Details | FT -AutoSize
    } -Credential $Credential

} 