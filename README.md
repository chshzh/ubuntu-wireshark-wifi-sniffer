# Kali Wireshark Monitor-mode capture (specific 5 GHz channel)

This repository collects a short, practical guide and helper files for capturing Wi‑Fi traffic on a specific 5 GHz channel (example: Channel 165 / 5825 MHz) using Kali Linux and Wireshark.

IMPORTANT: follow local radio regulations. Only use channels and transmit modes that are legal for your country and that your hardware supports. This repo is intended for passive capture and diagnostics.

## What this guide does
- Checks hardware/driver and regulatory domain
- Puts a Wi‑Fi interface into monitor mode on a specific 5 GHz channel
- Captures packets with `dumpcap`/`tshark` or Wireshark
- Provides common troubleshooting tips and useful filters

## Quick checklist
1. Identify your wireless interface:
   ```bash
   sudo iw dev
   ```
2. Check PHY capabilities and monitor-mode support:
   ```bash
   sudo iw phy
   ```
3. Check regulatory domain (channels allowed):
   ```bash
   sudo iw reg get
   ```
4. Stop NetworkManager/wpa_supplicant while configuring (optional):
   ```bash
   sudo systemctl stop NetworkManager wpa_supplicant
   ```
5. Create monitor interface and set channel 165 (5825 MHz):
   ```bash
   sudo ip link set wlan0 down
   sudo iw dev wlan0 interface add mon0 type monitor
   sudo ip link set mon0 up
   sudo iw dev mon0 set freq 5825
   ```
6. Verify monitor interface:
   ```bash
   sudo iw dev mon0 info
   ```
7. Capture with dumpcap (rotating files):
   ```bash
   sudo dumpcap -i mon0 -w ~/capture_ch165.pcapng -b filesize:10240 -b files:5
   ```
8. When finished, restart services:
   ```bash
   sudo systemctl start NetworkManager wpa_supplicant
   ```

## Useful capture filters (BPF)
- Only management frames: `wlan type mgt`
- Probe requests: `wlan type mgt subtype probe-req`
- Specific BSSID: `ether host AA:BB:CC:DD:EE:FF`
- Data frames: `wlan type data`

## Troubleshooting
- "Operation not supported" when enabling monitor mode: check driver and chipset; some Broadcom chips have poor monitor support.
- Channel not available: check `sudo iw reg get` and consider `sudo iw reg set <COUNTRY>` temporarily if legal.
- No packets: ensure proximity to AP/client, verify the AP actually uses channel 165, and the interface is in monitor mode.
- Permissions for dumpcap: grant capabilities so Wireshark/dumpcap can run without root:
  ```bash
  sudo setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip' $(which dumpcap)
  getcap $(which dumpcap)
  ```

## Example full session
```bash
sudo systemctl stop NetworkManager wpa_supplicant
sudo ip link set wlan0 down
sudo iw dev wlan0 interface add mon0 type monitor
sudo ip link set mon0 up
sudo iw dev mon0 set freq 5825
sudo iw dev mon0 info
sudo setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip' $(which dumpcap)
sudo dumpcap -i mon0 -w ~/capture_ch165.pcapng -b filesize:10240 -b files:5
# when done
sudo systemctl start NetworkManager wpa_supplicant
```

## After review — pushing to GitHub
I have left this repository as a local git repository with an initial commit. When you're ready to push to your GitHub account, run:

```bash
# from the repo root
git remote add origin https://github.com/<your-username>/kali-wireshark-monitor-spcific-channel.git
git branch -M main
git push -u origin main
```

Replace `<your-username>` with your GitHub username. I will not push anything until you tell me to.

## License
Choose a license appropriate for your needs (MIT/Unlicense/etc.).
