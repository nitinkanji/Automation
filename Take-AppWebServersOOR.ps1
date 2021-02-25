#  AUTHOR: Nitin Gupta [nitinkg@microsoft.com]
#  DESCRIPTION : Check Web & App Server LoadBalancer Status and make changes if needed.

$Pass = "*************" | ConvertTo-SecureString -AsPlainText -Force; $Account='domain\account'
$credential = [System.Management.Automation.PSCredential]::new($Account, $Pass)
$Details=@($null)

$Servers = (
'server1'
)

$CheckActive= {
    
    $OEMWebFile = 'd:\inetpub\wwwroot\LoadBalancer\active.txt'
    $OEMAppFile = 'd:\inetpub\wwwroot\Probetest\testpage.aspx'

    if((Test-Path $OEMWebFile) -or (Test-Path $OEMAppFile))
    {
        $flag='Active'
    } 
    else
    {
        $flag='InActive'
    }
    Return $flag
}
$MakeChanges= {
    param ($FileAtion)
    
    $OEMWebFile = 'd:\inetpub\wwwroot\LoadBalancer\active.txt'
    $OEMAppFile = 'd:\inetpub\wwwroot\Probetest\testpage.aspx'

    $InActiveOEMWebFile = 'D:\inetpub\wwwroot\LoadBalancer\Inactive.txt'
    $InActiveOEMAppFile = 'D:\inetpub\wwwroot\Probetest\Intestpage.aspx'

    if($FileAtion -eq 1)
    {
        Write-Host "Adding into Rotation !"
        $result=$null
        if((Test-Path $OEMWebFile) -or (Test-Path $OEMAppFile))
        {
            $result = 'Already Active'
        }
        else
        {
            if(Test-Path $InActiveOEMWebFile)
            {
                Rename-Item $InActiveOEMWebFile -NewName 'Active.txt'
            }
            elseif(Test-Path $InActiveOEMAppFile)
            {
                Rename-Item $InActiveOEMAppFile -NewName 'testpage.aspx'
            }
            $result = 'Action Completed'
        }

       
    }
    elseif($FileAtion -eq 2)
    {
        Write-Host "Taking node out of rotation (OOR)!"
        $result=$null
        if((Test-Path $InActiveOEMAppFile) -or (Test-Path $InActiveOEMWebFile))
        {
            $result = 'Already InActive'
        }
        else
        {
            if(Test-Path $OEMWebFile)
            {
                Rename-Item $OEMWebFile -NewName 'InActive.txt'
            }
            elseif(Test-Path $OEMAppFile)
            {
                Rename-Item $OEMAppFile -NewName 'Intestpage.aspx'
            }
            $result = 'Action Completed'
        }
        
    }
    else
    {
        $result = 'Action Failed'
    }

    return $result
}


Foreach($server in $Servers)
{
    $session = New-PSSession -ComputerName $server -Credential $credential
    $response = Invoke-Command -Session $session -ScriptBlock $CheckActive 
                Remove-PSSession -Session $session

    $Details+=New-Object -TypeName PSObject -Property @{
    Server = $server
    Status = $response}|Select-Object Server,Status
}

$Details | ft -AutoSize

Do
{
    $inputRequest = Read-Host "Want to make any change (Y/N)?"
    If($inputRequest -eq 'Y')
    {
        $read = Read-Host "Enter Server (FQDN) followed by Action Status Code 1 or 2 (1 = Active, 2=InActive)"
    
        if($read.IndexOf(',') -gt 0)
        {
            $action=@($read.Split(','))
                $ActionServer = $action[0]
                    [int]$FileAtion = $action[1]

            $session = New-PSSession -ComputerName $ActionServer -Credential $credential
            $Status  = Invoke-Command -Session $session -ScriptBlock $MakeChanges -ArgumentList $FileAtion
                       Remove-PSSession -Session $session 
        
            Write-Host -ForegroundColor Cyan "Status : {ServerName - $($ActionServer), Status - $($Status)}."   
       
        }
        elseif($read.IndexOf(' ') -gt 0)
        {
            $action=@($read.Split(' '))
                $ActionServer = $action[0]
                    [int]$FileAtion = $action[1]

            $session = New-PSSession -ComputerName $ActionServer -Credential $credential
            $Status  = Invoke-Command -Session $session -ScriptBlock $MakeChanges -ArgumentList $FileAtion
                       Remove-PSSession -Session $session 
        
            Write-Host -ForegroundColor Cyan "Status : {ServerName - $($ActionServer), Status - $($Status)}." 
        }
        else
        {
            Write-Host -ForegroundColor Cyan "Warning : No Action Status Code defined."
        }
    }
    else
    {
        Write-Host "Thanks!"
    }

}while($inputRequest -eq 'Y')
