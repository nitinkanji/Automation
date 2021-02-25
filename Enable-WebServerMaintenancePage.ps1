$DatabaseServer='i07oemsqldevops.northamerica.corp.microsoft.com'; $Database='OEMBCDR'; $LoggingTable = 'Operations'; $ErrorTable='Exceptions'
$Pass = "************" | ConvertTo-SecureString -AsPlainText -Force ; $Account='redmond\lpoaasvc'
$credential = [System.Management.Automation.PSCredential]::new($Account, $Pass)

Try
{
    #SQL Connection
    $connection=New-Object -TypeName System.Data.SqlClient.SqlConnection
    $connection.ConnectionString="Server=$DatabaseServer;Database=$Database;Integrated Security=true"
    $connection.Open()
    $command=New-Object -TypeName System.Data.SqlClient.SqlCommand
    $command.Connection=$connection

    #Server List
    $servers = Get-Content 'E:\OEM BCDR\FY16_Prod_BCDR_Scripts\Enable_Maintenance_Page\WebServers_OAWEBUI.txt' #Web Servers List where we want to enable maintenance page

    #User Confirmation
    $obj=New-Object -ComObject wscript.shell
    $result=$obj.popup("Are you sure you want to enable the maintenance mode on $Servers ?",0,"Warning",4);
}
Catch 
{
    Write-Host -ForegroundColor Cyan "Connection Failed {$($DatabaseServer)}, Error : {$($Error[0])}"
    break
}

#Function to capture Exceptions
Function InsertIntoExceptions($service,$server,$exception) {
    $command.CommandText="insert into $ErrorTable values(@Operation,@ServerName,@Exception,@Date)"
    $command.Parameters.Clear()
    $date=(Get-Date).ToUniversalTime()
    $command.Parameters.Add((New-Object -TypeName System.Data.SqlClient.SqlParameter("@Operation",[System.Data.SqlDbType]::NVarChar)))|Out-Null
    $command.Parameters.Add((New-Object -TypeName System.Data.SqlClient.SqlParameter("@ServerName",[System.Data.SqlDbType]::NVarChar)))|Out-Null
    $command.Parameters.Add((New-Object -TypeName System.Data.SqlClient.SqlParameter("@Exception",[System.Data.SqlDbType]::NVarChar)))|Out-Null
    $command.Parameters.Add((New-Object -TypeName System.Data.SqlClient.SqlParameter("@Date",[System.Data.SqlDbType]::DateTime)))|Out-Null
    $command.Parameters[0].value="Enabling maintenance mode on $server"
    $command.Parameters[1].value=$server
    $command.Parameters[2].value=$exception
    $command.Parameters[3].value=$date
    $command.ExecuteNonQuery()
    $command.Parameters.Clear()
}

#Function to capture Activities
Function InsertIntoOperations($service,$server,$startdate,$enddate, $msg) {
    $command.CommandText = "insert into $LoggingTable values(@Operation,@ServerName,@StartDate,@EndDate)"
    $command.Parameters.Add((New-Object -TypeName System.Data.SqlClient.SqlParameter("@Operation",[System.Data.SqlDbType]::NVarChar)))|Out-Null
    $command.Parameters.Add((New-Object -TypeName System.Data.SqlClient.SqlParameter("@ServerName",[System.Data.SqlDbType]::NVarChar)))|Out-Null
    $command.Parameters.Add((New-Object -TypeName System.Data.SqlClient.SqlParameter("@StartDate",[System.Data.SqlDbType]::DateTime)))|Out-Null
    $command.Parameters.Add((New-Object -TypeName System.Data.SqlClient.SqlParameter("@EndDate",[System.Data.SqlDbType]::DateTime)))|Out-Null
    
    $command.Parameters[0].value=$msg
    $command.Parameters[1].value=$Server
    $command.Parameters[2].value=$startdate
    $command.Parameters[3].value=$enddate
    
    $command.ExecuteNonQuery()
    $command.Parameters.Clear()
}

    
    #Function Validate WebCofig
    $validate = {
        Param($WebConfig)
        $xmldoc=New-Object System.Xml.XmlDocument
        $xmldoc.Load($WebConfig)
    
        $mtc=$xmldoc.GetElementsByTagName("Maintenance")[0]
        $mode=$mtc.Attributes["Mode"].Value
        $start=$mtc.Attributes["StartDate"].Value
        $end=$mtc.Attributes["EndDate"].Value
    
        if($mode -eq "Enabled" -and $start -eq $StartDate -and $end -eq $EndDate)
        {return $true}
        else
        {return $false}
    }

    #Putting Web into Maintenance Mode
    $WebMaintenance = {
        Param ($WebConfig, $WebConfigBackup, $StartDate, $Enddate, $userResponse, $server)
    
        Try
        {
            If($userResponse -eq 6)
            {
                if($Server -eq $null)
                {
                    break
                }
                $obj=new-object -ComObject wscript.shell
                $startd=(Get-Date).ToUniversalTime()

                #Updating Web Config 
                $doc=new-object System.Xml.XmlDocument
                $doc.Load($webconfig)
                $doc.Save($WebConfigBackup)
            
                $maintenance=$doc.GetElementsByTagName("Maintenance")[0];
                $maintenance.Attributes["Mode"].Value="Enabled"
                $maintenance.Attributes["StartDate"].Value=$start
                $maintenance.Attributes["EndDate"].Value=$end

                $doc.Save($webconfig)
            }
            $Response = "Success"
        }
        catch
        {
            $Response = "Failed"
        }
    return $Response
    }
    $WebCg = "$directory\web.config"
    $bkpWebCg = "$directory\web_DR_FO_Backup.config"

    $WebCngs = @(
        [PSCustomObject]@{WebConfig = "D:\OEMIT\UI.Web\Web.Config";  bkpWebConfig = "D:\OEMIT\UI.Web\web_DR_FO_Backup.config"},
        [PSCustomObject]@{WebConfig = "D:\inetpub\wwwroot\Web.Config";  bkpWebConfig = "D:\inetpub\wwwroot\web_DR_FO_Backup.config"})

    Try
    { 
        foreach($server in $servers)
        {
            foreach($web in $WebCngs)
            {
                if(Test-Path $We.webConfig)
                {
                    $MaintenanceResult = Invoke-Command -ComputerName $server -ScriptBlock $WebMaintenance -ArgumentList $WebCg, $bkpWebCg,$StartDate,$EndDate,$result,$server -Credential $credential
                    $validation = Invoke-Command -ComputerName $server -ScriptBlock $validate -ArgumentList $WebCg -Credential $credential

                    if($validation -eq $true -and $MaintenanceResult -eq 'Success')
                    {
                $resulttext+= " $server,"
                $obj.popup("Maintenance mode has been enabled successfully on $Server",0,"Information",0);
                InsertIntoOperations "" $Server $startd $endd
            }
                    else
                    {
                $obj.popup("Maintenance mode could not be enabled on $Server",0,"Information",0);
                InsertIntoExceptions "Failed to edit web.config" $Server "Failed to edit web.config"
                continue;
            }
    
                    $text=$resulttext.Remove($resulttext.Length-1,1);
                    $obj.popup("Maintenance mode enabled successfully on $text",0,"Information",0);
                }}
        }
    }
    catch
    {
        $obj.popup("The below exception occured $_.Exception.Message",0,"Warning",0);
        InsertIntoExceptions "" $Server $_.Exception.Message
    }