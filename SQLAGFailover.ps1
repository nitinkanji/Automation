param ([Parameter(Mandatory=$true, Position=0)][string] $ServerName)
$Server = @(Type $ServerName)

$AGFailover =
{
        Param ($Server)
        [void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")

        $flagValue =0
        $AGPrimaryServer = New-Object Microsoft.SqlServer.Management.Smo.Server $server
        $AGPrimaryServer.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.AvailabilityGroup], $true)
        $AGPrimaryServer.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.AvailabilityReplica], $true)
        $AGPrimaryServer.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.DatabaseReplicaState], $true)
        $agGROUPnAME=@($AGPrimaryServer.AvailabilityGroups.Name)

        $AgReplicaStates=$AGPrimaryServer.AvailabilityGroups[$agGROUPnAME].AvailabilityReplicas | Select-Object Name,Role,Failovermode,ConnectionState,Memberstate,AVailabilitymode

        $Roles=$AGPrimaryServer.AvailabilityGroups[$AGPrimaryServer.AvailabilityGroups.Name]| Select-Object Name,PrimaryReplicaServerName,State |ft -AutoSize

                if(@($AGPrimaryServer.AvailabilityGroups[$agGROUPnAME].AvailabilityReplicas.Name) -contains ($SERVER.split(".")[0]) -and $AGPrimaryServer.AvailabilityGroups[$AGPrimaryServer.AvailabilityGroups.Name].PrimaryReplicaServerName -eq ($SERVER.split(".")[0]))
                 {
                     Write-host "Primary Server - [$server]." -BackgroundColor yellow -ForegroundColor Black
                     
                     $tofailoverlist=@($AgReplicaStates | Where-Object { ($AgReplicaStates.role -eq 'Secondary' -and ($SERVER.split(".")[0]) -ne  $_.Name) -and $_.AVailabilitymode -eq 'SynchronousCommit' -and $_.FailoverMode -eq 'Automatic'}|Select-Object @{Name='Name';e={$_.Name}},Failovermode,AVailabilitymode)
                     $Tofailover = New-Object Microsoft.SqlServer.Management.Smo.Server $tofailoverlist.Name
                     try
                     {
                        Write-Host "1....Initiating the Failover to Target Node : $Tofailover" -ForegroundColor Cyan
                        $Tofailover.AvailabilityGroups[$Tofailover.AvailabilityGroups.Name].Failover()

                        Start-Sleep -Seconds 30

                        Write-Host "2....Failover completed to Target Node : $Tofailover" -ForegroundColor Cyan
                        $AGPrimaryServer.AvailabilityGroups[$agGROUPnAME].DatabaseReplicaStates|Select-Object AvailabilityReplicaServerName,AvailabilityDatabaseName,SynchronizationState | Format-Table -AutoSize
                        $AGPrimaryServer.AvailabilityGroups[$agGROUPnAME].AvailabilityReplicas |Select-Object Name,Role, ConnectionState, OperationalState | Format-Table -AutoSize

                        $flagValue =0
                     }
                     catch{$flagValue =2}
                 }
                else{$flagValue =1}
        
        Return $flagValue

     }

Try
{
   $flag = Invoke-Command -ComputerName $Server -Credential redmond\lpoaasvc -ScriptBlock $AGFailover -ArgumentList $Server
}
catch{$Flag = 1}
$host.SetShouldExit($flag)
exit
