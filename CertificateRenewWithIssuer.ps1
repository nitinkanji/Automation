 $accounts =@(Import-Csv C:\Users\frf\Desktop\CertDemo.csv)
 $Detail =@()

 Function GenerateADPassword              {
<#
    
    DESCRIPTION.
    Generates one or more complex passwords designed to fulfill the requirements for Active Directory
    
    EXAMPLE.
       GenerateADPassword
       GenerateADPassword -MinPasswordLength 8 -MaxPasswordLength 12 -Count 4
       GenerateADPassword -InputStrings abc, ABC, 123 -PasswordLength 4
       GenerateADPassword -InputStrings abc, ABC, 123 -PasswordLength 4 -FirstChar abcdefghijkmnpqrstuvwxyzABCEFGHJKLMNPQRSTUVWXYZ
    #>
    [CmdletBinding(DefaultParameterSetName='FixedLength',ConfirmImpact='None')]
    [OutputType([String])]
    
    Param (
    # Specifies minimum password length
    [Parameter(Mandatory=$false, ParameterSetName='RandomLength')]
    [ValidateScript({$_ -gt 0})]
    [Alias('Min')] 
    [int]$MinPasswordLength = 8,
        
    # Specifies maximum password length
    [Parameter(Mandatory=$false, ParameterSetName='RandomLength')]
    [ValidateScript({if($_ -ge $MinPasswordLength){$true} else{Throw 'Max value cannot be lesser than min value.'}})]
    [Alias('Max')]
    [int]$MaxPasswordLength = 12,

    # Specifies a fixed password length
    [Parameter(Mandatory=$false, ParameterSetName='FixedLength')]
    [ValidateRange(1,2147483647)]
    [int]$PasswordLength = 8,
    [String[]]$InputStrings = @('abcdefghijkmnpqrstuvwxyz', 'ABCEFGHJKLMNPQRSTUVWXYZ', '0123456789', '!@{[}]()~#%&'),
    [String] $FirstChar,
    [ValidateRange(1,2147483647)]
    [int]$Count = 1
)
    Begin {
    Function Get-Seed
    {
        # Generate a seed for randomization
        $RandomBytes = New-Object -TypeName 'System.Byte[]' 4
        $Random = New-Object -TypeName 'System.Security.Cryptography.RNGCryptoServiceProvider'
        $Random.GetBytes($RandomBytes)
        [BitConverter]::ToUInt32($RandomBytes, 0)
    }
}
    Process {
        For($iteration = 1;$iteration -le $Count; $iteration++)
        {
            $Password = @{}
            # Create char arrays containing groups of possible chars
            [char[][]]$CharGroups = $InputStrings

            $AllChars = $CharGroups | ForEach-Object {[Char[]]$_}

            # Set password length
            if($PSCmdlet.ParameterSetName -eq 'RandomLength')
            {
                if($MinPasswordLength -eq $MaxPasswordLength) 
                {
                    # If password length is set, use set length
                    $PasswordLength = $MinPasswordLength
                }
                else 
                {
                    # Otherwise randomize password length
                    $PasswordLength = ((Get-Seed) % ($MaxPasswordLength + 1 - $MinPasswordLength)) + $MinPasswordLength
                }
            }

            if($PSBoundParameters.ContainsKey('FirstChar'))
            {
                $Password.Add(0,$FirstChar[((Get-Seed) % $FirstChar.Length)])
            }
            
            # Randomize one char from each group
            Foreach($Group in $CharGroups) 
            {
                if($Password.Count -lt $PasswordLength) 
                {
                    $Index = Get-Seed
                    While ($Password.ContainsKey($Index))
                    {
                        $Index = Get-Seed                        
                    }
                    $Password.Add($Index,$Group[((Get-Seed) % $Group.Count)])
                }
            }

            for($i=$Password.Count;$i -lt $PasswordLength;$i++) 
            {
                $Index = Get-Seed
                While ($Password.ContainsKey($Index))
                {
                    $Index = Get-Seed                        
                }
                $Password.Add($Index,$AllChars[((Get-Seed) % $AllChars.Count)])
            }
            Write-Output -InputObject $(-join ($Password.GetEnumerator() | Sort-Object -Property Name | Select-Object -ExpandProperty Value))
        }
    }
}    
 Function Connect-Mstsc                   {
    
    [cmdletbinding(SupportsShouldProcess,DefaultParametersetName='UserPassword')]
    
    param     (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true,Position=0)][Alias('CN')] [string[]] $ComputerName,
        [Parameter(ParameterSetName='UserPassword',Mandatory=$true,Position=1)][Alias('U')][string] $User,
        [Parameter(ParameterSetName='UserPassword',Mandatory=$true,Position=2)][Alias('P')][string] $Password,
        [Parameter(ParameterSetName='Credential',Mandatory=$true,Position=1)][Alias('C')][PSCredential] $Credential,
        [Alias('A')] [switch] $Admin,
        [Alias('MM')][switch] $MultiMon,
        [Alias('F')] [switch] $FullScreen,
        [Alias('Pu')][switch] $Public,
        [Alias('W')] [int]    $Width,
        [Alias('H')] [int]    $Height,
        [Alias('WT')][switch] $Wait
    )
    begin     {
            [string]$MstscArguments = ''
            switch ($true) {
            {$Admin}      {$MstscArguments += '/admin '}
            {$MultiMon}   {$MstscArguments += '/multimon '}
            {$FullScreen} {$MstscArguments += '/f '}
            {$Public}     {$MstscArguments += '/public '}
            {$Width}      {$MstscArguments += "/w:$Width "}
            {$Height}     {$MstscArguments += "/h:$Height "}
        }
            if ($Credential) {
                $User     = $Credential.UserName
                $Password = $Credential.GetNetworkCredential().Password
            }
    }
    process   {
        foreach ($Computer in $ComputerName) 
        {
            $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
            $Process = New-Object System.Diagnostics.Process
            
            # Remove the port number for CmdKey otherwise credentials are not entered correctly
            if ($Computer.Contains(':')) {
                    $ComputerCmdkey = ($Computer -split ':')[0]} 
                else {
                        $ComputerCmdkey = $Computer}

            $ProcessInfo.FileName    = "$($env:SystemRoot)\system32\cmdkey.exe"
            $ProcessInfo.Arguments   = "/generic:TERMSRV/$ComputerCmdkey /user:$User /pass:$($Password)"
            $ProcessInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
            $Process.StartInfo = $ProcessInfo

            if ($PSCmdlet.ShouldProcess($ComputerCmdkey,'Adding credentials to store')) {
                [void]$Process.Start()}

            $ProcessInfo.FileName    = "$($env:SystemRoot)\system32\mstsc.exe"
            $ProcessInfo.Arguments   = "$MstscArguments /v $Computer"
            $ProcessInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
            $Process.StartInfo       = $ProcessInfo

            if ($PSCmdlet.ShouldProcess($Computer,'Connecting mstsc')) {[void]$Process.Start()
                if ($Wait) {$null = $Process.WaitForExit()}       
            }
        }
    }
}
    
 $ExportCert = {
    
    param($certName, $NewCertPassword)
    
        $thumbprint = (get-childitem 'Cert:\CurrentUser\My' | where { $_.subject -eq "CN=$CertName" }).Thumbprint
        $NewCertPwdEncrypted = ConvertTo-SecureString -String $NewCertPassword -Force -AsPlainText
        $d = Get-ChildItem -Path cert:\currentuser\my\$thumbprint
        $Expiry = $d.NotAfter
    
        Get-ChildItem -Path cert:\currentuser\my\$thumbprint | Export-PfxCertificate -FilePath "C:\Newcertificate\$CertName.pfx" -Password $NewCertPwdEncrypted
        $Expiry.date
 }
 $GetCertifiacteExpiry = {
    param($certName)
    $property = Get-ChildItem Cert:\CurrentUser\My | ? {$_.Subject -like "*$($certName)*"}
    $ExportCert =  $property.NotAfter
    $ExportCert
 }

#Creating Certificates on Remote Server
Write-Host -ForegroundColor Cyan "Creating Certificates on Remote Server [OACertRenew.guest.corp.microsoft.com]."
Write-Host ""

$i=1;

Foreach($account in $accounts)
{
    Try
    {
        Write-Host -ForegroundColor Green "$i...Initiating certificate renewal for $($account.ServiceAccount)"
        Connect-Mstsc -ComputerName 'OACertRenew.guest.corp.microsoft.com' -User $($account.ServiceAccount) -Password $($account.Password) -Admin
        Start-Sleep -Seconds 180

        Stop-Process -Name mstsc -Force
       
    }
    catch
    {
        Write-Host "Error : $($Error[0].Exception)"
    }

    $i+=1;
}

Write-Host ""
Write-Host -ForegroundColor Cyan "Info : Renewal completed for $($i-1) certificates."

Start-Sleep -Seconds 10

#Exporting Certificates on Remote Server's C:\NewCertificateFolder
Write-Host -ForegroundColor Cyan "Exporting Certificates on Remote Server[OACertRenew.guest.corp.microsoft.com] - C:\NewCertificateFolder\"
Write-Host ""

$j=1
Foreach($account in $accounts)
{   
    $NewCertPwd =(GenerateADPassword -PasswordLength 8)
    Write-Host -ForegroundColor Green "$j...Initiating PFX Certificate Export for {$($account.CertName)}, New Password {$($NewCertPwd)}"
        
    Try
    {
        $Pass = "$($account.Password)" | ConvertTo-SecureString -AsPlainText -Force; $ASccount="$($account.ServiceAccount)"
        $credential = [System.Management.Automation.PSCredential]::new($ASccount, $Pass)
        $session = New-PSSession -ComputerName OACertRenew.guest.corp.microsoft.com -Credential $credential
        $Newexpiry = Invoke-Command -Session $session -ScriptBlock $ExportCert -ArgumentList "$($account.CertName)", $NewCertPwd 
        
        $Detail += New-Object -TypeName PSObject -Property @{
            ServiceAccount = $($account.ServiceAccount)
            ServiceAccountPassword = $($account.Password)
            CertificateName = $($account.CertName)+".pfx"
            CertificatePassword =  $NewCertPwd
            NextExpiry = $Newexpiry
           
        }   
    }
    catch
    {
        Write-Host -ForegroundColor Red "Error :  $($Error[0].Exception)"
    }

    Remove-PSSession $session
    $J+=1

}    

Write-Host ""
$Detail | Select ServiceAccount, ServiceAccountPassword, CertificateName, CertificatePassword, NextExpiry| Format-Table -AutoSize

 
