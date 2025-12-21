#!/bin/bash
# Title: Client Probe Collector
# Description: Collects and analyzes probe requests from WiFi clients
# Author: WiFi Pineapple Pager Community
# Version: 1.0
# Category: Recon

LOG "Client Probe Collector"
LOG "Target Client: $_RECON_SELECTED_CLIENT_MAC_ADDRESS"

OUTPUT_FILE="/tmp/probe_analysis_$_RECON_SELECTED_CLIENT_MAC_ADDRESS.txt"

spinner_id=$(START_SPINNER "Collecting probes...")

cat > "$OUTPUT_FILE" <<EOF
=== Client Probe Analysis ===
Client MAC: $_RECON_SELECTED_CLIENT_MAC_ADDRESS
Client OUI: $_RECON_SELECTED_CLIENT_OUI
Current Connection: $_RECON_SELECTED_CLIENT_SSID ($_RECON_SELECTED_CLIENT_BSSID)
Analysis Started: $(date)

EOF

# Get vendor info
vendor=$(macchanger -l 2>/dev/null | grep "${_RECON_SELECTED_CLIENT_OUI}" | awk '{$1=""; print $0}' | xargs)
echo "Device Vendor: ${vendor:-Unknown}" >> "$OUTPUT_FILE"

# Check for available probe data from environment
echo "" >> "$OUTPUT_FILE"
echo "=== Detected Probe Requests ===" >> "$OUTPUT_FILE"

if [ ! -z "$_RECON_SELECTED_CLIENT_PROBED_SSID" ]; then
    echo "Primary Probed SSID: $_RECON_SELECTED_CLIENT_PROBED_SSID" >> "$OUTPUT_FILE"
fi

if [ ! -z "$_RECON_SELECTED_CLIENT_PROBED_SSIDS" ]; then
    echo "" >> "$OUTPUT_FILE"
    echo "All Probed SSIDs:" >> "$OUTPUT_FILE"
    echo "$_RECON_SELECTED_CLIENT_PROBED_SSIDS" | tr ',' '\n' | while read ssid; do
        if [ ! -z "$ssid" ]; then
            echo "- $ssid" >> "$OUTPUT_FILE"
        fi
    done
fi

# Active probe collection
LOG "Monitoring client probe requests..."

# Monitor for probe requests from this specific client
tcpdump -i wlan0mon -e -s 256 type mgt subtype probe-req -l 2>/dev/null | grep "$_RECON_SELECTED_CLIENT_MAC_ADDRESS" > /tmp/client_probes_raw.txt &
tcpdump_pid=$!

# Collect for 60 seconds
sleep 60

kill $tcpdump_pid 2>/dev/null

# Parse collected probes
if [ -f /tmp/client_probes_raw.txt ] && [ -s /tmp/client_probes_raw.txt ]; then
    echo "" >> "$OUTPUT_FILE"
    echo "=== Live Probe Collection ===" >> "$OUTPUT_FILE"
    
    probe_count=0
    declare -A ssid_count
    
    while read line; do
        # Extract SSID from probe
        ssid=$(echo "$line" | grep -oP '\(\K[^)]+' | tail -1)
        if [ ! -z "$ssid" ] && [ "$ssid" != "Broadcast" ]; then
            probe_count=$((probe_count + 1))
            ssid_count["$ssid"]=$((${ssid_count["$ssid"]:-0} + 1))
        fi
    done < /tmp/client_probes_raw.txt
    
    echo "Total Probes Captured: $probe_count" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "Probed Networks (by frequency):" >> "$OUTPUT_FILE"
    
    for ssid in "${!ssid_count[@]}"; do
        count=${ssid_count[$ssid]}
        echo "- $ssid: $count requests" >> "$OUTPUT_FILE"
    done
    
    rm -f /tmp/client_probes_raw.txt
else
    echo "" >> "$OUTPUT_FILE"
    echo "No active probes detected during monitoring period" >> "$OUTPUT_FILE"
fi

STOP_SPINNER $spinner_id

# Analysis and intelligence
echo "" >> "$OUTPUT_FILE"
echo "=== Intelligence Analysis ===" >> "$OUTPUT_FILE"

# Network history
cat >> "$OUTPUT_FILE" <<EOF

Network History:
---------------
The probed SSIDs reveal networks this device has previously connected to.
This information can be used for:
- Creating targeted evil twin attacks
- Understanding user movement patterns
- Identifying work/home networks
- Social engineering context

EOF

# Device behavior
echo "Device Behavior:" >> "$OUTPUT_FILE"
case "${vendor}" in
    *Apple*|*iPhone*|*iPad*)
        echo "- iOS devices: Use MAC randomization (iOS 14+)" >> "$OUTPUT_FILE"
        echo "- Probes may be limited due to privacy features" >> "$OUTPUT_FILE"
        echo "- Real MAC only revealed upon connection" >> "$OUTPUT_FILE"
        ;;
    *Samsung*|*Android*|*Google*)
        echo "- Android devices: MAC randomization varies by version" >> "$OUTPUT_FILE"
        echo "- Probe behavior depends on Android version" >> "$OUTPUT_FILE"
        echo "- May reveal historical network preferences" >> "$OUTPUT_FILE"
        ;;
    *)
        echo "- Standard WiFi client behavior expected" >> "$OUTPUT_FILE"
        echo "- May actively probe for known networks" >> "$OUTPUT_FILE"
        ;;
esac

# Attack vectors
echo "" >> "$OUTPUT_FILE"
echo "=== Attack Recommendations ===" >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" <<EOF

1. Evil Twin Attack:
   - Create fake APs using probed SSIDs
   - Device will automatically attempt connection
   - Higher success rate with frequently probed networks

2. Targeted Phishing:
   - Use probed SSIDs for social engineering
   - Craft captive portal matching expected networks
   - Harvest credentials for specific networks

3. Location Tracking:
   - Probed SSIDs reveal user locations
   - Can map user's frequent locations
   - Useful for physical security assessments

4. Deauth + Reconnection:
   - Force disconnection from current AP
   - Client will probe for known networks
   - Capture handshake during reconnection

EOF

# Security recommendations
echo "=== Security Notes ===" >> "$OUTPUT_FILE"
cat >> "$OUTPUT_FILE" <<EOF

Privacy Concerns:
- Probe requests reveal network history
- Can be used for tracking and profiling
- MAC randomization helps but not perfect

Mitigation (for defenders):
- Enable MAC randomization
- Forget unused networks
- Use VPN on untrusted networks
- Disable auto-connect features

EOF

# Create attack script template
echo "=== Evil Twin Configuration ===" >> "$OUTPUT_FILE"
if [ ${#ssid_count[@]} -gt 0 ]; then
    echo "" >> "$OUTPUT_FILE"
    echo "Suggested Evil Twin Targets (most frequently probed):" >> "$OUTPUT_FILE"
    
    # Sort by frequency
    for ssid in "${!ssid_count[@]}"; do
        count=${ssid_count[$ssid]}
        echo "$count:$ssid"
    done | sort -rn | head -3 | while IFS=: read count ssid; do
        echo "- SSID: $ssid (probed $count times)" >> "$OUTPUT_FILE"
    done
fi

# Summary
echo "" >> "$OUTPUT_FILE"
echo "=== Summary ===" >> "$OUTPUT_FILE"
echo "Client: $_RECON_SELECTED_CLIENT_MAC_ADDRESS" >> "$OUTPUT_FILE"
echo "Vendor: ${vendor:-Unknown}" >> "$OUTPUT_FILE"
echo "Current Network: $_RECON_SELECTED_CLIENT_SSID" >> "$OUTPUT_FILE"
echo "Total Unique Probed Networks: ${#ssid_count[@]}" >> "$OUTPUT_FILE"
echo "Analysis Complete: $(date)" >> "$OUTPUT_FILE"

LOG "Probe collection complete"
LOG "Unique networks: ${#ssid_count[@]}"
LOG "Report: $OUTPUT_FILE"

if [ ${#ssid_count[@]} -gt 0 ]; then
    ALERT "Found ${#ssid_count[@]} probed networks"
else
    ALERT "No probes detected"
fi
