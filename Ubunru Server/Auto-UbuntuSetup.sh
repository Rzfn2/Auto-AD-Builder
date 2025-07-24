#!/bin/bash

#######################################################################
# setup_splunk_ubuntu.sh
#
# Purpose: Automates installation and preparation of Splunk Enterprise
#          on Ubuntu to act as a central log receiver.
#######################################################################

# ================================
# SECTION 1: Global Variables
# ================================

# Splunk details
SPLUNK_VERSION="9.4.3"
SPLUNK_BUILD="237ebbd22314"
SPLUNK_DEB="splunk-${SPLUNK_VERSION}-${SPLUNK_BUILD}-linux-amd64.deb"
SPLUNK_URL="https://download.splunk.com/products/splunk/releases/${SPLUNK_VERSION}/linux/${SPLUNK_DEB}"
DOWNLOAD_DIR="/tmp"

# Splunk admin credentials and log index
SPLUNK_ADMIN_USER="admin"
SPLUNK_ADMIN_PASS="Rzfn@123"
SPLUNK_INDEX_NAME="abdullah-ad"

# Network settings
INTERFACE="ens33"                # Replace with your actual interface if needed
STATIC_IP="192.168.12.120"
SUBNET_MASK="24"
GATEWAY="192.168.12.1"
DNS_SERVER="192.168.12.10"

# Active Directory settings
AD_DOMAIN="ABDULLAH-AD.local"
AD_ADMIN="Administrator"
AD_PASSWORD="Rzfn@123"

# ================================
# SECTION 2: Download Splunk Installer
# ================================

echo "==== [2] Downloading Splunk ${SPLUNK_VERSION} to ${DOWNLOAD_DIR} ===="

cd "$DOWNLOAD_DIR" || {
  echo "ERROR: Failed to access $DOWNLOAD_DIR"
  exit 1
}

if wget -q -O "$SPLUNK_DEB" "$SPLUNK_URL"; then
  echo "Splunk installer downloaded successfully: $SPLUNK_DEB"
else
  echo "ERROR: Failed to download Splunk. Please check the URL and network."
  exit 1
fi

# ================================
# SECTION 3: Configure Static IP Address
# ================================

echo "==== [3] Configuring Static IP Address on $INTERFACE ===="

NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"

if [ -f "$NETPLAN_FILE" ]; then
  sudo cp "$NETPLAN_FILE" "${NETPLAN_FILE}.bak"
else
  echo "ERROR: Netplan config file not found at $NETPLAN_FILE"
  exit 1
fi

cat <<EOF | sudo tee "$NETPLAN_FILE" > /dev/null
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses: [$STATIC_IP/$SUBNET_MASK]
      gateway4: $GATEWAY
      nameservers:
        addresses: [$DNS_SERVER]
EOF

# Apply the new network configuration
sudo netplan apply

# Confirm that the IP was applied
if ip addr show "$INTERFACE" | grep -q "$STATIC_IP"; then
  echo "Static IP $STATIC_IP successfully applied to $INTERFACE"
else
  echo "ERROR: Static IP configuration failed"
  exit 1
fi

# ================================
# SECTION 4: Join Active Directory Domain
# ================================

echo "==== [4] Joining Active Directory Domain: $AD_DOMAIN ===="

# Update system and install required packages for AD integration
echo "Installing required packages..."
sudo apt update && sudo apt install -y \
  realmd sssd adcli samba-common-bin oddjob oddjob-mkhomedir packagekit

# Ensure the realm command exists
if ! command -v realm &> /dev/null; then
  echo "ERROR: 'realm' command not found. AD join tools are not properly installed."
  exit 1
fi

# Discover the AD domain
echo "Discovering domain $AD_DOMAIN..."
if ! realm discover "$AD_DOMAIN"; then
  echo "ERROR: Unable to discover domain $AD_DOMAIN. Check DNS resolution and network settings."
  exit 1
fi

# Attempt domain join
echo "Attempting to join domain $AD_DOMAIN with user $AD_ADMIN..."
echo "$AD_PASSWORD" | sudo realm join --user="$AD_ADMIN" "$AD_DOMAIN"

# Verify success
if [ $? -eq 0 ]; then
  echo "Successfully joined the Active Directory domain: $AD_DOMAIN"
else
  echo "ERROR: Domain join failed. Please verify credentials and network connectivity."
  exit 1
fi

# Enable automatic home directory creation on login
echo "Enabling automatic home directory creation for domain users..."
sudo authselect enable-feature with-mkhomedir

# Restart SSSD to apply changes
echo "Restarting SSSD service..."
sudo systemctl restart sssd

# ================================
# SECTION 5: Configure Splunk
# ================================

echo "==== [5.1] Installing Splunk and Preparing Environment ===="

# Install Splunk if not already installed
if ! [ -x /opt/splunk/bin/splunk ]; then
    echo "ERROR: Splunk binary not found. Please ensure the .deb installer was successfully installed."
    exit 1
fi

# Set admin credentials before first start
echo "==== [5.2] Creating user-seed.conf for admin credentials ===="
sudo mkdir -p /opt/splunk/etc/system/local

sudo tee /opt/splunk/etc/system/local/user-seed.conf > /dev/null <<EOF
[user_info]
USERNAME = $SPLUNK_ADMIN_USER
PASSWORD = $SPLUNK_ADMIN_PASS
EOF

# Enable Splunk to start at boot and launch service
echo "==== [5.3] Enabling Splunk boot-start and starting service ===="
sudo /opt/splunk/bin/splunk enable boot-start --accept-license --answer-yes --no-prompt
sudo /opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt
sleep 10

# Open necessary firewall ports
echo "==== [5.4] Configuring UFW firewall ===="
sudo ufw allow 8000/tcp     # Splunk Web UI
sudo ufw allow 9997/tcp     # Splunk Forwarder TCP port
sudo ufw --force enable

# Create the dedicated index for AD logs
echo "==== [5.5] Creating Splunk index: $SPLUNK_INDEX_NAME ===="
sudo /opt/splunk/bin/splunk add index "$SPLUNK_INDEX_NAME" -auth "$SPLUNK_ADMIN_USER:$SPLUNK_ADMIN_PASS"

# Configure TCP input on port 9997 for receiving logs from Universal Forwarders
echo "==== [5.6] Configuring TCP listener on port 9997 for index: $SPLUNK_INDEX_NAME ===="
sudo /opt/splunk/bin/splunk add tcp 9997 \
  -sourcetype wineventlog \
  -index "$SPLUNK_INDEX_NAME" \
  -auth "$SPLUNK_ADMIN_USER:$SPLUNK_ADMIN_PASS"

# Final check: confirm inputs and index exist
echo "==== [5.7] Verifying Splunk configuration ===="
sudo /opt/splunk/bin/splunk list input tcp -auth "$SPLUNK_ADMIN_USER:$SPLUNK_ADMIN_PASS"
sudo /opt/splunk/bin/splunk list index -auth "$SPLUNK_ADMIN_USER:$SPLUNK_ADMIN_PASS"

echo "✅ Splunk is fully installed, configured, and ready to receive Windows Event Logs on port 9997."
