$Server = 'I07OPDFOASVC3.partners.extranet.microsoft.com'#$env:COMPUTERNAME

$Pass = "***********" | ConvertTo-SecureString -AsPlainText -Force ; $Account='redmond\lpoaasvc'
$credential = [System.Management.Automation.PSCredential]::new($Account, $Pass)

$Interval = 2  #Interval in seconds between the samples
$Samples  = 5  #Numer of samples you want to ather

$Counters = @('\Web Service(*)\Bytes Received/sec', '\Web Service(*)\Current Connections')
$result = Invoke-Command -ComputerName $Server -ScriptBlock { Get-Counter -Counter $args[0] -MaxSamples $args[1] -SampleInterval $args[2]} -ArgumentList $Counters, $Samples,$Interval -Credential $credential
$result | Out-GridView -Title "$Server : WebSite Performance Statistics"