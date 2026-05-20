#!/usr/bin/env python3
"""Diagnose Pmod I2S2 mode-2 (ADC -> AudioLab DSP -> DAC) "clean" path.

mode 1 (direct ADC->DAC loopback) measured clean by ear. mode 2 with every
effect off was reported as "slightly distorted". This script isolates the
mode-2 DSP path with an explicit, exhaustive all-off configuration and
prints the same status numbers as test_pmod_i2s2.py so the two paths can
be compared apples-to-apples with the same external source.

It does NOT change RTL or bitstream; it only sets MODE = 2 and writes the
all-off effect state through the existing AudioLabOverlay API, then reads
status counters. Optional sub-modes A/B-test the DSP path with overdrive
on/off to confirm the chain is actually wired.

Usage on the PYNQ-Z2 (sudo + PYTHONPATH like every other smoke):

    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \\
        scripts/diagnose_pmod_i2s2_dsp_clean.py --duration 10

    # Same but spending 5 s with OD off then 5 s with OD on
    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \\
        scripts/diagnose_pmod_i2s2_dsp_clean.py --duration 5 --ab-overdrive

Outputs per phase:
  - applied / dropped kwargs (so any silent typo is visible)
  - mode register read-back
  - frame_count delta over the window (expected ~48000 / s)
  - clip_count
  - peak_abs L/R (24-bit absolute) + dBFS estimate
  - "INFO" lines: 24-bit signed full-scale = 8388607

PYNQ Python 3.6 compatibility: no dataclass, no f-string `=` syntax.
"""

import argparse
import inspect
import math
import sys
import time


REG = dict(
    VERSION         = 0x00,
    STATUS          = 0x04,
    FRAME_COUNT     = 0x08,
    NONZERO_COUNT   = 0x0C,
    SDOUT_XCOUNT    = 0x10,
    CLIP_COUNT      = 0x14,
    LAST_LEFT       = 0x18,
    LAST_RIGHT      = 0x1C,
    PEAK_ABS_LEFT   = 0x20,
    PEAK_ABS_RIGHT  = 0x24,
    MODE            = 0x28,
    CLEAR           = 0x2C,
)

FULL_SCALE_24 = (1 << 23) - 1


def _find_pmod_status(overlay):
    from pynq import MMIO
    ip_dict = getattr(overlay, "ip_dict", {})
    for key in sorted(ip_dict):
        if "pmod_status" in key or "pmod_i2s2_status" in key:
            entry = ip_dict[key]
            addr = entry.get("phys_addr")
            if addr is None:
                continue
            rng = entry.get("addr_range", 0x10000)
            return MMIO(addr, rng)
    return None


def _read(mmio, off):
    return mmio.read(off) & 0xFFFFFFFF


def _dbfs(absval):
    if absval <= 0:
        return float("-inf")
    return 20.0 * math.log10(absval / FULL_SCALE_24)


def _print_status(label, mmio):
    print("[diag] %s:" % label)
    st = _read(mmio, REG["STATUS"])
    print("    STATUS          = 0x%08X (mode=%d, sdout_alive=%d, "
          "bclk_seen=%d, lrclk_seen=%d)"
          % (st, (st >> 8) & 0x3, (st >> 2) & 1, (st >> 1) & 1, st & 1))
    print("    FRAME_COUNT     = %u" % _read(mmio, REG["FRAME_COUNT"]))
    print("    NONZERO_COUNT   = %u" % _read(mmio, REG["NONZERO_COUNT"]))
    print("    SDOUT_XCOUNT    = %u" % _read(mmio, REG["SDOUT_XCOUNT"]))
    print("    CLIP_COUNT      = %u" % _read(mmio, REG["CLIP_COUNT"]))
    pl = _read(mmio, REG["PEAK_ABS_LEFT"])
    pr = _read(mmio, REG["PEAK_ABS_RIGHT"])
    print("    PEAK_ABS_LEFT   = %u  (%.1f dBFS)" % (pl, _dbfs(pl)))
    print("    PEAK_ABS_RIGHT  = %u  (%.1f dBFS)" % (pr, _dbfs(pr)))
    print("    MODE            = 0x%08X" % _read(mmio, REG["MODE"]))


def _apply_safe_clean(ovl):
    """Push the overlay into a known all-effects-off state.

    The Pmod I2S2 notebook safe_clean() function does the same thing but
    we want this script to be self-contained (no notebook import) so we
    inline the calls here. set_compressor_settings / set_noise_suppressor_
    settings live outside set_guitar_effects and have to be called
    separately. Every kwargs dict is intersected with inspect.signature
    before being passed so a future rename does not silently drop an
    OFF flag.
    """
    # 1. Compressor (own GPIO, enabled bit in its ctrlD)
    comp_desired = dict(threshold=60, ratio=30, response=40,
                        makeup=50, enabled=False)
    comp_allowed = set(inspect.signature(ovl.set_compressor_settings).parameters)
    comp_kwargs = {k: v for k, v in comp_desired.items() if k in comp_allowed}
    comp_dropped = sorted(set(comp_desired) - set(comp_kwargs))
    print("[diag] set_compressor_settings kwargs:", comp_kwargs)
    if comp_dropped:
        print("[diag]   WARN dropped: %r" % comp_dropped)
    ovl.set_compressor_settings(**comp_kwargs)

    # 2. Noise suppressor (own GPIO, enabled flag in gate word but the
    #    settings API still has its own setter).
    ns_desired = dict(threshold=35, decay=40, damp=70, enabled=False)
    ns_allowed = set(inspect.signature(ovl.set_noise_suppressor_settings).parameters)
    ns_kwargs = {k: v for k, v in ns_desired.items() if k in ns_allowed}
    ns_dropped = sorted(set(ns_desired) - set(ns_kwargs))
    print("[diag] set_noise_suppressor_settings kwargs:", ns_kwargs)
    if ns_dropped:
        print("[diag]   WARN dropped: %r" % ns_dropped)
    ovl.set_noise_suppressor_settings(**ns_kwargs)

    # 3. Big chain: explicit all-off plus conservative levels so that even
    #    if the overlay's route ends up going through the chain we don't
    #    leak any clip / drive.
    chain_desired = dict(
        noise_gate_on=False,
        noise_gate_threshold=8,
        overdrive_on=False,
        overdrive_drive=0,
        overdrive_tone=50,
        overdrive_level=80,
        overdrive_model=0,
        distortion_on=False,
        distortion=0,
        distortion_tone=50,
        distortion_level=80,
        distortion_pedal_mask=0,
        distortion_bias=50,
        distortion_tight=50,
        distortion_mix=100,
        rat_on=False,
        rat_drive=0,
        rat_level=80,
        rat_mix=100,
        amp_on=False,
        amp_input_gain=0,
        amp_master=40,
        amp_bass=50,
        amp_middle=50,
        amp_treble=50,
        amp_presence=45,
        amp_resonance=35,
        amp_character=35,
        cab_on=False,
        cab_mix=100,
        cab_level=40,
        cab_model=1,
        cab_air=50,
        eq_on=False,
        eq_low=100,
        eq_mid=100,
        eq_high=100,
        reverb_on=False,
        reverb_decay=20,
        reverb_tone=65,
        reverb_mix=0,
    )
    # set_guitar_effects forwards **kwargs into guitar_effect_control_words
    # which has its own explicit signature. We filter against the inner
    # one because set_guitar_effects accepts arbitrary kwargs (sink + ...).
    inner_allowed = set(inspect.signature(ovl.guitar_effect_control_words).parameters)
    chain_kwargs = {k: v for k, v in chain_desired.items() if k in inner_allowed}
    chain_dropped = sorted(set(chain_desired) - set(chain_kwargs))
    print("[diag] set_guitar_effects kwargs:", sorted(chain_kwargs.keys()))
    if chain_dropped:
        print("[diag]   WARN dropped: %r" % chain_dropped)
    ovl.set_guitar_effects(**chain_kwargs)
    print("[diag] safe-clean applied: every *_on=False, every gain knob low.")


def _set_mode(mmio, value, label):
    mmio.write(REG["MODE"], value & 0x3)
    time.sleep(0.05)
    rb = _read(mmio, REG["MODE"]) & 0x3
    print("[diag] MODE write %d (%s) -> readback %d" % (value, label, rb))
    return rb


def _clear(mmio):
    mmio.write(REG["CLEAR"], 1)
    time.sleep(0.05)


def _watch(mmio, duration, label):
    """Sample status before / after `duration` and print the delta."""
    _clear(mmio)
    f0 = _read(mmio, REG["FRAME_COUNT"])
    print("[diag] %s: watching %.1f s ..." % (label, duration))
    time.sleep(duration)
    f1 = _read(mmio, REG["FRAME_COUNT"])
    _print_status("%s after %.1f s" % (label, duration), mmio)
    expected = int(round(48000.0 * duration))
    print("[diag]     frame delta = %u  (expected ~ %u for 48 kHz)"
          % ((f1 - f0) & 0xFFFFFFFF, expected))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--duration", type=float, default=10.0,
                   help="Seconds to watch each phase. Default 10.")
    p.add_argument("--ab-overdrive", action="store_true",
                   help="After the clean phase, also engage Overdrive ON "
                        "and watch for the same duration so the user can "
                        "confirm the DSP chain is actually in the loop.")
    p.add_argument("--end-mute", action="store_true", default=True,
                   help="Set MODE = 3 (mute) at the end. Default ON; pass "
                        "--no-end-mute to leave the device in mode 2.")
    p.add_argument("--no-end-mute", dest="end_mute", action="store_false")
    args = p.parse_args()

    print("[diag] AudioLab Pmod I2S2 mode-2 clean diagnostic")
    print("[diag] (mode 1 is clean by ear; this script profiles mode 2 with "
          "all effects off so the numbers can be compared.)")

    from audio_lab_pynq import AudioLabOverlay  # noqa: F401
    ovl = AudioLabOverlay()
    print("[diag] AudioLabOverlay loaded")

    mmio = _find_pmod_status(ovl)
    if mmio is None:
        print("[diag] ERROR: pmod_status IP not found on the overlay")
        return 1

    # Phase A: safe clean in mode 2.
    _set_mode(mmio, 2, "ADC_DSP_DAC")
    _apply_safe_clean(ovl)
    _print_status("initial (mode 2, all off)", mmio)
    _watch(mmio, args.duration, "mode 2 clean")

    # Phase B (optional): Overdrive ON. Confirms the chain is wired AND
    # gives the user a quick "yes that does change the audio" sanity
    # check.
    if args.ab_overdrive:
        print("[diag] --- A/B: enabling Overdrive ---")
        ovl.set_guitar_effects(
            overdrive_on=True,
            overdrive_drive=60,
            overdrive_tone=55,
            overdrive_level=80,
            overdrive_model=0,
        )
        _watch(mmio, args.duration, "mode 2 + OD on")

        print("[diag] --- A/B: disabling Overdrive again ---")
        ovl.set_guitar_effects(
            overdrive_on=False,
            overdrive_drive=0,
            overdrive_level=80,
        )
        _watch(mmio, args.duration, "mode 2 + OD back off")

    if args.end_mute:
        print("[diag] --- end: setting MODE = 3 (mute) ---")
        _set_mode(mmio, 3, "MUTE")
        _clear(mmio)
        time.sleep(0.1)
        _print_status("after mute", mmio)

    return 0


if __name__ == "__main__":
    sys.exit(main())
