$ErrorActionPreference = "SilentlyContinue"

. a:\Test-Command.ps1

Enable-RemoteDesktop
netsh advfirewall firewall add rule name="Remote Desktop" dir=in localport=3389 protocol=TCP action=allow

Update-ExecutionPolicy -Policy Unrestricted

Write-BoxstarterMessage "Installing legacy .NET frameworks..."
Add-WindowsFeature -Name NET-Framework-Core -Source d:\sources\sxs

if (Test-Command -cmdname 'Uninstall-WindowsFeature') {
    Write-BoxstarterMessage "Removing unused features..."
    Get-WindowsFeature |
    ? { $_.InstallState -eq 'Available' -and `
    $_.Name -ne "AD-Certificate" -and `
    $_.Name -ne "AD-Domain-Services" -and `
    $_.Name -ne "ADCS-Cert-Authority" -and `
    $_.Name -ne "DNS" -and `
    $_.Name -ne "GPMC" -and `
    $_.Name -ne "RSAT" -and `
    $_.Name -ne "RSAT-Role-Tools" -and `
    $_.Name -notlike "RSAT-AD*" -and `
    $_.Name -ne "RSAT-DNS-Server"} |
    Uninstall-WindowsFeature -Remove
}

# Add WSUS host entry and settings
$file = Join-Path -Path $($env:windir) -ChildPath "system32\drivers\etc\hosts"
$data = Get-Content -Path $file
$data += "192.168.1.150  wsus"
Set-Content -Value $data -Path $file -Force -Encoding ASCII

New-Item -Path "HKLM:Software\Policies\Microsoft\Windows\WindowsUpdate"
New-Item -Path "HKLM:Software\Policies\Microsoft\Windows\WindowsUpdate\AU"
Set-ItemProperty -Path "HKLM:\software\policies\Microsoft\Windows\WindowsUpdate" -Name WUServer -Value "http://wsus:8530" -Type String -force
Set-ItemProperty -Path "HKLM:\software\policies\Microsoft\Windows\WindowsUpdate" -Name WUStatusServer -Value "http://wsus:8530" -Type String -force
Set-ItemProperty -Path "HKLM:\software\policies\Microsoft\Windows\WindowsUpdate\AU" -Name UseWUServer -Value "1" -Type DWORD -force
Restart-Service wuauserv -Force

Install-WindowsUpdate -AcceptEula

Write-BoxstarterMessage "Removing page file"
$pageFileMemoryKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
Set-ItemProperty -Path $pageFileMemoryKey -Name PagingFiles -Value ""

if(Test-PendingReboot){ Invoke-Reboot }

Write-BoxstarterMessage "Setting up winrm"
netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in localport=5985 protocol=TCP action=allow

$enableArgs=@{Force=$true}
try {
 $command=Get-Command Enable-PSRemoting
  if($command.Parameters.Keys -contains "skipnetworkprofilecheck"){
      $enableArgs.skipnetworkprofilecheck=$true
  }
}
catch {
  $global:error.RemoveAt(0)
}
Enable-PSRemoting @enableArgs
Enable-WSManCredSSP -Force -Role Server
Disable-UAC
Set-StartScreenOptions -EnableBootToDesktop
Set-WindowsExplorerOptions -EnableShowFileExtensions -EnableShowFullPathInTitleBar
Set-TaskbarOptions -Size Small -Lock -Combine Full
winrm set winrm/config/client/auth '@{Basic="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
Write-BoxstarterMessage "winrm setup complete"
