#Author : Nitin Gupta
#Description : This Script will fetch Local SQL Server members and respective SQL Server role and store in SQL Table
#
#Table Structure
#CREATE TABLE [dbo].[SQLGrpMember](
#	[ServerName] [varchar](200) NULL,
#	[PCDomain] [varchar](200) NULL,
#	[RoleName] [varchar](200) NULL,
#	[MemberName] [varchar](200) NULL,
#	[MemberDomain] [varchar](100) NULL,
#	[TimeStamp] [datetime] NULL
#) ON [PRIMARY]
#
#GO
#
#ALTER TABLE [dbo].[SQLGrpMember] ADD  DEFAULT (getdate()) FOR [TimeStamp]
#GO

$DBServer = ('serverdb1') #Repository DB where we're capturing results
$SQLServers = ('server1') #Target Servers

$SQLServers | % {
    Write-host "Target Server : $($_)"
    Start-Job -ScriptBlock {
    Param($SQLServer, $DBServer)
    $Query="
    SELECT @@SERVERNAME [ServerName], DEFAULT_DOMAIN()[PCDomain], role.name AS RoleName, member.name AS MemberName, SUBSTRING(member.name,0,CHARINDEX('\',member.name,0)) AS [MemberDomain]
    FROM sys.server_role_members as Mem JOIN sys.server_principals AS role ON Mem.role_principal_id = role.principal_id  
    JOIN sys.server_principals AS member ON Mem.member_principal_id = member.principal_id"; 

    Function ExecuteSqlQuery ($Query, $SQLServer) { 
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
    }; $Rows = ExecuteSqlQuery -Query $Query -Server $DBServer

    ForEach($Res in $Rows)
    {
        If($res.ServerName -ne $null)
        {
            $Insert = "Insert into Projects..SQLGrpMember (ServerName, PCDomain, RoleName, MemberName, MemberDomain) Values ('$($Res.ServerName)','$($Res.PCDomain)','$($Res.RoleName)','$($Res.MemberName)','$($Res.MemberDomain)')"
            ExecuteSqlQuery -Query $Insert -Server $DBServer
        }
    }
    } -ArgumentList $_,$DBServer
} | Wait-Job | Receive-Job 
