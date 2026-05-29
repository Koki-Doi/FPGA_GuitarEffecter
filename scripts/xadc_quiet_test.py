#!/usr/bin/env python3
"""Runtime XADC quiet test for the D74 mute-noise (no rebuild).

With the Pmod DAC muted (no audio signal) and all effects off, this:
  1. reads the xadc_wiz_a0 CFR1 (sequencer config) + TEMP/VCCINT/VAUX1,
  2. holds (BASELINE: continuous VAUX1 conversion) so you can listen,
  3. writes CFR1 sequencer-mode -> default (stops the channel sequencer,
     i.e. no external VAUX1 sampling; on-chip calibration only),
  4. holds (QUIET) so you can listen for whether the HF noise drops,
  5. restores CFR1 to the original value.

If stopping VAUX1 conversion makes the mute noise drop toward D73 level,
the continuous external XADC sampling is the added noise source and a
non-continuous (on-demand) XADC build is the fix (Build A).

SAFETY: aborts the write unless CFR1 reads the expected 0x21AF (continuous)
that the wizard generated, so a wrong offset / unexpected state never gets
a blind register write. The write is documented (UG480/PG091) and fully
reversible (restored on exit; a bit reload also restores it).

  sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
      scripts/xadc_quiet_test.py --hold 15
"""

import importlib.util
import sys
import time

REPO = "/home/xilinx/Audio-Lab-PYNQ"
if REPO not in sys.path:
    sys.path.insert(0, REPO)

# AXI offsets (xadc_wiz v3.3): data region base 0x200 (DRP<<2), config
# region base 0x300. Verified empirically by the working VAUX1 read at 0x244.
REG_TEMP = 0x200
REG_VCCINT = 0x204
REG_VAUX1 = 0x244
REG_CFR1 = 0x304          # DRP 0x41 -> 0x200 + 0x41*4
CFR1_EXPECTED = 0x21AF    # wizard INIT_41 (continuous, VAUX1 in sequence)


def _rd(ip, off):
    return int(ip.read(off)) & 0xFFFF


def main(argv):
    hold = 15.0
    for i, a in enumerate(argv):
        if a.startswith("--hold"):
            try:
                hold = float(a.split("=")[1] if "=" in a else argv[i + 1])
            except Exception:
                pass

    from audio_lab_pynq.AudioLabOverlay import AudioLabOverlay
    ovl = AudioLabOverlay(download=False)  # attach to the loaded D74 PL
    if not hasattr(ovl, "xadc_wiz_a0"):
        print("ERROR: overlay has no xadc_wiz_a0 (is D74 loaded?).")
        return 2

    ovl.set_guitar_effects(
        noise_gate_on=False, overdrive_on=False, distortion_on=False,
        rat_on=False, amp_on=False, cab_on=False, eq_on=False,
        reverb_on=False)
    try:
        ovl.set_wah_settings(enabled=False, source="manual")
    except Exception:
        pass

    spec = importlib.util.spec_from_file_location(
        "runner", REPO + "/scripts/run_encoder_hdmi_gui.py")
    runner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runner)
    runner._write_pmod_mode(ovl, "mute")

    x = ovl.xadc_wiz_a0
    cfr1_0 = _rd(x, REG_CFR1)
    print("CFR1 baseline = 0x%04X  TEMP=%d VCCINT=%d VAUX1=%d"
          % (cfr1_0, _rd(x, REG_TEMP) >> 4, _rd(x, REG_VCCINT) >> 4,
             _rd(x, REG_VAUX1) >> 4))

    if cfr1_0 != CFR1_EXPECTED:
        print("ABORT: CFR1 != expected 0x%04X; not writing (offset/state "
              "unverified)." % CFR1_EXPECTED)
        return 3

    print(">>> BASELINE (continuous VAUX1), muted. LISTEN ~%.0fs <<<" % hold)
    time.sleep(hold)

    cfr1_quiet = cfr1_0 & 0x0FFF   # sequencer mode [15:12] -> 0000 (default)
    x.write(REG_CFR1, cfr1_quiet)
    time.sleep(0.3)
    print("CFR1 quiet   = 0x%04X  readback=0x%04X  TEMP=%d VCCINT=%d VAUX1=%d"
          % (cfr1_quiet, _rd(x, REG_CFR1), _rd(x, REG_TEMP) >> 4,
             _rd(x, REG_VCCINT) >> 4, _rd(x, REG_VAUX1) >> 4))
    print(">>> QUIET (VAUX1 sequencer stopped), muted. LISTEN ~%.0fs <<<" % hold)
    time.sleep(hold)

    x.write(REG_CFR1, cfr1_0)
    time.sleep(0.2)
    print("CFR1 restored = 0x%04X. pmod stays muted." % _rd(x, REG_CFR1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
