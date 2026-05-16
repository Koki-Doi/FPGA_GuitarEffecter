#!/usr/bin/env python3
"""Phase 4H 800x480 vertical-only offset sweep (ARCHIVED DIAGNOSTIC).

Status: ARCHIVED / FAILED DIRECTION.

This script was added in Phase 4H to chase a reported top-clip on the
5-inch HDMI LCD by walking ``offset_y`` in small positive steps with
``offset_x = 0`` fixed. The hypothesis was that the visible viewport
needed a downward shift to make the top of the compact-v2 layout
visible. On the real panel that direction (combined with the Phase 4H
chassis push-down) produced a layout shifted down and to the right
instead of fixing the top-clip, so Phase 4I rolled the renderer back
to the Phase 4G compact-v2 baseline and stopped recommending positive
``offset_y`` as a corrective tool.

The script is kept as a diagnostic record so the failed direction can
be reproduced from photos if needed, but the recommended runtime
placement on the 5-inch LCD is ``offset_x=0, offset_y=0``. Future
calibration work should change UI density / size or the logical canvas
size first (e.g. 760x440 logical UI at offset 0,0), not chase the
top-clip with a vertical viewport offset.

Loads ``AudioLabOverlay()`` exactly once, does not load ``base.bit``,
does not load a second overlay, and does not call ``run_pynq_hdmi()``.
"""
from __future__ import print_function

import argparse
import json
import os
import sys
import time
import traceback


DEFAULT_OFFSETS_Y = [0, 10, 20, 30, 40, 50]


def repo_paths():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(script_dir, ".."))
    for path in (repo_root, os.path.join(repo_root, "GUI"),
                 "/home/xilinx/Audio-Lab-PYNQ",
                 "/home/xilinx/Audio-Lab-PYNQ/GUI"):
        if path not in sys.path:
            sys.path.insert(0, path)


def hwh_contains(instance_name):
    candidates = [
        os.path.join(os.path.dirname(__file__), "..",
                     "audio_lab_pynq", "bitstreams", "audio_lab.hwh"),
        os.path.join(os.path.dirname(os.path.dirname(__file__)),
                     "audio_lab_pynq", "bitstreams", "audio_lab.hwh"),
        "/usr/local/lib/python3.6/dist-packages/audio_lab_pynq/bitstreams/audio_lab.hwh",
    ]
    for path in candidates:
        try:
            with open(os.path.abspath(path), "r") as fp:
                return instance_name in fp.read()
        except IOError:
            continue
    return False


def smoke(overlay):
    ip_keys = set(getattr(overlay, "ip_dict", {}).keys())
    return {
        "ADC HPF": bool(overlay.codec.get_adc_hpf_state()),
        "R19": "0x{:02x}".format(int(overlay.codec.R19_ADC_CONTROL[0]) & 0xFF),
        "has axi_gpio_delay_line": hasattr(overlay, "axi_gpio_delay_line"),
        "has legacy axi_gpio_delay": hasattr(overlay, "axi_gpio_delay"),
        "has axi_vdma_hdmi ip_dict": "axi_vdma_hdmi" in ip_keys,
        "has v_tc_hdmi ip_dict": "v_tc_hdmi" in ip_keys,
        "has rgb2dvi_hdmi in HWH": hwh_contains("rgb2dvi_hdmi"),
        "has v_axi4s_vid_out_hdmi in HWH": hwh_contains("v_axi4s_vid_out_hdmi"),
    }


def parse_offsets_y(raw, fallback):
    if not raw:
        return list(fallback)
    out = []
    for part in str(raw).split(","):
        part = part.strip()
        if not part:
            continue
        try:
            out.append(int(part))
        except ValueError:
            raise SystemExit(
                "[phase4h] bad --offsets-y entry {!r}; expected int".format(part))
    return out or list(fallback)


def main():
    parser = argparse.ArgumentParser(
        description=(
            "ARCHIVED Phase 4H diagnostic. Positive offset_y direction "
            "was rolled back in Phase 4I; the recommended runtime "
            "placement on the 5-inch LCD is offset_x=0 offset_y=0. This "
            "sweep is kept only to reproduce the failed direction from "
            "photos."),
        epilog=(
            "Phase 4I rolled back the Phase 4H push-down + 18 px left "
            "margin; do not use this sweep to pick a runtime offset_y."),
    )
    parser.add_argument("--seconds-per-offset", type=int, default=10)
    parser.add_argument("--hold-final-seconds", type=int, default=30)
    parser.add_argument("--variant", default="compact-v2",
                        choices=("compact-v1", "compact-v2"))
    parser.add_argument("--offsets-y", default=None,
                        help="comma-separated list of offset_y values to override "
                             "the default sweep (e.g. '0,10,20,30,40,50')")
    parser.add_argument("--offset-x", type=int, default=0,
                        help="constant horizontal offset (default 0; phase 4H "
                             "deliberately keeps the horizontal direction fixed)")
    args = parser.parse_args()
    print("[phase4h] NOTE: this script is an ARCHIVED Phase 4H diagnostic; "
          "Phase 4I rolled back the positive offset_y direction. "
          "Recommended runtime placement remains offset_x=0 offset_y=0.")

    offsets_y = parse_offsets_y(args.offsets_y, DEFAULT_OFFSETS_Y)
    if int(args.offset_x) != 0:
        print("[phase4h] WARNING: --offset-x is non-zero ({}); phase 4H "
              "diagnoses the layout with offset_x fixed at 0".format(args.offset_x))

    repo_paths()
    report = {
        "phase": "4H-vertical-offsets",
        "started_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "variant": args.variant,
        "offset_x": int(args.offset_x),
        "offsets_y": list(offsets_y),
        "seconds_per_offset": int(args.seconds_per_offset),
        "hold_final_seconds": int(args.hold_final_seconds),
    }

    print("[phase4h] importing AudioLabOverlay")
    t0 = time.time()
    from audio_lab_pynq import AudioLabOverlay
    report["overlay_import_s"] = time.time() - t0
    print("[phase4h] AudioLabOverlay imported in {:.3f} s".format(
        report["overlay_import_s"]))

    print("[phase4h] loading AudioLabOverlay() (single load)")
    t0 = time.time()
    overlay = AudioLabOverlay()
    report["overlay_load_s"] = time.time() - t0
    print("[phase4h] AudioLabOverlay() ready in {:.3f} s".format(
        report["overlay_load_s"]))

    pre_smoke = smoke(overlay)
    report["smoke_pre_hdmi"] = pre_smoke
    print(json.dumps({"smoke_pre_hdmi": pre_smoke}, indent=2, sort_keys=True))
    if not (pre_smoke["ADC HPF"] and pre_smoke["R19"] == "0x23" and
            not pre_smoke["has axi_gpio_delay_line"] and
            pre_smoke["has legacy axi_gpio_delay"] and
            pre_smoke["has axi_vdma_hdmi ip_dict"] and
            pre_smoke["has v_tc_hdmi ip_dict"]):
        raise SystemExit("[phase4h] pre-HDMI smoke failed")

    from pynq_multi_fx_gui import (
        AppState, make_pynq_static_render_cache, render_frame_800x480,
    )
    from audio_lab_pynq.hdmi_backend import AudioLabHdmiBackend

    state = AppState()
    cache = make_pynq_static_render_cache()
    backend = AudioLabHdmiBackend(overlay)

    first_oy = offsets_y[0]
    first_label = "p=manual off=({:+d},{:+d})".format(args.offset_x, first_oy)
    print("[phase4h] rendering first frame variant={} {}".format(
        args.variant, first_label))
    t0 = time.time()
    first_frame = render_frame_800x480(state, cache=cache,
                                       variant=args.variant,
                                       placement_label=first_label)
    first_render_s = time.time() - t0
    print("[phase4h] first render={:.3f}s shape={}".format(
        first_render_s, list(first_frame.shape)))

    t0 = time.time()
    backend.start(first_frame, placement="manual",
                  offset_x=args.offset_x, offset_y=first_oy)
    report["backend_start_s"] = time.time() - t0
    time.sleep(0.1)
    start_errors = backend.errors()
    start_status = backend.status()
    report["hdmi_errors_after_start"] = start_errors
    report["hdmi_status_after_start"] = start_status
    print(json.dumps({"hdmi_errors_after_start": start_errors,
                      "backend_start_s": report["backend_start_s"]},
                     indent=2, sort_keys=True))
    if (start_errors.get("dmainterr") or start_errors.get("dmaslverr")
            or start_errors.get("dmadecerr")):
        raise SystemExit("[phase4h] VDMA error bits set after start")

    runs = []
    for idx, oy in enumerate(offsets_y):
        label = "p=manual off=({:+d},{:+d})".format(args.offset_x, oy)
        print("[phase4h] [{}/{}] offset_y={:+d} (offset_x={:+d}) hold={}s {}".format(
            idx + 1, len(offsets_y), oy, args.offset_x,
            int(args.seconds_per_offset), label))
        t0 = time.time()
        frame = render_frame_800x480(state, cache=cache,
                                     variant=args.variant,
                                     placement_label=label)
        render_s = time.time() - t0
        t0 = time.time()
        meta = backend.write_frame(frame, placement="manual",
                                   offset_x=args.offset_x, offset_y=oy)
        write_s = time.time() - t0
        errs = backend.errors()
        summary = {
            "index": idx,
            "offset_x": args.offset_x,
            "offset_y": oy,
            "label": label,
            "render_s": render_s,
            "write_s": write_s,
            "compose_s": meta.get("compose_s"),
            "resize_compose_s": meta.get("resize_compose_s"),
            "framebuffer_copy_s": meta.get("framebuffer_copy_s"),
            "requested_destination_region":
                meta.get("requested_destination_region"),
            "source_visible_region": meta.get("source_visible_region"),
            "framebuffer_copied_region":
                meta.get("framebuffer_copied_region"),
            "negative_offset": meta.get("negative_offset"),
            "clipped": meta.get("clipped"),
            "fully_offscreen": meta.get("fully_offscreen"),
            "vdma_errors": errs,
        }
        runs.append(summary)
        print(json.dumps({"vertical_offset_run": summary}, indent=2,
                         sort_keys=True))
        if (errs.get("dmainterr") or errs.get("dmaslverr")
                or errs.get("dmadecerr")):
            raise SystemExit(
                "[phase4h] VDMA error bits set at offset_y={}".format(oy))
        if int(args.seconds_per_offset) > 0:
            time.sleep(int(args.seconds_per_offset))

    report["offset_runs"] = runs

    if int(args.hold_final_seconds) > 0:
        last_oy = offsets_y[-1]
        print("[phase4h] holding final offset_y={:+d} for {}s".format(
            last_oy, int(args.hold_final_seconds)))
        time.sleep(int(args.hold_final_seconds))

    final_status = backend.status()
    final_errors = backend.errors()
    report["hdmi_status_final"] = final_status
    report["hdmi_errors_final"] = final_errors
    print(json.dumps({"hdmi_errors_final": final_errors}, indent=2,
                     sort_keys=True))

    print("[phase4h] applying Safe Bypass through existing overlay APIs")
    overlay.clear_distortion_pedals()
    overlay.set_noise_suppressor_settings(enabled=False)
    overlay.set_compressor_settings(enabled=False)
    overlay.set_guitar_effects(noise_gate_on=False, overdrive_on=False,
                               distortion_on=False, rat_on=False,
                               amp_on=False, cab_on=False, eq_on=False,
                               reverb_on=False)

    post_smoke = smoke(overlay)
    report["smoke_post_hdmi"] = post_smoke
    print(json.dumps({"smoke_post_hdmi": post_smoke}, indent=2, sort_keys=True))
    print("[phase4h] best offset_y selection is user visual confirmation pending")
    print(json.dumps({"summary": report}, indent=2, sort_keys=True,
                     default=str))
    print("[phase4h] OK")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
