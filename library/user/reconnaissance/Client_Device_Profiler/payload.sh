#!/bin/bash
# Title: Client Device Profiler
# Description: Gathers detailed information about connected WiFi clients
# Author: WiFi Pineapple Pager Community
# Version: 1.0
# Category: Reconnaissance
# Net Mode: NAT
#
# LED State Descriptions
# Cyan Solid - Scanning for clients
# Green Blink - Device profiled
# Red Blink - Error occurred

# Configuration
PROFILE_LOG="/tmp/client_profiles.log"
SCAN_DURATION=60  # seconds

LOG "Starting Client Device Profiler"
touch "$PROFILE_LOG"

# Confirm operation
resp=$(CONFIRMATION_DIALOG "Start client profiling?")
case $? in
    $DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
        LOG "Operation cancelled"
        exit 1
        ;;
esac

case "$resp" in
    $DUCKYSCRIPT_USER_DENIED)
        exit 0
        ;;
esac

spinner_id=$(START_SPINNER "Profiling clients...")

# Start airodump-ng to capture client data
airodump-ng wlan0mon -w /tmp/client_scan --output-format csv > /dev/null 2>&1 &
airodump_pid=$!

# Scan for specified duration
sleep $SCAN_DURATION

# Stop airodump-ng
kill $airodump_pid 2>/dev/null

STOP_SPINNER $spinner_id

# Parse captured data
if [ -f /tmp/client_scan-01.csv ]; then
    LOG "Parsing client data..."
    
    client_count=0
    while IFS=',' read -r mac first_seen last_seen power packets bssid probed_ssids; do
        # Skip header and empty lines
        if [[ "$mac" =~ ^[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} ]]; then
            client_count=$((client_count + 1))
            
            # Get OUI vendor info
            vendor=$(macchanger -l | grep "${mac:0:8}" | awk '{$1=""; print $0}' | xargs)
            
            # Log detailed profile
            echo "=== Client $client_count ===" >> "$PROFILE_LOG"
            echo "MAC: $mac" >> "$PROFILE_LOG"
            echo "Vendor: ${vendor:-Unknown}" >> "$PROFILE_LOG"
            echo "Signal: $power dBm" >> "$PROFILE_LOG"
            echo "Packets: $packets" >> "$PROFILE_LOG"
            echo "Connected to: $bssid" >> "$PROFILE_LOG"
            echo "Probed SSIDs: $probed_ssids" >> "$PROFILE_LOG"
            echo "First Seen: $first_seen" >> "$PROFILE_LOG"
            echo "Last Seen: $last_seen" >> "$PROFILE_LOG"
            echo "" >> "$PROFILE_LOG"
            
            LOG "Profiled: $mac (${vendor:-Unknown})"
        fi
    done < <(tail -n +3 /tmp/client_scan-01.csv | grep -v "Station MAC")
    
    LOG "Total clients profiled: $client_count"
    ALERT "Profiled $client_count clients"
    
    # Cleanup
    rm -f /tmp/client_scan-01.csv
else
    LOG "No client data captured"
    ERROR_DIALOG "No clients detected"
fi

LOG "Profile saved to $PROFILE_LOG"
