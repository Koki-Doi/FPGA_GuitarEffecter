#!/usr/bin/env python3
"""Minimal audio baseline for the D73-vs-D74 HF-noise comparison (D74).

Loads the overlay (download configurable), forces ALL effects OFF (all_off
bypass) + Wah OFF, sets the Pmod I2S2 path to mode 2 (ADC -> DSP -> DAC),
prints the bitfile + ADC HPF, then HOLDS so the operator can listen for the
high-frequency noise. No HDMI GUI, no encoder, no FP02M pedal polling -- so
this isolates the bitstream + audio path from the GUI/pedal software.

  # Force-load whatever bit is on disk (use after swapping D73/D74 files):
  sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
      scripts/noise_check.py --download --hold 40

  # Attach to the already-loaded PL (no re-download):
  sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
      scripts/noise_check.py --hold 40

NOTE: PL.bitfile_name reports "audio_lab.bit" for both D73 and D74, so to
actually program a freshly-swapped bit you MUST pass --download.
"""

import importlib.util
import sys
import time

REPO = "/home/xilinx/Audio-Lab-PYNQ"
if REPO not in sys.path:
    sys.path.insert(0, REPO)


def _opt_value(argv, name, default):
    for i, a in enumerate(argv):
        if a == name and i + 1 < len(argv):
            return argv[i + 1]
        if a.startswith(name + "="):
            return a.split("=", 1)[1]
    return default


def main(argv):
    download = "--download" in argv
    hold = float(_opt_value(argv, "--hold", "40"))
    # Pmod path: mute (DAC silent ~= zero output), tone (FPGA tone -> DAC,
    # no ADC), dsp (ADC -> DSP all_off -> DAC), loopback (raw ADC -> DAC).
    pmod_mode = _opt_value(argv, "--pmod-mode", "dsp")

    from audio_lab_pynq.AudioLabOverlay import AudioLabOverlay
    ovl = AudioLabOverlay(download=download)

    ovl.set_guitar_effects(
        noise_gate_on=False, overdrive_on=False, distortion_on=False,
        rat_on=False, amp_on=False, cab_on=False, eq_on=False,
        reverb_on=False)
    try:
        ovl.set_wah_settings(enabled=False, source="manual")
    except Exception as exc:
        print("wah off skipped: %r" % (exc,))
    # Confirm all_off + Wah OFF actually applied.
    try:
        _ws = ovl.get_wah_settings()
        print("state: all 8 effect flags OFF sent; wah enabled=%s "
              "position_byte=%s" % (_ws.get("enabled"), _ws.get("position_byte")))
    except Exception as exc:
        print("state readback skipped: %r" % (exc,))

    # Reuse the runner's tested pmod-mode writer.
    spec = importlib.util.spec_from_file_location(
        "runner", REPO + "/scripts/run_encoder_hdmi_gui.py")
    runner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runner)
    runner._write_pmod_mode(ovl, pmod_mode)
    print("pmod mode = %s" % pmod_mode)

    try:
        from pynq import PL
        print("bitfile: %s" % PL.bitfile_name)
    except Exception:
        pass
    try:
        print("ADC HPF: %s  has_xadc=%s" % (
            ovl.codec.get_adc_hpf_state(), hasattr(ovl, "xadc_wiz_a0")))
    except Exception as exc:
        print("codec/xadc check: %r" % (exc,))

    print("all_off + Wah OFF + pmod %s. LISTEN ~%.0fs for HF noise..."
          % (pmod_mode, hold))
    try:
        time.sleep(hold)
    finally:
        runner._write_pmod_mode(ovl, "mute")
        print("muted (mode 3).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
