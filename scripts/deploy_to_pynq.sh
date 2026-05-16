#!/usr/bin/env bash
# Deploy Audio-Lab-PYNQ (Phase 1) to a PYNQ-Z2 board.
#
# Password handling:
#   - The PYNQ-Z2 default credentials are xilinx / xilinx.
#   - This script NEVER stores or logs the password.
#   - On first run, you will be prompted for the PYNQ password EXACTLY ONCE
#     by ssh-copy-id (the password goes to ssh, not to this script).
#   - All subsequent runs use SSH key authentication and require no input.
#
# Constraints honoured:
#   - No git push / pull / fetch / remote operations.
#   - No bitstream regeneration (the existing .bit/.hwh are deployed as-is).
#   - No HDL / HLS / Clash / block_design.tcl changes are made.
#
# Override defaults via environment variables (do not hard-code in files):
#   PYNQ_HOST       default 192.168.1.9
#   PYNQ_USER       default xilinx
#   SSH_KEY         default $HOME/.ssh/id_ed25519
#   PYNQ_REPO_DIR   default /home/xilinx/Audio-Lab-PYNQ
#   PYNQ_NB_DIR     default /home/xilinx/jupyter_notebooks
#
set -euo pipefail

PYNQ_HOST="${PYNQ_HOST:-192.168.1.9}"
PYNQ_USER="${PYNQ_USER:-xilinx}"
PYNQ_REPO_DIR="${PYNQ_REPO_DIR:-/home/xilinx/Audio-Lab-PYNQ}"
PYNQ_NB_DIR="${PYNQ_NB_DIR:-/home/xilinx/jupyter_notebooks}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
PYNQ_JUPYTER_URL="http://${PYNQ_HOST}:9090/tree"

SSH_TARGET="${PYNQ_USER}@${PYNQ_HOST}"
SSH_BASE_OPTS=(-o ConnectTimeout=5 -o ServerAliveInterval=10 -o ServerAliveCountMax=3)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log()  { printf '\033[1;34m[deploy]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[deploy]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[deploy]\033[0m %s\n' "$*" >&2; }

ssh_keyauth() {
    ssh "${SSH_BASE_OPTS[@]}" -i "$SSH_KEY" -o BatchMode=yes "$SSH_TARGET" "$@"
}
ssh_remote() {
    ssh "${SSH_BASE_OPTS[@]}" -i "$SSH_KEY" "$SSH_TARGET" "$@"
}
rsync_to_pynq() {
    rsync -az --info=stats1 \
        -e "ssh ${SSH_BASE_OPTS[*]} -i $SSH_KEY" \
        "$@"
}

unreachable() {
    err "Cannot reach PYNQ at $PYNQ_HOST"
    cat >&2 <<EOF
Check:
- PYNQ power
- Ethernet cable
- router DHCP reservation
- reserved MAC address
- IP conflict
EOF
}

# --- 1. SSH key bootstrap -------------------------------------------------

log "Using PYNQ_HOST=$PYNQ_HOST"
log "Jupyter: $PYNQ_JUPYTER_URL"
log "target: $SSH_TARGET"

if ! ping -c 1 -W 2 "$PYNQ_HOST" >/dev/null 2>&1; then
    warn "ping to $PYNQ_HOST failed; will still try SSH"
fi

if [[ ! -f "$SSH_KEY" ]]; then
    log "generating SSH key at $SSH_KEY (no passphrase)"
    mkdir -p "$(dirname "$SSH_KEY")"
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N '' -C "audio-lab-pynq-deploy" >/dev/null
fi

SSH_PROBE_RC=0
SSH_PROBE_OUTPUT=$(
    ssh "${SSH_BASE_OPTS[@]}" -i "$SSH_KEY" -o BatchMode=yes "$SSH_TARGET" 'echo ok' 2>&1 >/dev/null
) || SSH_PROBE_RC=$?
if [[ "$SSH_PROBE_RC" -ne 0 ]] && grep -Eqi 'No route to host|Connection timed out|Connection refused|Could not resolve|Name or service not known' <<<"$SSH_PROBE_OUTPUT"; then
    unreachable
    exit 1
fi

if ssh_keyauth 'echo ok' >/dev/null 2>&1; then
    log "SSH key auth already works -- no password prompt needed"
else
    warn "SSH key not yet authorized on PYNQ."
    warn "ssh-copy-id will prompt for the PYNQ password ONCE."
    warn "this script does NOT capture, log, or persist that password."
    ssh-copy-id -i "${SSH_KEY}.pub" "${SSH_BASE_OPTS[@]}" "$SSH_TARGET"
    if ! ssh_keyauth 'echo ok' >/dev/null 2>&1; then
        err "key auth still failing after ssh-copy-id; aborting"
        exit 1
    fi
    log "SSH key auth now active"
fi

# --- 2. Sudo capability check --------------------------------------------

if ssh_keyauth 'sudo -n true' >/dev/null 2>&1; then
    log "passwordless sudo available on PYNQ (default xilinx config)"
    HAS_PWLESS_SUDO=1
else
    warn "passwordless sudo not available; will install to user site instead"
    HAS_PWLESS_SUDO=0
fi
if [[ "$HAS_PWLESS_SUDO" -eq 1 ]]; then
    SUDO_PREFIX="sudo -n"
else
    SUDO_PREFIX=""
fi

# --- 3. Stage payload ----------------------------------------------------

log "staging payload"
STAGE_DIR=$(mktemp -d)
trap 'rm -rf "$STAGE_DIR"' EXIT

rsync -a --exclude='__pycache__' --exclude='.ipynb_checkpoints' \
    "$REPO_ROOT/audio_lab_pynq/" "$STAGE_DIR/audio_lab_pynq/"

mkdir -p "$STAGE_DIR/audio_lab_pynq/bitstreams"
cp "$REPO_ROOT/hw/Pynq-Z2/bitstreams/audio_lab.bit" \
   "$STAGE_DIR/audio_lab_pynq/bitstreams/"
cp "$REPO_ROOT/hw/Pynq-Z2/bitstreams/audio_lab.hwh" \
   "$STAGE_DIR/audio_lab_pynq/bitstreams/"

mkdir -p "$STAGE_DIR/scripts"
find "$REPO_ROOT/scripts" -maxdepth 1 -type f -name '*.py' -print0 \
    | xargs -0 -I{} cp "{}" "$STAGE_DIR/scripts/"

mkdir -p "$STAGE_DIR/GUI"
find "$REPO_ROOT/GUI" -maxdepth 1 -type f -name '*.py' -print0 \
    | xargs -0 -I{} cp "{}" "$STAGE_DIR/GUI/"

# Mirror the hw/ shape that setup.py expects for first-time pip install.
mkdir -p "$STAGE_DIR/hw/Pynq-Z2/bitstreams"
cp "$REPO_ROOT/hw/Pynq-Z2/Makefile"                     "$STAGE_DIR/hw/Pynq-Z2/Makefile"
cp "$REPO_ROOT/hw/Pynq-Z2/bitstreams/audio_lab.bit"     "$STAGE_DIR/hw/Pynq-Z2/bitstreams/"
cp "$REPO_ROOT/hw/Pynq-Z2/bitstreams/audio_lab.hwh"     "$STAGE_DIR/hw/Pynq-Z2/bitstreams/"
cp "$REPO_ROOT/setup.py"                                "$STAGE_DIR/setup.py"
[[ -f "$REPO_ROOT/README.md" ]] && cp "$REPO_ROOT/README.md" "$STAGE_DIR/README.md"

# --- 4. Push payload to PYNQ ---------------------------------------------

log "rsync to $SSH_TARGET:$PYNQ_REPO_DIR"
ssh_remote "mkdir -p '$PYNQ_REPO_DIR'"
rsync_to_pynq -r "$STAGE_DIR/" "$SSH_TARGET:$PYNQ_REPO_DIR/"

# --- 5. Install / refresh Python package ---------------------------------

log "checking for existing audio_lab_pynq install on PYNQ"
EXISTING_PATH=$(ssh_keyauth \
    'python3 -c "import audio_lab_pynq, os; print(os.path.dirname(audio_lab_pynq.__file__))" 2>/dev/null' \
    || true)

if [[ -n "$EXISTING_PATH" ]]; then
    log "package already installed at $EXISTING_PATH; refreshing files there"
    if [[ "$HAS_PWLESS_SUDO" -eq 1 ]]; then
        ssh_remote "sudo -n cp -r '$PYNQ_REPO_DIR/audio_lab_pynq/.' '$EXISTING_PATH/'"
    else
        ssh_remote "cp -r '$PYNQ_REPO_DIR/audio_lab_pynq/.' '$EXISTING_PATH/' 2>/dev/null \
                    || { echo 'cannot write to '$EXISTING_PATH'; need sudo'; exit 1; }"
    fi
else
    log "no existing install; running pip install -e (editable)"
    if [[ "$HAS_PWLESS_SUDO" -eq 1 ]]; then
        ssh_remote "cd '$PYNQ_REPO_DIR' && sudo -n env BOARD=Pynq-Z2 pip3 install -e . 2>&1 | tail -n 30"
    else
        ssh_remote "cd '$PYNQ_REPO_DIR' && env BOARD=Pynq-Z2 pip3 install --user -e . 2>&1 | tail -n 30"
    fi
fi

# --- 5.5 Mirror bit/hwh into pynq/overlays/audio_lab/ --------------------
#
# `AudioLabOverlay` resolves its default bitfile next to the
# `audio_lab_pynq` package that PYTHONPATH happens to pick up, but
# `pynq.Overlay("audio_lab")` (bare name) — and some user scripts
# we cannot enumerate — resolve through pynq's overlays registry at
# `/usr/local/lib/python3.6/dist-packages/pynq/overlays/audio_lab/`.
# Without this step that copy stays at whatever was loaded last and
# users get the old `1280x720` or `Phase 6H` bit instead of the
# current Phase 6I SVGA build. See DECISIONS.md D25 and memory
# `pynq-site-packages-bit-cache`.
log "mirroring bit/hwh into pynq/overlays/audio_lab/ for the overlays registry"
ssh_remote "
    set -e
    OVERLAYS_DIR=\$(python3 -c 'import pynq, os; print(os.path.join(os.path.dirname(pynq.__file__), \"overlays\", \"audio_lab\"))')
    $SUDO_PREFIX mkdir -p \"\$OVERLAYS_DIR\"
    $SUDO_PREFIX cp '$PYNQ_REPO_DIR/hw/Pynq-Z2/bitstreams/audio_lab.bit' \"\$OVERLAYS_DIR/audio_lab.bit\"
    $SUDO_PREFIX cp '$PYNQ_REPO_DIR/hw/Pynq-Z2/bitstreams/audio_lab.hwh' \"\$OVERLAYS_DIR/audio_lab.hwh\"
    echo \"  overlays registry: \$OVERLAYS_DIR\"
"

# --- 6. Import sanity check ----------------------------------------------

log "verifying imports on PYNQ"
ssh_remote 'python3 - <<PY
import importlib
mods = [
    "audio_lab_pynq",
    "audio_lab_pynq.AudioCodec",
    "audio_lab_pynq.AudioLabOverlay",
    "audio_lab_pynq.AxisSwitch",
    "audio_lab_pynq.diagnostics",
    "audio_lab_pynq.hdmi_backend",
]
for m in mods:
    importlib.import_module(m)
    print("  ok:", m)
from audio_lab_pynq.AudioCodec import ADAU1761
from audio_lab_pynq.AudioLabOverlay import AudioLabOverlay
from audio_lab_pynq import diagnostics
print("  DIAGNOSTIC_REGISTERS count:", len(ADAU1761.DIAGNOSTIC_REGISTERS))
for fn in ("dump_codec_registers", "capture_input", "diagnostic_capture",
           "output_zero_test", "output_sine_test", "codec_register_diff"):
    assert hasattr(AudioLabOverlay, fn), fn
    print("  AudioLabOverlay." + fn + ": present")
for fn in ("enable_adc_hpf", "disable_adc_hpf", "get_adc_hpf_state",
           "set_input_digital_volume", "get_input_digital_volume"):
    assert hasattr(ADAU1761, fn), fn
    print("  ADAU1761." + fn + ": present")
print("  decision table lines:", len(diagnostics.DECISION_TABLE.splitlines()))
PY'

# --- 7. Install notebooks via the package's own helper -------------------

log "installing notebooks under $PYNQ_NB_DIR/audio_lab"
ssh_remote "
    set -e
    $SUDO_PREFIX mkdir -p '$PYNQ_NB_DIR'
    $SUDO_PREFIX env PYNQ_JUPYTER_NOTEBOOKS='$PYNQ_NB_DIR' python3 -c '
from audio_lab_pynq import install_notebooks
install_notebooks(\"$PYNQ_NB_DIR\")
print(\"notebooks installed: $PYNQ_NB_DIR/audio_lab/\")
'
"

log "notebook placement on PYNQ:"
ssh_remote "ls -1 '$PYNQ_NB_DIR/audio_lab' | sed 's/^/  /'"

# --- 8. Summary ----------------------------------------------------------

cat <<EOF

----------------------------------------------------------------------
Deploy complete.

  Jupyter UI         ${PYNQ_JUPYTER_URL}
  Notebooks dir      $PYNQ_NB_DIR/audio_lab/
  Repo on PYNQ       $PYNQ_REPO_DIR/
  Diagnostic CLI     ssh ${SSH_TARGET} \\
                     'sudo env PYTHONPATH=${PYNQ_REPO_DIR} python3 ${PYNQ_REPO_DIR}/scripts/audio_diagnostics.py --help'
  HDMI 800x480 test  ssh ${SSH_TARGET} \\
                     'cd ${PYNQ_REPO_DIR} && sudo env PYTHONPATH=${PYNQ_REPO_DIR} python3 scripts/test_hdmi_800x480_frame.py'

Quick smoke test (run on the board):
  ssh ${SSH_TARGET} 'sudo python3 -c "
from audio_lab_pynq.AudioLabOverlay import AudioLabOverlay
ovl = AudioLabOverlay()
ovl.dump_codec_registers()
print(\"ADC HPF:\", ovl.codec.get_adc_hpf_state())
print(\"input vol:\", ovl.codec.get_input_digital_volume())
"'
----------------------------------------------------------------------
EOF
