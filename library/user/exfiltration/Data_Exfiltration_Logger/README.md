# Data Exfiltration Logger

## Description
Comprehensive logging and exfiltration tool that collects all captured WiFi data including handshakes, credentials, network maps, and client profiles. Supports multiple exfiltration methods.

## Features
- Collects data from multiple sources
- Creates compressed archive
- Multiple exfiltration methods (USB, Network, Local)
- System information gathering
- Automatic data organization

## Configuration
- `EXFIL_METHOD`: Default exfiltration method (usb/network/local)

## Exfiltration Methods
1. **USB**: Copies archive to mounted USB drive
2. **Network**: Uploads via SCP or netcat
3. **Local**: Keeps data on device

## Data Collected
- WiFi scan results
- Captured handshakes
- Credential logs
- Probe databases
- Network maps
- Client profiles
- System information

## Usage
1. Run payload from user menu
2. Wait for data collection
3. Select exfiltration method
4. Optionally cleanup after exfiltration

## Output
- Archive: `/tmp/exfil_[timestamp].tar.gz`
- Individual files in `/tmp/exfil_data/`
