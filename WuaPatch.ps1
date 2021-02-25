# *************************************************************
# * Windows Update Agent Patching Script
# *
# * @Description: This script is for Microsoft Patching Automation Tool Team
# *
# * @Author:      Peng Di
# * 
# * @Email:       dipeng@microsoft.com
# * 
# * @Last Update: 2017/Aug/17
# *************************************************************

# This script generates logs and return code in C:\wsuslog\

# *******************Return Code*******************************
# Binary bits description of return code from high to low:

# | High                               Low              |
# | 1 bit      | 4 bits | 1 bit      | 2 bits           |
# | b          | bbbb   | b          | bb               |
# | Reserved   | Result | NeedReboot | Param definition |

# Reserved:
# 0 - For reserved use, no meaning

# Result:
# 0000 - Success
# 0001 - Partial success
# 0010 - Need reboot before patch
# 0011 - Failed to connect to wsus server
# 0100 - No updates found
# 0101 - Updates are found, but none of them are installed
# 0110 - Exception while patching
# 0111 - No admin permission

# NeedReboot:
# 0 - No need reboot
# 1 - Need reboot

# Param definition:
# 00 - None of ListOnly or DownloadOnly is set
# 01 - ListOnly
# 10 - DownloadOnly

# Example:
# Return code 12, binary format is 00001100:
# 0          0001              1             00
# Reserved   Partial success   Need reboot   None of ListOnly or DownloadOnly is set
# *************************************************************

#Classifications filter(-CLS, -NOCLS) values and description:
# CU -> Critical updates. Broadly released fixes for specific problems addressing critical, non-security related bugs.
# DU -> Definition updates. Updates to virus or other definition files.
# DR -> Drivers. Software components designed to support new hardware.
# FP -> Feature packs. New feature releases, usually rolled into products at the next release.
# SU -> Security updates. Broadly released fixes for specific products, addressing security issues.
# SP -> Service packs. Cumulative sets of all hotfixes, security updates, critical updates, and updates created since the release of the product. Service packs might also contain a limited number of customer-requested design changes or features.
# TL -> Tools. Utilities or features that aid in accomplishing a task or set of tasks.
# UR -> Update rollups. Cumulative set of hotfixes, security updates, critical updates, and updates packaged together for easy deployment. A rollup generally targets a specific area, such as security, or a specific component, such as Internet Information Services (IIS).
# UP -> Updates. Broadly released fixes for specific problems addressing non-critical, non-security related bugs.

# Usage 1: Install all available updates
# WuaPatch.ps1

# Usage 2: Install updates specified by KB number
# WuaPatch.ps1 -ONLYQFE KB3115257
# WuaPatch.ps1 -ONLYQFE {KB3115257 KB313463}

# Usage 3: Install KB specified updates and mandatory updates
# WuaPatch.ps1 -QFE {KB3115257 KB313463}

# Usage 4: Install without KB specified updates
# WuaPatch.ps1 -NOQFE KB3115257
# WuaPatch.ps1 -NOQFE {KB3115257 KB313463}

# Usage 5: Install updates update to release
# WuaPatch.ps1 -UTR 201112

# Usage 6: Install updates except SQL Server
# WuaPatch.ps1 -NOSQL

# Usage 7: List updates without download and install
# WuaPatch.ps1 -ListOnly

# Usage 8: Download updates without install
# WuaPatch.ps1 -DownloadOnly

# Usage 9: Install updates, if reboot is required after installation, auto reboot.
# WuaPatch.ps1 -AutoReboot

# Usage 10: Install updates within specified classifications:
# WuaPatch.ps1 -CLS CU
# WuaPatch.ps1 -CLS {SU SP}

# Usage 11: Install updates without specified classifications:
# WuaPatch.ps1 -NOCLS CU
# WuaPatch.ps1 -NOCLS {SU SP}


[CmdletBinding()]
Param
(
    #Mode options
    [Switch]$ListOnly,

    [Switch]$DownloadOnly,

    [Switch]$AutoReboot,

    #Patch options

    #Installs ONLY user supplied QFE(s)
    [String]$ONLYQFE,

    #Installs mandatory and user supplied QFE(s)
    [String]$QFE,

    #Installs without user supplied QFE(s)
    [String]$NOQFE,

    #Installs QFE(s) which belong to user supplied classification(s)
    [String]$CLS,

    #Installs QFE(s) which don't belong to user supplied classification(s)
    [String]$NOCLS,

    #Up to Release - Will only install QFE(s) up to and including the release date provided
    #Ex: 201112, 201602
    [String]$UTR,

    #Skip SQL QFE(s)
    [Switch]$NOSQL
)


#Global and const variables

$script:needReboot = $false

$script:curFoler = "C:\wsuslog\" + (Get-Date -f yyyyMMddHHmmss) + "\"
$script:logFile = $script:curFoler + "wsus.log"
$script:resultCodeFile = $script:curFoler + "ResultCode"
$script:installResultFile = $script:curFoler + "InstallResult"

$script:logError = "Error"
$script:logTrace = "Trace"
$script:logWarning = "Warning"
$script:logException = "Exception"

$script:sqlServerFilter = "SQL Server"
$script:noneOrDefault = "N/A"
$script:noPermit = "You have no permission to perform this script."
$script:prepareEnv = "Prepare environment"
$script:checkReboot = "Check reboot status only for local instance"
$script:needRebooBeforePatch = "Reboot is required to continue"
$script:supportLocal = "Support local instance only, Continue..."
$script:getUpdates = "Get available updates"
$script:connectServer = "Connecting to server..."
$script:noConnect = "Failed connecting to WSUS server"
$script:maxRetryFailed = "Script failed on max retry times reached"
$script:noUpdates = "No updates found"
$script:prefoundUpdates = "Found [{0}] Updates:"
$script:updateInfo = 
"
       ----------------------------------------------------------------------------------------`n
       KBArticleID: {0}`n
       Title: {1}`n
       Classification: {2}`n
       Description: {3}`n
       IsMandatory: {4}`n
       Type: {5}`n
       Size: {6}`n
       LastDeploymentChangeTime: {7}`n
       ----------------------------------------------------------------------------------------"
$script:argInfo = "Arg {0} is set to: {1}"
$script:updateNotApproved = "Exclude the update from candidates:`n" + $script:updateInfo
$script:argUTRInvalid = "UTR is invalid, ignore"
$script:taskNotPermitted = "Your security policy don't allow a non-administator identity to perform this task"
$script:startDownloading = "Downloading update: {0}"
$script:updateDownloaded = "Successfully downloaded update: {0}"
$script:updateDownloadFailed = "Failed to download update: {0}"
$script:startInstalling = "Installing update: {0}"
$script:installResultInfo = 
"
       Install Result:
       ----------------------------------------------------------------------------------------`n
       Update: {0}`n
       Status: {1}`n
       RequireReboot: {2}`n
       ----------------------------------------------------------------------------------------"
$script:rebooting = "Rebooting server..."
$script:manuallyReboot = "Reboot is required. Please do it manually."
$script:resultSummary =
"
       ----------------------------------------------------------------------------------------`n
       Result Summary: {0} updates found, {1} updates installed.`n
       ----------------------------------------------------------------------------------------"

#Result bits
$script:resultCodeSuccess = 0 #0 0000 0 00
$script:resultCodePatialSuccess = 8 # 0 0001 0 00
$script:resultCodeNeedRebootBeforePatch = 16 # 0 0010 0 00
$script:resultCodeNoConnectToServer = 24 # 0 0011 0 00
$script:resultCodeNoUpdatesFound = 32 # 0 0100 0 00
$script:resultCodeInstallFailed = 40 # 0 0101 0 00
$script:resultCodeExceptionOccurred = 48 # 0 0110 0 00
$script:resultCodeNotAdmin = 56 # 0 0111 0 00

$script:updatesExtraDataCollection = @{}
$script:jsonSearchedArray = @{}
$script:jsonInstalledArray = @{}

function Write-Log
{
    param
    (
        [parameter(Mandatory=$true)]
        [string]$level,
        [parameter(Mandatory=$true)]
        [String]$content
    )

    #incase logfile gets deleted
    if(!(Test-Path $script:logFile))
    {
        New-Item $script:logFile -ItemType File -Force | Out-Null
    }

    $content += Get-Date -f " yyyy-MM-dd HH:mm:ss"

    switch ($level) 
    { 
        $script:logError {Write-Error $content}
        $script:logWarning {Write-Warning $content}
        $script:logTrace {Write-Verbose $content}
        $script:logException {Write-Error $content}
        default {Write-Verbose $content}
    }

    ([String]$level + ": " + $content) | Add-Content $script:logFile
}

function Convert-Json([object] $item){
    add-type -assembly system.web.extensions
    $ps_js=new-object system.web.script.serialization.javascriptSerializer
    return $ps_js.Serialize($item)
}

function Write-ResultCode
{
    param
    (
        [parameter(Mandatory=$true)]
        [int]$resultCode,
        [switch]$noexit
    )

    if(!(Test-Path $script:resultCodeFile))
    {
        New-Item $script:resultCodeFile -ItemType File -Force | Out-Null
    }
	
	$needRebootBits = 0; #000
	if($script:needReboot)
	{
		$needRebootBits = 4; #100
	}
	
	$paramBits = 0; #00
	if($ListOnly)
	{
		$paramBits = 1; #01
	}
	elseif($DownloadOnly)
	{
		$paramBits = 2; #10
	}
	
	$resultCode += $needRebootBits + $paramBits

    $resultCode | Set-Content $script:resultCodeFile
	
	$jsonSearched = Convert-Json $script:jsonSearchedArray
	$jsonInstalled = Convert-Json $script:jsonInstalledArray	
	
	$jsonSearched | Set-Content $script:installResultFile
	$jsonInstalled | Add-Content $script:installResultFile	
	
    if(!$noexit)
    {
        exit
    }
}

function Is-Admin
{
    [OutputType('Bool')]
    param()
        
    $User = [Security.Principal.WindowsIdentity]::GetCurrent()
    $IsAdmin = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

    return $IsAdmin
}

function Prepare-Environment
{
    param()

    Write-Log $script:logTrace $script:prepareEnv
    Write-Log $script:logTrace $script:checkReboot
    Try
    {
        $objSystemInfo = New-Object -ComObject "Microsoft.Update.SystemInfo"
        If($objSystemInfo.RebootRequired)
        {
            Write-Log $script:logError $script:needRebooBeforePatch
			$script:needReboot = $true
            Write-ResultCode $script:resultCodeNeedRebootBeforePatch
        }
    }
    Catch
    {        
        Write-Log $script:logWarning $script:supportLocal
    }
}

function Is-Sql
{
    [OutputType('Bool')]
    Param
    (
        [AllowNull()]
        $update
    )

    $IsSql = $false

    if($update.Title -match $script:sqlServerFilter)
    {
        $IsSql = $true
    }
    else
    {
        foreach($category in $update.Categories)
        {
            if(($category.Type -eq "ProductFamily") -and ($category.name -match $script:sqlServerFilter))
            {
                $IsSql = $true
                break
            }

            if($category.Type -eq "Product")
            {
                if(($category.Parent.Type -eq "ProductFamily") -and ($category.Parent.name -match $script:sqlServerFilter))
                {
                    $IsSql = $true
                    break
                }
            }
        }
    }

    return $IsSql
}

function Get-Classification
{
    Param
    (
        [AllowNull()]
        $update
    )

    $classification = @{}
    foreach($category in $update.Categories)
    {
        if(($category.Type -eq "UpdateClassification"))
        {
            $clsFilterValue = [String]::Empty
            $classification.DisplayName = $category.Name
            switch ($category.Name)
            {
                "Critical Updates" {$clsFilterValue = "CU"}
                "Definition Updates" {$clsFilterValue = "DU"}
                "Drivers" {$clsFilterValue = "DR"}
                "Feature Packs" {$clsFilterValue = "FP"}
                "Security Updates" {$clsFilterValue = "SU"}
                "Service Packs" {$clsFilterValue = "SP"}
                "Tools" {$clsFilterValue = "TL"}
                "Update Rollups" {$clsFilterValue = "UR"}
                "Updates" {$clsFilterValue = "UP"}
            }

            $classification.FilterValue = $clsFilterValue

            break
        }
    }

    return $classification
}

function Match-KB
{
    [OutputType('Bool')]
    Param
    (
        [AllowNull()]
        $inputKBs,
        [AllowNull()]
        $updateKBs
    )

    $isMatched = $false
    #if no KB specified, all updates are good to go
    If($inputKBs -eq $null -or $inputKBs -eq "" -or $inputKBs.count -le 0)
    {
        $isMatched = $true
    }
    else
    {
        foreach($inputKB in $inputKBs)
        {
            foreach($updateKB in $updateKBs)
            {
                #if one KB is matched, return true
                if($inputKB -match $updateKB)
                {
                    $isMatched = $true
                    break
                }
            }
        }
    }

    return $isMatched
}

function Retry-Script
{
    [OutputType('Bool')]
    Param
    (
        [parameter(Mandatory=$true)]
        [String]$jobName,
        [parameter(Mandatory=$true)]
        $script,
        [ref]$retVal,
        $retry = 3,
        $timeoutMilliseconds = 1000*60*20 #20 mins
    )

    for($i = 0; $i -lt $retry; ++$i)
    {
        try
        {    
            $shell = [PowerShell]::Create()
            $null = $shell.AddScript($script)
            $job = $shell.BeginInvoke()

            $signal = $job.AsyncWaitHandle.WaitOne($timeoutMilliseconds)

            if($shell.InvocationStateInfo.State -eq "Completed" )
            {
                Write-Log $script:logTrace ([String]::Format("{0} completed", $jobName))
                $retVal.Value = $shell.EndInvoke($job)
                return $true
            }

            Write-Log $script:logWarning ([String]::Format("{0} failed, {1} retry left", $jobName, $retry-$i-1))
            if($i -ge $retry-1) # Max retry reached
            {
                write-log $script:logError $script:maxRetryFailed
                if($shell.InvocationStateInfo.State -eq "Failed" ) #Exception thrown in the script
                {
                    throw $shell.InvocationStateInfo.Reason
                }
                else #No exception thrown, but script still not in completed state
                {
                    return $false
                }
            }
        }
        catch
        {
            throw
        }
        finally
        {
            $job.AsyncWaitHandle.Close()
            $shell.Stop()
            $shell.Dispose()
        }
    }
}

function Get-Updates
{
    [OutputType('Microsoft.Update.UpdateColl')]
    Param()

    Write-Log $script:logTrace $script:getUpdates
    Write-Log $script:logTrace $script:connectServer

    try
    {
        $searchScript = 
        {
            try
            {
                $session = New-Object -ComObject "Microsoft.Update.Session"
                $searcher = $session.CreateUpdateSearcher()

                #Generate search conditions
                $conditions = [String]::Empty

                #Search

                $result = $searcher.Search($conditions)
                
                if($result.ResultCode -eq 2)
                {
                    $result.Updates
                }
                else
                {
                    throw "Search resultcode is not success"
                }
            }
            catch
            {
                throw
            }
        }

        $Updates = New-Object -ComObject "Microsoft.Update.UpdateColl"

        <#$success = Retry-Script "Connect to WSUS Server" $searchScript ([ref]$Updates)
        if(!$success)
        {
            Write-Log $script:logError $script:noConnect
            Write-ResultCode $script:resultCodeNoConnectToServer
        }#>
        
        if(($Updates -eq $null) -or ([int]($Updates.count) -eq 0))
        {
			Write-log $script:logWarning $script:noUpdates
			Write-ResultCode $script:resultCodeNoUpdatesFound
        }

        $updateCandidates = New-Object -ComObject "Microsoft.Update.UpdateColl"

        Foreach($Update in $Updates)
        {
            
            $KB = [String]::Empty
            If(($Update.KBArticleIDs -ne "") -and ($Update.KBArticleIDs -ne $null) -and ($Update.KBArticleIDs -gt 0))
            {
                $KBCollection = @()
                foreach($KBArticleID in $Update.KBArticleIDs)
                {
                    $KBCollection += "KB" + $KBArticleID
                }
                $KB = [String]::Join(", ", $KBCollection)
            }
            Else
            {
                $KB = $script:noneOrDefault
            }

            
            $type = "Unknown"
            if($Update.Type -eq 1)
            {
                $type = "Software"
            }
            if($Update.Type -eq 2)
            {
                $type = "Driver"
            }

            $size = [String]::Empty
            Switch($Update.MaxDownloadSize)
            {
                {[System.Math]::Round($_/1KB,0) -lt 1024} { $size = [String]([System.Math]::Round($_/1KB,0))+" KB"; break }
                {[System.Math]::Round($_/1MB,0) -lt 1024} { $size = [String]([System.Math]::Round($_/1MB,0))+" MB"; break }  
                {[System.Math]::Round($_/1GB,0) -lt 1024} { $size = [String]([System.Math]::Round($_/1GB,0))+" GB"; break }    
                {[System.Math]::Round($_/1TB,0) -lt 1024} { $size = [String]([System.Math]::Round($_/1TB,0))+" TB"; break }
                default { $size = "Unknown" }
            }

            #Filter updates via command args
            $UpdateApproved = $true

            If(![String]::IsNullOrEmpty($ONLYQFE))
            {
                $arr = $ONLYQFE.Trim() -split '\s+'
                if(!(($KB -ne $script:noneOrDefault) -and (Match-KB $arr $Update.KBArticleIDs)))
                {
                    $UpdateApproved = $false
                    Write-Log $script:logTrace ([String]::Format($script:argInfo,"ONLYQFE", $ONLYQFE))
                }
            }
            else #ONLYQFE is exclusive from other args
            {
                $hasOtherFilterSet = $false;   
            
                If(($UTR -ne "") -and ($UTR -ne $null) -and ($UpdateApproved -eq $true))
                {
                    $hasOtherFilterSet = $true;
                    try
                    {
                        if($Update.LastDeploymentChangeTime -ne "")
                        {
                            $inputTime = [Datetime]::ParseExact($UTR, "yyyyMM", $null)
                            if(($Update.LastDeploymentChangeTime.year -gt $inputTime.year) -or
                               (($Update.LastDeploymentChangeTime.year -eq $inputTime.year) -and ($Update.LastDeploymentChangeTime.month -gt $inputTime.month)))
                               {
                                    $UpdateApproved = $false
                                    Write-Log $script:logTrace ([String]::Format($script:argInfo, "UTR", $UTR))
                               }
                        }
                    }
                    catch
                    {
                        Write-Warning $script:logTrace $script:argUTRInvalid
                        Write-Log $script:logException $_
                    }
                }

                If($NOSQL -and ($UpdateApproved -eq $true))
                {
                    $hasOtherFilterSet = $true;

                    #If this update relates to sql server, ignore it
                    if(Is-Sql($Update))
                    {
                        $UpdateApproved = $false
                        Write-Log $script:logTrace ([String]::Format($script:argInfo, "NOSQL", $NOSQL))
                    }
                }

                #Exclude updates from $NOQFE
                if((![String]::IsNullOrEmpty($NOQFE)) -and ($updateApproved -eq $true))
                {
                    $hasOtherFilterSet = $true;

                    $arr = $NOQFE.Trim() -split '\s+'
                    if(($KB -ne $script:noneOrDefault) -and (Match-KB $arr $Update.KBArticleIDs))
                    {
                        $UpdateApproved = $false
                        Write-Log $script:logTrace ([String]::Format($script:argInfo,"NOQFE", $NOQFE))
                    }
                }

                $classification = Get-Classification $Update

                If((![String]::IsNullOrEmpty($CLS)) -and ($updateApproved -eq $true))
                {
                    $hasOtherFilterSet = $true;

                    $arr = $CLS.Trim() -split '\s+'
                    If(!(($classification.FilterValue -ne $null) -and ($arr -contains $classification.FilterValue)))
                    {
                        $UpdateApproved = $false
                        Write-Log $script:logTrace ([String]::Format($script:argInfo, "CLS", $CLS))
                    }
                }

                If((![String]::IsNullOrEmpty($NOCLS)) -and ($updateApproved -eq $true))
                {
                    $hasOtherFilterSet = $true;

                    $arr = $NOCLS.Trim() -split '\s+'
                    If(($classification.FilterValue -ne $null) -and ($arr -contains $classification.FilterValue))
                    {
                        $UpdateApproved = $false
                        Write-Log $script:logTrace ([String]::Format($script:argInfo, "NOCLS", $NOCLS))
                    }
                }

                If(![String]::IsNullOrEmpty($QFE))
                {
                    $arr = $QFE.Trim() -split '\s+'

                    If($hasOtherFilterSet -eq $true)
                    {
                        #If there are other args, union the filtered result
                        If($UpdateApproved -eq $false) #If the KB is filtered out by previous filters, but matches the QFE passed in, make it approved
                        {
                            If(($KB -ne $script:noneOrDefault) -and (Match-KB $arr $Update.KBArticleIDs))
                            {
                                $UpdateApproved = $true
                            }
                        }
                    }
                    else
                    {
                        #If just QFE is set, just filter the result
                        If(!($Update.IsMandatory) -and !(($KB -ne $script:noneOrDefault) -and (Match-KB $arr $Update.KBArticleIDs)))
                        {
                            $UpdateApproved = $false
                            Write-Log $script:logTrace ([String]::Format($script:argInfo, "QFE", $QFE))
                        }
                    }
                }
            }


            #Add approved update to candidate
            if($updateApproved -eq $true)
            {
                $updateCandidates.Add($Update) | Out-Null
                $script:updatesExtraDataCollection.Add($Update.Identity.UpdateID,@{KB = $KB; Type = $type; Size = $size; Classification = $classification})
            }
            else
            {
                Write-Log $script:logTrace ([String]::Format($script:updateNotApproved, 
                                                            $KB,
                                                            $Update.Title,
                                                            $classification.DisplayName,
                                                            $Update.Description, 
                                                            [String]$Update.IsMandatory, 
                                                            $type,
                                                            $size,
                                                            $Update.LastDeploymentChangeTime))
            }
        }

        $updateInfos = [string]::Empty
        Foreach($Update in $updateCandidates)
        {
            $updateInfos += ([String]::Format($script:updateInfo, 
                                              $script:updatesExtraDataCollection[$Update.Identity.UpdateID].KB, 
                                              $Update.Title,
                                              $script:updatesExtraDataCollection[$Update.Identity.UpdateID].Classification.DisplayName,
                                              $Update.Description, 
                                              [String]$Update.IsMandatory, 
                                              $script:updatesExtraDataCollection[$Update.Identity.UpdateID].Type, 
                                              $script:updatesExtraDataCollection[$Update.Identity.UpdateID].Size, 
                                              $Update.LastDeploymentChangeTime))
											  
			$script:jsonSearchedArray.Add($Update.Identity.UpdateID, @{KB = $script:updatesExtraDataCollection[$Update.Identity.UpdateID].KB; Title = $Update.Title})
        }
        Write-Log $script:logTrace (([String]::Format($script:prefoundUpdates, $updateCandidates.count)) + $updateInfos)

        return $updateCandidates
    }

    Catch
    {
        If(($_ -match "HRESULT: 0x80072EE2") -or ($_ -match "HRESULT: 0x8024402c"))
        {
            Write-Log $script:logError $script:noConnect
            write-log $script:logException $_
            Write-ResultCode $script:resultCodeNoConnectToServer
        }
        Write-Log $script:logException $_
        Write-ResultCode $script:resultCodeExceptionOccurred
    }
}

function Download-Updates
{
    Param
    (
        [AllowNull()]
        $updatesToDownload
    )

    Try
    {
        if(($updatesToDownload -eq $null) -or ($updatesToDownload -eq ""))
        {
            return $null
        }

        $session = New-Object -ComObject "Microsoft.Update.Session"
        $updatesDownloaded = New-Object -ComObject "Microsoft.Update.UpdateColl"

        Foreach($Update in $updatesToDownload)
        {
            Write-Log $script:logTrace ([String]::Format($script:startDownloading, $Update.Title))
            $downloader = $session.CreateUpdateDownloader()
            $objCollectionTmp = New-Object -ComObject "Microsoft.Update.UpdateColl"
            $objCollectionTmp.Add($Update) | Out-Null
            $downloader.Updates = $objCollectionTmp
            $downloadResult = $downloader.Download()
            If($downloadResult.ResultCode -eq 2)
            {
                Write-Log $script:logTrace ([String]::Format($script:updateDownloaded, $Update.Title))
                $updatesDownloaded.Add($Update) | Out-Null
            }
            else
            {
                Write-Log $script:logWarning ([String]::Format($script:updateDownloadFailed, $Update.Title))
            }
        }

        return $updatesDownloaded
    }
    Catch
    {
        If($_ -match "HRESULT: 0x80240044")
        {
            write-log $script:logWarning $script:taskNotPermitted
        }
        write-log $script:logException $_
        Write-ResultCode $script:resultCodeExceptionOccurred
    }
}

function Install-Updates
{
    Param
    (
        [AllowNull()]
        $updatesToInstall
    )

    Try
    {
        if(($updatesToInstall -eq $null) -or ($updatesToInstall -eq ""))
        {
            return $null
        }

        $session = New-Object -ComObject "Microsoft.Update.Session"
        $updatesInstalled = New-Object -ComObject "Microsoft.Update.UpdateColl"

        $curIndex = 0

        Foreach($Update in $updatesToInstall)
        {
            Write-Log $script:logTrace ([String]::Format($script:startInstalling, $Update.Title))
            $installer = $session.CreateUpdateInstaller()
            $objCollectionTmp = New-Object -ComObject "Microsoft.Update.UpdateColl"
            $objCollectionTmp.Add($Update) | Out-Null
            $installer.Updates = $objCollectionTmp
            $installResult = $installer.Install()

            if(!$script:needReboot)
            {
                $script:needReboot = $installResult.RebootRequired  
            }

            $Status = "Unknown"
            Switch -exact ($installResult.ResultCode)
            {
                0   { $Status = "NotStarted"}
                1   { $Status = "InProgress"}
                2   { $Status = "Installed"}
                3   { $Status = "InstalledWithErrors"}
                4   { $Status = "Failed"}
                5   { $Status = "Aborted"}
            }
            Write-Log $script:logTrace ([String]::Format($script:installResultInfo, $Update.Title, $Status, [String]($installResult.RebootRequired)))

            if($installResult.ResultCode -eq 2)
            {
                $updatesInstalled.Add($Update) | Out-Null
				$script:jsonInstalledArray.Add($Update.Identity.UpdateID, @{KB = $script:updatesExtraDataCollection[$Update.Identity.UpdateID].KB; Title = $Update.Title})
            }
        }

        return $updatesInstalled
    }
    Catch
    {
        If($_ -match "HRESULT: 0x80240044")
        {
            write-log $script:logWarning $script:taskNotPermitted
        }
        write-log $script:logException $_
        Write-ResultCode $script:resultCodeExceptionOccurred
    }
}

function Handle-ResultCode
{
    Param
    (
        [AllowNull()]
        $searchedCount,
        [AllowNull()]
        $installedCount
    )

    Write-Log $script:logTrace ([String]::Format($script:resultSummary, [String]$searchedCount, [String]$installedCount))

    if($searchedCount -le 0)
    {
        Write-ResultCode $script:resultCodeNoUpdatesFound -noexit
    }
    else
    {
        if($installedCount -le 0)
        {
            Write-ResultCode $script:resultCodeInstallFailed -noexit
        }
        else
        {
            if($installedCount -eq $searchedCount)
            {
                Write-ResultCode $script:resultCodeSuccess -noexit
            }

            elseif($installedCount -lt $searchedCount)
            {
                Write-ResultCode $script:resultCodePatialSuccess -noexit
            }
        }
    }
}

function Handle-Reboot
{
    If($script:needReboot)
    {
        If($AutoReboot)
        {
            Write-Log $script:logTrace ([String]::Format($script:argInfo, "AutoReboot", [String]$AutoReboot))
            Write-Log $script:logTrace $script:rebooting
            Restart-Computer -Force
        }
        else
        {
            Write-Log $script:logTrace $script:manuallyReboot
        }
    }
}

#Log all params passed in for debugging purpose
$params = "Passed in params:"
foreach($psbp in $PSBoundParameters.GetEnumerator())
{
    $params += ([String]::Format(" {0}:{1}", $psbp.Key,$psbp.Value))
}
write-log $script:logTrace $params

#Check if user is admin to run this script
if(!(Is-Admin))
{
    Write-Log $script:logError $script:noPermit
    Write-ResultCode $script:resultCodeNotAdmin
}

#Prepare environment
Prepare-Environment

#Search and filter updates
$searchedUpdateColl = Get-Updates
if($ListOnly)
{
    Write-ResultCode $script:resultCodeSuccess
}

#Download updates
$downloadedUpdateColl = (Download-Updates $searchedUpdateColl)
if($DownloadOnly)
{
    Write-ResultCode $script:resultCodeSuccess
}

#Install updates
$installedUpdateColl = (Install-Updates $downloadedUpdateColl)

#Handle result code
$sCount = 0
$iCount = 0
if(($searchedUpdateColl -ne $null) -and ($searchedUpdateColl -ne $null))
{
    if(($searchedUpdateColl.count -gt 0))
    {
        $sCount = $searchedUpdateColl.count
    }
    else
    {
        $sCount = 1
    }
}
if(($installedUpdateColl -ne $null) -and ($installedUpdateColl -ne $null))
{
    if(($searchedUpdateColl.count -gt 0))
    {
        $iCount = $installedUpdateColl.count
    }
    else
    {
        $iCount = 1
    }
}
Handle-ResultCode $sCount $iCount

#Handle reboot
Handle-Reboot
