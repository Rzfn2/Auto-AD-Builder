<#
    AutoDC-Deployment.ps1
    Run this script AFTER reboot and logging in as Domain Administrator.
    This configures OUs, groups, users, policies, and basic features.
#>

$DomainName = "ABDULLAH-AD"

# ===========================
# Create Organizational Units
# ===========================
Write-Host "Creating Organizational Units..."

New-ADOrganizationalUnit -Name "IT" -Path "DC=$DomainName,DC=local"
New-ADOrganizationalUnit -Name "HR" -Path "DC=$DomainName,DC=local"
New-ADOrganizationalUnit -Name "Finance" -Path "DC=$DomainName,DC=local"
New-ADOrganizationalUnit -Name "Sales" -Path "DC=$DomainName,DC=local"
New-ADOrganizationalUnit -Name "Marketing" -Path "DC=$DomainName,DC=local"

# ===========================
# Create Security Groups
# ===========================
Write-Host "Creating Security Groups..."

New-ADGroup -Name "IT Group" -GroupScope Global -Path "OU=IT,DC=$DomainName,DC=local"
New-ADGroup -Name "HR Group" -GroupScope Global -Path "OU=HR,DC=$DomainName,DC=local"
New-ADGroup -Name "Finance Group" -GroupScope Global -Path "OU=Finance,DC=$DomainName,DC=local"
New-ADGroup -Name "Sales Group" -GroupScope Global -Path "OU=Sales,DC=$DomainName,DC=local"
New-ADGroup -Name "Marketing Group" -GroupScope Global -Path "OU=Marketing,DC=$DomainName,DC=local"

# ===========================
# Create Users
# ===========================
Write-Host "Creating User Accounts..."

# IT Users
New-ADUser -Name "Khalid IT" -SamAccountName "khalid.it" -AccountPassword (ConvertTo-SecureString "ITpass123!" -AsPlainText -Force) -Enabled $true -Path "OU=IT,DC=$DomainName,DC=local"
New-ADUser -Name "Ali IT" -SamAccountName "ali.it" -AccountPassword (ConvertTo-SecureString "AliIT@123" -AsPlainText -Force) -Enabled $true -Path "OU=IT,DC=$DomainName,DC=local"

# HR Users
New-ADUser -Name "Fatima HR" -SamAccountName "F.hr" -AccountPassword (ConvertTo-SecureString "HRsimple1!" -AsPlainText -Force) -Enabled $true -Path "OU=HR,DC=$DomainName,DC=local"
New-ADUser -Name "Yasmin HR" -SamAccountName "yasmin.hr" -AccountPassword (ConvertTo-SecureString "WelcomeHR!" -AsPlainText -Force) -Enabled $true -Path "OU=HR,DC=$DomainName,DC=local"

# Finance Users
New-ADUser -Name "Layla Finance" -SamAccountName "layla.finance" -AccountPassword (ConvertTo-SecureString "Finance007!" -AsPlainText -Force) -Enabled $true -Path "OU=Finance,DC=$DomainName,DC=local"
New-ADUser -Name "Rakan Finance" -SamAccountName "rakan.finance" -AccountPassword (ConvertTo-SecureString "FinSimple2!" -AsPlainText -Force) -Enabled $true -Path "OU=Finance,DC=$DomainName,DC=local"

# Sales Users
New-ADUser -Name "Yousef Sales" -SamAccountName "yousef.sales" -AccountPassword (ConvertTo-SecureString "SalesPass1!" -AsPlainText -Force) -Enabled $true -Path "OU=Sales,DC=$DomainName,DC=local"
New-ADUser -Name "Henry Sales" -SamAccountName "henry.sales" -AccountPassword (ConvertTo-SecureString "Henry321!" -AsPlainText -Force) -Enabled $true -Path "OU=Sales,DC=$DomainName,DC=local"

# Marketing Users
New-ADUser -Name "Omar Marketing" -SamAccountName "omar.marketing" -AccountPassword (ConvertTo-SecureString "omarPass9!" -AsPlainText -Force) -Enabled $true -Path "OU=Marketing,DC=$DomainName,DC=local"
New-ADUser -Name "Jack Marketing" -SamAccountName "jack.marketing" -AccountPassword (ConvertTo-SecureString "Jack@2024" -AsPlainText -Force) -Enabled $true -Path "OU=Marketing,DC=$DomainName,DC=local"

# Abdullah Admin Account
New-ADUser -Name "Abdullah BNR" -SamAccountName "abdullah" -AccountPassword (ConvertTo-SecureString "Rzfn@123" -AsPlainText -Force) -Enabled $true -Path "OU=IT,DC=$DomainName,DC=local"
Add-ADGroupMember -Identity "Domain Admins" -Members "abdullah"

# ===========================
# Add Users to Their Groups
# ===========================
Write-Host "Adding Users to Groups..."

Add-ADGroupMember -Identity "IT Group" -Members "khalid.it","ali.it"
Add-ADGroupMember -Identity "HR Group" -Members "F.hr","yasmin.hr"
Add-ADGroupMember -Identity "Finance Group" -Members "layla.finance","rakan.finance"
Add-ADGroupMember -Identity "Sales Group" -Members "yousef.sales","henry.sales"
Add-ADGroupMember -Identity "Marketing Group" -Members "omar.marketing","jack.marketing"

# ===========================
# Create Group Policy
# ===========================
Write-Host "Creating and Linking Group Policy..."

$gpo = Get-GPO -Name "BaselinePolicy" -ErrorAction SilentlyContinue
if (-not $gpo) {
    $gpo = New-GPO -Name "BaselinePolicy"
}

if ($gpo) {
    New-GPLink -Name $gpo.DisplayName -Target "DC=$DomainName,DC=local"

    # Disable password complexity
    Set-GPRegistryValue -Name $gpo.DisplayName `
        -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
        -ValueName "PasswordComplexity" `
        -Type DWord `
        -Value 0

    # Set minimum password length to 6
    Set-GPRegistryValue -Name $gpo.DisplayName `
        -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
        -ValueName "MinimumPasswordLength" `
        -Type DWord `
        -Value 6
} else {
    Write-Warning "GPO creation failed. Skipping GPO configuration."
}

# ===========================
# Enable SMBv1 and RDP
# ===========================
#Write-Host "Enabling SMBv1 and Remote Desktop..."

#try {
#    Set-SmbServerConfiguration -EnableSMB1Protocol $true -Force
#} catch {
#    Write-Warning "SMBv1 could not be enabled. It may not be available on this OS."
#}
#
#Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
#Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# ===========================
# Enable Null Sessions
# ===========================
Write-Host "Allowing Null Sessions..."

New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RestrictAnonymous" -Value 0 -PropertyType DWord -Force

Write-Host "Master deployment complete. Environment is fully configured."
