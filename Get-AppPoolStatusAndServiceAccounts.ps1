$AppPool =  {
        $Error.Clear()
        
        # Checking for the WebAdministration Module if not found it will Import
        If(Get-Module -ListAvailable | Select Name | Where {$_.Name -like 'WebAdministration'}){
            Import-Module WebAdministration
            $applicationPools = Get-ChildItem IIS:\AppPools
        }
        else{
            Write-Warning "Information : IIS Applications Not found."}
        $i = 1;

        #Retrieving Details from available Application pools.
        foreach($applicationPool in $applicationPools){
            If($($applicationPool.ProcessModel.UserName)){
                Write-Host -ForegroundColor Cyan "$i. $($applicationPool.Name) Application Pool using {" -NoNewline
                write-host -ForegroundColor Yellow $($applicationPool.ProcessModel.UserName) -NoNewline
                Write-Host -ForegroundColor Cyan "}. -" -NoNewline
                Write-Host "$($applicationPool.State)"

                $i+=1;
            }
        }
    }

#Connecting to Target server

$Pass = "**********" | ConvertTo-SecureString -AsPlainText -Force; $Account='redmond\lpoaasvc'
$credential = [System.Management.Automation.PSCredential]::new($Account, $Pass)

$TargetServer = ('ph1mslwb49.partners.extranet.microsoft.com','ph1mslwb49.partners.extranet.microsoft.com','ph1mslwb49.partners.extranet.microsoft.com')

ForEach($Server in $TargetServer)
{
    $session = New-PSSession -ComputerName $TargetServer  -Credential $credential
    Invoke-Command -Session $session -ScriptBlock $AppPool
    Remove-PSSession $session
}