# Title  : Service Account usage report
# Author : Nitin K. Gupta 
#
# Description : For better manageability\operation\maintenance support it is always good to have service accounts details including 
# where it has been used in your target servers;  This script will help you to scan given servers list parallels (Multithreading) and 
# generate consolidated report with service account usage details in one go.
#
# Jus specify the servers list either through .txt file or directly in variable

$scriptPath = Split-Path -parent $MyInvocation.MyCommand.Definition
start-transcript -path ($scriptPath + "\ServiceAccountScan_" + ([DateTime]::Now.ToString("MMddyyyyHHmmss"))+".txt") -noclobber

$Servers = ('I07OPDBSVCAPP1.partners.extranet.microsoft.com',
'I07OPDBSVCAPP2.partners.extranet.microsoft.com',
'I01OPDBSVCAPP1.partners.extranet.microsoft.com',
'I01OPDBSVCAPP2.partners.extranet.microsoft.com',
'I07OPDCSQLCIS1.northamerica.corp.microsoft.com',
'I01OPDCSQLCIS1.northamerica.corp.microsoft.com',
'I07OPDBSQLCOR1.partners.extranet.microsoft.com',
'I07OPDBSQLCOR2.partners.extranet.microsoft.com',
'I01OPDBSQLCOR1.partners.extranet.microsoft.com',
'I01OPDBSQLCOR2.partners.extranet.microsoft.com',
'I07OPDCSQLDM1.northamerica.corp.microsoft.com',
'I07OPDCSQLDM2.northamerica.corp.microsoft.com',
'I01OPDCSQLDM1.northamerica.corp.microsoft.com',
'I07OPDFWEBDOC1.partners.extranet.microsoft.com',
'I07OPDFWEBDOC2.partners.extranet.microsoft.com',
'I01OPDFWEBDOC1.partners.extranet.microsoft.com',
'I01OPDFWEBDOC2.partners.extranet.microsoft.com',
'I07OPCSQLDSS1.northamerica.corp.microsoft.com',
'I07OPCSQLDSS2.northamerica.corp.microsoft.com',
'I01OPDCSQLDSS1.northamerica.corp.microsoft.com',
'I07OPDBFILFSA1.partners.extranet.microsoft.com',
'I07OPDBFILFSA2.partners.extranet.microsoft.com',
'I01OPDBFILFSA1.partners.extranet.microsoft.com',
'I01OPDBFILFSA2.partners.extranet.microsoft.com',
'I07OPDFWEBMOO1.partners.extranet.microsoft.com',
'I07OPDFWEBMOO2.partners.extranet.microsoft.com',
'I01OPDFWEBMOO1.partners.extranet.microsoft.com',
'I01OPDFWEBMOO2.partners.extranet.microsoft.com',
'I07OPDCSVCMQ1.northamerica.corp.microsoft.com',
'I07OPDCSVCMQ2.northamerica.corp.microsoft.com',
'I01OPDCSVCMQ1.northamerica.corp.microsoft.com',
'I01OPDCSVCMQ2.northamerica.corp.microsoft.com',
'I07OPDBSQLPRS1.partners.extranet.microsoft.com',
'I07OPDBSQLPRS2.partners.extranet.microsoft.com',
'I01OPDBSQLPRS1.partners.extranet.microsoft.com',
'I01OPDBSQLPRS2.partners.extranet.microsoft.com',
'I07OPDCSQLRPD1.northamerica.corp.microsoft.com',
'I07OPDCSQLRPD2.northamerica.corp.microsoft.com',
'I01OPDCSQLRPD1.northamerica.corp.microsoft.com',
'I07OPDBSQLRPL1.partners.extranet.microsoft.com',
'I07OPDBSQLRPL2.partners.extranet.microsoft.com',
'I01OPDBSQLRPL1.partners.extranet.microsoft.com',
'I07OPDBSQLRPT1.partners.extranet.microsoft.com',
'I07OPDBSQLRPT2.partners.extranet.microsoft.com',
'I01OPDBSQLRPT1.partners.extranet.microsoft.com',
'I01OPDBSQLRPT2.partners.extranet.microsoft.com',
'I07OPDCSQLSRS1.northamerica.corp.microsoft.com',
'I07OPDCSQLSRS2.northamerica.corp.microsoft.com',
'I07OPDBWEBSRS1.partners.extranet.microsoft.com',
'I07OPDBWEBSRS2.partners.extranet.microsoft.com',
'I01OPDCSQLSRS1.northamerica.corp.microsoft.com',
'I01OPDCSQLSRS2.northamerica.corp.microsoft.com',
'I01OPDBWEBSRS1.partners.extranet.microsoft.com',
'I01OPDBWEBSRS2.partners.extranet.microsoft.com',
'I07OPDBSQLUI1.partners.extranet.microsoft.com',
'I07OPDBSQLUI2.partners.extranet.microsoft.com',
'I01OPDBSQLUI1.partners.extranet.microsoft.com',
'I01OPDBSQLUI2.partners.extranet.microsoft.com',
'I07OPDBSQLWHS1.partners.extranet.microsoft.com',
'I07OPDBSQLWHS2.partners.extranet.microsoft.com',
'I01OPDBSQLWHS1.partners.extranet.microsoft.com',
'I01OPDBSQLWHS2.partners.extranet.microsoft.com',
'I07OPDFOAWEB1.partners.extranet.microsoft.com',
'I07OPDFOAWEB2.partners.extranet.microsoft.com',
'I07OPDFOAWEB3.partners.extranet.microsoft.com',
'I07OPDFOASVC1.partners.extranet.microsoft.com',
'I07OPDFOASVC2.partners.extranet.microsoft.com',
'I07OPDFOASVC3.partners.extranet.microsoft.com',
'I07OPDBOAAPP1.partners.extranet.microsoft.com',
'I07OPDBOAAPP2.partners.extranet.microsoft.com',
'I07OPDBOAAPP3.partners.extranet.microsoft.com',
'I07OPDBOAAPP4.partners.extranet.microsoft.com',
'I07OPDBOAAPP5.partners.extranet.microsoft.com',
'CO1OEMPSQLOA3.partners.extranet.microsoft.com',
'CO1OEMPSQLOA4.partners.extranet.microsoft.com',
'I07OPDBOAIS1.partners.extranet.microsoft.com',
'I07OPDBOACCH1.partners.extranet.microsoft.com',
'I07OPDCSQLRDS1.northamerica.corp.microsoft.com',
'I07OPDCBAMRS1.northamerica.corp.microsoft.com',
'I07OPDBRAAPP1.partners.extranet.microsoft.com',
'I07OPDBRAAPP2.partners.extranet.microsoft.com',
'I04OPDFOASVC1.partners.extranet.microsoft.com',
'I04OPDFOASVC2.partners.extranet.microsoft.com',
'I04OPDFOASVC3.partners.extranet.microsoft.com',
'I04OPDBOAAPP1.partners.extranet.microsoft.com',
'I04OPDBOAAPP2.partners.extranet.microsoft.com',
'I04OPDBOAAPP3.partners.extranet.microsoft.com',
'I04OPDBOAAPP4.partners.extranet.microsoft.com',
'I04OPDBOAAPP5.partners.extranet.microsoft.com',
'DB3OEMPSQLOA3.partners.extranet.microsoft.com',
'DB3OEMPSQLOA4.partners.extranet.microsoft.com',
'I04OPDBOAIS1.partners.extranet.microsoft.com',
'I04OPDBOACCH1.partners.extranet.microsoft.com',
'I01OPDFOAWEB1.partners.extranet.microsoft.com',
'I01OPDFOAWEB2.partners.extranet.microsoft.com',
'I01OPDFOAWEB3.partners.extranet.microsoft.com',
'I01OPDBOAAPP1.partners.extranet.microsoft.com',
'I01OPDBOAAPP2.partners.extranet.microsoft.com',
'I01OPDBOAAPP3.partners.extranet.microsoft.com',
'I01OPDBOAAPP4.partners.extranet.microsoft.com',
'I01OPDBOAAPP5.partners.extranet.microsoft.com',
'CY1OEMPDSQLOA1.partners.extranet.microsoft.com',
'CY1OEMPDSQLOA2.partners.extranet.microsoft.com',
'I01OPDBOAIS1.partners.extranet.microsoft.com',
'I01OPDBOACCH1.partners.extranet.microsoft.com',
'I01OPDCSQLRDS01.northamerica.corp.microsoft.com',
'I01OPDBRAAPP1.partners.extranet.microsoft.com',
'I01OPDBRAAPP2.partners.extranet.microsoft.com')

$credential = Get-Credential

#$Servers = Get-Content $path
Write-Host "Start Time : $(get-date)"

$Servers | % {
Start-Job -ScriptBlock{
    param($server, $credential)
    $r=@()

    Write-Host -ForegroundColor Cyan   "========================Scanning : {$server}========================"
    Write-Host ""

    $r += Invoke-Command -ComputerName $server -ScriptBlock {
    param($server)
    Try
    {
        $TaskSystemAccounts = 'INTERACTIVE','NT AUTHORITY\SYSTEM', 'SYSTEM', 'NETWORK SERVICE', 'LOCAL SERVICE', 'Run As User', 'Authenticated Users', 'Users', 'Administrators', 'Everyone', ''
        $TaskFilter = { $TaskSystemAccounts -notcontains $_.'Run As User' }
        $details=@()
        Invoke-Expression "SCHTASKS /QUERY /FO CSV /V" -EA SilentlyContinue | ConvertFrom-CSV | Where-Object $TaskFilter | ForEach-Object {
        $details +=New-Object -TypeName PSObject -Property @{
        Type = 'Task'
        Name = $_.TaskName
        Account = $_.'Run As User'
        Server = $Server } | Select-Object Type, Name, Account, Server}

        If($details)
        {
            $details |select Type, Name, Account,server | format-table -AutoSize
        }
        else {"No Tasks found"}
    }
    catch {Write-Host -ForegroundColor Red "Error :  $($Error[0].Exception.Message)"}
    return $details
} -ArgumentList $server -Credential $credential  #Task -done
    $r += Invoke-Command -ComputerName $server -ScriptBlock {
param($server)
$details =@()
$i = Get-Module WebAdministration 
    If ($i.Name -eq 'WebAdministration')
    {}
    else
    {
        Import-Module WebAdministration -ErrorAction SilentlyContinue
        $i = Get-Module WebAdministration 
    }

    If ($i)
    {
        
        $applicationPools = Get-ChildItem IIS:\AppPools 
        ForEach ($applicationPool in $applicationPools)
        {
            if($applicationPool.ProcessModel.UserName -ne "")
            {
                #Write-host "$($applicationPool.Name) Application Pool using $($applicationPool.ProcessModel.UserName) on Server {$($server)}"
                $details +=New-Object -TypeName PSObject -Property @{
                Type = 'IIS AppPools'
                Name = $applicationPool.Name
                Account = $applicationPool.ProcessModel.UserName
                Server = $server} | Select-Object Type, Name, Account, Server
            }
        }
        $details | Format-Table Type, Name, Account, Server

    }
    else {"IIS Not found"}
    return $details
} -ArgumentList $server -Credential $credential  #AppPools - done 
    $r += Invoke-Command -ComputerName $server -ScriptBlock {
    Param($server)
    Try
    {
        $Response = Get-WMIObject Win32_Service | Where-Object {$_.startname -ne "localSystem" }| Where-Object {$_.startname -ne $null } |Where-Object {$_.startname -ne "NT Service\MSSQLFDLauncher"} `
                            | Where-Object {$_.startname -ne "NT AUTHORITY\LocalService" }| Where-Object {$_.startname -ne "NT AUTHORITY\NetworkService"}| Where-Object {$_.startname -ne "NT Service\SQLTELEMETRY"}`
                            | select startname, name, @{Name = "Server";Expression={$server}}

        if($Response)
        {
             $Responses=@()
             ForEach($res in $Response)
             {
                $Responses +=New-Object -TypeName PSObject -Property @{
                Type    = "Service"
                Name    = $res.Name 
                Account = $res.StartName
                server  = $server
                }
             }
        }
        else
        {"No Service Found with any service account"}
    }
    catch {Write-Host -ForegroundColor Red "Error : $($Error[0].Exception.Message)"}
    return $Responses 
} -ArgumentList $server -Credential $credential  #Service - done
    $r += Invoke-Command -ComputerName $server -ScriptBlock {
    param($server)
    
    Try{
        $comAdmin = New-Object -comobject COMAdmin.COMAdminCatalog
        $apps = $comAdmin.GetCollection(“Applications”)
        $apps.Populate();
        $details=@()
        If($apps)
        {
            ForEach($app in $apps)
            {
                If($app.Value("Identity") -ne 'Interactive User' -and $app.Value("Identity") -ne "LocalSystem")
                {
                    #write-host $app.Name "- using Service Account :" $app.Value("Identity") "on Server {$($server)}" 
                    $details +=New-Object -TypeName PSObject -Property @{
                    Type = 'COM+ Applications'
                    Name = $app.Name
                    Account = $app.Value("Identity")
                    Server = $server} | Select-Object Type, Name, Account, Server
                
                }
            }

            $details | Format-Table Type, Name, Account, Server
        }
        else {write-host "COM+ Application not found on Server"}
    }
    catch{Write-host -ForegroundColor Red "COM+ Application Not found, Details : $($Error[0].Exception.Message)"}
    return $details
    } -ArgumentList $server -Credential $credential  #Com+ Applications - done
    $r += Invoke-Command -ComputerName $server -ScriptBlock {   
    Param($server)
    Try
    {
        [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Web.Administration") | Out-Null 
        Try{
        $iis = new-object Microsoft.Web.Administration.ServerManager
        }catch {write-host "Information: IIS Not Found"; continue}

        $ErrorActionPreference = "stop"
        $registryPath = "HKLM:\SOFTWARE\Microsoft\InetStp\"
    
        Try
        {
            $iisVersion = $(get-itemproperty HKLM:\SOFTWARE\Microsoft\InetStp\).setupstring
        }
        catch [System.Management.Automation.PSArgumentException]
        { 
            write-host  "Argument Missing"; 
            Break
        }
        Catch [System.Management.Automation.ItemNotFoundException]
        {
            write-host "IIS Not Found on {$Server}"; 
            Break
        }
        
        write-host  "Information : $($iisVersion) - Found on server {$($server)}."
    
        Try
        {
            
             $Rows=@()
             $iis.Sites|ForEach-object { $Rows += New-Object -TypeName PSObject -Property @{
                Type    = "IIS Cred"
                Name    = "Web Site {$($_.Name)} - App Pools {$($_.Applications.ApplicationPoolName)}"
                
                Account = "{$($_.Applications.GetWebConfiguration().GetSection("system.webServer/security/authentication/anonymousAuthentication").`
                GetAttributeValue("UserName"))} - AnanomusEnabled {$($_.Applications.GetWebConfiguration().`
                GetSection("system.webServer/security/authentication/anonymousAuthentication").`
                GetAttributeValue("Enabled"))}"
                
                Server  = $server 
                }}           
        }
        catch{
            write-host  "Failure : Unable to Pull IIS Credentials, Exception Details - " -NoNewline
            write-host  $Error[0].Exception.Message
        }
    }
    catch{Write-Host -ForegroundColor Red "Error : $($Error[0].Exception.Message)"}  
    return $Rows
    } -ArgumentList $server -Credential $credential  #IIS WebSite Authentications - done
    $r += Invoke-Command -ComputerName $server -ScriptBlock {
    param($server)
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
        } 
               
        Try{ 
            $SQLStatus = (Get-WmiObject  -Namespace root\cimv2 -Class Win32_Service -EA SilentlyContinue | Where-Object {$_.Name -like "*MSSQLSERVER*" }) 
        }
        Catch{
            write-host $Error[0].Exception.Message
        }
        $Details = @()
        If($SQLStatus){  
            if($SQLStatus.state -eq 'running'){
                TRy{
                $credQuery = "Select cred.name [Name], prox.enabled [Enabled] from  master.sys.credentials cred with (nolock) inner join msdb..sysproxies prox on cred.credential_id = prox.credential_id 
                and prox.enabled = 1"; $Rows = ExecuteSqlQuery -Query $credQuery -Server $server      
                If($Rows){
                      $Responses=@()
                        Foreach($row in $rows){
                            If($row.Name -ne $null){
                                $Responses +=New-Object -TypeName PSObject -Property @{
                                Type    = "SQLProxy"
                                Name    = $row.Name 
                                Account = $row.Name
                                server  = $server}}}}
                else{"No Proxy Account Found"}}
                Catch {write-host  "Error: $($Error[0].Exception.Message)"}}
            else{write-host "SQL Service found in Stopped State";$SQLStatus}}
        else{"No SQL Found on $server"}
        return $Responses
    } -ArgumentList $server -Credential $credential  #SQLProxy - done
    

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
        }
    $dbServer ='nitinkg.fareast.corp.microsoft.com'
    
    ForEach($row in $r)
    {
        if($row.Server -ne $null){
        $query = "Insert into Projects..ServiceAccountUsage (ObjectType,ObjectName,MappedAccount,ServerName) values ('$($row.Type)','$($row.name)','$($row.account)','$($row.Server)')"
        ExecuteSqlQuery -Query $query -Server $dbServer}
    }
    
    $r | Select Type, Name, Account, Server | Format-Table -AutoSize 
    } -ArgumentList $_, $credential
} | Wait-Job | Receive-Job 

Write-Host "End Time : $(get-date)"

Stop-transcript