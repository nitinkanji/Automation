param ([Parameter(Mandatory=$true)] [string] $ServerName)   
$servers = @(Type $ServerName)

$Pass = "**************" | ConvertTo-SecureString -AsPlainText -Force; $Account='redmond\lpoaasvc'
$credential = [System.Management.Automation.PSCredential]::new($Account, $Pass)
$flag = 1; $DBServer = 'i07oemsqldevops.northamerica.corp.microsoft.com'
   
Function ExecuteSqlQuery ($Query, $Server) { 
            Try
            {
                $Datatable = New-Object System.Data.DataTable 
                $conn = New-Object System.Data.SqlClient.SqlConnection("Data Source="+$($server)+";Integrated Security=SSPI;Initial Catalog=OEMSupport")
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
        
$AppPoolAction = {
    Param($AppPoolName, $action)

    If($Action -eq 'Start')
    { Start-WebAppPool -Name $ServiceName }
    elseif($Action -eq 'Stop')
    { Stop-WebAppPool -Name $serviceName  }
} 
$AppPoolStatus = {
Import-Module WebAdministration
$details = @()
Get-ChildItem IIS:\AppPools | ForEach-Object {
$details+=New-Object -TypeName PSObject -Property @{
    AppPoolName = $_.Name
         Status = $_.State
    AccountType = $_.ProcessModel.identityType
    AccountName = $_.ProcessModel.UserName
}}
$details 
}

Try
{
    Foreach($server in $servers)
    {
        Try
        {
            $AppPools = Invoke-Command -ComputerName $server -ScriptBlock $ServiceCheck -ArgumentList $server -Credential $credential
            $flag=0 
        }
        Catch
        {$flag=1}

         $ApppoolQuery=$("select ServerName, AppPoolName,Status,LogOnAccount,AccountType, LastReporteddate from OEMSupport..AppPoolBeforePathing (nolock) 
         where ServerName = '$($server)' and format(LastReporteddate,'MM/dd/yyyy HH:mm') in (Select MAX(format(LastReporteddate,'MM/dd/yyyy HH:mm')) 
         from OEMSupport..AppPoolBeforePathing where ServerName = '$($server)')"); $Rows = ExecuteSqlQuery -Query $ApppoolQuery -Server $DBServer
         Try{
            ForEach($DBAppPool in $Rows){
                ForEach($AppPool in $AppPool){
                    IF($AppPool.AppPoolName -eq $DBAppPool.AppPoolName){
                        IF($AppPool.Status -ne $DBAppPool.Status) {
                            Write-host "$($AppPool.AppPoolName) status {$($AppPool.Status)} is not matching with before patching App Pool status {$($DBAppPool.Status)}. Applying the change."
                             Try{    
                                switch ($DBAppPool.Status){
                                'Started' { "Starting Apppool";Invoke-Command -ComputerName $Server -ScriptBlock $AppPoolAction -ArgumentList (,$DBAppPool.AppPoolName, 'Start') -Credential $credential }
                                 'Stoped' { "Stopping Apppool";Invoke-Command -ComputerName $Server -ScriptBlock $AppPoolAction -ArgumentList (,$DBAppPool.AppPoolName, 'Stop') -Credential $credential }
                                }}
                            catch{"Failed to pull the Before Patching Status from DB";$flag = 1}} 
                        Else{"{$($AppPool.AppPoolName)} Application Pool status is same as before patching..."}
                        $flag=0}
            }}}catch{"Failed to peform the Status change operations.";$flag = 1}}}
Catch
{"Failed to peform the Status change operations.";$flag = 1}
$host.SetShouldExit($flag)
exit 
