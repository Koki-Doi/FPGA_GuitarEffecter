#!/usr/bin/env python3
"""Standalone Phase 7G+ HDMI GUI driven by 3 rotary encoders with live-apply.

Run this on the PYNQ-Z2 (no notebook needed):

    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
        scripts/run_encoder_hdmi_gui.py --live-apply --skip-rat

Pmod I2S2 mode 2 (ADC -> AudioLab DSP -> DAC, D49) -- pair with the
`PmodI2S2HdmiGuiOneCell.ipynb` Notebook:

    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
        scripts/run_encoder_hdmi_gui.py --live-apply --skip-rat \
        --pmod-mode dsp

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

The script does NOT touch PMOD JA/JB unless ``--pmod-mode`` is passed.
When ``--pmod-mode {tone,loopback,dsp,mute}`` is supplied, the runner
writes the Pmod I2S2 status block MODE register once at startup and
writes MODE=3 (mute) at shutdown so SIGTERM / Ctrl+C leaves the
external speakers silent. The retired PCM1808 / PCM5102 path is left
alone. RAT pedal model is skipped from encoder-driven control by
default; pass ``--include-rat`` to override.
"""

import argparse
import os
import signal
import sys
import threading
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
    p.add_argument("--apply-interval-ms", type=int, default=20,
                   help="Throttle (ms) between live-apply pushes. Default 20 "
                        "(D76: HDMI render runs on a background thread now, so "
                        "the apply path is no longer render-bound).")
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
    sw_group = p.add_mutually_exclusive_group()
    # The bench encoder modules used on this rig report SW HIGH when
    # pressed (the IP's RTL default of sw_active_low=1 gave inverted
    # hold semantics on Encoder 1 / inverted toggle edge on Encoder 0,
    # see DECISIONS.md D47). The runner defaults to SW-active-high so a
    # fresh launch matches the documented spec without an extra flag.
    sw_group.add_argument("--sw-active-low", dest="sw_active_low",
                          action="store_true", default=False,
                          help="Treat SW=LOW as pressed. Use if the IP's "
                               "RTL default polarity matches your module "
                               "(uncommon for the bench modules).")
    sw_group.add_argument("--sw-active-high", dest="sw_active_low",
                          action="store_false",
                          help="Treat SW=HIGH as pressed (default for this rig).")
    # Loop pacing
    p.add_argument("--poll-hz-active", type=float, default=60.0,
                   help="Encoder poll rate while events are arriving. "
                        "D76: raised 30 -> 60 now that the render thread no "
                        "longer blocks the encoder/pedal/apply loop.")
    p.add_argument("--poll-hz-idle", type=float, default=10.0,
                   help="Encoder poll rate after --idle-threshold-s of no "
                        "events. Kept >= short_press latch detection window "
                        "so brief taps are not missed when idle.")
    p.add_argument("--idle-threshold-s", type=float, default=1.0,
                   help="After this many seconds without events, switch to "
                        "the idle poll rate.")
    p.add_argument("--max-render-fps", type=float, default=20.0,
                   help="Cap the render rate even under continuous rotation.")
    p.add_argument("--status-interval-s", type=float, default=2.0,
                   help="Seconds between resource/status prints.")
    # Pmod I2S2 cfg_mode (optional, default keep).
    p.add_argument("--pmod-mode",
                   choices=("keep", "tone", "loopback", "dsp", "mute"),
                   default="keep",
                   help="Write the Pmod I2S2 status block MODE register "
                        "right after AudioLabOverlay loads. 'keep' (default) "
                        "does not touch the register. 'dsp' selects the "
                        "ADC -> AudioLab DSP -> DAC path (mode 2). On exit "
                        "the runner mutes (MODE=3) if a non-keep mode was "
                        "set, so Ctrl+C / SIGTERM produce a clean shutdown.")
    # D74 FP02M expression pedal -> Wah POSITION.
    p.add_argument("--wah-pedal", action="store_true",
                   help="Enable the FP02M A0 pedal controller for Wah "
                        "POSITION. Reads the calibration JSON and streams "
                        "position_raw into set_wah_settings while "
                        "AppState.wah_source == 'pedal'. Stays MANUAL if A0 "
                        "is unreadable (no XADC channel) or no calibration.")
    p.add_argument("--wah-calibration", default=None,
                   help="FP02M calibration JSON (default "
                        "~/.config/audio_lab/fp02m_calibration.json).")
    p.add_argument("--wah-pedal-hz", type=float, default=100.0,
                   help="FP02M read/write rate cap in Hz (default 100). The "
                        "effective rate is min(this, active poll rate).")
    p.add_argument("--wah-pedal-debug", action="store_true",
                   help="Print a [wah-pedal] status line ~1/s (reader, "
                        "available, source, raw, u8, writes, gpio_pos) to "
                        "diagnose the pedal path.")
    return p


# --------------------------------------------------------------------------
# Overlay / HDMI bring-up (lazy-imported so --dry-run works off-board)
# --------------------------------------------------------------------------

def _bring_up_overlay():
    """Attach the AudioLab overlay; reuse the loaded bit when possible.

    Phase 6I C2 puts the HDMI pixel clock at 40 MHz which sits at the
    rgb2dvi v1.4 kClkRange=3 VCO lower bound (~800 MHz). Re-downloading
    `audio_lab.bit` while it is already loaded can knock the PLL out and
    drop the LCD to white (project memory ``rgb2dvi-pll-edge-at-40mhz``,
    `DECISIONS.md` D25). Mirror the smart-attach guard the
    `HdmiGuiShow.ipynb` / `EncoderGuiSmoke.ipynb` cells use: if
    `pynq.PL.bitfile_name` already reports `audio_lab.bit`, attach with
    ``download=False`` so the PLL keeps its lock. Anything else (no bit,
    `base.bit`, a different overlay) falls through to a fresh download.
    """
    from audio_lab_pynq import AudioLabOverlay  # type: ignore
    try:
        from pynq import PL  # type: ignore
        loaded_basename = os.path.basename(PL.bitfile_name or "")
    except Exception as exc:
        print("[gui] PL.bitfile_name lookup failed (%r); doing a full download."
              % (exc,))
        loaded_basename = ""
    if loaded_basename == "audio_lab.bit":
        print("[gui] audio_lab.bit already loaded; "
              "attaching with download=False to preserve rgb2dvi PLL lock.")
        try:
            overlay = AudioLabOverlay(download=False)
        except RuntimeError:
            print("[gui] download=False failed (stale PL record from another "
                  "process); falling back to download=True.")
            overlay = AudioLabOverlay()
    else:
        print("[gui] PL.bitfile_name=%r; loading audio_lab.bit (download=True)."
              % (loaded_basename or "<none>",))
        overlay = AudioLabOverlay()
    print("[gui] AudioLabOverlay loaded")
    return overlay


def _write_pmod_mode(overlay, mode_name):
    """Write the Pmod I2S2 MODE register; return True on success.

    Register map / mode table / IP discovery come from the shared
    `audio_lab_pynq.pmod_i2s2_status` module (imported lazily so the
    module-level CLI still works off-board).
    """
    if overlay is None or mode_name in (None, "keep"):
        return False
    from audio_lab_pynq.pmod_i2s2_status import (  # type: ignore
        MODE_INT, REG, find_status_mmio)
    if mode_name not in MODE_INT:
        print("[gui] pmod-mode %r unrecognised; skipping." % (mode_name,))
        return False
    mmio, _key = find_status_mmio(overlay=overlay)
    if mmio is None:
        print("[gui] pmod_status IP not found in overlay; "
              "--pmod-mode is a no-op on this bit.")
        return False
    mode_int = MODE_INT[mode_name]
    try:
        mmio.write(REG["MODE"], mode_int & 0x3)
        rb = mmio.read(REG["MODE"]) & 0x3
        print("[gui] pmod_mode set to %d (%s); readback=%d"
              % (mode_int, mode_name, rb))
        return True
    except Exception as exc:
        print("[gui] pmod_mode write failed: %r" % (exc,))
        return False


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
        # D74: SOURCE strip + live pedal POS bar must re-render on change.
        str(getattr(s, "wah_source", "manual")),
        bool(getattr(s, "wah_pedal_available", False)),
        int(getattr(s, "wah_position_pedal_u8", 0)),
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
    cfg_overrides["sw_active_low"] = bool(args.sw_active_low)

    overlay = None
    backend = None
    encoder = None
    pmod_mode_active = False
    if not args.dry_run:
        overlay = _bring_up_overlay()
        if args.pmod_mode != "keep":
            pmod_mode_active = _write_pmod_mode(overlay, args.pmod_mode)
        backend = _start_hdmi(overlay)
        encoder = _build_encoder(overlay, args.encoder_ip_name, cfg_overrides)
        encoder.configure(clear_on_read=True)

    try:
        from GUI.compact_v2.renderer import (  # type: ignore
            render_frame_800x480_compact_v2, make_pynq_static_render_cache)
    except Exception:
        from compact_v2.renderer import (  # type: ignore
            render_frame_800x480_compact_v2, make_pynq_static_render_cache)

    # D76 perf: a persistent render cache makes the renderer use the PYNQ
    # static fast path -- glow disabled, text/gradient memoised, and the WHOLE
    # frame returned from cache when the AppState signature is unchanged
    # (idle render drops from ~310 ms to ~0.5 ms on the board). Without a cache
    # the renderer built a throwaway one per call, so none of that persisted.
    render_cache = make_pynq_static_render_cache()

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
    applier.apply_appstate(state, force=True)
    print("[gui] startup state applied (AppState defaults)")
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

    # D74 FP02M expression pedal -> Wah POSITION (optional). The controller
    # stays unavailable (and the GUI stays MANUAL) if A0 cannot be read on
    # this overlay or no calibration exists -- nothing crashes.
    wah_pedal = None
    if args.wah_pedal:
        try:
            from audio_lab_pynq.fp02m import (  # type: ignore
                Fp02mA0Reader, Fp02mXadcMmioReader, Fp02mWahController,
                load_calibration, DEFAULT_CALIBRATION_PATH)
            cal_path = args.wah_calibration or DEFAULT_CALIBRATION_PATH
            cal = load_calibration(cal_path)
            # On the AudioLab overlay A0 is read from the PL xadc_wiz_a0 via
            # MMIO (the PL XADC is not an IIO channel). Fall back to the IIO
            # reader only when the overlay has no XADC Wizard.
            _has_xadc = overlay is not None and hasattr(overlay, "xadc_wiz_a0")
            if _has_xadc:
                reader = Fp02mXadcMmioReader.from_overlay(overlay)
            else:
                reader = Fp02mA0Reader()
            wah_pedal = Fp02mWahController(reader, cal)
            state.wah_pedal_available = bool(wah_pedal.available)
            print("[gui] FP02M pedal init: cal=%s cal_loaded=%s reader=%s "
                  "has_xadc=%s available=%s reason=%s"
                  % (cal_path, cal is not None,
                     getattr(reader, "read_path", "?"), _has_xadc,
                     wah_pedal.available, wah_pedal.unavailable_reason or "-"))
        except Exception as exc:
            print("[gui] FP02M pedal init failed: %r (staying MANUAL)" % (exc,))
            wah_pedal = None
            state.wah_pedal_available = False
    wah_pedal_period = 1.0 / max(1.0, float(args.wah_pedal_hz))
    last_wah_poll_t = 0.0
    last_wah_dbg_t = 0.0
    wah_writes = 0

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
    last_status_t = 0.0
    last_status_frames = 0
    last_status_polls = 0
    polls = 0

    # D76: the HDMI render (compose 800x480 + push the framebuffer) costs
    # ~100-200 ms on the PYNQ-Z2 ARM. Running it inline in the main loop made
    # it the bottleneck for EVERYTHING -- encoder apply and the FP02M pedal
    # write were starved to the render rate (~5-10 Hz), so knobs and the pedal
    # felt sluggish in both UI and audio. Move the render onto a daemon thread
    # that reads the shared AppState and repaints at --max-render-fps, while
    # the main loop polls the encoder, polls the pedal, and pushes audio GPIO
    # writes at the full poll rate (no longer render-bound). The render thread
    # only reads AppState and writes the HDMI framebuffer; every overlay /
    # GPIO write stays on the main thread, so there is no GPIO race.
    render_stats = {"frames": 0}

    def _render_loop():
        last_sig = None
        last_render_t = 0.0
        while not stop_flag["stop"]:
            now = time.time()
            sig = _render_signature(state)
            if sig != last_sig and (now - last_render_t) >= min_render_period:
                state.t = now - t0
                try:
                    frame = render_frame_800x480_compact_v2(
                        state, cache=render_cache)
                    if backend is not None:
                        backend.write_frame(frame, placement="manual",
                                            offset_x=0, offset_y=0)
                    last_sig = sig
                    last_render_t = now
                    render_stats["frames"] += 1
                except Exception as exc:
                    print("[gui] HDMI render/write failed: %r" % (exc,))
            # Short sleep so the thread is responsive to state changes without
            # busy-spinning; the actual draw cadence is governed by
            # min_render_period above.
            time.sleep(0.005)

    print("[gui] live_apply=%s apply_interval_ms=%d skip_rat=%s "
          "no_audio_apply=%s" % (args.live_apply, args.apply_interval_ms,
                                  args.skip_rat, args.no_audio_apply))
    print("[gui] Encoder0 rotate=effect select, button-down edge=current effect ON/OFF")
    print("[gui] Encoder1 rotate=knob select; hold+rotate=model select (OD/DIST/AMP/CAB)")
    print("[gui] Encoder2 rotate=value change; standalone button is no-op")
    print("[gui] RAT pedal model excluded from encoder control by default")

    render_thread = threading.Thread(target=_render_loop, name="hdmi-render",
                                     daemon=True)
    render_thread.start()

    try:
        while not stop_flag["stop"]:
            loop_t = time.time()
            polls += 1
            if encoder is not None:
                try:
                    n_events = controller.tick(encoder, timestamp=loop_t - t0)
                except Exception as exc:
                    print("[gui] encoder tick failed: %r" % (exc,))
                    n_events = 0
            else:
                n_events = 0
            if n_events:
                last_event_t = loop_t

            # D74 FP02M pedal step (non-blocking; main-thread overlay write,
            # so no GPIO race with the encoder applier). Only active when
            # SOURCE=PEDAL and the controller is available; a new byte marks
            # the loop active so the POS bar re-renders. Repeated read errors
            # auto-fall back to MANUAL without crashing audio / HDMI.
            if (wah_pedal is not None and wah_pedal.available
                    and str(getattr(state, "wah_source", "manual")) == "pedal"
                    and (loop_t - last_wah_poll_t) >= wah_pedal_period):
                last_wah_poll_t = loop_t
                u8 = wah_pedal.poll_once()
                if u8 is not None:
                    state.wah_position_pedal_u8 = int(u8)
                    if overlay is not None and not args.no_audio_apply:
                        try:
                            overlay.set_wah_settings(position_raw=int(u8))
                            wah_writes += 1
                        except Exception as exc:
                            print("[gui] wah pedal write failed: %r" % (exc,))
                    last_event_t = loop_t
                if not wah_pedal.available:
                    state.wah_pedal_available = False
                    state.wah_source = "manual"
                    print("[gui] FP02M pedal fell back to MANUAL: %s"
                          % wah_pedal.unavailable_reason)

            # D74 pedal debug line (~1/s) -- diagnose available / source /
            # reader / raw / u8 / writes / gpio position byte.
            if (args.wah_pedal_debug
                    and (loop_t - last_wah_dbg_t) >= 1.0):
                last_wah_dbg_t = loop_t
                _rp = getattr(getattr(wah_pedal, "reader", None),
                              "read_path", "none")
                _raw = None
                try:
                    if wah_pedal is not None and wah_pedal.available:
                        _raw = wah_pedal.reader.read_raw()
                except Exception:
                    _raw = None
                _gpio_pos = None
                try:
                    if overlay is not None and hasattr(overlay, "get_wah_settings"):
                        _gpio_pos = overlay.get_wah_settings().get("position_byte")
                except Exception:
                    _gpio_pos = None
                _has_x = overlay is not None and hasattr(overlay, "xadc_wiz_a0")
                print("[wah-pedal] available=%s source=%s selected=%s "
                      "reader=%s has_xadc=%s raw=%s u8=%s writes=%d "
                      "display=%s gpio_pos=%s"
                      % ((wah_pedal.available if wah_pedal else None),
                         getattr(state, "wah_source", None),
                         state.selected_effect, _rp, _has_x, _raw,
                         (wah_pedal.last_u8 if wah_pedal else None),
                         wah_writes,
                         (wah_pedal.display_pct() if wah_pedal else None),
                         _gpio_pos))

            # D76: the actual HDMI repaint happens on the background render
            # thread (see _render_loop); the main loop is now purely
            # encoder + pedal + audio-apply so neither is render-bound.

            if (loop_t - last_status_t) >= status_interval_s:
                r = sampler.sample()
                dt = (loop_t - last_status_t) if last_status_t > 0 \
                    else max(1e-3, loop_t - t0)
                frames = render_stats["frames"]
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
        # Stop the render thread first so it is not mid-write when the HDMI
        # backend is torn down.
        stop_flag["stop"] = True
        try:
            render_thread.join(timeout=1.0)
        except Exception:
            pass
        if pmod_mode_active and overlay is not None and args.pmod_mode != "mute":
            # Clean shutdown: mute the Pmod I2S2 DAC so SIGTERM / Ctrl+C does
            # not leave the external speakers driven. Skip when the user
            # explicitly started in mute already.
            _write_pmod_mode(overlay, "mute")
        if backend is not None:
            try:
                backend.stop()
                print("[gui] HDMI backend stopped")
            except Exception as exc:
                print("[gui] backend.stop() failed: %r" % (exc,))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
