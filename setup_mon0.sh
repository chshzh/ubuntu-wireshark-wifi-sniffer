#!/usr/bin/env bash
# setup_mon0.sh — Create a monitor interface (mon0) from a specific Wi-Fi adapter
# on boot if the adapter is present.
#
# Configuration: edit the three variables below to match your environment.
# IFACE      : physical Wi-Fi interface name of the sniffer adapter
# MON_IFACE  : name for the monitor virtual interface
# CHANNEL    : Wi-Fi channel to lock the monitor interface to (0 = do not set)
# FREQ_MHZ   : frequency in MHz (used when CHANNEL is 0, or leave 0 to skip)
#
# Install:  see README.md → "Auto-start mon0 on Boot (systemd)"

set -euo pipefail

IFACE="wlx289401bca7bd"
MON_IFACE="mon0"
CHANNEL=165
FREQ_MHZ=5825   # used only when CHANNEL=0

log() { echo "[$(date '+%Y-%m-%d %T')] $*"; }

# ── Guard: adapter must be present ──────────────────────────────────────────
if ! ip link show "${IFACE}" &>/dev/null; then
    log "Interface ${IFACE} not found — skipping mon0 setup."
    exit 0
fi

log "Adapter ${IFACE} detected — setting up ${MON_IFACE}..."

# ── Tear down any previous monitor interface with the same name ───────────
if ip link show "${MON_IFACE}" &>/dev/null; then
    log "Removing existing ${MON_IFACE}..."
    ip link set "${MON_IFACE}" down  || true
    iw dev "${MON_IFACE}" del        || true
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
