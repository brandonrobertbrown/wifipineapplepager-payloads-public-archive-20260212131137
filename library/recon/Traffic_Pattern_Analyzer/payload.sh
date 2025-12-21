#!/bin/bash
# Title: Traffic Pattern Analyzer
# Description: Analyzes WiFi traffic patterns and behavior for security assessment
# Author: WiFi Pineapple Pager Community
# Version: 1.0
# Category: Recon

LOG "Traffic Pattern Analyzer"
LOG "Analyzing: $_RECON_SELECTED_AP_SSID"

OUTPUT_FILE="/tmp/traffic_analysis_$_RECON_SELECTED_AP_BSSID.txt"
PCAP_FILE="/tmp/traffic_capture_$_RECON_SELECTED_AP_BSSID.pcap"

spinner_id=$(START_SPINNER "Capturing traffic...")

cat > "$OUTPUT_FILE" <<EOF
=== WiFi Traffic Pattern Analysis ===
Target AP: $_RECON_SELECTED_AP_SSID
BSSID: $_RECON_SELECTED_AP_BSSID
Channel: $_RECON_SELECTED_AP_CHANNEL
Analysis Started: $(date)

EOF

# Start packet capture
LOG "Starting packet capture..."
airodump-ng wlan0mon -c $_RECON_SELECTED_AP_CHANNEL --bssid $_RECON_SELECTED_AP_BSSID -w /tmp/traffic_cap --output-format pcap > /dev/null 2>&1 &
capture_pid=$!

# Also capture with tcpdump for detailed analysis
tcpdump -i wlan0mon -w "$PCAP_FILE" "wlan addr1 $_RECON_SELECTED_AP_BSSID or wlan addr2 $_RECON_SELECTED_AP_BSSID or wlan addr3 $_RECON_SELECTED_AP_BSSID" 2>/dev/null &
tcpdump_pid=$!

# Monitor for 90 seconds
monitor_duration=90
interval=10
iterations=$((monitor_duration / interval))

declare -A packet_counts
declare -A frame_types
total_packets=0
beacon_count=0
data_count=0
control_count=0
mgmt_count=0

for i in $(seq 1 $iterations); do
    sleep $interval
    
    # Sample current statistics
    if [ -f /tmp/traffic_cap-01.csv ]; then
        # Get current packet count
        current_packets=$(grep "$_RECON_SELECTED_AP_BSSID" /tmp/traffic_cap-01.csv | head -1 | cut -d',' -f11 | tr -d ' ')
        
        if [ ! -z "$current_packets" ] && [ "$current_packets" != "" ]; then
            total_packets=$current_packets
        fi
    fi
done

# Stop captures
kill $capture_pid $tcpdump_pid 2>/dev/null
sleep 2

STOP_SPINNER $spinner_id

# Analyze captured traffic
LOG "Analyzing captured packets..."
spinner_id=$(START_SPINNER "Processing data...")

# Basic statistics from airodump
if [ -f /tmp/traffic_cap-01.csv ]; then
    # Parse AP data
    while IFS=',' read -r bssid first_seen last_seen channel speed privacy cipher auth power beacons iv lan_ip id_length essid key; do
        if [ "$bssid" == "$_RECON_SELECTED_AP_BSSID" ]; then
            beacon_count="$beacons"
            break
        fi
    done < <(tail -n +3 /tmp/traffic_cap-01.csv | head -1)
    
    rm -f /tmp/traffic_cap-01.csv
fi

# Detailed packet analysis with tshark if available
if command -v tshark &> /dev/null && [ -f "$PCAP_FILE" ]; then
    LOG "Running deep packet inspection..."
    
    # Frame type distribution
    data_count=$(tshark -r "$PCAP_FILE" -Y "wlan.fc.type == 2" 2>/dev/null | wc -l)
    control_count=$(tshark -r "$PCAP_FILE" -Y "wlan.fc.type == 1" 2>/dev/null | wc -l)
    mgmt_count=$(tshark -r "$PCAP_FILE" -Y "wlan.fc.type == 0" 2>/dev/null | wc -l)
    
    # Protocol distribution
    http_count=$(tshark -r "$PCAP_FILE" -Y "http" 2>/dev/null | wc -l)
    https_count=$(tshark -r "$PCAP_FILE" -Y "tls or ssl" 2>/dev/null | wc -l)
    dns_count=$(tshark -r "$PCAP_FILE" -Y "dns" 2>/dev/null | wc -l)
    
    # Calculate total
    total_analyzed=$((data_count + control_count + mgmt_count))
else
    # Use tcpdump for basic analysis
    if [ -f "$PCAP_FILE" ]; then
        total_analyzed=$(tcpdump -r "$PCAP_FILE" 2>/dev/null | wc -l)
    else
        total_analyzed=0
    fi
fi

STOP_SPINNER $spinner_id

# Write analysis results
cat >> "$OUTPUT_FILE" <<EOF

=== Traffic Statistics ===
Analysis Duration: $monitor_duration seconds
Total Packets Observed: $total_packets

Frame Type Distribution:
- Management Frames: $mgmt_count
- Control Frames: $control_count
- Data Frames: $data_count
- Beacon Frames: $beacon_count

EOF

# Calculate rates
if [ $monitor_duration -gt 0 ]; then
    packets_per_sec=$(echo "scale=2; $total_packets / $monitor_duration" | bc 2>/dev/null || echo "0")
    beacons_per_sec=$(echo "scale=2; $beacon_count / $monitor_duration" | bc 2>/dev/null || echo "0")
    data_per_sec=$(echo "scale=2; $data_count / $monitor_duration" | bc 2>/dev/null || echo "0")
    
    cat >> "$OUTPUT_FILE" <<EOF
Traffic Rates:
- Overall: $packets_per_sec packets/sec
- Beacons: $beacons_per_sec beacons/sec
- Data: $data_per_sec data frames/sec

EOF
fi

# Protocol analysis
if [ ! -z "$http_count" ]; then
    cat >> "$OUTPUT_FILE" <<EOF
=== Protocol Distribution ===
- HTTP (unencrypted): $http_count packets
- HTTPS/TLS (encrypted): $https_count packets
- DNS queries: $dns_count packets

EOF
fi

# Traffic pattern analysis
echo "=== Traffic Pattern Analysis ===" >> "$OUTPUT_FILE"

# Activity level
if [ $data_count -gt 1000 ]; then
    activity_level="VERY HIGH"
    echo "Activity Level: VERY HIGH" >> "$OUTPUT_FILE"
    echo "- Heavy data transfer detected" >> "$OUTPUT_FILE"
    echo "- Multiple active connections" >> "$OUTPUT_FILE"
    echo "- Potential file transfers or streaming" >> "$OUTPUT_FILE"
elif [ $data_count -gt 500 ]; then
    activity_level="HIGH"
    echo "Activity Level: HIGH" >> "$OUTPUT_FILE"
    echo "- Significant network usage" >> "$OUTPUT_FILE"
    echo "- Active browsing or applications" >> "$OUTPUT_FILE"
elif [ $data_count -gt 100 ]; then
    activity_level="MEDIUM"
    echo "Activity Level: MEDIUM" >> "$OUTPUT_FILE"
    echo "- Moderate network usage" >> "$OUTPUT_FILE"
    echo "- Standard browsing activity" >> "$OUTPUT_FILE"
else
    activity_level="LOW"
    echo "Activity Level: LOW" >> "$OUTPUT_FILE"
    echo "- Minimal network usage" >> "$OUTPUT_FILE"
    echo "- Idle or background traffic only" >> "$OUTPUT_FILE"
fi

# Beacon interval analysis
if [ $beacon_count -gt 0 ]; then
    beacon_interval=$(echo "scale=0; $monitor_duration / $beacon_count * 1000" | bc 2>/dev/null || echo "100")
    
    echo "" >> "$OUTPUT_FILE"
    echo "Beacon Interval: ~${beacon_interval}ms" >> "$OUTPUT_FILE"
    
    if [ $beacon_interval -lt 120 ]; then
        echo "- Standard configuration (100ms typical)" >> "$OUTPUT_FILE"
    else
        echo "- Non-standard beacon interval detected" >> "$OUTPUT_FILE"
    fi
fi

# Traffic encryption analysis
if [ ! -z "$http_count" ] && [ ! -z "$https_count" ]; then
    total_web=$((http_count + https_count))
    if [ $total_web -gt 0 ]; then
        https_percent=$(echo "scale=1; ($https_count * 100) / $total_web" | bc 2>/dev/null || echo "0")
        
        echo "" >> "$OUTPUT_FILE"
        echo "Web Traffic Encryption:" >> "$OUTPUT_FILE"
        echo "- HTTPS: $https_percent%" >> "$OUTPUT_FILE"
        echo "- HTTP (unencrypted): $((100 - ${https_percent%.*}))%" >> "$OUTPUT_FILE"
        
        if (( $(echo "$https_percent < 50" | bc -l) )); then
            echo "- WARNING: High proportion of unencrypted traffic!" >> "$OUTPUT_FILE"
            echo "- Good target for traffic interception" >> "$OUTPUT_FILE"
        fi
    fi
fi

# Attack recommendations
echo "" >> "$OUTPUT_FILE"
echo "=== Attack Recommendations ===" >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" <<EOF

Based on Traffic Patterns:

1. Traffic Interception:
   Activity Level: $activity_level
EOF

if [ "$activity_level" == "VERY HIGH" ] || [ "$activity_level" == "HIGH" ]; then
    cat >> "$OUTPUT_FILE" <<EOF
   - High traffic volume = more data to capture
   - MitM attack highly recommended
   - Good candidate for SSL stripping
EOF
else
    cat >> "$OUTPUT_FILE" <<EOF
   - Low traffic may require patience
   - Consider deauth to force reconnection
   - Monitor for specific activity periods
EOF
fi

cat >> "$OUTPUT_FILE" <<EOF

2. Timing Attacks:
   - Beacon rate: $beacons_per_sec/sec
   - Best attack window: High activity periods
   - Deauth effectiveness: HIGH (due to beacon consistency)

3. Protocol Exploitation:
EOF

if [ ! -z "$http_count" ] && [ $http_count -gt 0 ]; then
    cat >> "$OUTPUT_FILE" <<EOF
   - HTTP traffic detected: $http_count packets
   - SSL stripping viable
   - Cookie hijacking possible
   - Credential sniffing recommended
EOF
fi

if [ ! -z "$dns_count" ] && [ $dns_count -gt 0 ]; then
    cat >> "$OUTPUT_FILE" <<EOF
   - DNS queries detected: $dns_count
   - DNS spoofing attack viable
   - Can redirect traffic to malicious sites
EOF
fi

# Data exfiltration potential
echo "" >> "$OUTPUT_FILE"
echo "=== Data Exfiltration Potential ===" >> "$OUTPUT_FILE"

if [ $data_count -gt 500 ]; then
    echo "HIGH: Significant data transfer detected" >> "$OUTPUT_FILE"
    echo "- Likely sensitive information in transit" >> "$OUTPUT_FILE"
    echo "- File transfers possible" >> "$OUTPUT_FILE"
    echo "- Credentials may be transmitted" >> "$OUTPUT_FILE"
elif [ $data_count -gt 100 ]; then
    echo "MEDIUM: Moderate data transfer" >> "$OUTPUT_FILE"
    echo "- Standard web browsing observed" >> "$OUTPUT_FILE"
    echo "- Session tokens available" >> "$OUTPUT_FILE"
else
    echo "LOW: Minimal data transfer" >> "$OUTPUT_FILE"
    echo "- Limited information available" >> "$OUTPUT_FILE"
    echo "- Wait for higher activity periods" >> "$OUTPUT_FILE"
fi

# Timing recommendations
echo "" >> "$OUTPUT_FILE"
echo "=== Optimal Attack Timing ===" >> "$OUTPUT_FILE"
cat >> "$OUTPUT_FILE" <<EOF

Based on observed patterns:
- Current activity: $activity_level
- Packet rate: $packets_per_sec/sec
- Data rate: $data_per_sec frames/sec

Recommendations:
EOF

if [ "$activity_level" == "LOW" ]; then
    echo "- Wait for higher activity period" >> "$OUTPUT_FILE"
    echo "- Re-analyze during peak hours" >> "$OUTPUT_FILE"
    echo "- Consider time-based monitoring" >> "$OUTPUT_FILE"
else
    echo "- Current timing is OPTIMAL for attacks" >> "$OUTPUT_FILE"
    echo "- High activity increases success rate" >> "$OUTPUT_FILE"
    echo "- Proceed with planned attack vectors" >> "$OUTPUT_FILE"
fi

# Summary
echo "" >> "$OUTPUT_FILE"
echo "=== Analysis Summary ===" >> "$OUTPUT_FILE"
echo "Network: $_RECON_SELECTED_AP_SSID ($_RECON_SELECTED_AP_BSSID)" >> "$OUTPUT_FILE"
echo "Total Packets: $total_packets" >> "$OUTPUT_FILE"
echo "Activity Level: $activity_level" >> "$OUTPUT_FILE"
echo "Data Frames: $data_count" >> "$OUTPUT_FILE"
echo "PCAP File: $PCAP_FILE" >> "$OUTPUT_FILE"
echo "Analysis Complete: $(date)" >> "$OUTPUT_FILE"

LOG "Traffic analysis complete"
LOG "Packets: $total_packets"
LOG "Activity: $activity_level"
LOG "Data frames: $data_count"
LOG "Report: $OUTPUT_FILE"
LOG "PCAP: $PCAP_FILE"

ALERT "Activity: $activity_level | $total_packets pkts"
