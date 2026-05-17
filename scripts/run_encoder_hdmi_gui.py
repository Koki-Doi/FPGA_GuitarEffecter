#!/usr/bin/env python3
"""Standalone Phase 7G+ HDMI GUI driven by 3 rotary encoders with live-apply.

Run this on the PYNQ-Z2 (no notebook needed):

    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
        scripts/run_encoder_hdmi_gui.py --live-apply --skip-rat

The script:
  1. Loads AudioLabOverlay (one overlay only -- no base.bit, no second
     load, see DECISIONS.md D23/D24/D25).
  2. Starts the integrated HDMI back end (SVGA 800x600 framebuffer with
     the 800x480 compact-v2 GUI pinned at (0, 0)).
  3. Builds AppState + EncoderEffectApplier (GUI-first live apply).
  4. Polls the encoder IP via ``EncoderInput`` and dispatches events
     through ``EncoderUiController`` (renders only on dirty flag).
  5. Repaints the HDMI framebuffer only when AppState changes, capped at
     --max-render-fps; sleeps longer when idle for low CPU.
  6. Periodically prints a resource snapshot (CPU / mem / temp / fps /
     last apply message).
  7. Quits cleanly on Ctrl+C, stops VTC/VDMA.

The script does NOT touch PMOD JA/JB or the external PCM1808/PCM5102
plans. RAT pedal model is skipped from encoder-driven control by
default; pass ``--include-rat`` to override.
"""

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
        description="Phase 7G+ encoder-driven HDMI GUI runner")
    p.add_argument("--hold-seconds", type=float, default=0.0,
                   help="If > 0, exit after this many seconds.")
    p.add_argument("--dry-run", action="store_true",
                   help="Skip Overlay/HDMI/encoder bring-up entirely. Use "
                        "for off-board CLI smoke.")
    p.add_argument("--no-audio-apply", action="store_true",
                   help="Skip every AudioLabOverlay set_* call but keep the "
                        "GUI / encoder loop running. AppState still updates "
                        "and the renderer still draws.")
    # Live apply controls
    apply_group = p.add_mutually_exclusive_group()
    apply_group.add_argument("--live-apply", dest="live_apply",
                             action="store_true", default=True,
                             help="Push every encoder change to the overlay "
                                  "with throttle (default).")
    apply_group.add_argument("--no-live-apply", dest="live_apply",
                             action="store_false",
                             help="Only apply on encoder-3 short press.")
    p.add_argument("--apply-interval-ms", type=int, default=100,
                   help="Throttle (ms) between live-apply pushes. Default 100.")
    p.add_argument("--value-step", type=float, default=5.0,
                   help="Knob value step per encoder-3 detent (0..100 scale).")
    # RAT skip
    rat_group = p.add_mutually_exclusive_group()
    rat_group.add_argument("--skip-rat", dest="skip_rat",
                           action="store_true", default=True,
                           help="Exclude RAT (Distortion pedal-mask bit 2) "
                                "from encoder model cycling and live apply. "
                                "Default.")
    rat_group.add_argument("--include-rat", dest="skip_rat",
                           action="store_false",
                           help="Allow encoder cycling and live apply to "
                                "touch the RAT pedal model.")
    # Encoder driver
    p.add_argument("--encoder-ip-name", default=None,
                   help="Override the encoder IP name in the overlay.")
    p.add_argument("--reverse-enc0", action="store_true")
    p.add_argument("--reverse-enc1", action="store_true")
    p.add_argument("--reverse-enc2", action="store_true")
    p.add_argument("--swap-enc0", action="store_true")
    p.add_argument("--swap-enc1", action="store_true")
    p.add_argument("--swap-enc2", action="store_true")
    p.add_argument("--debounce-ms", type=int, default=None,
                   help="Override CONFIG.debounce_ms (1..255).")
    # Loop pacing
    p.add_argument("--poll-hz-active", type=float, default=10.0,
                   help="Encoder poll rate while events are arriving.")
    p.add_argument("--poll-hz-idle", type=float, default=4.0,
                   help="Encoder poll rate after --idle-threshold-s of no "
                        "events.")
    p.add_argument("--idle-threshold-s", type=float, default=1.0,
                   help="After this many seconds without events, switch to "
                        "the idle poll rate.")
    p.add_argument("--max-render-fps", type=float, default=5.0,
                   help="Cap the render rate even under continuous rotation.")
    p.add_argument("--status-interval-s", type=float, default=2.0,
                   help="Seconds between resource/status prints.")
    return p


# --------------------------------------------------------------------------
# Overlay / HDMI bring-up (lazy-imported so --dry-run works off-board)
# --------------------------------------------------------------------------

def _bring_up_overlay():
    from audio_lab_pynq import AudioLabOverlay  # type: ignore
    overlay = AudioLabOverlay()
    print("[gui] AudioLabOverlay loaded")
    return overlay


def _start_hdmi(overlay, *, width: Optional[int] = None,
                height: Optional[int] = None):
    from audio_lab_pynq.hdmi_backend import (  # type: ignore
        AudioLabHdmiBackend, DEFAULT_WIDTH, DEFAULT_HEIGHT,
    )
    w = width or DEFAULT_WIDTH
    h = height or DEFAULT_HEIGHT
    backend = AudioLabHdmiBackend(overlay, width=w, height=h)
    backend.start()
    print("[gui] HDMI backend started at %dx%d" % (w, h))
    return backend


def _build_state():
    from GUI.compact_v2.state import AppState  # type: ignore
    return AppState()


def _build_encoder(overlay, ip_name, cfg_overrides):
    from audio_lab_pynq.encoder_input import EncoderInput  # type: ignore
    enc = EncoderInput.from_overlay(overlay, ip_name=ip_name)
    if cfg_overrides:
        enc.configure(**cfg_overrides)
    return enc


def _render_signature(s):
    """Tuple that changes iff something a render would visualise has changed."""
    knobs = ()
    akv = getattr(s, "all_knob_values", None)
    if isinstance(akv, dict):
        knobs = tuple((k, tuple(v)) for k, v in akv.items())
    return (
        getattr(s, "selected_effect", None),
        getattr(s, "selected_knob", None),
        bool(getattr(s, "value_dirty", False)),
        bool(getattr(s, "apply_pending", False)),
        bool(getattr(s, "edit_mode", False)),
        bool(getattr(s, "model_select_mode", False)),
        getattr(s, "dist_model_idx", None),
        getattr(s, "amp_model_idx", None),
        getattr(s, "cab_model_idx", None),
        bool(getattr(s, "last_apply_ok", True)),
        str(getattr(s, "last_apply_message", "")),
        id(getattr(s, "last_encoder_event", None)),
        tuple(bool(v) for v in (getattr(s, "effect_on", []) or [])),
        knobs,
    )


def _fmt_pct(value):
    return ("%5.1f%%" % value) if value is not None else "  n/a"


def _fmt_temp(value):
    return ("%4.1fC" % value) if value is not None else "  n/a"


# --------------------------------------------------------------------------
# Main loop
# --------------------------------------------------------------------------

def main(argv=None):
    args = _build_argparser().parse_args(argv)

    here = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(here, os.pardir))
    for path in (repo_root, os.path.join(repo_root, "GUI")):
        if path not in sys.path:
            sys.path.insert(0, path)

    state = _build_state()
    print("[gui] AppState constructed (selected_effect=%d)"
          % state.selected_effect)

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
        encoder.configure(clear_on_read=True)

    try:
        from GUI.compact_v2.renderer import (  # type: ignore
            render_frame_800x480_compact_v2)
    except Exception:
        from compact_v2.renderer import (  # type: ignore
            render_frame_800x480_compact_v2)

    from audio_lab_pynq.encoder_ui import EncoderUiController  # type: ignore
    from audio_lab_pynq.encoder_effect_apply import (  # type: ignore
        EncoderEffectApplier)
    from audio_lab_pynq.hdmi_state.resource_sampler import (  # type: ignore
        ResourceSampler)

    applier_overlay = None if args.no_audio_apply else overlay
    applier = EncoderEffectApplier(
        applier_overlay,
        apply_interval_s=max(0.001, float(args.apply_interval_ms) / 1000.0),
        dry_run=bool(args.dry_run or args.no_audio_apply),
        skip_rat=bool(args.skip_rat),
    )
    state.live_apply = bool(args.live_apply)
    state.apply_interval_ms = int(args.apply_interval_ms)

    controller = EncoderUiController(
        state,
        applier=applier,
        live_apply=bool(args.live_apply),
        skip_rat=bool(args.skip_rat),
        value_step=float(args.value_step),
        apply_on_value_change=False,
    )

    stop_flag = {"stop": False}

    def _on_sigint(*_):
        stop_flag["stop"] = True
        print("\n[gui] Ctrl+C received, stopping.")

    signal.signal(signal.SIGINT, _on_sigint)

    poll_period_active = 1.0 / max(0.1, float(args.poll_hz_active))
    poll_period_idle = 1.0 / max(0.1, float(args.poll_hz_idle))
    min_render_period = 1.0 / max(0.1, float(args.max_render_fps))
    status_interval_s = max(0.2, float(args.status_interval_s))

    sampler = ResourceSampler()
    sampler.sample()  # bootstrap

    t0 = time.time()
    last_event_t = t0
    last_render_t = 0.0
    last_sig = None
    last_status_t = 0.0
    last_status_frames = 0
    last_status_polls = 0
    frames = 0
    polls = 0

    print("[gui] live_apply=%s apply_interval_ms=%d skip_rat=%s "
          "no_audio_apply=%s" % (args.live_apply, args.apply_interval_ms,
                                  args.skip_rat, args.no_audio_apply))
    print("[gui] Encoder1 rotate=effect select, short=on/off, long=safe-bypass")
    print("[gui] Encoder2 rotate=param/model select, short=model/edit toggle")
    print("[gui] Encoder3 rotate=value change, short=apply, long=reset knob")
    print("[gui] RAT pedal model excluded from encoder control by default")

    try:
        while not stop_flag["stop"]:
            loop_t = time.time()
            polls += 1
            if encoder is not None:
                try:
                    events = encoder.poll(timestamp=loop_t - t0)
                except Exception as exc:
                    print("[gui] encoder poll failed: %r" % (exc,))
                    events = []
            else:
                events = []
            if events:
                controller.handle_events(events)
                last_event_t = loop_t

            sig = _render_signature(state)
            if sig != last_sig and (loop_t - last_render_t) >= min_render_period:
                state.t = loop_t - t0
                frame = render_frame_800x480_compact_v2(state)
                if backend is not None:
                    try:
                        backend.write_frame(frame, placement="manual",
                                            offset_x=0, offset_y=0)
                    except Exception as exc:
                        print("[gui] HDMI write_frame failed: %r" % (exc,))
                last_sig = sig
                last_render_t = loop_t
                frames += 1

            if (loop_t - last_status_t) >= status_interval_s:
                r = sampler.sample()
                dt = (loop_t - last_status_t) if last_status_t > 0 \
                    else max(1e-3, loop_t - t0)
                render_fps = (frames - last_status_frames) / dt
                poll_hz = (polls - last_status_polls) / dt
                rss_mb = int(r.get("proc_rss_kb", 0)) // 1024
                mem_total_mb = int(r.get("mem_total_kb", 0)) // 1024
                mem_avail_mb = int(r.get("mem_avail_kb", 0)) // 1024
                mem_used_mb = (mem_total_mb - mem_avail_mb
                               if mem_total_mb else 0)
                mem_used_pct = (100.0 * mem_used_mb / mem_total_mb) \
                    if mem_total_mb else None
                idle_for = loop_t - last_event_t
                mode = "idle" if idle_for > args.idle_threshold_s else "active"
                msg = applier.last_apply_message or "-"
                if len(msg) > 28:
                    msg = msg[:25] + "..."
                print(
                    "[gui] t=%6.1fs mode=%-6s poll=%4.1fHz render=%4.1ffps "
                    "sys_cpu=%s proc_cpu=%s mem=%4d/%4dMB(%s) rss=%4dMB "
                    "temp=%s sel_fx=%d knob=%d live=%s apply=%s last=%s"
                    % (
                        loop_t - t0, mode, poll_hz, render_fps,
                        _fmt_pct(r.get("sys_cpu_pct")),
                        _fmt_pct(r.get("proc_cpu_pct")),
                        mem_used_mb, mem_total_mb, _fmt_pct(mem_used_pct),
                        rss_mb, _fmt_temp(r.get("temperature_c")),
                        state.selected_effect, state.selected_knob,
                        "ON" if state.live_apply else "off",
                        "OK" if applier.last_apply_ok else "ERR",
                        msg,
                    )
                )
                last_status_t = loop_t
                last_status_frames = frames
                last_status_polls = polls

            if args.hold_seconds > 0 and (loop_t - t0) >= float(args.hold_seconds):
                print("[gui] hold-seconds reached; exiting.")
                break

            idle_for = loop_t - last_event_t
            period = (poll_period_idle if idle_for > args.idle_threshold_s
                      else poll_period_active)
            elapsed = time.time() - loop_t
            if elapsed < period:
                time.sleep(period - elapsed)
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
