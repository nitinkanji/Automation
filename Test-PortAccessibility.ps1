Function Test-PortAccessibility($hostname, $port) 
{
    Try 
    {
        $ip = [System.Net.Dns]::GetHostAddresses($hostname) | select-object IPAddressToString -expandproperty  IPAddressToString
        if($ip.GetType().Name -eq "Object[]")
        {
           $ip = $ip[0]
        }
    } 
    catch 
    {
        Write-Host "Possibly $hostname is wrong hostname or IP"
        return
    }
    
    $t = New-Object Net.Sockets.TcpClient
    
    Try
    {
        $t.Connect($ip,$port)
    } 
    catch {}

    if($t.Connected)
    {
        $t.Close()
        $msg = "$($hostname) : Port $port is Open & operational"
    }
    else
    {
        $msg = "$($hostname) : Port $port on $ip is closed, "
        $msg += "You may need to contact your IT team to open it. "                                 
    }
    Write-Host $msg
}


$servers = (
'I07OPDBOAAPP1.partners.extranet.microsoft.com', 
'I04OPDBOAAPP2.partners.extranet.microsoft.com', 
'I04OPDBOAAPP3.partners.extranet.microsoft.com', 
'I04OPDBOAAPP4.partners.extranet.microsoft.com', 
'I04OPDBOAAPP5.partners.extranet.microsoft.com'
)

Foreach($server in $servers)
{
    Test-PortAccessibility -hostname $server -port 443
}