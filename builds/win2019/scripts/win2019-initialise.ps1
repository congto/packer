# Basic configuration of vanilla Windows Server installation to progress Packer.io builds
# @author Michael Poore
# @website https://blog.v12n.io
# @source https://github.com/virtualhobbit
$ErrorActionPreference = "Stop"

# Switch network connection to private mode
# Required for WinRM firewall rules
$profile = Get-NetConnectionProfile
While ($profile.Name -eq "Identifying..."){
    Start-Sleep -Seconds 10
    $profile = Get-NetConnectionProfile
}
Set-NetConnectionProfile -Name $profile.Name -NetworkCategory Private

# Drop the firewall while building and re-enable as a standalone provisioner in the Packer file if needs be
netsh Advfirewall set allprofiles state off

# Enable WinRM service
winrm quickconfig -quiet
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'

# Disable IPV6
Disable-NetAdapterBinding -Name "*" -ComponentID ms_tcpip6

# Reset auto logon count
# https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-shell-setup-autologon-logoncount#logoncount-known-issue
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name AutoLogonCount -Value 0

$confFile2 = 'extend.ps1'
$confPath2 = "C:\"
$confContent2 = @"
$drive_letter = "C"
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax
"@
New-Item -Path $confPath2 -Name $confFile2 -ItemType File -Force -Value $confContent2 | Out-Null

schtasks /create /tn “FileMonitor” /sc onstart /delay 0000:30 /rl highest /ru system /tr “powershell.exe -file C:\extend.ps1

