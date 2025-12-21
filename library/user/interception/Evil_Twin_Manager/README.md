# Evil Twin Manager

## Description
Automated evil twin attack manager that creates a fake access point with captive portal to harvest credentials from victims.

## Features
- User-configurable target SSID
- Channel selection
- Built-in captive portal
- PHP credential capture
- DHCP and DNS services
- Real-time victim monitoring

## Components
- hostapd for AP creation
- dnsmasq for DHCP/DNS
- PHP server for captive portal
- Credential logging

## Configuration
Variables are collected via interactive prompts:
- Target SSID (text picker)
- Channel (number picker)

## Captive Portal
The portal mimics a network authentication page to harvest:
- Usernames
- Passwords
- Device information

## Usage
1. Launch from user interception menu
2. Enter target SSID when prompted
3. Select channel
4. Confirm operation
5. Wait for victims to connect
6. Review captured credentials

## Output
Credentials saved to: `/tmp/evil_creds.txt`
Portal files in: `/tmp/evil_portal/`

## Duration
Monitors for 5 minutes by default (300 seconds)
