<#
    AutoDC_Configuration.ps1

    DESCRIPTION:
    This script prepares a Windows Server for automated Active Directory deployment and log forwarding using Splunk.

    INSTRUCTIONS:
    1. Edit the variables in SECTION 1 to fit your environment.
    2. Run this script as Administrator on a clean Windows Server machine.
    3. After reboot, MasterDeployment.ps1 should run to finalize setup.
#>

# ================================
# SECTION 1: Global Variables
# ================================

# Splunk Configuration
$SplunkServer     = "192.168.12.120"        # IP address of your Splunk Indexer (receiver)
$SplunkPort       = 9997                    # Port used by Splunk Indexer to receive forwarded data (default: 9997)
$SplunkIndex      = "abdullah-ad"           # Index name in Splunk (must already exist)
$InstallerFile    = "splunkforwarder-9.4.3-237ebbd22314-windows-x64.msi"  # Splunk Universal Forwarder installer filename

# Auto-Login and Domain Setup
$AutoLoginUser     = "Administrator"        # Local admin user to auto-login (will be promoted to Domain Admin)
$AutoLoginPassword = "Rzfn@123"             # Password used for both auto-login and DSRM mode
$DomainName        = "ABDULLAH-AD"          # NetBIOS domain name (short name)
$FQDN              = "$DomainName.local"    # Fully Qualified Domain Name (FQDN) for the domain
$NetbiosName       = "ABDULLAHAD"           # NetBIOS-compatible name for legacy services

# Network Configuration
$IPAddress        = "192.168.12.10"         # Static IP address to assign to the DC
$PrefixLength     = 24                      # Subnet prefix length (24 = 255.255.255.0)
$Gateway          = "192.168.12.1"          # Default gateway for internet access
$DNSServers       = "127.0.0.1"             # Use loopback if this machine is also the DNS server
$InterfaceAlias = (Get-NetAdapter | Where-Object {
    $_.Status -eq 'Up' -and
    $_.InterfaceDescription -notmatch 'Loopback|Virtual'
} | Select-Object -First 1).Name




# ================================
# SECTION 2: Splunk Installation & Configuration
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

Write-Host "`n Configuring static IP address..." -ForegroundColor Cyan

New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $Gateway
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DNSServers

Write-Host " Static IP $IPAddress configured successfully." -ForegroundColor Green

# ================================
# SECTION 4: Auto-Login and Schedule Post-Reboot Script
# ================================

Write-Host "`nConfiguring auto-login for next boot..." -ForegroundColor Cyan

# Registry path for auto-login
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

# Set auto-login registry keys
Set-ItemProperty -Path $RegPath -Name "AutoAdminLogon" -Value "1" -Type String
Set-ItemProperty -Path $RegPath -Name "DefaultUsername" -Value $AutoLoginUser -Type String
Set-ItemProperty -Path $RegPath -Name "DefaultPassword" -Value $AutoLoginPassword -Type String
Set-ItemProperty -Path $RegPath -Name "DefaultDomainName" -Value $DomainName -Type String

# Schedule AutoDC-Deployment.ps1 to run after login
#Write-Host "Scheduling AutoDC-Deployment.ps1 to run on first login..." -ForegroundColor Cyan

#$RunOncePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
#$DeploymentScript = "C:\Users\Administrator\Desktop\AutoDC-Deployment.ps1"  # Adjust path if needed
#$Command = "powershell.exe -ExecutionPolicy Bypass -File `"$DeploymentScript`""

#Set-ItemProperty -Path $RunOncePath -Name "RunMasterDeployment" -Value $Command

#Write-Host "Auto-login and scheduled task configured successfully." -ForegroundColor Green

# ================================
# SECTION 5: Install and Promote to Domain Controller
# ================================

Write-Host "`nInstalling Active Directory Domain Services and DNS..." -ForegroundColor Cyan

Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
Install-WindowsFeature -Name DNS -IncludeManagementTools

Write-Host "Importing ADDSDeployment module..." -ForegroundColor Cyan
Import-Module ADDSDeployment

Write-Host "Promoting this server to Domain Controller..." -ForegroundColor Cyan

Install-ADDSForest `
    -DomainName $FQDN `
    -DomainNetbiosName $NetbiosName `
    -SafeModeAdministratorPassword (ConvertTo-SecureString $AutoLoginPassword -AsPlainText -Force) `
    -InstallDNS `
    -Force

Write-Host "Domain Controller promotion initiated. The system will now reboot automatically." -ForegroundColor Yellow
