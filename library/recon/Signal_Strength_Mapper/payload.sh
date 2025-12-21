#!/bin/bash
# Title: Signal Strength Mapper
# Description: Creates signal strength mapping data for WiFi coverage analysis
# Author: WiFi Pineapple Pager Community
# Version: 1.0
# Category: Recon

LOG "Signal Strength Mapper"
LOG "Mapping: $_RECON_SELECTED_AP_SSID"

OUTPUT_FILE="/tmp/signal_map_$_RECON_SELECTED_AP_BSSID.txt"
CSV_FILE="/tmp/signal_map_$_RECON_SELECTED_AP_BSSID.csv"

spinner_id=$(START_SPINNER "Mapping signal strength...")

cat > "$OUTPUT_FILE" <<EOF
=== Signal Strength Map ===
Target AP: $_RECON_SELECTED_AP_SSID
BSSID: $_RECON_SELECTED_AP_BSSID
Channel: $_RECON_SELECTED_AP_CHANNEL
Started: $(date)

EOF

# Initialize CSV
echo "Timestamp,RSSI,Quality,Distance_Est,Beacon_Count" > "$CSV_FILE"

LOG "Recording signal samples..."

# Collect signal strength samples over time
sample_count=30
samples=()
total_rssi=0
min_rssi=0
max_rssi=-100

for i in $(seq 1 $sample_count); do
    # Capture current signal
    airodump-ng wlan0mon -c $_RECON_SELECTED_AP_CHANNEL --bssid $_RECON_SELECTED_AP_BSSID -w /tmp/signal_sample --output-format csv > /dev/null 2>&1 &
    sample_pid=$!
    
    sleep 2
    kill $sample_pid 2>/dev/null
    
    if [ -f /tmp/signal_sample-01.csv ]; then
        # Extract RSSI and beacon count
        rssi=$(grep "$_RECON_SELECTED_AP_BSSID" /tmp/signal_sample-01.csv | cut -d',' -f9 | tr -d ' ' | head -1)
        beacons=$(grep "$_RECON_SELECTED_AP_BSSID" /tmp/signal_sample-01.csv | cut -d',' -f11 | tr -d ' ' | head -1)
        
        if [ ! -z "$rssi" ] && [ "$rssi" != "" ]; then
            # Calculate quality percentage
            quality=$(echo "scale=2; ($rssi + 100) / 0.7" | bc 2>/dev/null || echo "0")
            
            # Estimate distance (rough approximation)
            # Using Free Space Path Loss formula approximation with actual frequency
            freq=${_RECON_SELECTED_AP_FREQ:-2412}
            distance_est=$(echo "scale=1; 10^((27.55 - (20 * l($freq) / l(10)) + $rssi) / 20)" | bc -l 2>/dev/null || echo "unknown")
            
            # Record sample
            timestamp=$(date +%s)
            echo "$timestamp,$rssi,$quality,$distance_est,$beacons" >> "$CSV_FILE"
            
            samples+=("$rssi")
            total_rssi=$((total_rssi + rssi))
            
            # Track min/max
            if [ $rssi -gt $max_rssi ]; then
                max_rssi=$rssi
            fi
            if [ $rssi -lt $min_rssi ] || [ $min_rssi -eq 0 ]; then
                min_rssi=$rssi
            fi
            
            LOG "Sample $i: $rssi dBm (Quality: $quality%)"
        fi
        
        rm -f /tmp/signal_sample-01.csv
    fi
    
    sleep 1
done

STOP_SPINNER $spinner_id

# Calculate statistics
if [ ${#samples[@]} -gt 0 ]; then
    avg_rssi=$(echo "scale=2; $total_rssi / ${#samples[@]}" | bc)
    
    # Calculate standard deviation
    sum_squared_diff=0
    for sample in "${samples[@]}"; do
        diff=$(echo "$sample - $avg_rssi" | bc)
        squared=$(echo "$diff * $diff" | bc)
        sum_squared_diff=$(echo "$sum_squared_diff + $squared" | bc)
    done
    std_dev=$(echo "scale=2; sqrt($sum_squared_diff / ${#samples[@]})" | bc 2>/dev/null || echo "0")
    
    # Signal stability assessment
    if (( $(echo "$std_dev < 3" | bc -l) )); then
        stability="STABLE"
    elif (( $(echo "$std_dev < 6" | bc -l) )); then
        stability="MODERATE"
    else
        stability="UNSTABLE"
    fi
    
    # Coverage zone estimation
    if (( $(echo "$avg_rssi > -50" | bc -l) )); then
        coverage="EXCELLENT (Very Close)"
        attack_reliability="Very High"
    elif (( $(echo "$avg_rssi > -60" | bc -l) )); then
        coverage="GOOD (Close)"
        attack_reliability="High"
    elif (( $(echo "$avg_rssi > -70" | bc -l) )); then
        coverage="FAIR (Medium Range)"
        attack_reliability="Medium"
    elif (( $(echo "$avg_rssi > -80" | bc -l) )); then
        coverage="POOR (Far)"
        attack_reliability="Low"
    else
        coverage="VERY POOR (Very Far)"
        attack_reliability="Very Low"
    fi
    
    # Write statistics
    cat >> "$OUTPUT_FILE" <<EOF
=== Signal Statistics ===
Sample Count: ${#samples[@]}
Average RSSI: $avg_rssi dBm
Minimum RSSI: $min_rssi dBm
Maximum RSSI: $max_rssi dBm
Standard Deviation: $std_dev
Signal Stability: $stability

=== Coverage Assessment ===
Signal Strength: $coverage
Attack Reliability: $attack_reliability

Signal Quality Distribution:
EOF
    
    # Quality bands
    excellent=0
    good=0
    fair=0
    poor=0
    
    for sample in "${samples[@]}"; do
        if [ $sample -gt -50 ]; then
            excellent=$((excellent + 1))
        elif [ $sample -gt -60 ]; then
            good=$((good + 1))
        elif [ $sample -gt -70 ]; then
            fair=$((fair + 1))
        else
            poor=$((poor + 1))
        fi
    done
    
    echo "- Excellent (>-50 dBm): $excellent samples" >> "$OUTPUT_FILE"
    echo "- Good (-50 to -60 dBm): $good samples" >> "$OUTPUT_FILE"
    echo "- Fair (-60 to -70 dBm): $fair samples" >> "$OUTPUT_FILE"
    echo "- Poor (<-70 dBm): $poor samples" >> "$OUTPUT_FILE"
    
    # Movement detection
    range=$((max_rssi - min_rssi))
    if [ $range -gt 10 ]; then
        echo "" >> "$OUTPUT_FILE"
        echo "WARNING: Large signal variation detected ($range dB)" >> "$OUTPUT_FILE"
        echo "- You or the target may be moving" >> "$OUTPUT_FILE"
        echo "- Environmental interference present" >> "$OUTPUT_FILE"
        echo "- Consider stabilizing position for attacks" >> "$OUTPUT_FILE"
    fi
    
    # Attack recommendations
    cat >> "$OUTPUT_FILE" <<EOF

=== Pentesting Recommendations ===
Signal Strength: $avg_rssi dBm
Stability: $stability
Attack Success Probability: $attack_reliability

Recommendations:
EOF
    
    if (( $(echo "$avg_rssi > -60" | bc -l) )); then
        echo "- Excellent position for all attack types" >> "$OUTPUT_FILE"
        echo "- High packet injection success rate expected" >> "$OUTPUT_FILE"
        echo "- Deauth attacks will be very effective" >> "$OUTPUT_FILE"
    elif (( $(echo "$avg_rssi > -70" | bc -l) )); then
        echo "- Good position for most attacks" >> "$OUTPUT_FILE"
        echo "- Packet injection should be reliable" >> "$OUTPUT_FILE"
        echo "- Consider moving closer for best results" >> "$OUTPUT_FILE"
    else
        echo "- Marginal position for attacks" >> "$OUTPUT_FILE"
        echo "- Packet loss likely - move closer" >> "$OUTPUT_FILE"
        echo "- Deauth attacks may be unreliable" >> "$OUTPUT_FILE"
    fi
    
    if [ "$stability" != "STABLE" ]; then
        echo "- Signal instability detected - find stable position" >> "$OUTPUT_FILE"
    fi
    
    # Log summary
    LOG "Signal mapping complete"
    LOG "Average RSSI: $avg_rssi dBm"
    LOG "Range: $min_rssi to $max_rssi dBm"
    LOG "Stability: $stability"
    LOG "Coverage: $coverage"
    LOG "Data: $CSV_FILE"
    LOG "Report: $OUTPUT_FILE"
    
    ALERT "Avg: $avg_rssi dBm | $stability"
else
    echo "ERROR: No samples collected" >> "$OUTPUT_FILE"
    LOG "Failed to collect signal samples"
    ERROR_DIALOG "No signal data"
fi

echo "" >> "$OUTPUT_FILE"
echo "Completed: $(date)" >> "$OUTPUT_FILE"
