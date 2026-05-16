#!/usr/bin/env python3
"""Phase 4G 800x480 offset sweep on the integrated AudioLab HDMI path.

Loads ``AudioLabOverlay`` exactly once, renders the 800x480 compact-v2
logical GUI frame, and writes that frame to the fixed 1280x720 HDMI
framebuffer at a sequence of (offset_x, offset_y) placements. Each
placement is held for ``--seconds-per-offset`` so the user can take a
photo of the 5-inch LCD and visually compare which offset fits best.

The script does NOT load ``base.bit``, does NOT load a second overlay,
and does NOT call ``run_pynq_hdmi()``. The bitstream / HWH on disk are
not touched.
"""
from __future__ import print_function

import argparse
import json
import os
import sys
import time
import traceback


DEFAULT_OFFSETS = [
    (0, 0),
    (-80, 0),
    (-120, 0),
    (-160, 0),
    (-240, 0),
    (0, -40),
    (-120, -40),
    (-160, -40),
]


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


def parse_offsets(raw, fallback):
    if not raw:
        return list(fallback)
    out = []
    for part in str(raw).split(";"):
        part = part.strip()
        if not part:
            continue
        try:
            x_s, y_s = part.split(",")
            out.append((int(x_s), int(y_s)))
        except Exception:
            raise SystemExit(
                "[phase4g] bad --offsets entry {!r}; expected 'x,y;x,y;...'"
                .format(part))
    return out or list(fallback)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seconds-per-offset", type=int, default=10)
    parser.add_argument("--hold-final-seconds", type=int, default=30)
    parser.add_argument("--variant", default="compact-v2",
                        choices=("compact-v1", "compact-v2"))
    parser.add_argument("--offsets", default=None,
                        help="optional 'x,y;x,y' list to override the default sweep")
    args = parser.parse_args()

    offsets = parse_offsets(args.offsets, DEFAULT_OFFSETS)

    repo_paths()
    report = {
        "phase": "4G-cycle-offsets",
        "started_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "variant": args.variant,
        "seconds_per_offset": int(args.seconds_per_offset),
        "hold_final_seconds": int(args.hold_final_seconds),
        "offsets": [list(o) for o in offsets],
    }

    print("[phase4g] importing AudioLabOverlay")
    t0 = time.time()
    from audio_lab_pynq import AudioLabOverlay
    report["overlay_import_s"] = time.time() - t0
    print("[phase4g] AudioLabOverlay imported in {:.3f} s".format(
        report["overlay_import_s"]))

    print("[phase4g] loading AudioLabOverlay() (single load)")
    t0 = time.time()
    overlay = AudioLabOverlay()
    report["overlay_load_s"] = time.time() - t0
    print("[phase4g] AudioLabOverlay() ready in {:.3f} s".format(
        report["overlay_load_s"]))

    pre_smoke = smoke(overlay)
    report["smoke_pre_hdmi"] = pre_smoke
    print(json.dumps({"smoke_pre_hdmi": pre_smoke}, indent=2, sort_keys=True))
    if not (pre_smoke["ADC HPF"] and pre_smoke["R19"] == "0x23" and
            not pre_smoke["has axi_gpio_delay_line"] and
            pre_smoke["has legacy axi_gpio_delay"] and
            pre_smoke["has axi_vdma_hdmi ip_dict"] and
            pre_smoke["has v_tc_hdmi ip_dict"]):
        raise SystemExit("[phase4g] pre-HDMI smoke failed")

    from pynq_multi_fx_gui import (
        AppState, make_pynq_static_render_cache, render_frame_800x480,
    )
    from audio_lab_pynq.hdmi_backend import AudioLabHdmiBackend

    state = AppState()
    cache = make_pynq_static_render_cache()
    backend = AudioLabHdmiBackend(overlay)

    # Start with the first offset so VDMA / VTC come up exactly once.
    first_ox, first_oy = offsets[0]
    first_label = "p=manual off=({:+d},{:+d})".format(first_ox, first_oy)
    print("[phase4g] rendering first frame variant={} {}".format(
        args.variant, first_label))
    t0 = time.time()
    first_frame = render_frame_800x480(state, cache=cache,
                                       variant=args.variant,
                                       placement_label=first_label)
    first_render_s = time.time() - t0
    print("[phase4g] first frame render={:.3f}s shape={}".format(
        first_render_s, list(first_frame.shape)))

    t0 = time.time()
    backend.start(first_frame, placement="manual",
                  offset_x=first_ox, offset_y=first_oy)
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
        raise SystemExit("[phase4g] VDMA error bits set after start")

    runs = []
    for idx, (ox, oy) in enumerate(offsets):
        label = "p=manual off=({:+d},{:+d})".format(ox, oy)
        print("[phase4g] [{}/{}] offset=({:+d},{:+d}) hold={}s {}".format(
            idx + 1, len(offsets), ox, oy,
            int(args.seconds_per_offset), label))
        t0 = time.time()
        frame = render_frame_800x480(state, cache=cache,
                                     variant=args.variant,
                                     placement_label=label)
        render_s = time.time() - t0
        t0 = time.time()
        meta = backend.write_frame(frame, placement="manual",
                                   offset_x=ox, offset_y=oy)
        write_s = time.time() - t0
        errs = backend.errors()
        summary = {
            "index": idx,
            "offset_x": ox,
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
        print(json.dumps({"offset_run": summary}, indent=2, sort_keys=True))
        if (errs.get("dmainterr") or errs.get("dmaslverr")
                or errs.get("dmadecerr")):
            raise SystemExit(
                "[phase4g] VDMA error bits set at offset ({},{})".format(
                    ox, oy))
        if int(args.seconds_per_offset) > 0:
            time.sleep(int(args.seconds_per_offset))

    report["offset_runs"] = runs

    # Park on the last offset for an extended user-photo window.
    if int(args.hold_final_seconds) > 0:
        last_ox, last_oy = offsets[-1]
        print("[phase4g] holding final offset=({:+d},{:+d}) for {}s".format(
            last_ox, last_oy, int(args.hold_final_seconds)))
        time.sleep(int(args.hold_final_seconds))

    final_status = backend.status()
    final_errors = backend.errors()
    report["hdmi_status_final"] = final_status
    report["hdmi_errors_final"] = final_errors
    print(json.dumps({"hdmi_errors_final": final_errors}, indent=2,
                     sort_keys=True))

    print("[phase4g] applying Safe Bypass through existing overlay APIs")
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
    print("[phase4g] best offset selection is user visual confirmation pending")
    print(json.dumps({"summary": report}, indent=2, sort_keys=True,
                     default=str))
    print("[phase4g] OK")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
