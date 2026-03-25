#!/usr/bin/env bash
# setup_mon0.sh — Set up a Wi-Fi monitor interface and open Wireshark.
#
# Usage: sudo ./setup_mon0.sh
#   (or: sudo /usr/local/sbin/setup_mon0.sh after installing)
#
# Run this script after plugging in the sniffer USB adapter.
# It creates mon0 on the adapter, tunes it to the configured channel,
# then launches Wireshark on that interface.
#
# Configuration: edit the variables below to match your environment.
# IFACE     : physical Wi-Fi interface name of the sniffer adapter
# MON_IFACE : name for the monitor virtual interface
# CHANNEL   : Wi-Fi channel to lock to (0 = skip, use FREQ_MHZ instead)
# FREQ_MHZ  : frequency in MHz (used when CHANNEL=0)

set -euo pipefail

IFACE="wlx289401bca7bd"
MON_IFACE="mon0"
CHANNEL=165
FREQ_MHZ=5825   # used only when CHANNEL=0

log() { echo "[$(date '+%Y-%m-%d %T')] $*"; }

# ── Guard: adapter must be present ──────────────────────────────────────────
if ! ip link show "${IFACE}" &>/dev/null; then
    log "ERROR: Interface ${IFACE} not found."
    log "Unplug and re-plug the USB Wi-Fi adapter, then run this script again."
    exit 1
fi

log "Adapter ${IFACE} detected — setting up ${MON_IFACE}..."

# ── Tear down any previous monitor interface with the same name ───────────
if ip link show "${MON_IFACE}" &>/dev/null; then
    log "Removing existing ${MON_IFACE}..."
    ip link set "${MON_IFACE}" down || true
    iw dev "${MON_IFACE}" del       || true
fi

# ── Create monitor interface ─────────────────────────────────────────────
ip link set "${IFACE}" down
iw dev "${IFACE}" interface add "${MON_IFACE}" type monitor
ip link set "${MON_IFACE}" up

# ── Tune to channel / frequency ──────────────────────────────────────────
if [[ "${CHANNEL}" -ne 0 ]]; then
    log "Setting ${MON_IFACE} to channel ${CHANNEL}..."
    if ! iw dev "${MON_IFACE}" set channel "${CHANNEL}"; then
        log "WARNING: 'set channel' failed — trying freq ${FREQ_MHZ} MHz instead..."
        iw dev "${MON_IFACE}" set freq "${FREQ_MHZ}" || log "WARNING: 'set freq' also failed — interface is up but channel is unset."
    fi
elif [[ "${FREQ_MHZ}" -ne 0 ]]; then
    log "Setting ${MON_IFACE} to ${FREQ_MHZ} MHz..."
    iw dev "${MON_IFACE}" set freq "${FREQ_MHZ}" || log "WARNING: 'set freq' failed — interface is up but channel is unset."
fi

# ── Final status ─────────────────────────────────────────────────────────
log "Done. Current state:"
iw dev "${MON_IFACE}" info

# ── Launch Wireshark ─────────────────────────────────────────────────────
log "Launching Wireshark on ${MON_IFACE}..."
wireshark -i "${MON_IFACE}" -k &
