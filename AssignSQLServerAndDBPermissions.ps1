
Function ExecuteSqlQuery { 
    Param ($Query, $Server) 
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
                
            }
            return $Dataset.Tables[0] 
        }  

$DBServer =  'server1' # 
$Account  = 'domain\account1'
$DB = 'Provisioning' #ProvisioningDS, Instrumentation, Configuration, MSDB

$QueryCreateLogin = "CREATE LOGIN [$($Account)] FROM WINDOWS;"; $Result = ExecuteSqlQuery -Query $QueryCreateLogin -Server $DBServer 


$CreateDBUser     = "Use $($DB); 
                     CREATE USER [$($Account)] FOR LOGIN [$($Account)]; "; 
                     
                     $Result = ExecuteSqlQuery -Query $CreateDBUser -Server $DBServer

#ALTER ROLE [db_owner] ADD MEMBER [$($Account)];
#                 ;
$GrantDBRoles = "USE [$($DB)]; 
                 ALTER ROLE [db_datareader] ADD MEMBER [$($Account)];
                 ALTER ROLE [db_datawriter] ADD MEMBER [$($Account)];
                 ALTER ROLE [db_executor] ADD MEMBER [$($Account)];
                 ALTER ROLE [db_owner] ADD MEMBER [$($Account)]"

                 $Result = ExecuteSqlQuery -Query $GrantDBRoles -Server $DBServer
