#!/usr/bin/env python3
"""Phase 7F on-board smoke for the rotary-encoder PL IP.

Usage on the PYNQ-Z2:

    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
        scripts/test_encoder_input.py --duration 60

Verifies:
  * AudioLabOverlay loads (one overlay only).
  * axi_encoder_input IP appears in overlay.ip_dict.
  * VERSION register reads 0x00070001.
  * Initial CONFIG matches the default 0x00010105.
  * BUTTON_STATE reads cleanly.
  * Live polling: prints rotate / short / long / release events as the
    user turns the knobs.

Does NOT touch the audio DSP, HDMI, ADAU1761, or PMOD JB/JA.
"""

from __future__ import annotations

import argparse
import time


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--duration", type=float, default=60.0,
                   help="Seconds to poll encoder events. Default 60.")
    p.add_argument("--poll-hz", type=float, default=50.0,
                   help="Poll rate. Default 50 Hz.")
    p.add_argument("--encoder-ip-name", default=None,
                   help="Override the encoder IP name.")
    args = p.parse_args()

    from audio_lab_pynq import AudioLabOverlay  # type: ignore
    overlay = AudioLabOverlay()
    print("[enc] AudioLabOverlay loaded")

    # IP presence
    ip_dict = getattr(overlay, "ip_dict", {})
    enc_names = [k for k in ip_dict if "encoder" in k.lower() or k.startswith("enc_in")]
    print("[enc] encoder IP candidates: %s" % enc_names)
    if not enc_names:
        print("[enc] ERROR: no encoder IP found in overlay.ip_dict")
        return 2

    from audio_lab_pynq.encoder_input import (  # type: ignore
        EncoderInput, EXPECTED_VERSION, CONFIG_DEFAULT,
    )
    enc = EncoderInput.from_overlay(overlay, ip_name=args.encoder_ip_name)

    ver = enc.read_version()
    cfg = enc.read_config()
    btn = enc.read_button_state()
    cnt = enc.read_counts()
    print("[enc] VERSION       = 0x%08X (expected 0x%08X)" % (ver, EXPECTED_VERSION))
    print("[enc] CONFIG        = 0x%08X (expected 0x%08X)" % (cfg, CONFIG_DEFAULT))
    print("[enc] BUTTON_STATE  = 0b%s" % bin(btn)[2:].zfill(3))
    print("[enc] COUNT0..2     = %d / %d / %d" % cnt)

    if ver != EXPECTED_VERSION:
        print("[enc] WARNING: VERSION mismatch -- bit/hwh may be stale.")

    print("[enc] Now turn the encoders and press the switches.")
    print("[enc] (Polling every %.1f ms for %.1f s)" % (1000.0 / args.poll_hz, args.duration))

    t0 = time.time()
    period = 1.0 / max(1.0, float(args.poll_hz))
    total_events = 0
    while time.time() - t0 < args.duration:
        try:
            events = enc.poll(timestamp=time.time() - t0)
        except Exception as exc:
            print("[enc] poll failed: %r" % (exc,))
            break
        for ev in events:
            if ev.kind == "rotate":
                print("[enc] enc%d ROTATE delta=%+d (raw=%+d)" % (
                    ev.encoder_id, ev.delta, ev.raw_delta))
            elif ev.kind == "short_press":
                print("[enc] enc%d SHORT_PRESS" % ev.encoder_id)
            elif ev.kind == "long_press":
                print("[enc] enc%d LONG_PRESS" % ev.encoder_id)
            elif ev.kind == "release":
                print("[enc] enc%d RELEASE" % ev.encoder_id)
            total_events += 1
        time.sleep(period)

    cnt = enc.read_counts()
    print("[enc] DONE: total events = %d, final COUNTs = %d / %d / %d" % (
        total_events, cnt[0], cnt[1], cnt[2]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
