$Pass = "**********" | ConvertTo-SecureString -AsPlainText -Force; $Account='domain\account'
$credential = [System.Management.Automation.PSCredential]::new($Account, $Pass)

#Specify the Folder where permission need to Granted
$HAWKDFSPermission = {
    
    Param($Account)
    
    $colRights = [System.Security.AccessControl.FileSystemRights]"Read, Write, FullControl" 
    $InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]::None  
    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]::None 
    $objType =[System.Security.AccessControl.AccessControlType]::Allow 
    $objUser = New-Object System.Security.Principal.NTAccount($Account) 
    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser, $colRights, $InheritanceFlag, $PropagationFlag, $objType) 
    $objACL = Get-ACL "D:\OSVReportFiles"
    $objACL.AddAccessRule($objACE) 
    Set-ACL "D:\OSVReportFiles" $objACL

    #Getting Permission List
    Start-Sleep -Seconds 5
    Get-ACL "D:\OSVReportFiles" | fl

}
$GetAllShareFolderPermissions = {
    
    $FildShares = get-WmiObject -class Win32_Share | ? {$_.Description -ne 'Default share' -and $_.Description -notlike '*Remote*'}
    ForEach ($Folder in $FildShares)
    {
        $Row = @(Get-Acl $Folder.Path)
    
        $Row.Access | ForEach-Object {    
        $Details += New-Object -TypeName PSObject -Property @{
            FileShareName = $Folder.name
            Path          = $Row.Path
            Owner         = $Row.Owner
            Account       = $_.IdentityReference
            Permission    = $_.Access.FileSystemRights
            AccessType    = $_.Access.AccessControlType
            }
        }
    }
    
    $Details | Ft -AutoSize
 }
$RemoveFileSharePermission = {
    param($account)
    $acl = Get-Acl -Path 'D:\OSVReportFiles'
    $everyone = $acl.Access | Where-Object { $_.IdentityReference -match $account } #Give the account name which want to remove (Don't include Domain name) Ex. lpoaasvc
    $modified = @($everyone | Foreach-Object { $acl.RemoveAccessRule($_) }) -contains $true

    if($modified) 
    {
        Set-Acl -Path 'D:\OSVReportFiles' -AclObject $acl
    }

    Get-Acl -Path 'D:\OSVReportFiles'
}

$HAWKDFSServers = (
'Server1'
)


#Set Individual Account to the File Share
$HAWKDFSServers | ForEach-Object {
    Invoke-Command -ComputerName $_ -ScriptBlock $HAWKDFSPermission -Credential $credential -ArgumentList 'Northamerica\pdoarpt'
}


#Pull All Fileshare access
$HAWKDFSServers | ForEach-Object {
    Invoke-Command -ComputerName $_ -ScriptBlock $GetAllShareFolderPermissions -Credential $credential
}


#Remove Individual Account from File Share
$HAWKDFSServers | ForEach-Object {
    Invoke-Command -ComputerName $_ -ScriptBlock $RemoveFileSharePermission -Credential $credential -ArgumentList 'pdoarpt'
}

