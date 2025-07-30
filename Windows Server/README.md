# 🖥️ Windows Server 2022 Setup Guide

This guide explains how to automatically install and configure a Windows Server 2022 machine as a Domain Controller (DC) for the Auto-AD-Builder environment.

---

## 🔧 Tools Needed

* Windows Server 2022 ISO
* [AnyBurn](https://www.anyburn.com/) to embed the unattend file into the ISO
* [Autounattend.xml](https://github.com/Rzfn2/Auto-AD-Builder/blob/main/Windows%20Server/autounattend.xml) file

---

## 📝 Step-by-Step Instructions

### Step 1: Modify Windows Server ISO with AnyBurn

1. Download and install AnyBurn.
2. Open AnyBurn > **Edit Image File**.
3. Select your original Windows Server 2022 ISO.
4. Click **Add** and choose the `Autounattend.xml` file.
5. Make sure it's placed at the **root** of the ISO structure.
6. Click **Save As** and name the new ISO (e.g., `WinServer-Auto.iso`).

> ✅ Default credentials used in Autounattend.xml are:
>
> * **Username:** Administrator
> * **Password:** Rzfn@123

### Step 2: Choose Windows Server Version in XML

Inside your `Autounattend.xml`, search for:

```xml
      <Key>/IMAGE/INDEX </Key>
```

The `<ImageIndex>` value selects which edition of Windows Server is installed. To find the available editions:

#### Get Windows Server Editions with DISM

1. Mount the ISO.
2. Open PowerShell and run:

```powershell
dism /Get-WimInfo /WimFile:D:\sources\install.wim
```

Replace `D:` with your ISO drive letter.

This will list all available editions and their corresponding index numbers. Use this info to update your XML accordingly (e.g., Standard Core, Standard with Desktop Experience, etc.).

---

## 🚀 Final Setup

* Boot the VM using the modified ISO.
* Installation will complete automatically.
* Windows will log in with the Administrator account.

---

> 🧠 This setup is the base for configuring the Domain Controller. For Active Directory setup, DNS, Group Policy, and static IP configurations, refer to the main deployment scripts and logic.
