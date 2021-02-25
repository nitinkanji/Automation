$servers = (
'Server1'
)

$Pass = "**************" | ConvertTo-SecureString -AsPlainText -Force ; $Account='domain\account'
$credential = [System.Management.Automation.PSCredential]::new($Account, $Pass)

Foreach($Server in $servers)
{
    $services = Get-WMIObject Win32_Service -ComputerName $Server -Credential $credential | 
    select startname, name,State,StartMode, @{Name = "Server";Expression={$Server}} | ? {$_.name -like '*MSMQ111*'} 

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
     -or $_.name -like '*NfxProcessingService*' -or $_.name -like '*MSM111Q*' -or $_.name -like '*NetMsmqActivator*' -or $_.name -like '*Microsoft.IT.Commerce.Diagnostics.EtwCollectorService*' } 

    $services | ft -AutoSize

}
