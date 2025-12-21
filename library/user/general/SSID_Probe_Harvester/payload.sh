#!/bin/bash
# Title: SSID Probe Harvester
# Description: Collect and analyze probed SSIDs from WiFi clients to identify previously connected networks
# Author: WiFi Pineapple Pager Community
# Version: 1.0
# Category: General
# Net Mode: NAT
#
# LED State Descriptions
# Cyan Solid - Monitoring probe requests
# Green Blink - Probe captured
# Red Blink - Error occurred

# Configuration
PROBE_LOG="/tmp/ssid_probes.log"
PROBE_DB="/tmp/probe_database.txt"
SCAN_DURATION=120  # 2 minutes

LOG "Starting SSID Probe Harvester"
touch "$PROBE_LOG"
touch "$PROBE_DB"

# Confirm operation
resp=$(CONFIRMATION_DIALOG "Start probe harvesting?")
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

spinner_id=$(START_SPINNER "Harvesting probes...")

# Start airodump-ng to capture probe requests
airodump-ng wlan0mon -w /tmp/probe_capture --output-format csv > /dev/null 2>&1 &
capture_pid=$!

# Also use tcpdump for detailed probe analysis
tcpdump -i wlan0mon -e -s 256 type mgt subtype probe-req -l 2>/dev/null | while read line; do
    # Extract SSID from probe request
    if echo "$line" | grep -q "Probe Request"; then
        ssid=$(echo "$line" | grep -oP '\(\K[^)]+' | tail -1)
        if [ ! -z "$ssid" ] && [ "$ssid" != "Broadcast" ]; then
            echo "$(date +%s):$ssid" >> "$PROBE_LOG"
            LOG "Probe: $ssid"
        fi
    fi
done &
tcpdump_pid=$!

# Monitor for specified duration
sleep $SCAN_DURATION

# Stop capture
kill $capture_pid $tcpdump_pid 2>/dev/null

STOP_SPINNER $spinner_id

LOG "Processing captured probes..."

# Parse airodump results for client probe data
if [ -f /tmp/probe_capture-01.csv ]; then
    # Extract client probe information
    awk -F',' '/^Station MAC/,EOF {
        if ($1 ~ /^[0-9A-F]{2}:[0-9A-F]{2}/) {
            mac = $1
            probed = $7
            if (probed != "" && probed != " ") {
                print mac "," probed
            }
        }
    }' /tmp/probe_capture-01.csv > /tmp/probe_parsed.txt
    
    # Build database
    while IFS=',' read -r mac ssid; do
        # Clean up values
        mac=$(echo "$mac" | xargs)
        ssid=$(echo "$ssid" | xargs)
        
        if [ ! -z "$ssid" ]; then
            # Get vendor info
            vendor=$(macchanger -l 2>/dev/null | grep "${mac:0:8}" | awk '{$1=""; print $0}' | xargs)
            
            echo "MAC: $mac | Vendor: ${vendor:-Unknown} | Probed: $ssid" >> "$PROBE_DB"
            LOG "Client $mac probing for: $ssid"
        fi
    done < /tmp/probe_parsed.txt
    
    rm -f /tmp/probe_capture-01.csv /tmp/probe_parsed.txt
fi

# Analyze collected data
unique_ssids=$(sort -u "$PROBE_LOG" | wc -l)
unique_clients=$(cut -d',' -f1 /tmp/probe_parsed.txt 2>/dev/null | sort -u | wc -l)
total_probes=$(wc -l < "$PROBE_LOG")

LOG "Probe harvesting complete"
LOG "Total probes: $total_probes"
LOG "Unique SSIDs: $unique_ssids"
LOG "Unique clients: $unique_clients"
LOG "Database: $PROBE_DB"

# Generate summary report
cat > /tmp/probe_report.txt <<EOF
SSID Probe Harvester Report
Generated: $(date)
========================

Statistics:
-----------
Total Probe Requests: $total_probes
Unique SSIDs Probed: $unique_ssids
Unique Clients Seen: $unique_clients

Top 10 Probed SSIDs:
-------------------
$(cut -d':' -f2 "$PROBE_LOG" | sort | uniq -c | sort -rn | head -10)

Detailed Database: $PROBE_DB
EOF

LOG "Report saved to /tmp/probe_report.txt"
ALERT "Harvested $total_probes probes from $unique_clients clients"
