#!/bin/bash
# Title: WiFi Network Mapper
# Description: Creates comprehensive map of all nearby WiFi networks and topology
# Author: WiFi Pineapple Pager Community
# Version: 1.0
# Category: Reconnaissance
# Net Mode: NAT
#
# LED State Descriptions
# Cyan Blink - Scanning networks
# Green Solid - Mapping complete
# Red Blink - Error occurred

# Configuration
MAP_LOG="/tmp/network_map.txt"
JSON_LOG="/tmp/network_map.json"
SCAN_DURATION=90  # seconds

LOG "Starting WiFi Network Mapper"

# User confirmation
resp=$(CONFIRMATION_DIALOG "Start network mapping?")
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

spinner_id=$(START_SPINNER "Mapping networks...")

# Initialize output files
echo "WiFi Network Map - $(date)" > "$MAP_LOG"
echo "{\"networks\": [" > "$JSON_LOG"

# Scan all channels
for channel in 1 2 3 4 5 6 7 8 9 10 11; do
    LOG "Scanning channel $channel..."
    
    # Set channel
    iwconfig wlan0 channel $channel 2>/dev/null
    
    # Scan for 8 seconds per channel
    timeout 8 airodump-ng wlan0mon -c $channel -w /tmp/scan_ch${channel} --output-format csv > /dev/null 2>&1
    
    # Parse results
    if [ -f /tmp/scan_ch${channel}-01.csv ]; then
        while IFS=',' read -r bssid first_seen last_seen channel_num speed privacy cipher auth power beacons iv lan_ip id_length essid key; do
            if [[ "$bssid" =~ ^[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} ]]; then
                # Get vendor
                vendor=$(macchanger -l | grep "${bssid:0:8}" | awk '{$1=""; print $0}' | xargs)
                
                # Write to map
                echo "---" >> "$MAP_LOG"
                echo "BSSID: $bssid" >> "$MAP_LOG"
                echo "SSID: $essid" >> "$MAP_LOG"
                echo "Channel: $channel_num" >> "$MAP_LOG"
                echo "Security: $privacy" >> "$MAP_LOG"
                echo "Signal: $power dBm" >> "$MAP_LOG"
                echo "Vendor: ${vendor:-Unknown}" >> "$MAP_LOG"
                echo "Beacons: $beacons" >> "$MAP_LOG"
                
                # Write JSON entry
                echo "{\"bssid\":\"$bssid\",\"ssid\":\"$essid\",\"channel\":$channel_num,\"security\":\"$privacy\",\"power\":\"$power\",\"vendor\":\"${vendor:-Unknown}\"}," >> "$JSON_LOG"
            fi
        done < <(tail -n +3 /tmp/scan_ch${channel}-01.csv | grep -v "Station MAC")
        
        rm -f /tmp/scan_ch${channel}-01.csv
    fi
done

# Finalize JSON
echo "{}]}" >> "$JSON_LOG"

STOP_SPINNER $spinner_id

# Count networks
network_count=$(grep -c "BSSID:" "$MAP_LOG")

LOG "Network mapping complete"
LOG "Total networks found: $network_count"
LOG "Map saved to $MAP_LOG"
ALERT "Mapped $network_count networks"
