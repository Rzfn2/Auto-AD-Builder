<#
   Auto-Client.ps1
    DESCRIPTION:
    This script configures a Windows 11 client machine to:
    - Install & configure Splunk Universal Forwarder
    - Set static IP
    - Join Active Directory domain
#>
# ================================
# Global Variables
# ================================

# Splunk Configuration
$SplunkServer     = "192.168.12.120"        # IP address of your Splunk Indexer (receiver)
$SplunkPort       = 9997                    # Port used by Splunk Indexer to receive forwarded data (default: 9997)
$SplunkIndex      = "abdullah-ad"           # Index name in Splunk (must already exist)
$InstallerFile    = "splunkforwarder-9.4.3-237ebbd22314-windows-x64.msi"  # Splunk Universal Forwarder installer filename

# Join Domain

$Domain = "ABDULLAH-AD.local"
$DomainUser = "ABDULLAH-AD\Administrator"
$DomainPassword = "Rzfn@123"
$SecurePassword = ConvertTo-SecureString $DomainPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential($DomainUser, $SecurePassword)

# Network Configuration
$IPAddress        = "192.168.12.110"         # Static IP address to assign to the DC
$PrefixLength     = 24                      # Subnet prefix length (24 = 255.255.255.0)
$Gateway          = "192.168.12.1"          # Default gateway for internet access
$DNSServers       = "192.168.12.10"             # Use loopback if this machine is also the DNS server
$InterfaceAlias = (Get-NetAdapter | Where-Object {
    $_.Status -eq 'Up' -and
    $_.InterfaceDescription -notmatch 'Loopback|Virtual'
} | Select-Object -First 1).Name




# ================================
# Splunk Installation & Configuration
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
# Configure Static IP Address
# ================================

Write-Host "`n Configuring static IP address..." -ForegroundColor Cyan

New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $Gateway
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DNSServers

Write-Host " Static IP $IPAddress configured successfully." -ForegroundColor Green

# ==============================
# Join Active Directory domain
# ==============================
Write-Host ' Join Active Directory domain' -ForegroundColor Yellow
Add-Computer -DomainName $Domain -Credential $Credential -Restart:$false
Write-Host "Joined to domain $Domain"
