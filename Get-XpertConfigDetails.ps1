$servers= (
'server1'
)
$ReadXpertAgentCongif = {
    [xml]$xml=$null
     
    if(Test-Path "D:\XpertAgent\data\AgentIdentityConfiguration.xml")
    {
        $xml = Get-Content D:\XpertAgent\data\AgentIdentityConfiguration.xml
    }
    elseif (Test-Path "E:\XpertAgent\data\AgentIdentityConfiguration.xml")
    {
        $xml = Get-Content E:\XpertAgent\data\AgentIdentityConfiguration.xml
    }
    
    [string]$Environment = $xml.AgentIdentityConfiguration.Environment | Out-String     
    [string]$Role = $xml.AgentIdentityConfiguration.Role | Out-String 
    
    $Detail = New-Object -TypeName PSObject -Property @{
        ServerName = $env:COMPUTERNAME.Trim()
        XpertEnvironment = $Environment.Trim()
        XpertRole = $Role.Trim()
    }   

    $Detail
}

$Details=@()
$Pass = "**********" | ConvertTo-SecureString -AsPlainText -Force; $Account='domain\account'
$credential = [System.Management.Automation.PSCredential]::new($Account, $Pass)

Foreach($server in $servers)
{
    $session = New-PSSession -ComputerName $server -Credential $credential
    $Details +=Invoke-Command -Session $session -ScriptBlock $ReadXpertAgentCongif 
}

$Details | Select PSComputerName, XpertEnvironment, XpertRole | Format-Table -AutoSize
