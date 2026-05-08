#!/usr/bin/env bash
# Show the network identity used for the PYNQ-Z2 DHCP reservation.
#
# This is a fixed-reservation verification helper, not a network scanner.
# Set PYNQ_HOST to override the reserved address when needed.
set -euo pipefail

PYNQ_HOST="${PYNQ_HOST:-192.168.1.9}"
PYNQ_USER="${PYNQ_USER:-xilinx}"
PYNQ_JUPYTER_URL="http://${PYNQ_HOST}:9090/tree"
SSH_TARGET="${PYNQ_USER}@${PYNQ_HOST}"
SSH_OPTS=(-o ConnectTimeout=5 -o BatchMode=yes)

fail() {
    cat >&2 <<EOF
ERROR: Cannot reach PYNQ at ${PYNQ_HOST}
Check:
- PYNQ power
- Ethernet cable
- router DHCP reservation
- reserved MAC address
- IP conflict
EOF
    exit 1
}

INFO=$(
    ssh "${SSH_OPTS[@]}" "$SSH_TARGET" 'python3 - <<PY
from pathlib import Path
import socket

print("HOSTNAME=" + socket.gethostname())
mac = Path("/sys/class/net/eth0/address")
print("ETH0_MAC=" + (mac.read_text().strip() if mac.exists() else ""))
PY
ip -br addr' 2>/dev/null
) || fail

HOSTNAME=$(printf '%s\n' "$INFO" | awk -F= '/^HOSTNAME=/{print $2; exit}')
ETH0_MAC=$(printf '%s\n' "$INFO" | awk -F= '/^ETH0_MAC=/{print $2; exit}')

if [[ -z "$HOSTNAME" || -z "$ETH0_MAC" ]]; then
    fail
fi

cat <<EOF
PYNQ host      : ${PYNQ_HOST}
Hostname       : ${HOSTNAME}
eth0 MAC       : ${ETH0_MAC}
Jupyter        : ${PYNQ_JUPYTER_URL}

Router DHCP reservation:
Device name    : PYNQ-Z2
MAC address    : ${ETH0_MAC}
Reserved IP    : 192.168.1.9

SSH            : ssh ${SSH_TARGET}
EOF
