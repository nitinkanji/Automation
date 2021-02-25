
#Variable declearation
[int]$DayToExpire = 60
$Response=@()
$Pass = "***********" | ConvertTo-SecureString -AsPlainText -Force; $Account='domain\account'
$credential = [System.Management.Automation.PSCredential]::new($Account, $Pass)

#Pulling Certificates
$Certificate= {
    Param([int]$DaysToExpire)
    $ds=@()
        $deadline = (Get-Date).AddDays($DaysToExpire)   #Set deadline date 
        Dir Cert:\LocalMachine\My | foreach { 
        if(($_.NotAfter - (Get-Date)).days -ge -30)
        {
            If ($_.NotAfter -le $deadline) 
            { 
                $ds+=$_ | Select Subject, Thumbprint,NotAfter, @{Label="Expires In (Days)";Expression={($_.NotAfter - (Get-Date)).Days} } 
            }
        }}
    Return $ds 
}
$Servers = (
'I07OPDBOAAPP1.partners.extranet.microsoft.com',
'I07OPDBOAAPP2.partners.extranet.microsoft.com',
'I07OPDBOAAPP3.partners.extranet.microsoft.com',
'I07OPDBOAAPP4.partners.extranet.microsoft.com',
'I07OPDBOAAPP5.partners.extranet.microsoft.com'
)

ForEach($server in $servers)
{
    #Connecting to Remote Server
    $response += Invoke-Command -ComputerName $Server  -ScriptBlock $Certificate -ArgumentList $DayToExpire -Credential $credential

}

$Response | Format-Table -AutoSize
Write-Host ""
Write-Host -ForegroundColor Cyan "Exporting on D:\CertificateExpiry.csv"
$Response | Export-Csv -Path "D:\CertificateExpiry_$(Get-Date)_.csv" -NoTypeInformation
