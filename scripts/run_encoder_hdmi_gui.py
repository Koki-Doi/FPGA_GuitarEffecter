#!/usr/bin/env python3
"""Standalone Phase 7F/7G HDMI GUI driven by 3 rotary encoders.

Run this on the PYNQ-Z2 (no notebook needed):

    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
        scripts/run_encoder_hdmi_gui.py --fps 5

The script:
  1. Loads AudioLabOverlay (one overlay only -- no base.bit, no second
     load, see DECISIONS.md D23/D24/D25).
  2. Starts the integrated HDMI back end (SVGA 800x600 framebuffer with
     the 800x480 compact-v2 GUI pinned at (0, 0)).
  3. Builds AppState + HdmiEffectStateMirror.
  4. Polls the encoder IP via ``EncoderInput`` and dispatches events
     through ``EncoderUiController``.
  5. Repaints the HDMI framebuffer at the requested FPS.
  6. Quits cleanly on Ctrl+C, stops VTC/VDMA.

The script is read-only against PCM1808/PCM5102 plans -- it does NOT
touch PMOD JB/JA or the external codec path.
"""

from __future__ import annotations

import argparse
import os
import signal
import sys
import time
from typing import Optional


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def _build_argparser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Phase 7F/7G encoder-driven HDMI GUI runner")
    p.add_argument("--fps", type=float, default=5.0,
                   help="Repaint rate (frames per second). Default 5.")
    p.add_argument("--hold-seconds", type=float, default=0.0,
                   help="If > 0, exit after this many seconds.")
    p.add_argument("--dry-run", action="store_true",
                   help="Skip Overlay/HDMI/encoder access. Run the AppState "
                        "loop with synthesised no-op polls. Use for "
                        "off-board smoke.")
    p.add_argument("--no-apply", action="store_true",
                   help="Do not push apply() into the mirror/overlay even on "
                        "encoder-3 short_press. Useful for first-light "
                        "verification when no encoders are wired.")
    p.add_argument("--encoder-ip-name", default=None,
                   help="Override the encoder IP name in the overlay. "
                        "Default tries axi_encoder_input_0 / enc_in_0 / "
                        "axi_encoder_input.")
    p.add_argument("--reverse-enc0", action="store_true")
    p.add_argument("--reverse-enc1", action="store_true")
    p.add_argument("--reverse-enc2", action="store_true")
    p.add_argument("--swap-enc0", action="store_true")
    p.add_argument("--swap-enc1", action="store_true")
    p.add_argument("--swap-enc2", action="store_true")
    p.add_argument("--debounce-ms", type=int, default=None,
                   help="Override CONFIG.debounce_ms (1..255).")
    p.add_argument("--print-status-every", type=float, default=5.0,
                   help="Seconds between resource/status prints.")
    return p


# --------------------------------------------------------------------------
# Overlay / HDMI bring-up (lazy-imported so --dry-run works off-board)
# --------------------------------------------------------------------------

def _bring_up_overlay():
    from audio_lab_pynq import AudioLabOverlay  # type: ignore
    overlay = AudioLabOverlay()
    print("[gui] AudioLabOverlay loaded")
    # Smoke: ADC HPF + R19
    try:
        codec = getattr(overlay, "audio_codec", None) or getattr(overlay, "codec", None)
        if codec is not None and hasattr(codec, "get_adc_hpf_state"):
            hpf = codec.get_adc_hpf_state()
            print("[gui] ADC HPF: %s" % bool(hpf))
            try:
                r19 = int(codec.R19_ADC_CONTROL[0])
                print("[gui] R19_ADC_CONTROL = 0x%02X" % r19)
            except Exception:
                pass
    except Exception as exc:
        print("[gui] HPF/R19 probe failed: %r" % (exc,))
    # Smoke: HDMI/VDMA/VTC presence
    try:
        ip_dict = getattr(overlay, "ip_dict", {})
        print("[gui] axi_vdma_hdmi present:", "axi_vdma_hdmi" in ip_dict)
        print("[gui] v_tc_hdmi    present:", "v_tc_hdmi"    in ip_dict)
        enc_present = [k for k in ip_dict.keys() if "encoder" in k.lower() or k.startswith("enc_in")]
        print("[gui] encoder IP entries:", enc_present)
    except Exception as exc:
        print("[gui] ip_dict probe failed: %r" % (exc,))
    return overlay


def _start_hdmi(overlay, *, width: Optional[int] = None, height: Optional[int] = None):
    from audio_lab_pynq.hdmi_backend import (  # type: ignore
        AudioLabHdmiBackend, DEFAULT_WIDTH, DEFAULT_HEIGHT,
    )
    w = width or DEFAULT_WIDTH
    h = height or DEFAULT_HEIGHT
    backend = AudioLabHdmiBackend(overlay, width=w, height=h)
    backend.start()  # black framebuffer first; we overwrite immediately below
    print("[gui] HDMI backend started at %dx%d" % (w, h))
    return backend


def _build_state():
    # Imports here so --dry-run on a workstation only needs the GUI half
    from GUI.compact_v2.state import AppState  # type: ignore
    return AppState()


def _build_encoder(overlay, ip_name: Optional[str], cfg_overrides: dict):
    from audio_lab_pynq.encoder_input import EncoderInput  # type: ignore
    enc = EncoderInput.from_overlay(overlay, ip_name=ip_name)
    if cfg_overrides:
        enc.configure(**cfg_overrides)
    # Verify VERSION
    try:
        v = enc.read_version()
        print("[gui] encoder IP VERSION = 0x%08X" % v)
    except Exception as exc:
        print("[gui] encoder VERSION read failed: %r" % (exc,))
    return enc


# --------------------------------------------------------------------------
# Main loop
# --------------------------------------------------------------------------

def main(argv: Optional[list] = None) -> int:
    args = _build_argparser().parse_args(argv)

    # Make the repo's GUI/ directory importable just like the notebooks do.
    here = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(here, os.pardir))
    for path in (repo_root, os.path.join(repo_root, "GUI")):
        if path not in sys.path:
            sys.path.insert(0, path)

    state = _build_state()
    print("[gui] AppState constructed (selected_effect=%d)" % state.selected_effect)

    # CLI -> encoder CONFIG overrides
    cfg_overrides = {}
    if args.debounce_ms is not None:
        cfg_overrides["debounce_ms"] = int(args.debounce_ms)
    if args.reverse_enc0 or args.reverse_enc1 or args.reverse_enc2:
        cfg_overrides["reverse_direction"] = (
            args.reverse_enc0, args.reverse_enc1, args.reverse_enc2)
    if args.swap_enc0 or args.swap_enc1 or args.swap_enc2:
        cfg_overrides["clk_dt_swap"] = (
            args.swap_enc0, args.swap_enc1, args.swap_enc2)

    overlay = None
    backend = None
    encoder = None
    if not args.dry_run:
        overlay = _bring_up_overlay()
        backend = _start_hdmi(overlay)
        encoder = _build_encoder(overlay, args.encoder_ip_name, cfg_overrides)

    # Renderer
    try:
        from GUI.compact_v2.renderer import render_frame_800x480_compact_v2  # type: ignore
    except Exception:
        # Fallback for when only GUI/ is on sys.path (legacy import path)
        from compact_v2.renderer import render_frame_800x480_compact_v2  # type: ignore

    # Controller
    from audio_lab_pynq.encoder_ui import EncoderUiController  # type: ignore
    controller = EncoderUiController(
        state, overlay=(None if args.no_apply else overlay),
        apply_on_value_change=False,
    )

    stop_flag = {"stop": False}

    def _on_sigint(*_):
        stop_flag["stop"] = True
        print("\n[gui] Ctrl+C received, stopping.")

    signal.signal(signal.SIGINT, _on_sigint)

    period = 1.0 / max(0.5, float(args.fps))
    t0 = time.time()
    next_status = t0 + max(0.1, float(args.print_status_every))
    frame_count = 0

    try:
        while not stop_flag["stop"]:
            loop_start = time.time()

            # 1) poll encoder events
            if encoder is not None:
                try:
                    controller.poll_and_apply(encoder)
                except Exception as exc:
                    print("[gui] encoder poll failed: %r" % (exc,))

            # 2) render
            state.t = loop_start - t0
            frame = render_frame_800x480_compact_v2(state)

            # 3) push to HDMI (compose at (0,0) per Phase 6I)
            if backend is not None:
                try:
                    backend.write_frame(frame, placement="manual",
                                        offset_x=0, offset_y=0)
                except Exception as exc:
                    print("[gui] HDMI write_frame failed: %r" % (exc,))

            frame_count += 1

            # 4) periodic status print
            now = time.time()
            if now >= next_status:
                next_status = now + max(0.1, float(args.print_status_every))
                msg = ("[gui] t=%.1fs frames=%d sel_fx=%d sel_knob=%d "
                       "src=%s dirty=%s apply=%s last=%r" %
                       (now - t0, frame_count, state.selected_effect,
                        state.selected_knob,
                        getattr(state, "last_control_source", "?"),
                        getattr(state, "value_dirty", False),
                        getattr(state, "apply_pending", False),
                        getattr(state, "last_encoder_event", None)))
                print(msg)
                if backend is not None:
                    try:
                        st = backend.status()
                        print("[gui]   vdma_dmasr=%s vtc_ctl=%s vdma_hsize=%d vdma_vsize=%d" % (
                            st.get("vdma_dmasr"), st.get("vtc_ctl"),
                            st.get("vdma_hsize"), st.get("vdma_vsize")))
                    except Exception:
                        pass

            # 5) exit on hold-seconds
            if args.hold_seconds > 0 and (now - t0) >= float(args.hold_seconds):
                print("[gui] hold-seconds reached; exiting.")
                break

            # 6) pacing
            elapsed = time.time() - loop_start
            sleep_for = max(0.0, period - elapsed)
            if sleep_for > 0:
                time.sleep(sleep_for)
    finally:
        if backend is not None:
            try:
                backend.stop()
                print("[gui] HDMI backend stopped")
            except Exception as exc:
                print("[gui] backend.stop() failed: %r" % (exc,))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
