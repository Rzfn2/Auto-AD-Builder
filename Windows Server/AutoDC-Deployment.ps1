<#
    MasterDeployment.ps1
    GitHub-Friendly Script to Deploy Active Directory OUs, Groups, Users, and GPOs
    Designed for automated AD environment configuration post-DC setup and reboot.
#>

# ================================
# SECTION 1: Global Variables
# ================================

# Domain name and DN (DN is auto-derived)
$DomainName = "ABDULLAH-AD.local"
$DomainDN = ($DomainName -split '\.') -replace { "DC=$($_)" } -join ','

# Organizational Units
$OUs = @("IT", "HR", "Finance", "Sales", "Marketing")

# Security Groups
$Groups = @{
    "IT"        = "IT Group"
    "HR"        = "HR Group"
    "Finance"   = "Finance Group"
    "Sales"     = "Sales Group"
    "Marketing" = "Marketing Group"
}

# Users
$UserData = @{
    "IT" = @(
        @{ Name = "Alice IT";      User = "alice.it";      Pass = "ITpass123!" },
        @{ Name = "Bob IT";        User = "bob.it";        Pass = "Bob321pass" }
    )
    "HR" = @(
        @{ Name = "Carol HR";      User = "carol.hr";      Pass = "HRsimple1" },
        @{ Name = "Dave HR";       User = "dave.hr";       Pass = "WelcomeHR!" }
    )
    "Finance" = @(
        @{ Name = "Eve Finance";   User = "eve.finance";   Pass = "Finance007" },
        @{ Name = "Frank Finance"; User = "frank.finance"; Pass = "FinSimple2" }
    )
    "Sales" = @(
        @{ Name = "Grace Sales";   User = "grace.sales";   Pass = "SalesPass1" },
        @{ Name = "Henry Sales";   User = "henry.sales";   Pass = "Henry321" }
    )
    "Marketing" = @(
        @{ Name = "Ivy Marketing"; User = "ivy.marketing"; Pass = "IvyPass9" },
        @{ Name = "Jack Marketing";User = "jack.marketing";Pass = "JackSimple" }
    )
}

# Admin Account
$AdminUser = "abdullah"
$AdminPass = "Rzfn@123"
$AdminName = "Abdullah BNR"

# GPO
$GPOName = "BaselinePolicy"

# ================================
# SECTION 2: Create OUs and Groups
# ================================

Write-Host "`n=== Creating Organizational Units ==="
foreach ($ou in $OUs) {
    New-ADOrganizationalUnit -Name $ou -Path $DomainDN -ErrorAction SilentlyContinue
}

Write-Host "`n=== Creating Security Groups ==="
foreach ($ou in $Groups.Keys) {
    $groupName = $Groups[$ou]
    $ouPath = "OU=$ou,$DomainDN"
    New-ADGroup -Name $groupName -GroupScope Global -Path $ouPath -ErrorAction SilentlyContinue
}

# ================================
# SECTION 3: Create Users
# ================================

Write-Host "`n=== Creating Users ==="
foreach ($ou in $UserData.Keys) {
    $users = $UserData[$ou]
    foreach ($user in $users) {
        $userPath = "OU=$ou,$DomainDN"
        New-ADUser -Name $user.Name `
                   -SamAccountName $user.User `
                   -AccountPassword (ConvertTo-SecureString $user.Pass -AsPlainText -Force) `
                   -Enabled $true `
                   -Path $userPath
    }
}

Write-Host "`n=== Creating Admin Account ==="
New-ADUser -Name $AdminName -SamAccountName $AdminUser `
    -AccountPassword (ConvertTo-SecureString $AdminPass -AsPlainText -Force) `
    -Enabled $true -Path "OU=IT,$DomainDN"

Add-ADGroupMember -Identity "Domain Admins" -Members $AdminUser

# ================================
# SECTION 4: Add Users to Groups
# ================================

Write-Host "`n=== Adding Users to Security Groups ==="
foreach ($ou in $UserData.Keys) {
    $users = $UserData[$ou]
    $group = $Groups[$ou]
    $usernames = $users | ForEach-Object { $_.User }
    Add-ADGroupMember -Identity $group -Members $usernames
}

# ================================
# SECTION 5: Create and Link GPO
# ================================

Write-Host "`n=== Creating and Linking GPO: $GPOName ==="
$gpo = New-GPO -Name $GPOName -ErrorAction SilentlyContinue
New-GPLink -Name $gpo.DisplayName -Target $DomainDN

# Disable password complexity
Set-GPRegistryValue -Name $GPOName `
    -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
    -ValueName "PasswordComplexity" -Type DWord -Value 0

# Set minimum password length to 6
Set-GPRegistryValue -Name $GPOName `
    -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
    -ValueName "MinimumPasswordLength" -Type DWord -Value 6

# ================================
# SECTION 6: Enable Features
# ================================

Write-Host "`n=== Enabling SMBv1 and RDP ==="
Set-SmbServerConfiguration -EnableSMB1Protocol $true -Force
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
                 -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

Write-Host "`n=== Allowing Null Sessions ==="
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" `
                 -Name "RestrictAnonymous" -Value 0 -PropertyType DWord -Force

Write-Host "`n Master deployment complete. AD environment is fully configured."
