# Handshake Collector

## Description
Automated WPA/WPA2 handshake capture tool that targets multiple access points, performs deauth attacks, and collects handshakes for offline cracking.

## Features
- Automatic target scanning
- Multi-target handshake capture
- Deauth attack automation
- Handshake verification
- Hashcat format conversion
- Configurable target count

## Configuration
- `DEAUTH_COUNT`: Number of deauth packets (default: 10)
- `TARGET_COUNT`: Maximum APs to target (default: 5)

## Process
1. Scans for nearby WPA networks
2. Selects top targets by signal strength
3. For each target:
   - Starts packet capture
   - Sends deauth packets
   - Waits for handshake
   - Verifies capture
4. Converts to hashcat format

## Requirements
- airodump-ng
- aireplay-ng
- aircrack-ng
- hcxpcapngtool (for hashcat conversion)

## Usage
1. Run from user reconnaissance menu
2. Confirm operation
3. Wait for automatic capture process
4. Review captured handshakes

## Output
- Handshakes: `/tmp/handshakes/`
- Hashcat files: `/tmp/handshakes/[BSSID].hc22000`
- Use with: `hashcat -m 22000 file.hc22000 wordlist.txt`
