# Network Credential Harvester

## Description
Creates a rogue access point to harvest network credentials from connecting devices. This payload sets up a fake WiFi hotspot with a captive portal to capture authentication attempts and credentials.

## Features
- Configurable SSID and channel
- Automated rogue AP setup using hostapd
- Real-time connection monitoring
- Credential logging
- Configurable capture duration

## Configuration
Edit the following variables in the payload:
- `ROGUE_SSID`: SSID of the rogue AP (default: "FreePublicWiFi")
- `ROGUE_CHANNEL`: WiFi channel to use (default: "6")
- `MAX_CAPTURE_TIME`: Maximum capture duration in seconds (default: 300)

## Requirements
- hostapd
- WiFi interface in monitor mode
- Active WiFi clients nearby

## Usage
1. Launch payload from user payloads menu
2. Confirm operation when prompted
3. Wait for clients to connect
4. Review captured credentials in `/tmp/captured_credentials.log`

## Legal Notice
This tool is for authorized security testing only. Unauthorized use may violate laws.
