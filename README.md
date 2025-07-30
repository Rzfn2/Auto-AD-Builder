# 🛠️ Auto-AD-Builder

**Auto-AD-Builder** is a fully automated Active Directory lab environment that simplifies the deployment of:

* A Windows Server Domain Controller
* A Windows 11 domain-joined client
* An Ubuntu Server for integration

The setup uses custom unattended installation files and automation scripts to streamline configuration. Each system is modular, isolated, and designed for fast deployment.

---

## 📂 Environment Setup Guides

Please begin by following the individual OS setup guides to create and install your virtual machines:

* 🪟 [Windows 11 Client Setup](https://github.com/Rzfn2/Auto-AD-Builder/tree/main/Windows%2011)
* 🖥️ [Windows Server 2022 Setup](https://github.com/Rzfn2/Auto-AD-Builder/tree/main/Windows%20Server)
* 🐧 [Ubuntu Server Setup](https://github.com/Rzfn2/Auto-AD-Builder/tree/main/Ubunru%20Server)

---

## ⚙️ Configuration Preparation (Required Before Deployment)

Before beginning step-by-step deployment, you must copy the configuration scripts into each virtual machine after OS installation.

### 🖥️ Windows Server

Use these PowerShell commands inside the VM to download your script files:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Rzfn2/Auto-AD-Builder/main/windows-server/AutoDC-Conflagrations.ps1" -OutFile "C:\Users\Administrator\Desktop\AutoDC-Conflagrations.ps1"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Rzfn2/Auto-AD-Builder/main/windows-server/AutoDC-Deployment.ps1" -OutFile "C:\Users\Administrator\Desktop\AutoDC-Deployment.ps1"
```

Edit them if needed:

```powershell
notepad C:\Users\Administrator\Desktop\AutoDC-Conflagrations.ps1
notepad C:\Users\Administrator\Desktop\AutoDC-Deployment.ps1
```

**Script Descriptions:**

* `AutoDC-Conflagrations.ps1`: This script runs after the initial installation. It sets the computer name (`WINDC-001`), configures the network (static IP and DNS), installs the AD DS role, and promotes the server to a Domain Controller with forest and domain setup (`ABDULLAH-AD.local`). It also reboots the server after promotion.
* `AutoDC-Deployment.ps1`: This script runs *after the reboot*. It handles post-promotion configuration: creates OUs, users, groups, assigns users to groups, and links GPOs to the right OUs.

### 🪟 Windows 11 Client

Download the client setup script:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Rzfn2/Auto-AD-Builder/main/windows11/Auto-Client.ps1" -OutFile "C:\Users\Administrator\Desktop\Auto-Client.ps1"
```

Edit it if needed:

```powershell
notepad C:\Users\Administrator\Desktop\Auto-Client.ps1
```

### 🐧 Ubuntu Server

Use this command inside the VM:

```bash
wget https://raw.githubusercontent.com/Rzfn2/Auto-AD-Builder/main/ubuntu-server/Auto-Ubuntu.sh
chmod +x Auto-Ubuntu.sh
nano Auto-Ubuntu.sh
```

---

## 🚀 Step-by-Step Lab Deployment

### ✅ Step 1: Configure the Domain Controller (Windows Server)

After first login, run the following script:

```powershell
powershell -ExecutionPolicy Bypass -File .\AutoDC-Conflagrations.ps1
```

This script will:

* Set hostname to `WINDC-001`
* Configure static IP and DNS
* Install AD DS
* Promote to Domain Controller (`ABDULLAH-AD.local`)
* Reboot after setup

After reboot, log back in and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\AutoDC-Deployment.ps1
```

This script will:

* Create Organizational Units (OUs)
* Create users and groups
* Add users to groups
* Link Group Policy Objects (GPOs) to OUs

### ✅ Step 2: Configure the Windows 11 Client

After login, open PowerShell in the Desktop directory and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\Auto-Client.ps1
```

This script will:

* Download and configure Splunk Universal Forwarder
* Assign static IP (default: `192.168.12.10`)
* Join the domain `ABDULLAH-AD.local`

### ✅ Step 3: Configure Ubuntu Server

Login as `abdullah` and run:

```bash
sudo ./Auto-Ubuntu.sh
```

This script will:

* Configure hostname (`ubuntu-client`)
* Set static IP and DNS
* Install required packages (realm, sssd, etc.)
* Join the domain `ABDULLAH-AD.local`
* Install and configure Splunk Forwarder

---

## 📋 Credentials Summary

| Machine           | Username      | Password   |
| ----------------- | ------------- | ---------- |
| Windows Server    | Administrator | Rzfn2\@123 |
| Windows 11 Client | Administrator | Rzfn\@123  |
| Ubuntu Server     | abdullah      | Password   |

> 🔐 Change passwords and hostnames if needed for security or customization.

---

## 🧠 Final Notes

* Follow the OS setup guide links first before script deployment.
* Ensure all scripts are executed from elevated/administrator terminals.
* Adjust network configuration if using a different IP range.
---
## 📸 Screenshots
<img width="863" height="511" alt="image" src="https://github.com/user-attachments/assets/027fe76f-3bac-4057-bec3-4b5ae9bd8cc4" />


<img width="1910" height="871" alt="image" src="https://github.com/user-attachments/assets/941cab90-25da-4ba0-ba43-79918499bf16" />


<img width="1904" height="826" alt="image" src="https://github.com/user-attachments/assets/a55466f5-b64a-4d6d-8f62-3494b3ef119e" />


---

> 💬 For feedback or issues, please open an issue on the [GitHub repository](https://github.com/Rzfn2/Auto-AD-Builder)
