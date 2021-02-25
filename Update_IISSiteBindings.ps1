$Binding = 
{
        $Lists = @(
            [PSCustomObject]@{Name = "Web UI Site";  Protocol = "http"; Port = 80; IPAddress = "*"; HostHeader="microsoftoem.com"; SslFlags=0}
            [PSCustomObject]@{Name = "Web UI Site";  Protocol = "http"; Port = 80; IPAddress = "*"; HostHeader="www.microsoftoem.com"; SslFlags=0}
            [PSCustomObject]@{Name = "Web UI Site";  Protocol = "http"; Port = 443; IPAddress = "*"; HostHeader="microsoftoem.com"; SslFlags=0}
            [PSCustomObject]@{Name = "Web UI Site";  Protocol = "http"; Port = 443; IPAddress = "*"; HostHeader="www.microsoftoem.com"; SslFlags=0}
        )
    Import-Module Webadministration
    If(Get-WebBinding -Name "Web UI Site")
    {
        Foreach ($List in $Lists)
        {
            New-WebBinding -Name $($List.Name) -Protocol $($List.Protocol) -Port $($List.Port) -IPAddress $($list.IPAddress) -HostHeader $($List.HostHeader) -SslFlags $($List.SslFlags)
        }

        Get-WebBinding -Name "Web UI Site"
    }
    else {Write-host "Web UI Site - Not found."}
}

$Pass = "*************" | ConvertTo-SecureString -AsPlainText -Force ; $Account='domain\account'
$credential = [System.Management.Automation.PSCredential]::new($Account, $Pass)

$servers = (
'server1'
)

Foreach($server in $servers)
{
    Write-Host $server " " -NoNewline
    Invoke-Command -ComputerName $Server -ScriptBlock {Import-Module Webadministration; Get-ChildItem IIS:\AppPools |  select Name, state} -Credential $credential
}
