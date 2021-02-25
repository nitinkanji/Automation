$Pass = "*********" | ConvertTo-SecureString -AsPlainText -Force ; $Account='domain\account'
$credential = [System.Management.Automation.PSCredential]::new($Account, $Pass)

$servers =(
'server1')

$TIMEZONES = {
      $TIMEZONE =  [SYSTEM.TIMEZONE]::CURRENTTIMEZONE
      IF($TIMEZONE.STANDARDNAME -EQ 'PACIFIC STANDARD TIME')
      {
             WRITE-HOST  "$ENV:COMPUTERNAME : TIMEZONE ($($TIMEZONE.STANDARDNAME))"
      } 
      ELSE
      {            
             WRITE-HOST  "$ENV:COMPUTERNAME : TIMEZONE ($($TIMEZONE.STANDARDNAME))"
             $RESPONSE = READ-HOST "WANT TO CHANGE TO PST TIMEZONE? Y/N"
             
             IF($RESPONSE -EQ 'Y')
             {

                   WRITE-HOST "UPDATING $ENV:COMPUTERNAME TIMEZONE TO PST."
            TRY
            {
                       TZUTIL /S 'PACIFIC STANDARD TIME'      
                START-SLEEP -SECONDS 2 
                WRITE-HOST -FOREGROUNDCOLOR CYAN "COMPLETED : " -NONEWLINE
                (GET-ITEMPROPERTY -PATH "HKLM:\SYSTEM\CURRENTCONTROLSET\CONTROL\TIMEZONEINFORMATION").TIMEZONEKEYNAME                 
             }
            CATCH {WRITE-HOST "EXCEPTION: $($ERROR[0].EXCEPTION.INNEREXCEPTION)"}
        }

    }
}

Foreach($server in $servers)
{
    Invoke-Command -ComputerName $server  -ScriptBlock $TIMEZONES -Credential $credential
}
