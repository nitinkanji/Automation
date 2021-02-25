function Get-Uptime{
      Param(
            $ComputerName = $env:COMPUTERNAME
       )

      if($c=Get-WmiObject win32_operatingsystem -ComputerName $ComputerName){
          [datetime]::Now - $c.ConverttoDateTime($c.lastbootuptime)
     }else{
          Write-Error "Unable to retrieve WMI Object win32_operatingsystem from $ComputerName"
     } 
}
$Now = Get-Uptime
Write-Host -ForegroundColor Cyan "Last reboot time $($Now.days) Days, $($Now.Hours) Hours and $($Now.Minutes) Minutes."