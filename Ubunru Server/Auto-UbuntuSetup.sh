#!/bin/bash
set -euo pipefail
#######################################################################
# Auto-UbuntuSetup.sh
# Purpose: Automates installation and preparation of Splunk Enterprise 
# on Ubuntu to act as a central log receiver.
#######################################################################

# ================================
# Global Variables
# ================================

# Splunk download URL
SPLUNK_URL="https://download.splunk.com/products/splunk/releases/9.4.3/linux/splunk-9.4.3-237ebbd22314-linux-amd64.deb"
DEB_NAME="${SPLUNK_URL##*/}"
DOWNLOAD_DIR="$HOME"

# Splunk admin creds and index name
SPLUNK_ADMIN_USER="admin"
SPLUNK_ADMIN_PASS="Rzfn@123"
SPLUNK_INDEX_NAME="abdullah-ad"

# Network settings
INTERFACE="ens33"
STATIC_IP="192.168.12.120"
SUBNET_MASK="24"
GATEWAY="192.168.12.1"
DNS_SERVER="192.168.12.10"

# Active Directory settings
AD_DOMAIN="ABDULLAH-AD.local"
AD_ADMIN_USER="Administrator"
AD_ADMIN_PASS="Rzfn@123"

# ================================
# Helpers
# ================================
info() { echo -e "\e[1;34m[INFO]\e[0m $*"; }
die()  { echo -e "\e[1;31m[ERROR]\e[0m $*" >&2; exit 1; }

# must run as root
[[ $EUID -eq 0 ]] || die "Please run this script as root or via sudo."

# ================================
# Install Prerequisites
# ================================
info "Installing prerequisites (realmd, sssd, sssd-tools, network tools)..."
apt-get update -y
apt-get install -y \
  realmd sssd sssd-tools authselect adcli samba-common-bin oddjob oddjob-mkhomedir packagekit \
  wget ufw netplan.io

# ================================
# Download & Install Splunk
# ================================
info "Downloading Splunk Enterprise to $DOWNLOAD_DIR"
mkdir -p "$DOWNLOAD_DIR" && cd "$DOWNLOAD_DIR"
[[ -f "$DEB_NAME" ]] || {
  wget -q "$SPLUNK_URL" -O "$DEB_NAME" || die "Download failed."
  info "Downloaded $DEB_NAME"
}
info "Installing Splunk Enterprise"
dpkg -i "$DEB_NAME" || (apt-get update -y && apt-get install -f -y)
[[ -x /opt/splunk/bin/splunk ]] || die "Splunk not installed properly."

# ================================
# Configure Static IP & DNS
# ================================
info "Configuring static IP ${STATIC_IP}/${SUBNET_MASK} on $INTERFACE"
NETPLAN_FILE=$(ls /etc/netplan/*.yaml | head -n1)
[[ -f "$NETPLAN_FILE" ]] || die "No netplan file found."
cp "$NETPLAN_FILE" "${NETPLAN_FILE}.bak"
cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${INTERFACE}:
      dhcp4: no
      addresses: [${STATIC_IP}/${SUBNET_MASK}]
      nameservers:
        search: [${AD_DOMAIN}]
        addresses: [${DNS_SERVER}]
      routes:
        - to: 0.0.0.0/0
          via: ${GATEWAY}
EOF
netplan apply
ip addr show dev "$INTERFACE" | grep -q "$STATIC_IP" || die "Static IP apply failed"
info "Static IP applied successfully."

info "Updating /etc/resolv.conf"
cat > /etc/resolv.conf <<EOF
search ${AD_DOMAIN}
nameserver ${DNS_SERVER}
EOF

# ================================
# Join Active Directory domain
# ================================
info "Discovering AD domain $AD_DOMAIN"
realm discover "$AD_DOMAIN" >/dev/null || die "Domain discovery failed"
info "Joining domain $AD_DOMAIN as $AD_ADMIN_USER"
echo "$AD_ADMIN_PASS" | realm join --user="$AD_ADMIN_USER" "$AD_DOMAIN" || die "Domain join failed"
info "Enabling home directory creation"
authselect enable-feature with-mkhomedir
systemctl restart sssd

# ================================
# Configure Splunk
# ================================
info "Seeding Splunk admin credentials"
mkdir -p /opt/splunk/etc/system/local
cat > /opt/splunk/etc/system/local/user-seed.conf <<EOF
[user_info]
USERNAME = ${SPLUNK_ADMIN_USER}
PASSWORD = ${SPLUNK_ADMIN_PASS}
EOF
info "Enabling and starting Splunk"
/opt/splunk/bin/splunk enable boot-start --accept-license --answer-yes
/opt/splunk/bin/splunk start --accept-license --answer-yes
sleep 5

info "Configuring firewall"
ufw allow 8000/tcp
ufw allow 9997/tcp
ufw --force enable

info "Creating Splunk index and TCP input"
/opt/splunk/bin/splunk add index "${SPLUNK_INDEX_NAME}" -auth "${SPLUNK_ADMIN_USER}:${SPLUNK_ADMIN_PASS}"
/opt/splunk/bin/splunk add tcp 9997 -sourcetype wineventlog -index "${SPLUNK_INDEX_NAME}" -auth "${SPLUNK_ADMIN_USER}:${SPLUNK_ADMIN_PASS}"

info "Verifying Splunk configuration"
/opt/splunk/bin/splunk list input tcp -auth "${SPLUNK_ADMIN_USER}:${SPLUNK_ADMIN_PASS}"
/opt/splunk/bin/splunk list index -auth "${SPLUNK_ADMIN_USER}:${SPLUNK_ADMIN_PASS}"

info "Setup complete: Splunk installed, network configured, and domain joined."
