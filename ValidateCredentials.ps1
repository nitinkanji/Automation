
$accounts =@(Import-Csv C:\Users\nitinkg\Desktop\CertDemo1.csv)
$Details  =@()


Function DomainCheck($name)                       {
    
    switch($name)
    {
        "northamerica"   {  $domain  =  "LDAP://DC=northamerica,DC=corp,DC=microsoft,DC=com"; break}
        "partners"       {  $domain  =  "LDAP://DC=partners,DC=extranet,DC=microsoft,DC=com"; break}
        "southpacific"   {  $domain  =  "LDAP://DC=southpacific,DC=corp,DC=microsoft,DC=com"; break}
        "redmond"        {  $domain  =  "LDAP://DC=redmond,DC=corp,DC=microsoft,DC=com"; break}
    }

    return $domain
}

Foreach($ac in $accounts)
{
    If($ac.SERVICEACCOUNT)
    {
        $LDAP = DomainCheck -name ($($ac.SERVICEACCOUNT).Split("\")[0])
        $Domain = NEW-OBJECT SYSTEM.DIRECTORYSERVICES.DIRECTORYENTRY("LDAP://DC=partners,DC=extranet,DC=microsoft,DC=com",'partners\tpisvc0577','#729evLX3rFfT}')
        
            if($Domain.name -NE $null){$status = "Valid"}
            else {$status = "Invalid"}

        write-host "$($ac.SERVICEACCOUNT)- $($status))"

        $Details+= New-Object -TypeName psobject -Property @{
            ServiceAccount = $ac.SERVICEACCOUNT
            Password       = $ac.PASSWORD
            PasswordStatus = $status
            AsOndate       = (Get-Date).ToString("yyyy-M-dd")
        } 
    }
}

$Details | Select ServiceAccount, Password, PasswordStatus, AsOndate | ft -AutoSize