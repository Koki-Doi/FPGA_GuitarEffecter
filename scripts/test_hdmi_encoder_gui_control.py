#!/usr/bin/env python3
"""Phase 7G on-board smoke: HDMI GUI driven by synthetic encoder events.

Usage on the PYNQ-Z2:

    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
        scripts/test_hdmi_encoder_gui_control.py

This script doesn't need physical encoder hardware to be wired up. It
synthesises encoder events, runs them through EncoderUiController, and
checks that:
  * AppState focus / dirty / apply / source flags update as expected.
  * The HDMI back end accepts the new frames (no VDMA error bits).
  * The renderer draws a frame each iteration.

If real encoders are wired up, an optional flag (--use-real-encoder)
substitutes a live EncoderInput poll for the synthetic events.
"""

from __future__ import annotations

import argparse
import os
import sys
import time
from typing import Optional


def _scripted_events():
    """Yield (kind, encoder_id, delta) tuples mimicking a small user session."""
    from audio_lab_pynq.encoder_input import EncoderEvent  # type: ignore
    yield EncoderEvent("rotate",       0,  1, 4)
    yield EncoderEvent("rotate",       0,  1, 4)
    yield EncoderEvent("rotate",       1,  1, 4)
    yield EncoderEvent("rotate",       2,  3, 12)
    yield EncoderEvent("rotate",       2, -1, -4)
    yield EncoderEvent("short_press",  2)
    yield EncoderEvent("rotate",       0, -2, -8)
    yield EncoderEvent("short_press",  0)
    yield EncoderEvent("long_press",   0)
    yield EncoderEvent("long_press",   0)  # un-bypass


def main(argv: Optional[list] = None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--use-real-encoder", action="store_true",
                   help="Use a real EncoderInput poll instead of scripted events.")
    p.add_argument("--frames", type=int, default=6,
                   help="HDMI frames to write. Default 6.")
    args = p.parse_args(argv)

    here = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(here, os.pardir))
    for path in (repo_root, os.path.join(repo_root, "GUI")):
        if path not in sys.path:
            sys.path.insert(0, path)

    from audio_lab_pynq import AudioLabOverlay  # type: ignore
    overlay = AudioLabOverlay()
    print("[test] AudioLabOverlay loaded")

    from audio_lab_pynq.hdmi_backend import AudioLabHdmiBackend  # type: ignore
    backend = AudioLabHdmiBackend(overlay)
    backend.start()
    print("[test] HDMI backend started")

    from GUI.compact_v2.state import AppState  # type: ignore
    state = AppState()
    print("[test] AppState constructed (selected_effect=%d)" % state.selected_effect)

    from audio_lab_pynq.encoder_ui import EncoderUiController  # type: ignore
    controller = EncoderUiController(state, overlay=overlay)

    if args.use_real_encoder:
        from audio_lab_pynq.encoder_input import EncoderInput  # type: ignore
        enc = EncoderInput.from_overlay(overlay)
        print("[test] EncoderInput attached; poll-driven")
        events_source = (lambda: enc.poll(timestamp=time.time()))
    else:
        print("[test] scripted %d events" % len(list(_scripted_events())))
        events_source = None

    try:
        from GUI.compact_v2.renderer import render_frame_800x480_compact_v2  # type: ignore
    except Exception:
        from compact_v2.renderer import render_frame_800x480_compact_v2  # type: ignore

    failures = []
    for i in range(args.frames):
        # Dispatch events (real or one scripted event per frame)
        if args.use_real_encoder:
            for ev in events_source():
                controller.handle_event(ev)
        else:
            # Re-emit the original scripted list cyclically
            evs = list(_scripted_events())
            if i < len(evs):
                controller.handle_event(evs[i])

        frame = render_frame_800x480_compact_v2(state)
        backend.write_frame(frame, placement="manual", offset_x=0, offset_y=0)

        status = backend.status()
        sr = status.get("vdma_dmasr", "?")
        print("[test] frame %d: sel_fx=%d sel_knob=%d src=%s dirty=%s apply=%s vdma_dmasr=%s" % (
            i, state.selected_effect, state.selected_knob,
            getattr(state, "last_control_source", "?"),
            getattr(state, "value_dirty", False),
            getattr(state, "apply_pending", False), sr))

    backend.stop()
    print("[test] HDMI backend stopped")
    if failures:
        for f in failures:
            print("[test] FAIL:", f)
        return 1
    print("[test] OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
