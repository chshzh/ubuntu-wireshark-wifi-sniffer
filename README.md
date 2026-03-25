# Ubuntu Wireshark capture wifi packet from one specific channel

This repository collects a short, practical guide and helper files for capturing Wi‑Fi traffic on a specific channel (for example: Channel 165 / 5825 MHz at 5GHz band) using Ubuntu Linux and Wireshark. The guide is written so you can target any channel by changing the channel number or frequency.

IMPORTANT: follow local radio regulations. Only use channels and transmit modes that are legal for your country and that your hardware supports. This repo is intended for passive capture and diagnostics.

## What this guide does
- Checks hardware/driver and regulatory domain
-- Puts a Wi‑Fi interface into monitor mode on a specific channel
- Captures packets with Wireshark or `dumpcap`/`tshark` 
- Provides common troubleshooting tips and useful filters

## Wi-Fi Adapter Monitor mode support

Wi‑Fi monitor mode and specific-channel capture require adapter and driver support. Not all USB or PCIe adapters support monitor mode on all bands or all channels. If you're using a Netgear A9000 (or similar USB adapters), see the community-maintained compatibility list for adapters and in-kernel driver support:

- Netgear A9000 reference: https://github.com/morrownr/USB-WiFi/blob/main/home/USB_WiFi_Adapters_that_are_supported_with_Linux_in-kernel_drivers.md#be6500---usb30---24-ghz-5-ghz-and-6-ghz-wifi-7

That page lists adapters and whether they work with mainline kernel drivers (preferred) or require out-of-tree drivers. For Ubuntu Linux, prefer adapters that are supported by in-kernel drivers for easiest monitor-mode operation.

## Setup Steps
1. Identify your wireless interface:
   ```bash
   ip link            # list interfaces (e.g. wlx289401bca7bd)
   iw dev             # show wireless devices
   ```
2. Check PHY capabilities and monitor-mode support:
   ```bash
   iw list | grep -A10 "Supported interface modes"   # see if 'monitor' is listed
   ```
3. Stop NetworkManager/wpa_supplicant while configuring (optional):
   ```bash
   systemctl stop NetworkManager wpa_supplicant
   ```
4. Create monitor interface and set the desired channel (example uses channel 165 / 5825 MHz):
   ```bash
   ip link set wlx289401bca7bd down
   iw dev wlx289401bca7bd interface add mon0 type monitor
   ip link set mon0 up
   # To set by channel number (if supported):
   iw dev mon0 set channel 165
   # Or set by frequency (MHz):
   iw dev mon0 set freq 5825
   ```
5. Verify monitor interface:
   ```bash
   iw dev mon0 info
   ```
6. Start capturing packets:
   
   **Option A: Using Wireshark GUI (Recommended for interactive analysis)**
   1. Start Wireshark as your normal user
   2. Launch Wireshark and select `mon0` as the capture interface
   3. Click "Start capturing packets" to begin monitoring live traffic
   4. Use capture filters if needed (e.g., `wlan type mgt` for management frames only)
   
   **Option B: Using dumpcap (For long-term or automated captures)**
   ```bash
   dumpcap -i mon0 -w ~/capture_ch165.pcapng -b filesize:10240 -b files:5
   # or use a generic name
   dumpcap -i mon0 -w ~/capture_channel_<CH>.pcapng -b filesize:10240 -b files:5
   ```
7. When finished, restart services:
   ```bash
   systemctl start NetworkManager wpa_supplicant
   ```


## Using Wireshark and decrypting WPA/WPA2 traffic

After you create the monitor interface (`mon0`) and set the desired channel, you can open Wireshark and select `mon0` as the capture interface to start monitoring live traffic. Below are steps and tips for decrypting WPA/WPA2-PSK traffic (passphrase/PSK) in Wireshark.

### Basic Wireshark Setup
1. Start Wireshark as your normal user (preferably give `dumpcap` capabilities so the GUI doesn't need root).
2. Select `mon0` in the capture interface list and start capturing.

### Capturing the handshake
- To decrypt WPA/WPA2-PSK traffic, Wireshark needs the 4-way handshake between a client and the AP. Ensure a client connects or re-authenticates while you capture. You can force a reconnect from the client (toggle Wi‑Fi, disable/re-enable the interface, or use a deauth if you have permission).

### Entering keys into Wireshark
- Go to Edit → Preferences → Protocols → IEEE 802.11.
- Check "Enable decryption".
- In "Decryption Keys", add entries in one of these formats (one per line):
   - Passphrase form (Wireshark derives the PSK):
      wpa-pwd:yourpassphrase:ssid
      Example: `wpa-pwd:mysecretpassword:MyNetworkSSID`
   - Raw PSK (64 hex chars):
      wpa-psk:0123456789abcdef...:ssid
      Example: `wpa-psk:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef:MyNetworkSSID`

### Notes on decryption
- Verify the handshake is in the capture: use the display filter `eapol` to find EAPOL/4-way messages.
- If the handshake was captured and the key is correct, Wireshark will decrypt data frames and show higher-layer payloads.
- For WPA/WPA2-Enterprise (EAP) networks, PSK entry won't work; you need the appropriate EAP credentials or a different approach.
- If decryption fails, check SSID spelling, that the captured handshake corresponds to the SSID, and that you captured the full handshake.

### Offline decryption
- If you captured to a file (via `dumpcap`/`tshark`), open the file in Wireshark and add keys as above; Wireshark can decrypt the file offline after keys are provided.

### Security and privacy reminder
- Only decrypt networks you own or are authorized to analyze. Decrypting traffic for networks you don't control is illegal in many jurisdictions.

## Wireshark, dumpcap and tshark — differences and how to use them

Short summary:
- `dumpcap` is the lightweight capture engine (used by Wireshark). It writes packets to disk with minimal processing and lowest overhead — the recommended tool for long-running or high-throughput captures.
- `tshark` is the terminal (CLI) version of Wireshark. It can capture and dissect packets, display decoded fields, apply display filters live, and write capture files. Because it dissects packets, it uses more CPU than `dumpcap`.
- `Wireshark` is the graphical packet analyzer used for deep inspection and protocol decoding. Wireshark delegates capture operations to `dumpcap` for security and performance.

When to use which:
- Use `dumpcap` for long-term captures, high-throughput captures, and when you want the smallest capture overhead. It supports ring buffers (`-b`) and rotation. Example:
```bash
dumpcap -i mon0 -w ~/capture_ch165.pcapng -b filesize:10240 -b files:5
```
- Use `tshark` for quick CLI captures or automated analysis pipelines where you want immediate dissection or to print fields. Example: capture 1000 packets and write to a file:
```bash
tshark -i mon0 -c 1000 -w ~/cap_1000_ch165.pcapng
```
You can also apply a BPF capture filter with `-f` (applies at capture time):
```bash
tshark -i mon0 -f "wlan type mgt" -w ~/beacons.pcapng
```
Note: display filters (Wireshark/tshark syntax) are not capture filters — they only filter displayed packets after capture. Use BPF with `-f` for capture-time filtering.

- Use `Wireshark` for interactive analysis. Prefer to capture with `dumpcap` (or give `dumpcap` capabilities) and then open the `.pcapng` in Wireshark as a normal user. Give `dumpcap` the necessary capabilities so Wireshark doesn't need root:
```bash
setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip' $(which dumpcap)
```

Performance note:
- `dumpcap` writes raw packets with minimal CPU usage. `tshark` performs protocol dissection while capturing which increases CPU and may cause packet loss on very busy captures. If in doubt, capture with `dumpcap` and analyze later in Wireshark.

Tip: rotate files to avoid huge single files and to enable continuous capture without manual intervention:
```bash
dumpcap -i mon0 -w capture -b duration:600 -b files:10
# creates capture_00001_YYYYMMDDhhmmss.pcapng files rotated every 10 minutes, keeping 10 files
```

How to open captured files in Wireshark:
1. Start Wireshark as a normal user.
2. File → Open → select the `.pcapng` created by `dumpcap` or `tshark`.

Security note:
- Avoid running Wireshark GUI as root. Instead give `dumpcap` capabilities (see above) and use Wireshark for analysis.


## Auto-start mon0 on Boot (systemd)

Three files in this repository automate the monitor interface setup whenever the sniffer adapter is present:

| File | Purpose |
|---|---|
| `setup_mon0.sh` | Shell script — creates `mon0` from the sniffer adapter and sets the channel |
| `mon0-setup.service` | systemd unit — runs the script when triggered |
| `99-mon0-setup.rules` | udev rule — fires the service the moment the adapter is enumerated by the kernel |

### How boot vs. hot-plug is handled

USB adapters are enumerated asynchronously and may appear after systemd has already started services. The two triggers work together:

| Trigger | When it fires | How it works |
|---|---|---|
| `systemctl enable` (boot) | At `multi-user.target` | Script waits up to `WAIT_SECS` (40 s) for the adapter to appear, then proceeds |
| udev rule (hot-plug) | The instant the kernel registers the interface | Starts the service immediately; adapter is already present so the wait exits at once |

`Type=oneshot` + `RemainAfterExit=yes` prevents double-runs if both triggers fire at boot.

### Configuration

Before installing, open `setup_mon0.sh` and edit the three variables at the top:

```bash
IFACE="wlx289401bca7bd"   # physical interface name of your sniffer adapter
MON_IFACE="mon0"           # name for the monitor virtual interface
CHANNEL=165                # Wi-Fi channel to lock to (set to 0 to use FREQ_MHZ)
FREQ_MHZ=5825              # frequency in MHz (used when CHANNEL=0)
```

### How it works

On startup, the script:
1. Checks whether `IFACE` exists — if the adapter is absent (unplugged) it exits silently without error.
2. Tears down any leftover `mon0` from a previous session.
3. Brings the physical interface down, creates `mon0` of type `monitor`, then brings `mon0` up.
4. Sets the channel/frequency on `mon0`.

Because the physical interface is taken down, this script is intended for a **dedicated sniffer adapter** (second USB dongle). Your primary Wi-Fi adapter for internet connectivity is not affected. See [the question about running both simultaneously](#networkmanager-and-ip-vs-iw) for background.

### Installation

Run the following commands once (requires root):

```bash
# 1. Copy files into place
sudo cp setup_mon0.sh       /usr/local/sbin/setup_mon0.sh
sudo cp mon0-setup.service  /etc/systemd/system/mon0-setup.service
sudo cp 99-mon0-setup.rules /etc/udev/rules.d/99-mon0-setup.rules

# 2. Make the script executable
sudo chmod +x /usr/local/sbin/setup_mon0.sh

# 3. Reload systemd and udev rules, then enable the service
sudo systemctl daemon-reload
sudo udevadm control --reload-rules
sudo systemctl enable --now mon0-setup.service
```

### Verify and manage

```bash
# Check service status and last run output
systemctl status mon0-setup.service

# View full logs
journalctl -u mon0-setup.service

# Simulate the udev add event to test without unplugging the dongle
sudo udevadm trigger --action=add --subsystem-match=net \
    --attr-match=ifindex=$(cat /sys/class/net/wlx289401bca7bd/ifindex)

# Run the script manually (useful for testing config changes)
sudo /usr/local/sbin/setup_mon0.sh

# Confirm mon0 is up and on the right channel
iw dev mon0 info
```

### Uninstall

```bash
sudo systemctl disable --now mon0-setup.service
sudo rm /etc/systemd/system/mon0-setup.service
sudo rm /etc/udev/rules.d/99-mon0-setup.rules
sudo rm /usr/local/sbin/setup_mon0.sh
sudo systemctl daemon-reload
sudo udevadm control --reload-rules
```

---

## NetworkManager and `ip` vs `iw`

These three tools operate at different layers and often get used together when preparing a wireless interface for monitoring. Knowing their roles helps avoid conflicts.

- NetworkManager: a high-level service that automatically manages network interfaces and connections (Wi‑Fi, Ethernet, VPNs). It starts/stops `wpa_supplicant`, configures IP addressing, and may automatically change interface modes. On Ubuntu you can control it with `systemctl` and `nmcli`.
   - Common commands:
      - `systemctl stop NetworkManager` — stop the service (prevents automatic reconfiguration).
      - `nmcli radio wifi off` — disable Wi‑Fi radio via NetworkManager.
      - `nmcli device set <IFACE> managed no` — mark an interface unmanaged (persistent until re-enabled).
   - When preparing monitor mode: stop NetworkManager or mark the interface unmanaged to prevent it from switching the interface out of monitor mode.

- `ip`: the low-level link/address/route manager used to bring interfaces up/down, add virtual links, and inspect addresses. Use `ip` to change interface state and inspect links.
   - Common commands:
      - `ip link set <IFACE> down` / `ip link set <IFACE> up`
      - `ip link show` — list links
      - `ip addr show <IFACE>` — show addresses
   - `ip` does not manage wireless-specific properties (channels, monitor mode) — use it alongside `iw` to control link state.

- `iw`: the wireless-specific tool for controlling nl80211 features (modes, channels, PHY settings). Use `iw` to create monitor interfaces and set channels/frequencies.
   - `iw` is the correct tool to set monitor mode and tune frequencies; `ip` is used to change link state (up/down) for the interfaces `iw` creates.

Best practice when enabling monitor mode:
1. Stop NetworkManager or mark your interface unmanaged so it doesn't interfere:
    ```bash
    systemctl stop NetworkManager
    # or
    nmcli device set wlx289401bca7bd managed no
    ```
2. Use `ip` to take the physical interface down, then use `iw` to create the monitor interface and set the channel/frequency:
    ```bash
    ip link set wlx289401bca7bd down
    iw dev wlx289401bca7bd interface add mon0 type monitor
    ip link set mon0 up
    iw dev mon0 set freq 5825
    ```
3. Capture with `dumpcap`/`tshark`/Wireshark.
4. When finished, restore NetworkManager or re-enable management on the interface:
    ```bash
    ip link set mon0 down
    # remove monitor iface if desired: iw dev mon0 del
    nmcli device set wlx289401bca7bd managed yes
    systemctl start NetworkManager
    ```

This workflow keeps responsibilities clear: NetworkManager manages connections, `ip` manages link state, and `iw` manages wireless parameters.
