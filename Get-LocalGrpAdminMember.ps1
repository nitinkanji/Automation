#Author : Nitin Gupta
#Description : This Script will fetch Local groups members and store in SQL Table
#Table Structure
#--------------------------------------
#CREATE TABLE [dbo].[LocalGrpMembers](
#	[Account] [varchar](200) NULL,
#	[GroupName] [varchar](200) NULL,
#	[DomainName] [varchar](200) NULL,
#	[PSComputerName] [varchar](200) NULL,
#	[PCDomain] [varchar](100) NULL,
#	[TimeStamp] [datetime] NULL
#) ON [PRIMARY]
#
#GO
#
#ALTER TABLE [dbo].[LocalGrpMembers] ADD  DEFAULT (getdate()) FOR [TimeStamp]
#GO

$Pass = "********" | ConvertTo-SecureString -AsPlainText -Force ; $Account='redmond\lpoaasvc'
$credential = [System.Management.Automation.PSCredential]::new($Account, $Pass)
$DBServer = 'nitinkg.fareast.corp.microsoft.com'
$Servers =  Get-Content D:\Servers.txt

$servers | % {
    Write-host "Target Server : $($_)"
    Start-Job -ScriptBlock {
    Param($server, $DBServer, $credential)
    $LocalGrpMembers = {
        Param($server)
        $Groups= @(net localgroup)
        [int]$j = ($Groups.Count)- 3

        $Details=@()
        $i=4
        Foreach($grp in $Groups)
        {
            if($i -le ($Groups.Count) -3)
            {
                $users = @(net localgroup $Groups[$i].Substring(1,$Groups[$i].Length-1))
                foreach($user in $users)
                {
                    if($user -notlike "*Successfully*" -and $user -notlike "*Members*" -and $user -notlike "*Alias*"`
                     -and $user -notlike "*DefaultAccount*" -and $user -notlike "*---*" -and $user -ne "" -and $user`
                     -notlike "*Comment*")
                    {

                        If($user.IndexOf("\") -ne -1)
                        {
                            $Domain = $user.Substring(0,$user.IndexOf("\")) 
                        }
                        else{$Domain=$null}

                        $Value = @($Server.Split('.'))
                        $PCDomain = $Value[1]

                        $Details += New-Object PSObject -Property @{
                        Server = $Server
                        Group = $Groups[$i].Substring(1,$Groups[$i].Length-1)
                        User  = $user
                        Domain = $Domain
                        PCDomain = $PCDomain
                        } | Select-Object Server, Group, User, Domain, PCDomain
                    }
                }

                $i++
            }
       
        }
       $Details
    }

    $response = Invoke-Command -ComputerName $server -Credential $credential -ScriptBlock  $LocalGrpMembers -ArgumentList $server
    $Response | Select Server, Group, User, Domain,PCDomain  | Format-Table -AutoSize

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
                    write-host  "SQL Exception: Connection Failure on $($Server)."
                    write-host  "Details: $($Error[0].Exception.Message)."
                    $conn.Close()
                    $flag=1
                }
                return $Dataset.Tables[0] 
            }; 

    ForEach($Res in $Response)
    {
        $Insert = "Insert into Projects..LocalGrpMembers (Account, GroupName, DomainName, PSComputername, PCDomain) Values ('$($Res.User)','$($Res.Group)','$($Res.Domain)','$($Res.Server)','$($Res.PCDomain)')"
        ExecuteSqlQuery -Query $Insert -Server $DBServer
    }
} -ArgumentList $_, $DBServer, $credential } | Wait-Job | Receive-Job  
