# Hidden SSID Revealer

## Description
Multi-method tool for discovering and revealing hidden WiFi network SSIDs using probe analysis, deauth attacks, and dictionary methods.

## Features
- Three discovery methods
- Automated method escalation
- Probe response monitoring
- Client deauth technique
- Dictionary-based probing
- Comprehensive reporting

## Methods

### Method 1: Probe Response Monitoring
Passively monitors probe responses to detect SSID

### Method 2: Deauth Attack
Forces clients to reconnect, revealing SSID during re-authentication

### Method 3: Dictionary Probe
Tests common SSIDs against the target AP

## Requirements
- airodump-ng
- aireplay-ng
- mdk3
- Active clients (for Method 2)

## Usage
1. Select hidden AP from recon
2. Run Hidden SSID Revealer
3. Wait for methods to execute
4. SSID revealed in alert

## Success Factors
- Client presence (improves success rate)
- Signal strength
- SSID commonality

## Output
Report: `/tmp/hidden_ssid_[BSSID].txt`

## Common SSIDs Tested
- Network brands (Linksys, Netgear, etc.)
- Generic names (Home, Office, WiFi, etc.)
- Default router SSIDs
