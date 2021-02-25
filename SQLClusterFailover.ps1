param ([Parameter(Mandatory=$true, Position=0)][string] $ServerName)
$Servers = @(Type $ServerName)

$Pass = "******************" | ConvertTo-SecureString -AsPlainText -Force ; $Account='domain\account'
$credential = [System.Management.Automation.PSCredential]::new($Account, $Pass)

$Drain = 
{
    param ($ActiveNode)
    
    Import-Module FailoverClusters
    
    Write-Host "Start Time : $(Get-Date)"
    write-host -ForegroundColor Cyan "Current Active Node : $ActiveNode"
    Write-Host ""

    #Capturing the Event Logs
    #Write-EventLog -LogName "Application" -Source "ServerMaint" -EventID 101 -EntryType Information -Message "Cluster Drain Operation started for Windows Patching"
    Write-Host "Cluster Drain Operation started for Windows Patching"
    
    $flag = 1
    $computer = get-content env:computername
    $computer = $computer.ToLower()
    $destnode = Get-clusternode | select Name #Pulling vailable Cluster Nodes

    #Failover Initiate if Active Node = TargetNode
    If($ActiveNode -eq $computer)
    {        
        [string]$drainnode = ($destnode.Name -ne $computer) 
        Try
        {
            Get-ClusterGroup | foreach-object `
            {
                If ($_.Name -ne $computer -and $_.State -ne 'offline')
                {
                
                    #Move Cluster groups to other node
                    if((Get-ClusterNode -Name $drainnode).State -eq 'Up')
                    {
                        Write-Host -ForegroundColor Green "Initiating Failover for Cluster Resource [$($_.name) :{CurrentOwner - $($_.OwnerNode)},{CurrentState - $($_.State)}] to $($drainnode)"
                        
                        Move-ClusterGroup -Name $($_.Name) -Node $($drainnode)
                        
                        Write-Host -ForegroundColor Green "Sucess : Cluster Resource [$($_.name) :{CurrentOwner - $($_.OwnerNode)}, {CurrentState - $($_.State)}]"
                        $flag=0
                        Write-Host ""
                    }
                    else
                    {
                        Write-Host -ForegroundColor Cyan "Warning : Destination node {$($drainnode)} is offline. Failover to this node will not initiate."
                    }
                }
                else
                {
                    write-host -ForegroundColor Cyan "Warning : Clsuter Resource [$($_.name) :{CurrentOwner - $($_.OwnerNode)}] is in $($_.State) and will not failover."
                }
            }
            Write-Host "Cluster Drain Operation completed for Windows Patching"
            #Write-EventLog -LogName "Application" -Source "ServerMaint" -EventID 201 -EntryType Information -Message "Cluster Drain Operation completed for Windows Patching"
        }
        catch
        {
            $flag=1
            Write-Host "Exception : $($Error[0].Exception.Message)"
        }
    }
    else
    {
        Write-Host -ForegroundColor Cyan "Information : Failover not require for passive node {$($computer)}, current active node {$($ActiveNode)}."
        $flag=0
    }
    Write-Host "End Time : $(Get-Date)"

return $flag

}

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
                
            }
            return $Dataset.Tables[0] 
        }

Try
{
    Foreach($server in $servers)
    {
        Try
        {
            #Start SQL Virtual Name
            $SQLNode = Invoke-Command -ComputerName $server -ScriptBlock `
            {
                $SQLServer = [net.dns]::Resolve((Get-ClusterResource "SQl server" | Get-ClusterParameter `
                | select Name, Value | ? {$_.Name -eq 'VirtualServerName'}).Value).hostname
                return $SQLServer
            } -Credential $credential
            #End SQL Virtual Name

            #Start Active Cluster Node
            $Query = "Select NodeName FROM sys.dm_os_cluster_nodes where is_current_owner='true'"; 
            $CurrentNode = (ExecuteSqlQuery -Query $Query -Server $SQLNode).NodeName
            $flag = Invoke-Command -ComputerName $server -Credential $credential -ScriptBlock $Drain -ArgumentList $CurrentNode
            #End Active Cluster Node
        }
        catch
        {
            $flag = 1
            Write-Host "Failed for {$($server)}, Error : $($Error[0].Exception)"
        }
    }
}
catch
{
    $flag = 1
    Write-Host "Error : $($Error[0].Exception)"
}

$Host.SetShouldExit($Flag)
exit
