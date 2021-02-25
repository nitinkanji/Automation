$ServerList = (
'I02BU2FWEBAWS01.partners.extranet.microsoft.com', 
'I02BU2FWEBAWS02.partners.extranet.microsoft.com',
'I02BU2BWEBAWS03.partners.extranet.microsoft.com', 
'I02BU2BWEBAWS04.partners.extranet.microsoft.com', 
'I02BU2BSVCAWS01.partners.extranet.microsoft.com', 
'I02BU2BSVCAWS02.partners.extranet.microsoft.com', 
'I02BU2BSQLAWS01.partners.extranet.microsoft.com', 
'I02BU2BSQLAWS02.partners.extranet.microsoft.com'
)

$Run = {
$tcpobject = new-Object system.Net.Sockets.TcpClient
$connect = $tcpobject.BeginConnect("tools.cp.microsoft.com",443,$null,$null); 
$wait = $connect.AsyncWaitHandle.WaitOne(5000,$false); 

if (-Not $Wait) 
{$Flag =1}
    else{
        $error.clear()
        $tcpobject.EndConnect($connect) | out-Null}
    
        if ($Error[0]){
            Write-warning ("{0}" -f $error[0].Exception.Message)}
        else {$Flag = 2}
        }


foreach($Server in $ServerList)
{
    $chk = (Invoke-Command -ComputerName $Server -ScriptBlock $Run)
    if ($Chk -eq 1)
    {
        Write-host $Server " - tools.cp.microsoft.com 443 - ACL Blocked or Timed out!"}
        elseif($Chk -eq 1)
        {Write-host $Server " - tools.cp.microsoft.com 443 - ACL Open!"}
        else{Write-host $Error[0]}
}
