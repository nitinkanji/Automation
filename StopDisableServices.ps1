$servers = (
'I07OU1BOAAPP1.partners.extranet.microsoft.com', 
'I07OU1BOAAPP2.partners.extranet.microsoft.com',
'I07OU1BOAAPP3.partners.extranet.microsoft.com',
'I07OU1BOAAPP4.partners.extranet.microsoft.com',
'I07OU1BOAAPP5.partners.extranet.microsoft.com',
'I11OU1BOAAPP1.partners.extranet.microsoft.com',
'I11OU1BOAAPP2.partners.extranet.microsoft.com',
'I11OU1BOAAPP3.partners.extranet.microsoft.com'
)

$Pass = "**************" | ConvertTo-SecureString -AsPlainText -Force ; $Account='redmond\lpoaasvc'
$credential = [System.Management.Automation.PSCredential]::new($Account, $Pass)

Foreach($Server in $servers)
{
    $services = Get-WMIObject Win32_Service -ComputerName $Server -Credential $credential | 
    select startname, name,State,StartMode, @{Name = "Server";Expression={$Server}} | ? {$_.name -like '*MSMQ*'} 

    $services

    ForEach($service in $services)
    {
        $StopDisable ={
            param ($servicename) 
            Stop-Service $servicename
            Set-service -Name $servicename -StartupType Disabled
        }

        Invoke-Command -ComputerName $Server -ScriptBlock $StopDisable -ArgumentList $service.name -Credential $credential
    }
}

Foreach($Server in $servers)
{
    $services = Get-WMIObject Win32_Service -ComputerName $Server -Credential $credential | 
    select startname, name,State,StartMode, @{Name = "Server";Expression={$Server}} | ? {$_.name -like '*ProvisioningAdminService*'`
     -or $_.name -like '*NfxProcessingService*' -or $_.name -like '*MSMQ*' -or $_.name -like '*NetMsmqActivator*' -or $_.name -like '*Microsoft.IT.Commerce.Diagnostics.EtwCollectorService*' } 

    $services | ft -AutoSize

}
