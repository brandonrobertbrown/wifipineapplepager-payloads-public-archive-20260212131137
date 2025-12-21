#!/bin/bash
# Title: Network Relationship Mapper
# Description: Maps relationships between access points and clients
# Author: WiFi Pineapple Pager Community
# Version: 1.0
# Category: Recon

LOG "Network Relationship Mapper"
LOG "Mapping: $_RECON_SELECTED_AP_SSID"

OUTPUT_FILE="/tmp/network_map_$_RECON_SELECTED_AP_BSSID.txt"
DOT_FILE="/tmp/network_map_$_RECON_SELECTED_AP_BSSID.dot"

spinner_id=$(START_SPINNER "Mapping relationships...")

cat > "$OUTPUT_FILE" <<EOF
=== Network Relationship Map ===
Root AP: $_RECON_SELECTED_AP_SSID
BSSID: $_RECON_SELECTED_AP_BSSID
Channel: $_RECON_SELECTED_AP_CHANNEL
Mapping Started: $(date)

EOF

# Capture network activity
LOG "Scanning network topology..."
airodump-ng wlan0mon -c $_RECON_SELECTED_AP_CHANNEL --bssid $_RECON_SELECTED_AP_BSSID -w /tmp/network_scan --output-format csv > /dev/null 2>&1 &
scan_pid=$!

sleep 45

kill $scan_pid 2>/dev/null

if [ ! -f /tmp/network_scan-01.csv ]; then
    STOP_SPINNER $spinner_id
    ERROR_DIALOG "Scan failed"
    exit 1
fi

# Parse AP information
echo "=== Access Point Details ===" >> "$OUTPUT_FILE"
cat >> "$OUTPUT_FILE" <<EOF
SSID: $_RECON_SELECTED_AP_SSID
BSSID: $_RECON_SELECTED_AP_BSSID
Channel: $_RECON_SELECTED_AP_CHANNEL
Encryption: $_RECON_SELECTED_AP_ENCRYPTION_TYPE
Signal: $_RECON_SELECTED_AP_RSSI dBm
Client Count: $_RECON_SELECTED_AP_CLIENT_COUNT

EOF

# Extract and analyze clients
echo "=== Connected Clients ===" >> "$OUTPUT_FILE"

declare -A client_data
client_count=0

while IFS=',' read -r station first_seen last_seen power packets bssid probed_ssids; do
    # Clean up values
    station=$(echo "$station" | xargs)
    bssid=$(echo "$bssid" | xargs)
    
    if [[ "$station" =~ ^[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} ]] && [ "$bssid" == "$_RECON_SELECTED_AP_BSSID" ]; then
        client_count=$((client_count + 1))
        
        # Get OUI
        oui="${station:0:8}"
        vendor=$(macchanger -l 2>/dev/null | grep "$oui" | awk '{$1=""; print $0}' | xargs)
        
        # Store client data
        client_data["$station"]="$vendor|$power|$packets|$probed_ssids"
        
        echo "" >> "$OUTPUT_FILE"
        echo "Client #$client_count:" >> "$OUTPUT_FILE"
        echo "  MAC: $station" >> "$OUTPUT_FILE"
        echo "  Vendor: ${vendor:-Unknown}" >> "$OUTPUT_FILE"
        echo "  Signal: $power dBm" >> "$OUTPUT_FILE"
        echo "  Packets: $packets" >> "$OUTPUT_FILE"
        
        if [ ! -z "$probed_ssids" ] && [ "$probed_ssids" != " " ]; then
            echo "  Probed Networks: $probed_ssids" >> "$OUTPUT_FILE"
        fi
    fi
done < <(awk -F',' '/Station MAC/,EOF' /tmp/network_scan-01.csv | tail -n +2)

rm -f /tmp/network_scan-01.csv

# Check for related APs on same channel
echo "" >> "$OUTPUT_FILE"
echo "=== Nearby Access Points (Same Channel) ===" >> "$OUTPUT_FILE"

airodump-ng wlan0mon -c $_RECON_SELECTED_AP_CHANNEL -w /tmp/nearby_scan --output-format csv > /dev/null 2>&1 &
scan_pid=$!

sleep 20
kill $scan_pid 2>/dev/null

if [ -f /tmp/nearby_scan-01.csv ]; then
    nearby_count=0
    
    while IFS=',' read -r bssid first_seen last_seen channel speed privacy cipher auth power beacons iv lan_ip id_length essid key; do
        if [[ "$bssid" =~ ^[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} ]] && [ "$bssid" != "$_RECON_SELECTED_AP_BSSID" ]; then
            nearby_count=$((nearby_count + 1))
            
            echo "" >> "$OUTPUT_FILE"
            echo "Nearby AP #$nearby_count:" >> "$OUTPUT_FILE"
            echo "  SSID: $essid" >> "$OUTPUT_FILE"
            echo "  BSSID: $bssid" >> "$OUTPUT_FILE"
            echo "  Encryption: $privacy" >> "$OUTPUT_FILE"
            echo "  Signal: $power dBm" >> "$OUTPUT_FILE"
        fi
    done < <(tail -n +3 /tmp/nearby_scan-01.csv | grep -v "Station MAC")
    
    rm -f /tmp/nearby_scan-01.csv
fi

STOP_SPINNER $spinner_id

# Generate GraphViz DOT file for visualization
cat > "$DOT_FILE" <<EODOT
digraph NetworkMap {
    rankdir=LR;
    node [shape=box];
    
    // Access Point
    AP [label="$_RECON_SELECTED_AP_SSID\n$_RECON_SELECTED_AP_BSSID\nCh: $_RECON_SELECTED_AP_CHANNEL" style=filled fillcolor=lightblue];
    
EODOT

# Add clients to graph
for mac in "${!client_data[@]}"; do
    IFS='|' read -r vendor power packets probed <<< "${client_data[$mac]}"
    
    # Sanitize MAC for DOT format
    node_id=$(echo "$mac" | tr ':' '_')
    
    cat >> "$DOT_FILE" <<EODOT
    $node_id [label="$mac\n${vendor:-Unknown}\nPkts: $packets" style=filled fillcolor=lightgreen];
    AP -> $node_id [label="$power dBm"];
EODOT
done

echo "}" >> "$DOT_FILE"

# Relationship analysis
echo "" >> "$OUTPUT_FILE"
echo "=== Relationship Analysis ===" >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" <<EOF

Network Topology:
- Root AP: $_RECON_SELECTED_AP_SSID
- Connected Clients: $client_count
- Same-channel neighbors: $nearby_count

Client Activity Patterns:
EOF

# Analyze client activity levels
high_activity=0
medium_activity=0
low_activity=0

for mac in "${!client_data[@]}"; do
    IFS='|' read -r vendor power packets probed <<< "${client_data[$mac]}"
    
    if [ $packets -gt 1000 ]; then
        high_activity=$((high_activity + 1))
    elif [ $packets -gt 100 ]; then
        medium_activity=$((medium_activity + 1))
    else
        low_activity=$((low_activity + 1))
    fi
done

cat >> "$OUTPUT_FILE" <<EOF
- High activity clients: $high_activity
- Medium activity clients: $medium_activity
- Low activity clients: $low_activity

EOF

# Attack surface analysis
echo "=== Attack Surface Analysis ===" >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" <<EOF

Network Structure:
- Central AP with $client_count associated devices
- Channel shared with $nearby_count other APs
- Potential for channel-based attacks

Attack Vectors:
1. Deauth Attack:
   - Target all $client_count clients simultaneously
   - Force mass disconnection
   - Capture multiple handshakes

2. Man-in-the-Middle:
   - Position between AP and high-activity clients
   - Intercept traffic from $high_activity active devices
   - Focus on high packet count clients

3. Evil Twin:
   - Clone $_RECON_SELECTED_AP_SSID
   - Leverage probed SSIDs from clients
   - Target disconnected clients

4. Targeted Attacks:
   - Focus on high-value clients
   - Identify by vendor/activity level
   - Custom attacks per device type

EOF

# High-value target identification
if [ $high_activity -gt 0 ]; then
    echo "High-Value Targets:" >> "$OUTPUT_FILE"
    
    for mac in "${!client_data[@]}"; do
        IFS='|' read -r vendor power packets probed <<< "${client_data[$mac]}"
        
        if [ $packets -gt 1000 ]; then
            echo "- $mac (${vendor:-Unknown}): $packets packets" >> "$OUTPUT_FILE"
        fi
    done
fi

# Summary
echo "" >> "$OUTPUT_FILE"
echo "=== Summary ===" >> "$OUTPUT_FILE"
echo "Network: $_RECON_SELECTED_AP_SSID ($_RECON_SELECTED_AP_BSSID)" >> "$OUTPUT_FILE"
echo "Total Clients: $client_count" >> "$OUTPUT_FILE"
echo "High Activity: $high_activity" >> "$OUTPUT_FILE"
echo "Channel Neighbors: $nearby_count" >> "$OUTPUT_FILE"
echo "Visualization: $DOT_FILE" >> "$OUTPUT_FILE"
echo "Mapping Complete: $(date)" >> "$OUTPUT_FILE"

LOG "Network mapping complete"
LOG "Clients: $client_count"
LOG "High activity: $high_activity"
LOG "Report: $OUTPUT_FILE"
LOG "Graph: $DOT_FILE"

ALERT "$client_count clients mapped"
