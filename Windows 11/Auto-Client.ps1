<#
   Auto-Client.ps1
    DESCRIPTION:
    This script configures a Windows 11 client machine to:
    - Install & configure Splunk Universal Forwarder
    - Set static IP
    - Join Active Directory domain
    - Enable RDP
    - Install RSAT tools (optional)
    - Apply Defender and firewall settings
#>

# ================================
# SECTION 1: Global Variables
# ================================

# Splunk Universal Forwarder settings
$SplunkServer   = "192.168.12.120"               # Splunk Indexer IP
$SplunkPort    = 9997                           # Splunk Indexer port (default: 9997)
$SplunkIndex    = "abdullahad"                   # Index to forward logs to
$InstallerFile  = "splunkforwarder-9.4.3-237ebbd22314-windows-x64.msi"

# Network settings
$InterfaceAlias = "Ethernet"
$IPAddress      = "192.168.12.11"
$PrefixLength   = 24                             # Subnet mask: 255.255.255.0
$Gateway        = "192.168.12.1"
$DNSServers     = "192.168.12.10"                # IP of Domain Controller (acts as DNS)

# Domain join settings
$ComputerName   = "AD-CLIENT01"
$DomainFQDN     = "ABDULLAH-AD.local"
$DomainUser     = "ABDULLAH-AD\Administrator"
$DomainPassword = "Rzfn@123"

# Auto-Login for next boot
$AutoLoginUser = "Administrator"
$AutoLoginPassword = "Rzfn@123"
$Domain = "ABDULLAH-AD"
# ================================
# SECTION 2: Install & Configure Splunk Universal Forwarder
# ================================

Write-Host "`n Downloading Splunk Universal Forwarder..." -ForegroundColor Cyan
$TempPath = "C:\Temp"
if (-not (Test-Path $TempPath)) { New-Item -Path $TempPath -ItemType Directory }

$InstallerPath = Join-Path $TempPath $InstallerFile
$DownloadURL = "https://download.splunk.com/products/universalforwarder/releases/9.4.3/windows/$InstallerFile"

Invoke-WebRequest -Uri $DownloadURL -OutFile $InstallerPath

Write-Host "Installing Splunk Universal Forwarder..." -ForegroundColor Cyan
Start-Process msiexec.exe -ArgumentList "/i `"$InstallerPath`" AGREETOLICENSE=Yes /quiet" -Wait

# Generate outputs.conf
$OutputsConf = @"
[tcpout]
defaultGroup = primary-indexer-group
disabled = false

[tcpout:primary-indexer-group]
server = $($SplunkServer):$($SplunkPort)
autoLBFrequency = 30
compressed = true
sendCookedData = true
useACK = true

[tcpout-server://$($SplunkServer):$($SplunkPort)]
"@
$OutputsPath = "C:\Program Files\SplunkUniversalForwarder\etc\system\local\outputs.conf"
$OutputsConf | Out-File -Encoding ASCII -FilePath $OutputsPath -Force

# Generate inputs.conf
$InputsConf = @"
[default]
host = $($env:COMPUTERNAME)

[WinEventLog://Application]
disabled = false
index = $($SplunkIndex)
renderXml = false

[WinEventLog://Security]
disabled = false
index = $($SplunkIndex)
renderXml = false

[WinEventLog://System]
disabled = false
index = $($SplunkIndex)
renderXml = false

# Optional: Monitor local log directory
#[monitor://C:\Logs]
#disabled = false
#index = $($SplunkIndex)
#sourcetype = winlog_custom
"@
$InputsPath = "C:\Program Files\SplunkUniversalForwarder\etc\system\local\inputs.conf"
$InputsConf | Out-File -Encoding ASCII -FilePath $InputsPath -Force

# Enable and start Splunk Forwarder
& "C:\Program Files\SplunkUniversalForwarder\bin\splunk.exe" enable boot-start --accept-license --answer-yes
Set-Service -Name SplunkForwarder -StartupType Automatic
Start-Service SplunkForwarder

Write-Host " Splunk Universal Forwarder installed and configured." -ForegroundColor Green

# ================================
# SECTION 3: Configure Static IP Address
# ================================

Write-Host "`nConfiguring static IP address..." -ForegroundColor Cyan

# Set static IP, subnet, gateway
New-NetIPAddress `
    -InterfaceAlias $InterfaceAlias `
    -IPAddress $IPAddress `
    -PrefixLength $PrefixLength `
    -DefaultGateway $Gateway

# Set DNS server to domain controller IP
Set-DnsClientServerAddress `
    -InterfaceAlias $InterfaceAlias `
    -ServerAddresses $DNSServers

Write-Host "Static IP $IPAddress with DNS $DNSServers configured." -ForegroundColor Green

# ================================
# SECTION 4: Join Active Directory Domain & Rename Computer
# ================================

Write-Host "`nRenaming computer to $ComputerName..." -ForegroundColor Cyan
Rename-Computer -NewName $ComputerName -Force

Write-Host "Joining domain $DomainFQDN..." -ForegroundColor Cyan
$SecurePassword = ConvertTo-SecureString $DomainPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential($DomainUser, $SecurePassword)

Add-Computer -DomainName $DomainFQDN -Credential $Credential -Force -Restart:$false

Write-Host "Computer renamed and joined to $DomainFQDN successfully." -ForegroundColor Green
Write-Host "Please reboot the system to finalize domain join." -ForegroundColor Yellow

# ================================
# SECTION 5: Enable Remote Desktop & Install RSAT
# ================================

Write-Host "`nEnabling Remote Desktop..." -ForegroundColor Cyan

# Enable RDP connections
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
    -Name "fDenyTSConnections" -Value 0

# Allow RDP through firewall
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

Write-Host "Remote Desktop enabled and allowed through firewall." -ForegroundColor Green

Write-Host "Installing RSAT tools..." -ForegroundColor Cyan

# Install Remote Server Administration Tools
Get-WindowsCapability -Name Rsat.* -Online | Add-WindowsCapability -Online

Write-Host "RSAT tools installation initiated." -ForegroundColor Green

# ================================
# SECTION 6: Configure Windows Defender
# ================================

Write-Host "`nConfiguring Windows Defender..." -ForegroundColor Cyan

# Enable real-time protection
Set-MpPreference -DisableRealtimeMonitoring $false

Write-Host "Windows Defender real-time protection is enabled." -ForegroundColor Green

# ================================
# SECTION 7: Final Confirmation Message
# ================================

Write-Host "`n==== CLIENT SETUP COMPLETE ====" -ForegroundColor Green
Write-Host "Computer is renamed and joined to domain."
Write-Host "Splunk Universal Forwarder is configured and running."
Write-Host "Static IP and RDP are enabled."
Write-Host "RSAT tools installed, Windows Defender configured."
Write-Host "A reboot is recommended to finalize the domain join and policy sync."

# ================================
# SECTION 8: Configure Auto-Login (Optional)
# ================================

Write-Host "`nEnabling Auto-Login for next boot..." -ForegroundColor Cyan


$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

Set-ItemProperty -Path $RegPath -Name "AutoAdminLogon" -Value "1"
Set-ItemProperty -Path $RegPath -Name "DefaultUsername" -Value $AutoLoginUser
Set-ItemProperty -Path $RegPath -Name "DefaultPassword" -Value $AutoLoginPassword
Set-ItemProperty -Path $RegPath -Name "DefaultDomainName" -Value $Domain

Write-Host "Auto-login has been configured for user '$Domain\\$AutoLoginUser'." -ForegroundColor Green

# ================================
# SECTION 9: Reboot System
# ================================

Write-Host "`nRebooting system in 10 seconds..." -ForegroundColor Yellow
Start-Sleep -Seconds 10
Restart-Computer -Force
