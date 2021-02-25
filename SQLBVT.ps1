param ([Parameter(Mandatory=$true, Position=0, HelpMessage='Please provide the SQL Listiner Name')] [string] $ServerName)   
$servers = @(type $ServerName)
$flag = 0

Foreach($Server in $servers)
{

    $SrvcName =@{label="Service Name" ;alignment="left" ;width=20 ; Expression={$_.Name};};
    $SrvcMode =@{label="Start Mode" ;alignment="left" ;width=20 ;Expression={$_.StartMode};};
    $SrvcState =@{label="State" ;alignment="left" ;width=20 ;Expression={$_.State};};
    $SrvcMsg =@{label="Message" ;alignment="left" ;width=50 ; `
    Expression={ if ($_.State -ne "Running") {"Alarm: Stopped"} else {"OK"} };};
    $Rows = $null;  $i = 1; $DT =@()

    Try
    {
        Function ExecuteSqlQuery ($Query, $Server) 
        { 
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
                $flag=1
            }
            return $Dataset.Tables[0] 
        } 

        $SQLList = ExecuteSqlQuery -Query $("Select dns_name [ListenerName] from sys.availability_group_listeners") -Server $Server
        $HostName1 = [net.dns]::Resolve($SQLList.ListenerName)
        $SQLListinerFQDN = [string]$HostName1.HostName


        $SQL   = "SELECT 'Node' AS SITE, R.REPLICA_SERVER_NAME [NODE] FROM SYS.AVAILABILITY_REPLICAS  R JOIN SYS.DM_HADR_AVAILABILITY_REPLICA_STATES  RS ON R.REPLICA_ID = RS.REPLICA_ID LEFT OUTER JOIN SYS.DM_HADR_CLUSTER_MEMBERS CM
	ON CM.MEMBER_NAME = R.REPLICA_SERVER_NAME WHERE CM.NUMBER_OF_QUORUM_VOTES = 1 UNION ALL SELECT 'DRNode' AS SITE, R.REPLICA_SERVER_NAME [NODE]FROM SYS.AVAILABILITY_REPLICAS  R 
	JOIN SYS.DM_HADR_AVAILABILITY_REPLICA_STATES  RS ON R.REPLICA_ID = RS.REPLICA_ID LEFT OUTER JOIN SYS.DM_HADR_CLUSTER_MEMBERS CM
	ON CM.MEMBER_NAME = R.REPLICA_SERVER_NAME WHERE CM.NUMBER_OF_QUORUM_VOTES = 0 UNION ALL SELECT 'CURRENTPRIMARYNODE' AS SITE, RCS.REPLICA_SERVER_NAME [NODE]
	FROM SYS.AVAILABILITY_GROUPS_CLUSTER AS AGC INNER JOIN SYS.DM_HADR_AVAILABILITY_REPLICA_CLUSTER_STATES AS RCS ON RCS.GROUP_ID = AGC.GROUP_ID
	INNER JOIN SYS.DM_HADR_AVAILABILITY_REPLICA_STATES AS ARS ON ARS.REPLICA_ID = RCS.REPLICA_ID INNER JOIN SYS.AVAILABILITY_GROUP_LISTENERS AS AGL
	ON AGL.GROUP_ID = ARS.GROUP_ID WHERE ARS.ROLE_DESC = 'PRIMARY' UNION ALL Select 'ListenerName' as site, dns_name [ListenerName] from sys.availability_group_listeners
	UNION ALL SELECT 'CLUSTERNAME' AS SITE, CLUSTER_NAME [NODE] FROM SYS.DM_HADR_CLUSTER
	UNION ALL SELECT 'AGNAME' AS SITE , NAME AS [NODE] FROM SYS.AVAILABILITY_GROUPS_CLUSTER
	UNION ALL SELECT 'OSVersion' AS SITE, windows_release FROM sys.dm_os_windows_info
	UNION ALL SELECT 'Domain' AS SITE, DEFAULT_DOMAIN()[DomainName]
	UNION ALL SELECT 'QuorumType' as Site, quorum_type_desc from sys.dm_hadr_cluster
	union all SELECT 'SQL Server' as Site,'SQL Server '+cast(SERVERPROPERTY('productversion')as varchar(20))
	union all SELECT 'SQL SP' as site, SERVERPROPERTY ('productlevel')
	union all SELECT 'SQL Edition' as site, SERVERPROPERTY ('edition')"; $Rows   = ExecuteSqlQuery -Query $SQL   -Server $SQLListinerFQDN
        $AGSQL = "select r.replica_server_name [Nodes], rs.role_desc [AGRole], r.failover_mode_desc [FailoverMode], r.availability_mode_desc [AvailabilityMode], rs.synchronization_health_desc [Health], cm.number_of_quorum_votes [QuorumVotes]
    from sys.availability_replicas  r join sys.dm_hadr_availability_replica_states  rs on r.replica_id = rs.replica_id left outer join sys.dm_hadr_cluster_members cm
    on cm.member_name = r.replica_server_name"; $AGRows = ExecuteSqlQuery -Query $AGSQL -Server $SQLListinerFQDN
        $DBSQL = "select r.replica_server_name [Node], d.name [Database], drs.synchronization_state_desc [DBState], drcs.is_failover_ready [IsFailoverReady] from sys.dm_hadr_database_replica_states drs
              join sys.databases d on drs.database_id = d.database_id join sys.availability_replicas  r on r.replica_id = drs.replica_id join sys.dm_hadr_database_replica_cluster_states drcs
              on drcs.replica_id = r.replica_id and drcs.database_name = d.name where drs.synchronization_state_desc = 'SYNCHRONIZED'
              order by 1, 2"; $DBRows = ExecuteSqlQuery -Query $DBSQL -Server $SQLListinerFQDN
        
        Write-host "******************************************************************"
        Write-host "Initiating SQL BVT for [$($SQLListinerFQDN)]                      "
        Write-host "******************************************************************"
        Write-host ""   
        Write-host -ForegroundColor cyan "1. Pulling SQL Server [$($SQLListinerFQDN)] System Configuration Details.                            " 
   
        ForEach($row in $Rows){ $DT +=($Rows[$i]);$i+=1} #Pulling SQL Infra Details
       
        $PrimaryNode = $DT | Select Site, Node | where {$_.Site -eq 'CURRENTPRIMARYNODE'}
        $ClusterName  = $DT | Select Site, Node | where {$_.Site -eq 'CLUSTERNAME'}

        #Write-host -ForegroundColor Cyan "Active Primary Node : $($PrimaryNode.Node )"
        $DT | Select Site, Node | Format-table -AutoSize

        Write-host -ForegroundColor cyan "2. Pulling SQL Server [$($SQLListinerFQDN)] AG Health Status." 
        $AGRows | select Nodes, AGRole,FailoverMode, AvailabilityMode, Health, QuorumVotes | format-table -autosize #Pulling SQL AG Details
    
        Write-host -ForegroundColor cyan "3. Pulling SQL Server [$($SQLListinerFQDN)] AlwaysON Database Health Status." 
        $DBRows | Select Node, Database, DBState,IsFailoverReady | format-table -autosize # DB Health
                
        Write-host -ForegroundColor cyan "4. Pulling SQL Server [$($SQLListinerFQDN)] Service Health Status of each connected nodes." 
        $i = 0
        write-host ""
        Foreach($r in $AGRows)
        {
       
            if($r.Nodes -ne $null)
            {$i = $i+ 1
                write-host -ForegroundColor cyan "********4.$($i) Pulling $($r.Nodes) Server Service Status."
                try    
                {    
                   $srvc = Get-WmiObject -query "SELECT * FROM win32_service WHERE name LIKE '%MSSQL%' OR name LIKE '%SQL%'" -computername $r.Nodes | Sort-Object -property name;
                   $srvc | Format-Table $SrvcName, $SrvcMode, $SrvcState, $SrvcMsg -AutoSize 
                    
                }
                catch{write-host -ForegroundColor red "Error: $($r.Nodes) unable to connect"; $flag=1}
            }
        }
        write-host ""
        #Get Cluster Details

        if(Get-Module -ListAvailable -Name failoverclusters)
        {
            Write-host "Failovercluster module avilable, can perform cluster related validations."
            Write-Host -ForegroundColor cyan "5. Pulling [$($SQLListinerFQDN)\$($ClusterName.Node)] Cluster Health Status:"
            write-host ""
            
            Try
            {
                    Get-Cluster -Name $ClusterName.Node
                    Get-ClusterNode -Cluster:$ClusterName.Node | select NodeName, NodeWeight,State | Format-table -AutoSize
                    $RG = @(Get-ClusterResource -Cluster:$ClusterName.Node | Get-ClusterOwnerNode)
                    $RS = @(Get-ClusterResource -Cluster:$ClusterName.Node | Select  Name, OwnerNode,State)

                    $ClsuterDependency =@()
                    Write-Host -ForegroundColor cyan "6. Pulling Cluster Resource Node Ownership and Resource State:"
                    $j = 0     
            
                    foreach($r in $RG)
                    {   
                        Foreach($G in $RS)
                        {
                            if($r.ClusterObject -eq $g.Name)
                            {$j= $J+1
                                if($g.State -eq 'Online'){
                                write-host -ForegroundColor Green "*******6.$($j) ClusterResource`t - $($r.ClusterObject):`tOwnerNodes {$($r.OwnerNodes)} ---> Resource State : $($g.state)"
                                }
                                else{write-host -ForegroundColor Red "*******6.$($j) ClusterResource`t - $($r.ClusterObject):`tOwnerNodes {$($r.OwnerNodes)} ---> Resource State : $($g.state)"}
                            }
                        }
                        $ClsuterDependency += Get-ClusterResourceDependency -Cluster $ClusterName.Node -Resource $([string]$r.ClusterObject)
                    }

                    Write-Host -ForegroundColor cyan "7. Gathering Cluster Resource Dependency Expression :"
                    $ClsuterDependency | Format-Table -AutoSize       
                }
            catch 
            {
                    Write-host -foregroundColor red "Exception: CLuster [$($ClusterName.Node)] unable to connect."
                    Write-host -foregroundColor red "Details: $($Error[0].Exception.Message)."
                    $flag=1
                } 
        }
        else
        {
            Import-Module servermanager
            if(Add-WindowsFeature RSAT-Clustering)
            {
                Import-module Failovercluster
                Write-host "Cluster Failover Module Imported sucessfully."

                Write-Host -ForegroundColor cyan "5. Pulling [$($SQLListinerFQDN)\$($ClusterName.Node)] Cluster Health Status:"
                write-host ""
                Try
                {
                    Get-Cluster -Name $ClusterName.Node
                    Get-ClusterNode -Cluster:$ClusterName.Node | select NodeName, NodeWeight,State | Format-table -AutoSize
                    $RG = @(Get-ClusterResource -Cluster:$ClusterName.Node | Get-ClusterOwnerNode)
                    $RS = @(Get-ClusterResource -Cluster:$ClusterName.Node | Select  Name, OwnerNode,State)

                    $ClsuterDependency =@()
                    Write-Host -ForegroundColor cyan "6. Pulling Cluster Resource Node Ownership and Resource State:"
                    $j = 0     
            
                    foreach($r in $RG)
                    {   
                        Foreach($G in $RS)
                        {
                            if($r.ClusterObject -eq $g.Name)
                            {$j= $J+1
                                if($g.State -eq 'Online'){
                                write-host -ForegroundColor Green "*******6.$($j) ClusterResource`t - $($r.ClusterObject):`tOwnerNodes {$($r.OwnerNodes)} ---> Resource State : $($g.state)"
                                }
                                else{write-host -ForegroundColor Red "*******6.$($j) ClusterResource`t - $($r.ClusterObject):`tOwnerNodes {$($r.OwnerNodes)} ---> Resource State : $($g.state)"}
                            }
                        }
                        $ClsuterDependency += Get-ClusterResourceDependency -Cluster $ClusterName.Node -Resource $([string]$r.ClusterObject)
                    }

                    Write-Host -ForegroundColor cyan "7. Gathering Cluster Resource Dependency Expression :"
                    $ClsuterDependency | Format-Table -AutoSize       
                }
                catch 
                {
                    Write-host -foregroundColor red "Exception: CLuster [$($ClusterName.Node)] unable to connect."
                    Write-host -foregroundColor red "Details: $($Error[0].Exception.Message)."
                    $flag=1
                } 
            }
            else{write-host "Failed to import failover cluster module, please check with ServerIM team"}
        }   
    }
    catch
    {
        Write-host -ForegroundColor red "SQL Exception: Connection Failure on $($Server)."
        Write-Host -ForegroundColor red "Details: $($Error[0].Exception.Message)"
        $flag=1
        
    }

    write-host ""
    write-host -ForegroundColor Green "SQL BVT Completed Successfully - $(Get-Date)"
    write-host ""
    Write-host "******************************************************************"
    Write-host "Ending SQL BVT for [$($SQLListinerFQDN)]                          "
    Write-host "******************************************************************"
  
}
#$host.SetShouldExit($flag)
#exit 
$flag


