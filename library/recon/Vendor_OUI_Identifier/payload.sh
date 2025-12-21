#!/bin/bash
# Title: Vendor OUI Identifier
# Description: Identifies device vendors by OUI and provides security intelligence
# Author: WiFi Pineapple Pager Community
# Version: 1.0
# Category: Recon

LOG "Vendor OUI Identifier"

# Determine if analyzing AP or Client
if [ ! -z "$_RECON_SELECTED_AP_BSSID" ]; then
    target_mac="$_RECON_SELECTED_AP_BSSID"
    target_oui="$_RECON_SELECTED_AP_OUI"
    target_type="Access Point"
    target_name="$_RECON_SELECTED_AP_SSID"
else
    target_mac="$_RECON_SELECTED_CLIENT_MAC_ADDRESS"
    target_oui="$_RECON_SELECTED_CLIENT_OUI"
    target_type="Client"
    target_name="$_RECON_SELECTED_CLIENT_MAC_ADDRESS"
fi

LOG "Analyzing: $target_type - $target_name"
OUTPUT_FILE="/tmp/vendor_analysis_$target_mac.txt"

spinner_id=$(START_SPINNER "Identifying vendor...")

cat > "$OUTPUT_FILE" <<EOF
=== Vendor OUI Analysis ===
Target: $target_name
Type: $target_type
MAC: $target_mac
OUI: $target_oui
Analysis Time: $(date)

EOF

# Get vendor from local OUI database
vendor=$(macchanger -l 2>/dev/null | grep -i "${target_oui}" | awk '{$1=""; print $0}' | xargs)

if [ -z "$vendor" ]; then
    vendor="Unknown"
fi

echo "Vendor: $vendor" >> "$OUTPUT_FILE"
LOG "Vendor: $vendor"

# Device classification
echo "" >> "$OUTPUT_FILE"
echo "=== Device Classification ===" >> "$OUTPUT_FILE"

device_class="Unknown"
os_estimate="Unknown"

case "$vendor" in
    *Apple*|*iPhone*|*iPad*)
        device_class="Mobile Device"
        os_estimate="iOS/iPadOS"
        security_profile="High Security"
        ;;
    *Samsung*|*LG*|*Motorola*|*OnePlus*|*Google*|*Pixel*)
        device_class="Mobile Device"
        os_estimate="Android"
        security_profile="Medium Security"
        ;;
    *Intel*|*Broadcom*|*Qualcomm*|*Realtek*|*Atheros*)
        device_class="Network Adapter"
        os_estimate="Various (Laptop/Desktop)"
        security_profile="Variable"
        ;;
    *Cisco*|*Juniper*|*Ubiquiti*|*Aruba*)
        device_class="Enterprise Network Equipment"
        os_estimate="Proprietary"
        security_profile="High Security"
        ;;
    *Netgear*|*Linksys*|*TP-Link*|*D-Link*|*Asus*)
        device_class="Consumer Router/AP"
        os_estimate="Embedded Linux"
        security_profile="Low-Medium Security"
        ;;
    *Raspberry*)
        device_class="Single Board Computer"
        os_estimate="Linux (Likely Raspberry Pi OS)"
        security_profile="Variable"
        ;;
    *Amazon*|*Ring*)
        device_class="IoT Device"
        os_estimate="Embedded OS"
        security_profile="Low Security"
        ;;
    *Nest*|*Google*)
        device_class="Smart Home Device"
        os_estimate="Embedded OS"
        security_profile="Medium Security"
        ;;
    *Sonos*|*Roku*|*Chromecast*)
        device_class="Media Device"
        os_estimate="Embedded OS"
        security_profile="Low-Medium Security"
        ;;
    *)
        device_class="Unknown Device"
        os_estimate="Unknown"
        security_profile="Unknown"
        ;;
esac

echo "Device Class: $device_class" >> "$OUTPUT_FILE"
echo "Estimated OS: $os_estimate" >> "$OUTPUT_FILE"
echo "Security Profile: $security_profile" >> "$OUTPUT_FILE"

# Security vulnerabilities database
echo "" >> "$OUTPUT_FILE"
echo "=== Known Vulnerabilities ===" >> "$OUTPUT_FILE"

case "$vendor" in
    *Netgear*|*Linksys*|*TP-Link*|*D-Link*)
        echo "Consumer routers often have:" >> "$OUTPUT_FILE"
        echo "- Default credentials vulnerability" >> "$OUTPUT_FILE"
        echo "- Outdated firmware" >> "$OUTPUT_FILE"
        echo "- UPnP exploits" >> "$OUTPUT_FILE"
        echo "- Web interface vulnerabilities" >> "$OUTPUT_FILE"
        ;;
    *Apple*)
        echo "Apple devices:" >> "$OUTPUT_FILE"
        echo "- Generally well-secured" >> "$OUTPUT_FILE"
        echo "- Vulnerable to Bluetooth exploits" >> "$OUTPUT_FILE"
        echo "- MAC randomization used in iOS 14+" >> "$OUTPUT_FILE"
        ;;
    *Samsung*|*Android*)
        echo "Android devices:" >> "$OUTPUT_FILE"
        echo "- Fragmented security updates" >> "$OUTPUT_FILE"
        echo "- Bluetooth vulnerabilities" >> "$OUTPUT_FILE"
        echo "- Variable MAC randomization" >> "$OUTPUT_FILE"
        ;;
    *Amazon*|*Ring*|*IoT*)
        echo "IoT devices:" >> "$OUTPUT_FILE"
        echo "- Weak default passwords common" >> "$OUTPUT_FILE"
        echo "- Rarely updated firmware" >> "$OUTPUT_FILE"
        echo "- Poor encryption implementation" >> "$OUTPUT_FILE"
        ;;
esac

# Attack recommendations
echo "" >> "$OUTPUT_FILE"
echo "=== Attack Recommendations ===" >> "$OUTPUT_FILE"

if [ "$target_type" == "Access Point" ]; then
    echo "AP-Specific Attacks:" >> "$OUTPUT_FILE"
    echo "- WPS PIN attack (if WPS enabled)" >> "$OUTPUT_FILE"
    echo "- Rogue AP/Evil Twin attack" >> "$OUTPUT_FILE"
    echo "- Default credential brute force" >> "$OUTPUT_FILE"
    
    case "$vendor" in
        *Netgear*|*Linksys*|*TP-Link*)
            echo "- Try default logins: admin/admin, admin/password" >> "$OUTPUT_FILE"
            ;;
    esac
else
    echo "Client-Specific Attacks:" >> "$OUTPUT_FILE"
    echo "- Deauth attack to capture handshake" >> "$OUTPUT_FILE"
    echo "- Evil twin with probed SSIDs" >> "$OUTPUT_FILE"
    echo "- Traffic interception via MitM" >> "$OUTPUT_FILE"
    
    case "$device_class" in
        "Mobile Device")
            echo "- Captive portal credential phishing" >> "$OUTPUT_FILE"
            echo "- SSL strip attack for app traffic" >> "$OUTPUT_FILE"
            ;;
        "IoT Device")
            echo "- Default credential attempts" >> "$OUTPUT_FILE"
            echo "- Firmware exploit research" >> "$OUTPUT_FILE"
            ;;
    esac
fi

# Intelligence gathering
echo "" >> "$OUTPUT_FILE"
echo "=== Intelligence Summary ===" >> "$OUTPUT_FILE"
echo "MAC Address: $target_mac" >> "$OUTPUT_FILE"
echo "OUI: $target_oui" >> "$OUTPUT_FILE"
echo "Vendor: $vendor" >> "$OUTPUT_FILE"
echo "Device Type: $device_class" >> "$OUTPUT_FILE"
echo "Estimated OS: $os_estimate" >> "$OUTPUT_FILE"

# Add target-specific details
if [ "$target_type" == "Access Point" ]; then
    echo "SSID: $_RECON_SELECTED_AP_SSID" >> "$OUTPUT_FILE"
    echo "Channel: $_RECON_SELECTED_AP_CHANNEL" >> "$OUTPUT_FILE"
    echo "Encryption: $_RECON_SELECTED_AP_ENCRYPTION_TYPE" >> "$OUTPUT_FILE"
    echo "Signal: $_RECON_SELECTED_AP_RSSI dBm" >> "$OUTPUT_FILE"
    echo "Clients: $_RECON_SELECTED_AP_CLIENT_COUNT" >> "$OUTPUT_FILE"
else
    echo "Connected AP: $_RECON_SELECTED_CLIENT_SSID" >> "$OUTPUT_FILE"
    echo "Signal: $_RECON_SELECTED_CLIENT_RSSI dBm" >> "$OUTPUT_FILE"
    echo "Packets: $_RECON_SELECTED_CLIENT_PACKETS" >> "$OUTPUT_FILE"
fi

STOP_SPINNER $spinner_id

LOG "Vendor analysis complete"
LOG "Vendor: $vendor"
LOG "Device: $device_class"
LOG "Security: $security_profile"
LOG "Report: $OUTPUT_FILE"

ALERT "$vendor | $device_class"
