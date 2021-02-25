param ([Parameter(Mandatory=$true, Position=0, HelpMessage='Please provide the SQL Listiner Name')] [string] $ServerName)   
$servers = @(Type $ServerName)
$flag = 1

$Pass = "*************" | ConvertTo-SecureString -AsPlainText -Force; $Account='redmond\lpoaasvc'
$credential = [System.Management.Automation.PSCredential]::new($Account, $Pass)

$DBServer ='i07oemsqldevops.northamerica.corp.microsoft.com'
$conn = New-Object System.Data.SqlClient.SqlConnection("Data Source=$($DBServer);Integrated Security=SSPI;Initial Catalog=OEMSupport")
$cmd = New-Object System.Data.SqlClient.SqlCommand
$AppPool=@()
$Details = @()

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
            $AppPool = Invoke-Command -ComputerName $server -ScriptBlock $AppPoolStatus -Credential $credential

            foreach($App in $AppPool)
            {
                if($conn.State -eq [Data.ConnectionState]::Open) {$conn.Close()}
                $conn.Open()
                $cmd.connection = $conn
                Try
                {
                    if($App.accountName -ne "" -and $App.accountName -ne $null)
                    {
                        $cmd.commandtext = "INSERT INTO OEMSupport.dbo.AppPoolBeforePathing (ServerName, AppPoolName, Status, LogonAccount, AccountType) values ('{0}','{1}','{2}','{3}','{4}')"`
                        -f $($Server), $($app.AppPoolName), $($app.Status), $($app.AccountName),$($app.AccountType)
                        $cmd.executenonquery()
                        $conn.Close()
                        $flag = 0

                        $Details +=New-Object -TypeName PSObject -Property @{
                        Server = $server
                        AppPoolStatus = "App Pool{$($app.AppPoolName)} Status captured on DB"}
                    }
                    
                }
                catch
                {
                    $flag=1
                    $Details +=New-Object -TypeName PSObject -Property @{
                    Server = $server
                    AppPoolStatus = "App Pool {$($app.AppPoolName)} Status Failed to captured into DB"}
                }
            }
        }
        catch
        {
            "Failed to pull App pool Status"; 
            $flag = 1
            $Details +=New-Object -TypeName PSObject -Property @{
                        Server = $server
                        ServiceStatus = "App Pool {$($app.AppPoolName)} Status Failed to Pull"}
        }

    }
    $details
}
catch
{
    $flag=1
    $Details +=New-Object -TypeName PSObject -Property @{
    Server = $server
    ServiceStatus = "App Pool {$($app.AppPoolName)} Status Failed to Pull"}
}
$host.SetShouldExit($flag)
exit 