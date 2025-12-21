#!/bin/bash
# Title: Advanced AP Scanner
# Description: Enhanced access point discovery with detailed analysis and filtering
# Author: WiFi Pineapple Pager Community
# Version: 1.0
# Category: Recon

LOG "Advanced AP Scanner"
LOG "Selected AP: $_RECON_SELECTED_AP_SSID"
LOG "BSSID: $_RECON_SELECTED_AP_BSSID"

# Detailed analysis output
OUTPUT_FILE="/tmp/advanced_ap_scan_$_RECON_SELECTED_AP_BSSID.txt"

spinner_id=$(START_SPINNER "Analyzing AP...")

cat > "$OUTPUT_FILE" <<EOF
=== Advanced AP Analysis ===
Timestamp: $(date)

Basic Information:
-----------------
SSID: $_RECON_SELECTED_AP_SSID
BSSID: $_RECON_SELECTED_AP_BSSID
MAC: $_RECON_SELECTED_AP_MAC_ADDRESS
Hidden: $_RECON_SELECTED_AP_HIDDEN

Network Details:
---------------
Channel: $_RECON_SELECTED_AP_CHANNEL
Frequency: $_RECON_SELECTED_AP_FREQ MHz
Encryption: $_RECON_SELECTED_AP_ENCRYPTION_TYPE

Signal Information:
------------------
RSSI: $_RECON_SELECTED_AP_RSSI dBm
Quality: $(echo "scale=2; ($_RECON_SELECTED_AP_RSSI + 100) / 0.7" | bc)%

Traffic Statistics:
------------------
Total Packets: $_RECON_SELECTED_AP_PACKETS
Client Count: $_RECON_SELECTED_AP_CLIENT_COUNT
Last Seen: $_RECON_SELECTED_AP_TIMESTAMP

Hardware Information:
--------------------
OUI: $_RECON_SELECTED_AP_OUI
EOF

# Get vendor information
vendor=$(macchanger -l 2>/dev/null | grep "${_RECON_SELECTED_AP_OUI}" | awk '{$1=""; print $0}' | xargs)
echo "Vendor: ${vendor:-Unknown}" >> "$OUTPUT_FILE"

# Additional beaconed SSIDs if available
if [ ! -z "$_RECON_SELECTED_AP_BEACONED_SSIDS" ]; then
    echo "" >> "$OUTPUT_FILE"
    echo "Beaconed SSIDs:" >> "$OUTPUT_FILE"
    echo "$_RECON_SELECTED_AP_BEACONED_SSIDS" >> "$OUTPUT_FILE"
fi

# Perform channel analysis
LOG "Analyzing channel usage..."
iwlist wlan0 scan 2>/dev/null | grep -A 5 "Channel:$_RECON_SELECTED_AP_CHANNEL" | while read line; do
    echo "$line" >> "$OUTPUT_FILE"
done

# Security analysis
echo "" >> "$OUTPUT_FILE"
echo "Security Assessment:" >> "$OUTPUT_FILE"
case "$_RECON_SELECTED_AP_ENCRYPTION_TYPE" in
    *WPA3*)
        echo "- Strong: WPA3 encryption detected" >> "$OUTPUT_FILE"
        ;;
    *WPA2*)
        echo "- Good: WPA2 encryption (vulnerable to KRACK)" >> "$OUTPUT_FILE"
        ;;
    *WPA*)
        echo "- Weak: WPA1 encryption (deprecated)" >> "$OUTPUT_FILE"
        ;;
    *WEP*)
        echo "- Very Weak: WEP encryption (easily crackable)" >> "$OUTPUT_FILE"
        ;;
    *Open*)
        echo "- None: Open network (no encryption)" >> "$OUTPUT_FILE"
        ;;
esac

# Threat level assessment
threat_level="LOW"
if [ $_RECON_SELECTED_AP_CLIENT_COUNT -gt 10 ]; then
    threat_level="MEDIUM"
fi
if [[ "$_RECON_SELECTED_AP_ENCRYPTION_TYPE" =~ "WEP" ]] || [[ "$_RECON_SELECTED_AP_ENCRYPTION_TYPE" =~ "Open" ]]; then
    threat_level="HIGH"
fi

echo "" >> "$OUTPUT_FILE"
echo "Threat Level: $threat_level" >> "$OUTPUT_FILE"

# Recommendations
echo "" >> "$OUTPUT_FILE"
echo "Recommendations:" >> "$OUTPUT_FILE"
if [ $_RECON_SELECTED_AP_CLIENT_COUNT -gt 5 ]; then
    echo "- High client count - good target for mass attacks" >> "$OUTPUT_FILE"
fi
if [ $_RECON_SELECTED_AP_RSSI -gt -50 ]; then
    echo "- Strong signal - optimal for attacks" >> "$OUTPUT_FILE"
elif [ $_RECON_SELECTED_AP_RSSI -lt -70 ]; then
    echo "- Weak signal - may affect attack reliability" >> "$OUTPUT_FILE"
fi

STOP_SPINNER $spinner_id

LOG "Analysis complete"
LOG "Report: $OUTPUT_FILE"

# Display summary
ALERT "AP: $_RECON_SELECTED_AP_SSID | Threat: $threat_level"

# Log key findings
LOG "Channel: $_RECON_SELECTED_AP_CHANNEL"
LOG "Encryption: $_RECON_SELECTED_AP_ENCRYPTION_TYPE"
LOG "Clients: $_RECON_SELECTED_AP_CLIENT_COUNT"
LOG "Signal: $_RECON_SELECTED_AP_RSSI dBm"
LOG "Vendor: ${vendor:-Unknown}"
