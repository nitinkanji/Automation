Import-Module E:\Automation\GeneralMonitoring\CompletedWork\Modules\ECPasswordMaintenance_8April17.psm1
$dbServer ='server1'
Function ExecuteSqlQuery ($Query, $Server) { 
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
                Write-host -ForegroundColor red "SQL Exception: Connection Failure on $($Server)."
                Write-host -ForegroundColor red "Details: $($Error[0].Exception.Message)."
                $conn.Close()
                $false
            }
            return $Dataset.Tables[0] 
        } 

$Query = 'Select Account,DomainFQDN from Projects.[dbo].[ECServiceAccount] (Nolock)'
$rows = ExecuteSqlQuery -Query $Query -Server $dbServer
$details = @()

$Trncate = " truncate table [Projects].[dbo].[ECServiceAccountPasswordExpiry]"
ExecuteSqlQuery -Query $Trncate -Server $dbServer


Foreach ($row in $rows)
{
    If($row.account -ne "")
    {
        $details = Get-PasswordExpiry -accountname $row.Account -dom $row.DomainFQDN
        $Expirydate = $details.Substring(0,$details.IndexOf("#"))
        $DaysToExpire = $details.Substring($details.IndexOf("#")+1,$details.Length-($details.IndexOf("#")+1))


        $insert = "Insert into Projects..ECServiceAccountPasswordExpiry (Account,DomainFQDN,Expirydate,daysToExpire) values ('$($row.Account)', '$($row.DomainFQDN)','$($Expirydate)','$($DaysToExpire)')"
        ExecuteSqlQuery -Query $insert -Server $dbServer
    }
}
