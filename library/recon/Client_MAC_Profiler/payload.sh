#!/bin/bash
# Title: Client MAC Profiler
# Description: Detailed analysis of selected WiFi client including vendor, behavior, and history
# Author: WiFi Pineapple Pager Community
# Version: 1.0
# Category: Recon

LOG "Client MAC Profiler"
LOG "Selected Client: $_RECON_SELECTED_CLIENT_MAC_ADDRESS"

# Output file
OUTPUT_FILE="/tmp/client_profile_$_RECON_SELECTED_CLIENT_MAC_ADDRESS.txt"

spinner_id=$(START_SPINNER "Profiling client...")

cat > "$OUTPUT_FILE" <<EOF
=== Client Profile ===
Generated: $(date)

Identity:
---------
MAC Address: $_RECON_SELECTED_CLIENT_MAC_ADDRESS
OUI: $_RECON_SELECTED_CLIENT_OUI
EOF

# Get detailed vendor info
vendor=$(macchanger -l 2>/dev/null | grep "${_RECON_SELECTED_CLIENT_OUI}" | awk '{$1=""; print $0}' | xargs)
echo "Vendor: ${vendor:-Unknown}" >> "$OUTPUT_FILE"

# Device type estimation based on OUI
device_type="Unknown"
case "$vendor" in
    *Apple*|*iPhone*|*iPad*)
        device_type="Apple iOS Device"
        ;;
    *Samsung*|*Android*)
        device_type="Android Device"
        ;;
    *Intel*|*Dell*|*HP*|*Lenovo*)
        device_type="Laptop/Desktop"
        ;;
    *Raspberry*)
        device_type="Raspberry Pi"
        ;;
esac
echo "Device Type: $device_type" >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" <<EOF

Connection Information:
----------------------
Current SSID: $_RECON_SELECTED_CLIENT_SSID
Connected AP: $_RECON_SELECTED_CLIENT_BSSID
Channel: $_RECON_SELECTED_CLIENT_CHANNEL
Frequency: $_RECON_SELECTED_CLIENT_FREQ MHz

Signal & Traffic:
----------------
RSSI: $_RECON_SELECTED_CLIENT_RSSI dBm
Packets Observed: $_RECON_SELECTED_CLIENT_PACKETS
Encryption: $_RECON_SELECTED_CLIENT_ENCRYPTION_TYPE
Last Seen: $_RECON_SELECTED_CLIENT_TIMESTAMP

Associated AP Details:
---------------------
AP SSID: $_RECON_SELECTED_AP_SSID
AP BSSID: $_RECON_SELECTED_AP_BSSID
AP Channel: $_RECON_SELECTED_AP_CHANNEL
AP Encryption: $_RECON_SELECTED_AP_ENCRYPTION_TYPE
AP Signal: $_RECON_SELECTED_AP_RSSI dBm
AP Client Count: $_RECON_SELECTED_AP_CLIENT_COUNT
EOF

# Probe request analysis
if [ ! -z "$_RECON_SELECTED_CLIENT_PROBED_SSID" ]; then
    echo "" >> "$OUTPUT_FILE"
    echo "Probed Networks:" >> "$OUTPUT_FILE"
    echo "$_RECON_SELECTED_CLIENT_PROBED_SSID" >> "$OUTPUT_FILE"
fi

if [ ! -z "$_RECON_SELECTED_CLIENT_PROBED_SSIDS" ]; then
    echo "All Probes: $_RECON_SELECTED_CLIENT_PROBED_SSIDS" >> "$OUTPUT_FILE"
fi

# Behavioral analysis
echo "" >> "$OUTPUT_FILE"
echo "Behavioral Analysis:" >> "$OUTPUT_FILE"

# Activity level
if [ $_RECON_SELECTED_CLIENT_PACKETS -gt 1000 ]; then
    echo "- High Activity: Active data transfer detected" >> "$OUTPUT_FILE"
elif [ $_RECON_SELECTED_CLIENT_PACKETS -gt 100 ]; then
    echo "- Moderate Activity: Regular traffic" >> "$OUTPUT_FILE"
else
    echo "- Low Activity: Minimal traffic" >> "$OUTPUT_FILE"
fi

# Signal quality
if [ $_RECON_SELECTED_CLIENT_RSSI -gt -50 ]; then
    echo "- Signal Quality: Excellent (close to AP)" >> "$OUTPUT_FILE"
elif [ $_RECON_SELECTED_CLIENT_RSSI -gt -70 ]; then
    echo "- Signal Quality: Good" >> "$OUTPUT_FILE"
else
    echo "- Signal Quality: Poor (far from AP)" >> "$OUTPUT_FILE"
fi

# Security assessment
echo "" >> "$OUTPUT_FILE"
echo "Security Assessment:" >> "$OUTPUT_FILE"
echo "- Encryption in use: $_RECON_SELECTED_CLIENT_ENCRYPTION_TYPE" >> "$OUTPUT_FILE"

if [[ "$_RECON_SELECTED_CLIENT_ENCRYPTION_TYPE" =~ "WPA" ]]; then
    echo "- Vulnerable to: Deauth attacks, handshake capture" >> "$OUTPUT_FILE"
fi

# Attack recommendations
echo "" >> "$OUTPUT_FILE"
echo "Attack Recommendations:" >> "$OUTPUT_FILE"
echo "- Deauth Attack: Target this client to force reconnection" >> "$OUTPUT_FILE"
echo "- Evil Twin: Create fake AP with probed SSIDs" >> "$OUTPUT_FILE"
if [ $_RECON_SELECTED_CLIENT_PACKETS -gt 500 ]; then
    echo "- Traffic Analysis: High activity makes good MitM target" >> "$OUTPUT_FILE"
fi
echo "- Handshake Capture: Deauth and capture WPA handshake" >> "$OUTPUT_FILE"

# Device fingerprinting
echo "" >> "$OUTPUT_FILE"
echo "Device Fingerprint:" >> "$OUTPUT_FILE"
echo "- MAC: $_RECON_SELECTED_CLIENT_MAC_ADDRESS" >> "$OUTPUT_FILE"
echo "- OUI: $_RECON_SELECTED_CLIENT_OUI ($vendor)" >> "$OUTPUT_FILE"
echo "- Type: $device_type" >> "$OUTPUT_FILE"

STOP_SPINNER $spinner_id

LOG "Profile complete: $OUTPUT_FILE"

# Create summary alert
summary="Client: $device_type | Signal: $_RECON_SELECTED_CLIENT_RSSI dBm"
ALERT "$summary"

# Log key information
LOG "Vendor: ${vendor:-Unknown}"
LOG "Device: $device_type"
LOG "Connected to: $_RECON_SELECTED_CLIENT_SSID"
LOG "Signal: $_RECON_SELECTED_CLIENT_RSSI dBm"
LOG "Packets: $_RECON_SELECTED_CLIENT_PACKETS"
