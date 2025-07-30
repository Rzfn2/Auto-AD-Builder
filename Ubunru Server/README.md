# 🐧 Ubuntu Server Setup Guide

This guide explains how to automatically install and configure Ubuntu Server for the Auto-AD-Builder environment using a modified ISO. The process uses **AnyBurn** to replace `grub.cfg` and add the autoinstall configuration.

---

## 🔧 Tools Needed

* Ubuntu Server ISO (22.04 preferred)
* [AnyBurn](https://www.anyburn.com/) to modify the ISO
* Custom configuration files:

  * [`grub.cfg`](https://github.com/Rzfn2/Auto-AD-Builder/blob/main/Ubunru%20Server/grub.cfg)
  * [`user-data`](https://github.com/Rzfn2/Auto-AD-Builder/blob/main/Ubunru%20Server/user-data) ← **must be in valid YAML format**

---

## 📝 Instructions

### Step 1: Prepare the Custom ISO Using AnyBurn

1. Install and launch AnyBurn.
2. Select **Edit Image File** and open the original Ubuntu ISO (`ubuntu-22.04-live-server-amd64.iso`).
3. Navigate to `boot/grub/` and delete the existing `grub.cfg`.
4. Add the new `grub.cfg` file into `boot/grub/`.
5. Create a folder at the root level named `nocloud` (if not present).
6. Add your `autoinstall.yaml` file into the `nocloud/` folder and rename it to `user-data`.
7. Also add a new, empty file named `meta-data` into the same `nocloud/` folder. This file is required for the autoinstall process to initialize correctly.
8. Save the updated image as a new ISO, e.g., `ubuntu-autoinstall.iso`.

> ⚠️ Only include the most up-to-date versions of `grub.cfg`, `user-data`, and `meta-data`. Delete all outdated versions.

---

## 🚀 Final Setup and Credentials

* Boot the VM using the new ISO (`ubuntu-autoinstall.iso`).
* The installation will run automatically with no user input.

> ✅ **Default setup from user-data**:
>
> * **Username:** `abdullah`
> * **Password:** `Password`
> * **Hostname:** `ubuntu-client`

After installation, the VM will log into the `abdullah` account by default and be ready for post-deployment integration.

---

> 🧠 This Ubuntu machine is intended to join the domain and participate in the Auto-AD-Builder lab. Next steps include setting up `realm`, `sssd`, and forwarding logs if needed.
