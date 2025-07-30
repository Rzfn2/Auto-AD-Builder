# 🪟 Windows 11 Client Setup Guide

This guide explains how to automatically install and configure a Windows 11 client in the Auto-AD-Builder environment using an unattended installation and post-install script.

---

## 🔧 Tools Needed

* Windows 11 ISO 
* [AnyBurn](https://www.anyburn.com/) to embed the unattend file into the ISO
* [Autounattend XML](https://github.com/Rzfn2/Auto-AD-Builder/blob/main/Windows%2011/autounattend.xml) file 

---

## 📝 Step-by-Step Instructions

### Step 1: Modify Windows 11 ISO with AnyBurn

1. Download and install AnyBurn.
2. Open AnyBurn > **Edit Image File**.
3. Select your original Windows 11 ISO.
4. Click **Add** and choose the `Autounattend.xml` file.
5. Make sure it's placed at the **root** of the ISO structure.
6. Click **Save As** and name the new ISO (e.g., `Win11-Auto.iso`).

> ✅ Default credentials used in Autounattend.xml are:
>
> * **Username:** Administrator
> * **Password:** Rzfn@123

### Step 2: Choose Windows Version in XML

Inside your `Autounattend.xml`, search for:

```xml
      <Key>/IMAGE/INDEX </Key>
```

The `<ImageIndex>` determines which version of Windows is installed. To check what index matches your ISO:

#### Get Windows Editions with DISM

1. Mount the Windows ISO.
2. Run this in PowerShell:

```powershell
dism /Get-WimInfo /WimFile:D:\sources\install.wim
```

Replace `D:` with your ISO drive letter.

This will list available editions and their index numbers (e.g., Pro might be `10`).
Update the XML accordingly.

---

## 🚀 Final Setup

* Boot the VM using the modified ISO.
* Installation will be completely automated.
* After setup, Windows will auto-log in with the configured Administrator account.

---

> 🧠 This setup is used as part of a larger automated Active Directory lab. For domain join and network config, refer to the appropriate scripts or master deployment logic.
