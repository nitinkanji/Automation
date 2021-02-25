Function ExecuteSqlQuery ($Query, $Server)        { 
    Try
    {
        $Datatable = New-Object System.Data.DataTable 
        $conn = New-Object System.Data.SqlClient.SqlConnection("Data Source="+$($server)+";Integrated Security=SSPI;Initial Catalog=master")
        $conn.Open()
    
                $Command = New-Object System.Data.SQLClient.SQLCommand 
                $Command.Connection = $conn 
                $Command.CommandText = $Query

                        $DataAdapter = new-object System.Data.SqlClient.SqlDataAdapter $Command 
                        $Dataset = new-object System.Data.Dataset 
                        $DataAdapter.Fill($Dataset) 
                        $conn.Close() 
            
            }
            
            catch
            {
                    write-host  "SQL Exception: Connection Failure on $($Server)."
                    write-host  "Details: $($Error[0].Exception.Message)."
                
                    $conn.Close()
                    $flag=1
            }

            return $Dataset.Tables[0] 
}

$DBServer ='nitinkg.fareast.corp.microsoft.com'
$Pass = "**********" | ConvertTo-SecureString -AsPlainText -Force; $Account='redmond\lpoaasvc'
$Cred = [System.Management.Automation.PSCredential]::new($Account, $Pass)


$Certificate   = {
    Param([int]$DaysToExpire)
    $ds=@()
        $deadline = (Get-Date).AddDays($DaysToExpire)   #Set deadline date 
        Dir Cert:\LocalMachine\My | foreach { 
        if(($_.NotAfter - (Get-Date)).days -ge -60)
        {
            If ($_.NotAfter -le $deadline) 
            { 
                $ds+=$_ | Select Subject, Thumbprint,NotAfter, Serialnumber, @{Label="ExpiresInDays";Expression={($_.NotAfter - (Get-Date)).Days} } 
            }
        }}
    Return $ds 
}
$GetCertUsages = {
    Param($Thumbprint)
    $Files = Get-Childitem 'D:\' -Recurse | Select-String $Thumbprint |group path | select name
    $Files
}

#Scaning Certificates Expiration details

$ServerQuery = "select distinct ServerName from Projects..ServiceAccountUsage (nolock) where servername not like '%VLA%' and servername not like '%MOE%'"
$Servers  = ExecuteSqlQuery -Query $ServerQuery -Server $DBServer

$Truncate = ExecuteSqlQuery -Query "Truncate table Projects..CertificateUsage" -Server $DBServer
$Details  = @()

[int]$DayToExpire = 60


Foreach($server in $Servers.ServerName)
{
    Try
    {
        "Checking --- $server."
        $response = Invoke-Command -ComputerName $server  -ScriptBlock $Certificate -ArgumentList $DayToExpire -Credential $Cred
        Foreach($detail in $response)
        {     
            $query = "Insert into Projects..CertificateUsage (csubject, thumbprint, notafter, ServerName, ExpiresInDays, CertSerialNumber) values ('$($Detail.subject)','$($Detail.Thumbprint)','$($Detail.NotAfter)','$($Detail.PSComputerName)','$($Detail.ExpiresInDays)','$($Detail.SerialNumber)')"                    
            ExecuteSqlQuery -Query $query -Server $dbServer
        }
    }
    catch {"Error : Connection Failure $($server)"}
}


#Scaning Certificates Usages details

$Thumbprints = "select Thumbprint, ServerName from Projects..CertificateUsage where ExpiresInDays <= 30 and ExpiresInDays > 0"
$Rows = ExecuteSqlQuery -Query $Thumbprints -Server $dbServer
$FileCounts=@()

Foreach($row in $rows)
{
    If($row.ServerName -ne $null)
    {
        "Scanning Files on $($row.ServerName)"
        $FileCounts = Invoke-Command -ComputerName $Row.ServerName -ScriptBlock $GetCertUsages -ArgumentList $row.Thumbprint -Credential $Cred
        $FileCounts | ft -AutoSize
    }
}
