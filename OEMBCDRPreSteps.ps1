[CmdletBinding()]

param(
[string]$Directory, 
[string]$StartDate,
[string]$EndDate)

###################################
# Starting DBConnection and Tables
###################################
$DatabaseServer='i07oemsqldevops.northamerica.corp.microsoft.com'; $Database='OEMBCDR'; $LoggingTable = 'Operations'; $ErrorTable='Exceptions'
$Pass = "C9sKv!xMi#84gH5gY2" | ConvertTo-SecureString -AsPlainText -Force ; $Account='redmond\lpoaasvc'
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
    $servers = Get-Content 'E:\OEM BCDR\FY16_Prod_BCDR_Scripts\Enable_Maintenance_Page\WebServers_OAWEBUI.txt'

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

###################################
# Ending DBConnection and Tables
###################################

#################################
# Starting Maintenance Page Block
#################################

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

#################################
# End Maintenance Page Block
#################################


#################################
# Taking Nodes OOR (SVC,APP,WEB)
#################################

#App & Web Server OOR
#---------------------

#  AUTHOR: Nitin Gupta [nitinkg@microsoft.com]
#  DESCRIPTION : Check Web & App Server LoadBalancer Status and make changes if needed.

$Pass = "***************" | ConvertTo-SecureString -AsPlainText -Force; $Account='redmond\lpoaasvc'
$credential = [System.Management.Automation.PSCredential]::new($Account, $Pass)
$Details=@($null)

$Servers = (
'I07OPDFOAWEB1.partners.extranet.microsoft.com',
'I07OPDFOAWEB2.partners.extranet.microsoft.com',
'I07OPDFOAWEB3.partners.extranet.microsoft.com',
'I07OPDBOAAPP1.partners.extranet.microsoft.com',
'I07OPDBOAAPP2.partners.extranet.microsoft.com',
'I07OPDBOAAPP3.partners.extranet.microsoft.com',
'I07OPDBOAAPP4.partners.extranet.microsoft.com',
'I07OPDBOAAPP5.partners.extranet.microsoft.com'
)

$CheckActive= {
    
    $OEMWebFile = 'd:\inetpub\wwwroot\LoadBalancer\active.txt'
    $OEMAppFile = 'd:\inetpub\wwwroot\Probetest\testpage.aspx'

    if((Test-Path $OEMWebFile) -or (Test-Path $OEMAppFile))
    {
        $flag='Active'
    } 
    else
    {
        $flag='InActive'
    }
    Return $flag
}

$MakeChanges= {
    param ($FileAtion)
    
    $OEMWebFile = 'd:\inetpub\wwwroot\LoadBalancer\active.txt'
    $OEMAppFile = 'd:\inetpub\wwwroot\Probetest\testpage.aspx'

    $InActiveOEMWebFile = 'D:\inetpub\wwwroot\LoadBalancer\Inactive.txt'
    $InActiveOEMAppFile = 'D:\inetpub\wwwroot\Probetest\Intestpage.aspx'

    if($FileAtion -eq 1)
    {
        Write-Host "Adding into Rotation !"
        $result=$null
        if((Test-Path $OEMWebFile) -or (Test-Path $OEMAppFile))
        {
            $result = 'Already Active'
        }
        else
        {
            if(Test-Path $InActiveOEMWebFile)
            {
                Rename-Item $InActiveOEMWebFile -NewName 'Active.txt'
            }
            elseif(Test-Path $InActiveOEMAppFile)
            {
                Rename-Item $InActiveOEMAppFile -NewName 'testpage.aspx'
            }
            $result = 'Action Completed'
        }

       
    }
    elseif($FileAtion -eq 2)
    {
        Write-Host "Taking node out of rotation (OOR)!"
        $result=$null
        if((Test-Path $InActiveOEMAppFile) -or (Test-Path $InActiveOEMWebFile))
        {
            $result = 'Already InActive'
        }
        else
        {
            if(Test-Path $OEMWebFile)
            {
                Rename-Item $OEMWebFile -NewName 'InActive.txt'
            }
            elseif(Test-Path $OEMAppFile)
            {
                Rename-Item $OEMAppFile -NewName 'Intestpage.aspx'
            }
            $result = 'Action Completed'
        }
        
    }
    else
    {
        $result = 'Action Failed'
    }

    return $result
}


Foreach($server in $Servers)
{
    $session = New-PSSession -ComputerName $server -Credential $credential
    $response = Invoke-Command -Session $session -ScriptBlock $CheckActive 
                Remove-PSSession -Session $session

    $Details+=New-Object -TypeName PSObject -Property @{
    Server = $server
    Status = $response}|Select-Object Server,Status
}

$Details | ft -AutoSize

Do
{
    $inputRequest = Read-Host "Want to make any change (Y/N)?"
    If($inputRequest -eq 'Y')
    {
        $read = Read-Host "Enter Server (FQDN) followed by Action Status Code 1 or 2 (1 = Active, 2=InActive)"
    
        if($read.IndexOf(',') -gt 0)
        {
            $action=@($read.Split(','))
                $ActionServer = $action[0]
                    [int]$FileAtion = $action[1]

            $session = New-PSSession -ComputerName $ActionServer -Credential $credential
            $Status  = Invoke-Command -Session $session -ScriptBlock $MakeChanges -ArgumentList $FileAtion
                       Remove-PSSession -Session $session 
        
            Write-Host -ForegroundColor Cyan "Status : {ServerName - $($ActionServer), Status - $($Status)}."   
       
        }
        elseif($read.IndexOf(' ') -gt 0)
        {
            $action=@($read.Split(' '))
                $ActionServer = $action[0]
                    [int]$FileAtion = $action[1]

            $session = New-PSSession -ComputerName $ActionServer -Credential $credential
            $Status  = Invoke-Command -Session $session -ScriptBlock $MakeChanges -ArgumentList $FileAtion
                       Remove-PSSession -Session $session 
        
            Write-Host -ForegroundColor Cyan "Status : {ServerName - $($ActionServer), Status - $($Status)}." 
        }
        else
        {
            Write-Host -ForegroundColor Cyan "Warning : No Action Status Code defined."
        }
    }
    else
    {
        Write-Host "Thanks!"
    }

}while($inputRequest -eq 'Y') 


#End App & Web OOR
#-----------------


#SVC Nodes OOR
#--------------
$Val = wget -Uri https://atmmt/api/v1.0/ltm/vip/az_efl_OASVCPWUS2_80_vs/stats/AZ/EFL/CO1  -UseDefaultCredentials | ConvertFrom-Json 
$nodes = $Val.NodeStats | Select UserNote,Name,StatusEnabledState
$nodes | ForEach-Object # have scope for parallel execution if require
{
    If($_.StatusEnabledState -eq 'enabled')
    {
        $Status = Invoke-WFLTMVIP.ps1 -Activity UPdateNode -NodeName $_.name -VipName 'az_efl_OASVCPWUS2_80_vs' -NetworkType EFL -DataCenter CO1 -Area AZ -Body 
@"
{"Status": "Disabled"}
"@    
        Write-Host -ForegroundColor Cyan "Information : Taking Node {$($_.usernote)} out of rotation from ATM."
        if(($Status.Substring($Status.IndexOf(":")+1,4)).trim() -eq 200)
        {
            
            $timeout = (get-date).AddMinutes(2)
            $i=1
            Write-Host -ForegroundColor Red -BackgroundColor Yellow "Will Restart IIS at $($timeout)"
            while(1)
            {
                $now = (Get-date)
                $Connection = Invoke-Command -ComputerName ([net.dns]::Resolve("$($_.usernote)")).hostname -ScriptBlock {
                                $Counters = @('\Web Service(_total)\Current Connections'); 
                                Get-Counter  -Counter $Counters -MaxSamples 1 -SampleInterval 1 
                                } -Credential $credential
        
                [int]$Active=($Connection.readings).substring($Connection.readings.indexof(":")+1,3)

                if($now -ge $timeout -or $Active -le 0)
                {
                    Write-Host ""
                    Write-Host -ForegroundColor Cyan "Information : Initiating IIS Reset with No force on {$server}."
                    Invoke-Command -ComputerName ([net.dns]::Resolve("$($_.usernote)")).hostname -ScriptBlock {iisreset /noforce} -Credential $credential 
                    return

                }else
                    {
                        $i | % -begin {$msg = "$(get-date) - Active Connections : $($active)"} -process{
                            write-host -nonewline "`r$msg";sleep 1;write-host -nonewline ("" + ("" * $msg.Length));sleep 1
                        }
                    }
            } 
        }
        else
        {
            Write-Host -ForegroundColor Cyan "Failed : $($Status)"
        }
    
   
    }
    else
    {
        Write-Host -ForegroundColor Cyan "$($_.usernote) : is in $($_.StatusEnabledState)"
    }
}

#################################
# ATM Work Flow
#################################

workflow Invoke-WFLTMVIP {
	param
    (       
        [Parameter(Mandatory=$false)]
        [string]$LoggedInUserName,

        [Parameter(Mandatory=$false)]
        [string]$PoolName,

        [Parameter(Mandatory=$false)]
        [string]$NodeName,

        [Parameter(Mandatory=$false)]
        [string]$MemberName,        
             
        [Parameter(Mandatory=$false)]
        [string]$OwnerSGName,

		[Parameter(Mandatory=$false)]
        [string]$Body = "",
		
        [Parameter(Mandatory=$false)]
        [string]$VipName,

        [Parameter(Mandatory=$false)]
        [string]$Area,
    
        [Parameter(Mandatory=$false)]
        [string]$NetworkType,

        [Parameter(Mandatory=$false)]
        [string]$DataCenter,
		        
		[Parameter(Mandatory=$false)]
        [string]$Activity,

        [Parameter(Mandatory=$false)]
        [string]$ValidationOnly,

        [Parameter(Mandatory=$false)]
        [string]$FQDN,
		
		[Parameter(Mandatory=$false)]
        [string]$CNAME
    )

    #region STATIC_VARIABLES
    #------------------------------
    # Declaring All Static Variables Here
    #------------------------------
	
    #DEV - azcusimetmct01
    #UAT - atmmtuat
    #Prod - atmmt
    [string]$BASE_URI = "https://atmmt/api/v1.0"    
    [string]$RUNBOOK_NAME    = 'Invoke-WFLTMVIP' # Name of the current runbook.
    [string]$RUNBOOK_WORKER  = "$ENV:ComputerName"   # Runbook Worker Name
    [hashtable]$SUPPORTED_ACTIVITY_VALUES  = @{
         "LTMDATACENTER"	= "GET"
         "SAGETALLVIPS" = "GET"
         "SAGETALLDEVICE" = "GET"
         "UPDATEPOOL"	= "PUT"
         "UPDATENODE"	= "PUT"
         "CREATEPOOLMEMBER"	= "POST"
         "UPDATEPOOLMEMBER"	= "PUT"
         "DELETEPOOLMEMBER"	= "DELETE"
         "GETALLMONITORS" = "GET"
         "CREATEOWNERSG" = "POST"
         "DELETEOWNERSG" = "DELETE"
         "CREATEVIP"	= "POST"
		 "DELETEVIP"	= "DELETE"
		 "UPDATEVIP"	= "PUT"
		 "GETVIP"	    = "GET"
         "GETALLVIPS"	= "GET"
         "CREATEDNS"	= "POST"
         "DELETEDNS"	= "DELETE" 
		 "CREATECNAME"	= "POST"
         "DELETECNAME"	= "DELETE"
 		} # Hashtable of Activity values and their API Verbs
		
	#------------------------------
    #endregion
	
	#region Runtime Variables
    #------------------------------
    # Declaring All Runtime ( Dynamic ) Variables Here
    #------------------------------

    [bool]$ShouldContinue = $true                         # This variable should be updated as the runbook progresses
	[bool]$Success        = $false                        # This variable should only be manipulated ONCE at the very end of the workflow, based on the final value of $ShouldContinue
    [string]$SmaJobId     = $PSPrivateMetadata.Jobid.Guid #http://technet.microsoft.com/en-us/library/jj129719.aspx
    [string]$ErrorData    = $null                         # This variable should be used to capture any error messages alone the way...
	[string]$TargetVerb   = $null                         # This variable holds the Verb which we in API functions.
	[string]$TargetURI    = $null                         # This variable holds the URI which we in API functions
	
    #------------------------------
    #endregion
	
	#region Input Validations
	#------------------------------
    # We will do all Input Validations Here
    #------------------------------

	# Converting Activity to Upper Case for case identity
    $Activity = InlineScript {  $Activity = $Using:Activity ; $Activity.toUpper(); }

	# Activity Validation
    if($Activity -notin $SUPPORTED_ACTIVITY_VALUES.Keys)
    {
        $ShouldContinue = $false
        $ErrorData += "[E] - The input value for the Activity is not supported."
    }
	
	# Other Validations
	if($ShouldContinue)
	{                
        #SuperAdmin
        if( ($Activity -eq "SAGETALLVIPS") -and ($Area -eq $null -or $NetworkType -eq $null -or $DataCenter -eq $null) )
		{
			$ShouldContinue = $false
        	$ErrorData += "[E] - For Super Admin Get All Vips activity, Area, NetworkType, DataCenter are required."
		}

        #LTMPool
        if( ($Activity -eq "UPDATEPOOL") -and ($Body -eq $null -or $Body -eq "" -or $VipName -eq $null -or $PoolName -eq $null -or $Area -eq $null -or $NetworkType -eq $null -or $DataCenter -eq $null) )
		{
			$ShouldContinue = $false
        	$ErrorData += "[E] - For Update Pool activity, Body, VIPName, PoolName, Area, NetworkType, DataCenter are required."
		}

        #LTMNode
        if( ($Activity -eq "UPDATENODE") -and ($Body -eq $null -or $Body -eq "" -or $VipName -eq $null -or $NodeName -eq $null -or $Area -eq $null -or $NetworkType -eq $null -or $DataCenter -eq $null) )
		{
			$ShouldContinue = $false
        	$ErrorData += "[E] - For Update Node activity, Body, VIPName, NodeName, Area, NetworkType, DataCenter are required."
		}

        #LTMPoolMember
        if( ($Activity -eq "CREATEPOOLMEMBER") -and ($Body -eq $null -or $Body -eq "" -or $VipName -eq $null -or $PoolName -eq $null -or $Area -eq $null -or $NetworkType -eq $null -or $DataCenter -eq $null) )
		{
			$ShouldContinue = $false
        	$ErrorData += "[E] - For Create Pool Member activity, Body, VIPName, PoolName, Area, NetworkType, DataCenter are required."
		}
        if( ($Activity -eq "UPDATEPOOLMEMBER") -and ($Body -eq $null -or $Body -eq "" -or $VipName -eq $null -or $PoolName -eq $null -or $MemberName -eq $null -or $Area -eq $null -or $NetworkType -eq $null -or $DataCenter -eq $null) )
		{
			$ShouldContinue = $false
        	$ErrorData += "[E] - For Update Pool Member activity, Body, VIPName, PoolName, MemberName, Area, NetworkType, DataCenter are required."
		}
        if( ($Activity -eq "DELETEPOOLMEMBER") -and ($VipName -eq $null -or $PoolName -eq $null -or $MemberName -eq $null -or $Area -eq $null -or $NetworkType -eq $null -or $DataCenter -eq $null) )
		{
			$ShouldContinue = $false
        	$ErrorData += "[E] - For Delete Pool Member activity, VIPName, PoolName, MemberName, Area, NetworkType, DataCenter are required."
		}

        #LTMMonitor
        if( ($Activity -eq "GETALLMONITORS") -and ($Area -eq $null -or $NetworkType -eq $null -or $DataCenter -eq $null) )
		{
			$ShouldContinue = $false
        	$ErrorData += "[E] - For Get all Monitors activity, Area, NetworkType, DataCenter are required."
		}

        #LTMVipOwner
        if( ($Activity -eq "CREATEOWNERSG") -and ($Body -eq $null -or $Body -eq "" -or $VipName -eq $null -or $Area -eq $null -or $NetworkType -eq $null -or $DataCenter -eq $null) )
		{
			$ShouldContinue = $false
        	$ErrorData += "[E] - For Update Create Owner Security Group activity, Body, VipName, Area, NetworkType, DataCenter are required."
		}
        if( ($Activity -eq "DELETEOWNERSG") -and ($VipName -eq $null -or $OwnerSGName -eq $null -or $Area -eq $null -or $NetworkType -eq $null -or $DataCenter -eq $null) )
		{
			$ShouldContinue = $false
        	$ErrorData += "[E] - For Update Delete Owner Security Group activity, VIP Name, OwnerSGName, Area, NetworkType, DataCenter are required."
		}

        #LTMVip
		if( ($Activity -eq "CREATEVIP") -and ($Body -eq $null -or $Body -eq "" -or $Area -eq $null -or $NetworkType -eq $null -or $DataCenter -eq $null) )
		{
			$ShouldContinue = $false
        	$ErrorData += "[E] - For Create Activity, Body, Area, NetworkType, DataCenter are required."
		}		
		if( ($Activity -eq "DELETEVIP") -and ($VipName -eq $null -or $Area -eq $null -or $NetworkType -eq $null -or $DataCenter -eq $null) )
		{
			$ShouldContinue = $false
        	$ErrorData += "[E] - For Delete Activity, VIP Name, Area, NetworkType, DataCenter are required."
		}
        if( ($Activity -eq "UPDATEVIP") -and ($Body -eq $null -or $Body -eq "" -or $VipName -eq $null -or $Area -eq $null -or $NetworkType -eq $null -or $DataCenter -eq $null) )
		{
			$ShouldContinue = $false
        	$ErrorData += "[E] - For Update Activity, Body, VIP Name, Area, NetworkType, DataCenter are required."
		}
        if( ($Activity -eq "GETVIP") -and ($VipName -eq $null -or $Area -eq $null -or $NetworkType -eq $null -or $DataCenter -eq $null) )
		{
			$ShouldContinue = $false
        	$ErrorData += "[E] - For Get Vip Activity, VIP Name, Area, NetworkType, DataCenter are required."
		} 
        #DNS
        if(($Activity -eq "CREATEDNS") -and ($Body -eq $null -or $Body -eq "" -or $VipName -eq $null -or $Area -eq $null -or $NetworkType -eq $null -or $DataCenter -eq $null))
        {
            $ShouldContinue = $false
        	$ErrorData += "[E] - For Create DNS Activity, Body, VIP Name, Area, NetworkType, DataCenter are required."
        }    
        if(($Activity -eq "DELETEDNS") -and ($VipName -eq $null -or $Area -eq $null -or $NetworkType -eq $null -or $DataCenter -eq $null))
        {
            $ShouldContinue = $false
        	$ErrorData += "[E] - For Delete DNS Activity, VIP Name, Area, NetworkType, DataCenter are required."
        }  
		#CNAME
        if(($Activity -eq "CREATECNAME") -and ($Body -eq $null -or $Body -eq "" -or $VipName -eq $null -or $Area -eq $null -or $NetworkType -eq $null -or $DataCenter -eq $null))
        {
            $ShouldContinue = $false
        	$ErrorData += "[E] - For Create CNAME Activity, Body, VIP Name, Area, NetworkType, DataCenter are required."
        }    
        if(($Activity -eq "DELETECNAME") -and ($VipName -eq $null -or $CNAME -eq $null -or $Area -eq $null -or $NetworkType -eq $null -or $DataCenter -eq $null))
        {
            $ShouldContinue = $false
        	$ErrorData += "[E] - For Delete CNAME Activity, CNAME, VIP Name, Area, NetworkType, DataCenter are required."
        }  
	}
	
	#endregion
	
	#region Gathering Inputs
	#------------------------------
    # We will try set all input Variables Here
    #------------------------------

	if($ShouldContinue)
	{
		# Verb to be used in API Calls - Post/Get/Delete
		$TargetVerb = $SUPPORTED_ACTIVITY_VALUES[$Activity]
		
		# URI to be used in API calls
        if($Activity -eq "LTMDATACENTER")
        {
            $TargetURI = $BASE_URI+"/ltm/datacenter"
            $Body = $null
        }
        elseif($Activity -eq "SAGETALLVIPS")
		{
			$TargetURI = $BASE_URI+"/superadmin/vip/{0}/{1}/{2}" -f $Area,$NetworkType,$DataCenter
            $Body = $null
		}
        elseif($Activity -eq "SAGETALLDEVICE")
		{
			$TargetURI = $BASE_URI+"/superadmin/ltmdevice"
            $Body = $null
		}
        elseif($Activity -eq "UPDATEPOOL")
		{
			$TargetURI = $BASE_URI+"/ltm/vip/{0}/pool/{1}/{2}/{3}/{4}" -f $VipName,$PoolName,$Area,$NetworkType,$DataCenter
		}
        elseif($Activity -eq "UPDATENODE")
		{
			$TargetURI = $BASE_URI+"/ltm/vip/{0}/node/{1}/{2}/{3}/{4}" -f $VipName, $NodeName,$Area,$NetworkType,$DataCenter
		}
        elseif($Activity -eq "CREATEPOOLMEMBER")
		{
		   if($ValidationOnly -eq 'true' -or $ValidationOnly -eq 'false')
            {
			   $TargetURI = $BASE_URI+"/ltm/vip/{0}/pool/{1}/members/{2}/{3}/{4}?ValidationOnly={5}" -f $VipName,$PoolName,$Area,$NetworkType,$DataCenter,$ValidationOnly  
            }
            else
            {
			    $TargetURI = $BASE_URI+"/ltm/vip/{0}/pool/{1}/members/{2}/{3}/{4}" -f $VipName,$PoolName,$Area,$NetworkType,$DataCenter
            }
		}
        elseif($Activity -eq "UPDATEPOOLMEMBER")
		{
			$TargetURI = $BASE_URI+"/ltm/vip/{0}/pool/{1}/members/{2}/{3}/{4}/{5}" -f $VipName,$PoolName,$MemberName,$Area,$NetworkType,$DataCenter
		}
        elseif($Activity -eq "DELETEPOOLMEMBER")
		{
			$TargetURI = $BASE_URI+"/ltm/vip/{0}/pool/{1}/members/{2}/{3}/{4}/{5}" -f $VipName,$PoolName,$MemberName,$Area,$NetworkType,$DataCenter
            $Body = $null
		}
        elseif($Activity -eq "GETALLMONITORS")
		{
			$TargetURI = $BASE_URI+"/ltm/monitor/{0}/{1}/{2}" -f $Area,$NetworkType,$DataCenter
            $Body = $null
		}
        elseif($Activity -eq "CREATEOWNERSG")
		{
			$TargetURI = $BASE_URI+"/ltm/vip/{0}/owner/{1}/{2}/{3}" -f $VipName,$Area,$NetworkType,$DataCenter
		}
        elseif($Activity -eq "DELETEOWNERSG")
		{
			$TargetURI = $BASE_URI+"/ltm/vip/{0}/owner/{1}/{2}/{3}/{4}" -f $VipName,$OwnerSGName,$Area,$NetworkType,$DataCenter
            $Body = $null
		}
		elseif($Activity -eq "CREATEVIP")
		{
            if($ValidationOnly -eq 'true' -or $ValidationOnly -eq 'false')
            {
			   $TargetURI = $BASE_URI+"/ltm/vip/{0}/{1}/{2}?ValidationOnly={3}" -f $Area,$NetworkType,$DataCenter,$ValidationOnly   
            }else
            {
                $TargetURI = $BASE_URI+"/ltm/vip/{0}/{1}/{2}" -f $Area,$NetworkType,$DataCenter
            }
		}
		elseif($Activity -eq "DELETEVIP")
		{
			$TargetURI = $BASE_URI+"/ltm/vip/{0}/{1}/{2}/{3}" -f $VipName,$Area,$NetworkType,$DataCenter	
            $Body = $null		
		}
        elseif($Activity -eq "UPDATEVIP")
		{
			$TargetURI = $BASE_URI+"/ltm/vip/{0}/{1}/{2}/{3}" -f $VipName,$Area,$NetworkType,$DataCenter			
		}
        elseif($Activity -eq "GETVIP")
		{
			$TargetURI = $BASE_URI+"/ltm/vip/{0}/{1}/{2}/{3}" -f $VipName,$Area,$NetworkType,$DataCenter
            $Body = $null		
		}
        elseif($Activity -eq "GETALLVIPS")
		{
			$TargetURI = $BASE_URI+"/ltm/vip"
            $Body = $null
		}
        elseif($Activity -eq "CREATEDNS")
		{
			$TargetURI = $BASE_URI+"/dns/{0}/{1}/{2}/{3}" -f $VipName,$Area,$NetworkType,$DataCenter            
		} 
        elseif($Activity -eq "DELETEDNS")
		{
			$TargetURI = $BASE_URI+"/dns/{0}/{1}/{2}/{3}" -f $VipName,$Area,$NetworkType,$DataCenter
            $Body = $null
		}
		elseif($Activity -eq "CREATECNAME")
		{
			$TargetURI = $BASE_URI+"/cname/{0}/{1}/{2}/{3}" -f $VipName,$Area,$NetworkType,$DataCenter            
		} 
        elseif($Activity -eq "DELETECNAME")
		{
			$TargetURI = $BASE_URI+"/cname/{0}/vip/{1}/{2}/{3}/{4}" -f $CNAME,$VipName,$Area,$NetworkType,$DataCenter
            $Body = $null
		}
	}
	#endregion
	
	#region Pre-Defined Functions
	#------------------------------
    # Declaring All Pre-Defined Functions Here
    #------------------------------

	function CallAPI()
	{            
	    param
	    (
	        [Parameter(Mandatory=$true)]
	        [string] $uri, 

	        [Parameter(Mandatory=$false)]
	        [string] $body, 

            [Parameter(Mandatory=$false)]
	        [string] $userName,

	        [Parameter(Mandatory=$true)]
	        [string] $verb
	    )
		
		$Result = $false
		$Message = ""
		    
		try 
		{
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"

            if($userName -ne $null -and $userName -ne "")
            {
                $headers.Add("X-TM-LoggedInUserName", $userName)
            }


            #Send body only when its not null or empty
            if($Body -eq "" -or $Body -eq $null)
            {
                $response = Invoke-WebRequest -Uri $uri -UseDefaultCredentials -Method:$verb -ContentType "application/json" -Headers $headers -TimeoutSec 180 -ErrorAction:Stop
            }
            else
            {
    		    $response = Invoke-WebRequest -Uri $uri -UseDefaultCredentials -Method:$verb -Body:$body -ContentType "application/json" -Headers $headers -TimeoutSec 180 -ErrorAction:Stop
            }

			
			if($response -eq $null)
			{
				$response = "[E] : Request Failed - No response from the API. "
			}
			else
			{
				#success status code
	    		$statuscode = $response.StatusCode                           

                Write-Output "StatusCode: $statuscode"                
                Write-Output $response.Content | ConvertFrom-Json | Format-List
			}
            return $response.Content | ConvertFrom-Json
		} 
		catch 
		{
			$ErrorMessage = $_ 		
            $Message = "[E] : Request Failed - $ErrorMessage "

            Write-Output $Message
		}
        return $null
		
	}
	#endregion
	
    #region Implementation
	#------------------------------
    # We will call ATM VIP API here
    #------------------------------

    if($ShouldContinue)
    {
		Write-Output "Calling ATM VIP API with parameters: "
		Write-Output "Verb : $TargetVerb ; $Body"
		Write-Output "URI  : $TargetURI "
        #Write-Output "LoggedInUserName  : $LoggedInUserName "

        try
		{       
            # Case 1: CreateVIP & DNS  
            #      Call CreateVIP followed by CreateDNS
            # Case 2: DelteVIP
            #      Call DeleteDNS followed by DeleteVIP

            # Delete DNS before deleting the VIP
            if($Activity -eq "DELETEVIP" -and $FQDN -ne $null)
            {  
                Write-Output "Calling ATM Delete DNS API with parameters: "
                          
                $deleteDnsUri = $BASE_URI+"/dns/{0}/{1}/{2}/{3}" -f $VipName,$Area,$NetworkType,$DataCenter                
		        Write-Output "URI  : $deleteDnsUri "
	
                CallAPI -uri $deleteDnsUri -body $null -userName $LoggedInUserName -verb $TargetVerb	
            }
                 
			# Call ATM API
            $returnValue = CallAPI -uri $TargetURI -body $Body -userName $LoggedInUserName -verb $TargetVerb	
            $returnValue		
            
            # Create DNS 
            if($Activity -eq "CREATEVIP" -and $FQDN -ne $null -and $returnValue -ne $null)
            {     
                $VipName = $returnValue.Name

                $VipName
                Write-Output "Calling ATM Create DNS API with parameters: "
                                    
                $createDns = $BASE_URI+"/dns/{0}/{1}/{2}/{3}" -f $VipName.Trim(),$Area,$NetworkType,$DataCenter
                Write-Output "URI  : $createDns "

                $Body = @"
"$FQDN"
"@
                CallAPI -uri $createDns -body $Body -userName $LoggedInUserName -verb $TargetVerb
            }
		}
		catch
        {   
            # Catch the Exception thrown in Try block and remove extra line breaks, single quotes or double quotes to make it readable.
            $ErrorMessage = $_ 
            $ShouldContinue = $false
            $ErrorData += "[E] : Request Failed - $ErrorMessage "
        }        
    }

    # Write validation and exception output
    Write-Output $ErrorData

    #endregion	
}

#End SVC Nodes OOR
#-----------------

Finally
{
    $connection.Close()
}

