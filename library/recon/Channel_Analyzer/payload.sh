#!/bin/bash
# Title: Channel Analyzer
# Description: Comprehensive analysis of WiFi channel usage, congestion, and interference
# Author: WiFi Pineapple Pager Community
# Version: 1.0
# Category: Recon

LOG "Channel Analyzer"
LOG "Analyzing channel $_RECON_SELECTED_AP_CHANNEL"

OUTPUT_FILE="/tmp/channel_analysis_$_RECON_SELECTED_AP_CHANNEL.txt"

spinner_id=$(START_SPINNER "Analyzing channel...")

cat > "$OUTPUT_FILE" <<EOF
=== Channel Analysis ===
Target Channel: $_RECON_SELECTED_AP_CHANNEL
Target AP: $_RECON_SELECTED_AP_SSID ($_RECON_SELECTED_AP_BSSID)
Analysis Time: $(date)

EOF

# Scan channel for all APs
LOG "Scanning channel $_RECON_SELECTED_AP_CHANNEL..."
timeout 30 airodump-ng wlan0mon -c $_RECON_SELECTED_AP_CHANNEL -w /tmp/channel_scan --output-format csv > /dev/null 2>&1

if [ ! -f /tmp/channel_scan-01.csv ]; then
    ERROR_DIALOG "Channel scan failed"
    exit 1
fi

# Parse results
ap_count=0
total_clients=0
declare -A encryption_types

while IFS=',' read -r bssid first_seen last_seen channel speed privacy cipher auth power beacons iv lan_ip id_length essid key; do
    if [[ "$bssid" =~ ^[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} ]] && [ "$channel" == "$_RECON_SELECTED_AP_CHANNEL" ]; then
        ap_count=$((ap_count + 1))
        
        # Count clients for this AP
        client_count=$(awk -F',' -v bssid="$bssid" '$6 == bssid {count++} END {print count+0}' /tmp/channel_scan-01.csv)
        total_clients=$((total_clients + client_count))
        
        # Track encryption types
        encryption_types["$privacy"]=$((${encryption_types["$privacy"]:-0} + 1))
        
        # Log AP details
        echo "---" >> "$OUTPUT_FILE"
        echo "BSSID: $bssid" >> "$OUTPUT_FILE"
        echo "SSID: $essid" >> "$OUTPUT_FILE"
        echo "Signal: $power dBm" >> "$OUTPUT_FILE"
        echo "Encryption: $privacy" >> "$OUTPUT_FILE"
        echo "Clients: $client_count" >> "$OUTPUT_FILE"
        echo "Beacons: $beacons" >> "$OUTPUT_FILE"
    fi
done < <(tail -n +3 /tmp/channel_scan-01.csv | grep -v "Station MAC")

rm -f /tmp/channel_scan-01.csv

# Channel statistics
cat >> "$OUTPUT_FILE" <<EOF

=== Channel Statistics ===
Total APs on Channel: $ap_count
Total Clients: $total_clients
Average Clients per AP: $(echo "scale=2; $total_clients / $ap_count" | bc 2>/dev/null || echo "0")

Encryption Distribution:
EOF

for enc_type in "${!encryption_types[@]}"; do
    count=${encryption_types[$enc_type]}
    percent=$(echo "scale=1; ($count * 100) / $ap_count" | bc)
    echo "- $enc_type: $count APs ($percent%)" >> "$OUTPUT_FILE"
done

# Congestion analysis
echo "" >> "$OUTPUT_FILE"
echo "=== Congestion Analysis ===" >> "$OUTPUT_FILE"

if [ $ap_count -gt 10 ]; then
    congestion="SEVERE"
    echo "Status: SEVERE CONGESTION" >> "$OUTPUT_FILE"
    echo "- $ap_count APs competing on channel $_RECON_SELECTED_AP_CHANNEL" >> "$OUTPUT_FILE"
    echo "- High interference expected" >> "$OUTPUT_FILE"
    echo "- Recommend channel change" >> "$OUTPUT_FILE"
elif [ $ap_count -gt 5 ]; then
    congestion="MODERATE"
    echo "Status: MODERATE CONGESTION" >> "$OUTPUT_FILE"
    echo "- $ap_count APs on channel $_RECON_SELECTED_AP_CHANNEL" >> "$OUTPUT_FILE"
    echo "- Some interference possible" >> "$OUTPUT_FILE"
elif [ $ap_count -gt 2 ]; then
    congestion="LIGHT"
    echo "Status: LIGHT CONGESTION" >> "$OUTPUT_FILE"
    echo "- $ap_count APs on channel $_RECON_SELECTED_AP_CHANNEL" >> "$OUTPUT_FILE"
    echo "- Minimal interference" >> "$OUTPUT_FILE"
else
    congestion="CLEAR"
    echo "Status: CLEAR CHANNEL" >> "$OUTPUT_FILE"
    echo "- Only $ap_count AP(s) on channel" >> "$OUTPUT_FILE"
    echo "- Optimal conditions" >> "$OUTPUT_FILE"
fi

# Channel overlap analysis (for 2.4GHz)
if [ $_RECON_SELECTED_AP_CHANNEL -le 11 ]; then
    echo "" >> "$OUTPUT_FILE"
    echo "=== 2.4GHz Overlap Analysis ===" >> "$OUTPUT_FILE"
    
    # Non-overlapping channels are 1, 6, 11
    case $_RECON_SELECTED_AP_CHANNEL in
        1|6|11)
            echo "Channel $_RECON_SELECTED_AP_CHANNEL is a non-overlapping channel (1, 6, 11)" >> "$OUTPUT_FILE"
            echo "- Good choice for minimal interference" >> "$OUTPUT_FILE"
            ;;
        *)
            echo "Channel $_RECON_SELECTED_AP_CHANNEL overlaps with adjacent channels" >> "$OUTPUT_FILE"
            echo "- Consider using channels 1, 6, or 11 instead" >> "$OUTPUT_FILE"
            ;;
    esac
fi

# Attack recommendations
echo "" >> "$OUTPUT_FILE"
echo "=== Pentesting Recommendations ===" >> "$OUTPUT_FILE"

if [ $congestion == "CLEAR" ] || [ $congestion == "LIGHT" ]; then
    echo "- Good channel for targeted attacks" >> "$OUTPUT_FILE"
    echo "- Clear signal makes packet injection reliable" >> "$OUTPUT_FILE"
else
    echo "- Congested channel may affect attack effectiveness" >> "$OUTPUT_FILE"
    echo "- Packet loss possible due to interference" >> "$OUTPUT_FILE"
fi

if [ $ap_count -gt 5 ]; then
    echo "- Multiple targets available" >> "$OUTPUT_FILE"
    echo "- Mass deauth attack feasible" >> "$OUTPUT_FILE"
fi

if [ $total_clients -gt 10 ]; then
    echo "- High client activity - good for credential harvesting" >> "$OUTPUT_FILE"
fi

# Signal strength comparison
echo "" >> "$OUTPUT_FILE"
echo "Target AP Signal Strength: $_RECON_SELECTED_AP_RSSI dBm" >> "$OUTPUT_FILE"

if [ $_RECON_SELECTED_AP_RSSI -gt -50 ]; then
    echo "- Excellent signal - optimal for attacks" >> "$OUTPUT_FILE"
elif [ $_RECON_SELECTED_AP_RSSI -gt -70 ]; then
    echo "- Good signal - suitable for attacks" >> "$OUTPUT_FILE"
else
    echo "- Weak signal - may affect attack reliability" >> "$OUTPUT_FILE"
fi

STOP_SPINNER $spinner_id

LOG "Channel analysis complete"
LOG "Channel: $_RECON_SELECTED_AP_CHANNEL"
LOG "APs found: $ap_count"
LOG "Total clients: $total_clients"
LOG "Congestion: $congestion"
LOG "Report: $OUTPUT_FILE"

ALERT "Ch$_RECON_SELECTED_AP_CHANNEL: $ap_count APs, $congestion"
