#!/usr/bin/env python3
"""Read or write the Pmod I2S2 status block MODE register.

This is a thin companion to `scripts/run_encoder_hdmi_gui.py --pmod-mode`
intended to be invoked by `PmodI2S2HdmiGuiOneCell.ipynb` while the GUI
runner is still alive. It does NOT re-download the FPGA bit (uses
`Overlay(... download=False)`), it does NOT re-run the ADAU1761 codec
config (avoids `AudioLabOverlay` entirely), and it returns a non-zero
status if `audio_lab.bit` is not currently loaded on the PL.

Usage on the PYNQ-Z2:

    # Force the Pmod I2S2 master into mode 2 (ADC -> AudioLab DSP -> DAC).
    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
        scripts/pmod_i2s2_mode.py --mode dsp

    # Print the live pmod_status snapshot.
    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
        scripts/pmod_i2s2_mode.py --read

    # Clear the peak / nonzero / xcount counters (frame_count keeps running).
    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
        scripts/pmod_i2s2_mode.py --clear

Modes accepted: tone (0), loopback (1), dsp (2), mute (3). Mode 1
(direct ADC -> DAC loopback) requires `--confirm-loopback` because it
bypasses every safety filter in the DSP chain.

PYNQ Python 3.6 compatible (no f-strings, no `:=`).
"""

import argparse
import os
import sys

# The register map / mode table / MMIO discovery live in the shared
# `audio_lab_pynq.pmod_i2s2_status` module (single source of truth). It is
# imported lazily inside the functions below so this board-only CLI still
# imports off-board for `--help` / inspection (the package __init__ pulls
# in pynq, which is absent on a dev host).
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Mode names for argparse `choices` (the authoritative name->int mapping is
# `pmod_i2s2_status.MODE_INT`; kept in lock-step with it).
MODE_NAMES = ("tone", "loopback", "dsp", "mute")


def _find_pmod_status_mmio():
    """Return a (mmio, key) tuple for the pmod_status IP, or (None, None).

    The PL must already have `audio_lab.bit` loaded by some other
    process (e.g. the encoder HDMI GUI runner). Delegates to the shared
    no-overlay discovery path, which uses `pynq.Overlay(download=False)`
    purely for its ip_dict and falls back to the documented physical
    address.
    """
    from audio_lab_pynq.pmod_i2s2_status import find_status_mmio
    return find_status_mmio(overlay=None, require_loaded=True)


def _print_status(mmio, key):
    from audio_lab_pynq.pmod_i2s2_status import (
        EXPECTED_VERSION, MODE_LABEL, REG, sign24 as _sign24)
    ver = mmio.read(REG["VERSION"]) & 0xFFFFFFFF
    st  = mmio.read(REG["STATUS"]) & 0xFFFFFFFF
    mode = (st >> 8) & 0x3
    print("pmod_status IP   : %s" % (key or "?"))
    print("VERSION          : 0x%08X (expected 0x%08X)"
          % (ver, EXPECTED_VERSION))
    print("STATUS           : 0x%08X (mode=%d, sdout_alive=%d, "
          "bclk_seen=%d, lrclk_seen=%d)"
          % (st, mode, (st >> 2) & 1, (st >> 1) & 1, st & 1))
    print("MODE_REG         : %d (%s)"
          % (mmio.read(REG["MODE"]) & 0x3,
             MODE_LABEL.get(mmio.read(REG["MODE"]) & 0x3, "?")))
    print("FRAME_COUNT      : %u"
          % (mmio.read(REG["FRAME"]) & 0xFFFFFFFF))
    print("NONZERO_COUNT    : %u"
          % (mmio.read(REG["NONZERO"]) & 0xFFFFFFFF))
    print("SDOUT_XCOUNT     : %u"
          % (mmio.read(REG["SDOUT_XCOUNT"]) & 0xFFFFFFFF))
    print("CLIP_COUNT       : %u"
          % (mmio.read(REG["CLIP"]) & 0xFFFFFFFF))
    print("LAST_LEFT        : %d" % _sign24(mmio.read(REG["LAST_LEFT"])))
    print("LAST_RIGHT       : %d" % _sign24(mmio.read(REG["LAST_RIGHT"])))
    print("PEAK_ABS_LEFT    : %u"
          % (mmio.read(REG["PEAK_L"]) & 0xFFFFFFFF))
    print("PEAK_ABS_RIGHT   : %u"
          % (mmio.read(REG["PEAK_R"]) & 0xFFFFFFFF))


def main(argv=None):
    p = argparse.ArgumentParser()
    grp = p.add_mutually_exclusive_group(required=True)
    grp.add_argument("--mode", choices=MODE_NAMES,
                     help="Write MODE register to the given symbolic mode.")
    grp.add_argument("--read", action="store_true",
                     help="Print the live pmod_status snapshot.")
    grp.add_argument("--clear", action="store_true",
                     help="Issue a CLEAR pulse (peak / nonzero / xcount).")
    p.add_argument("--confirm-loopback", action="store_true",
                   help="Required when --mode loopback is requested. "
                        "Mode 1 routes ADC -> DAC at unity gain and can "
                        "feed back; without this flag the request is "
                        "refused.")
    args = p.parse_args(argv)

    if args.mode == "loopback" and not args.confirm_loopback:
        print("ERROR: --mode loopback requires --confirm-loopback "
              "(feedback risk).", file=sys.stderr)
        return 4

    mmio, key = _find_pmod_status_mmio()
    if mmio is None:
        return 2

    from audio_lab_pynq.pmod_i2s2_status import MODE_INT, REG

    if args.mode is not None:
        mode_int = MODE_INT[args.mode]
        mmio.write(REG["MODE"], mode_int & 0x3)
        rb = mmio.read(REG["MODE"]) & 0x3
        print("MODE write %d (%s) at %s; readback=%d"
              % (mode_int, args.mode, key, rb))
        return 0 if rb == (mode_int & 0x3) else 5

    if args.clear:
        mmio.write(REG["CLEAR"], 1)
        print("CLEAR pulse issued at %s." % key)
        return 0

    _print_status(mmio, key)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
