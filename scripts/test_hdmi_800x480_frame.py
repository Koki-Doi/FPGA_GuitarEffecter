#!/usr/bin/env python3
"""Phase 4E 800x480 logical HDMI GUI check.

Loads ``AudioLabOverlay`` exactly once, renders
``render_frame_800x480(AppState())``, places that logical frame at the
center of the fixed 1280x720 HDMI framebuffer, and prints VDMA/VTC status.

This script does not load ``base.bit``, does not load a second overlay,
and does not call ``run_pynq_hdmi()``.
"""
from __future__ import print_function

import argparse
import json
import os
import sys
import time
import traceback


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
        "has axi_gpio_noise_suppressor": hasattr(overlay, "axi_gpio_noise_suppressor"),
        "has axi_gpio_compressor": hasattr(overlay, "axi_gpio_compressor"),
        "has axi_vdma_hdmi ip_dict": "axi_vdma_hdmi" in ip_keys,
        "has v_tc_hdmi ip_dict": "v_tc_hdmi" in ip_keys,
        "has rgb2dvi_hdmi in HWH": hwh_contains("rgb2dvi_hdmi"),
        "has v_axi4s_vid_out_hdmi in HWH": hwh_contains("v_axi4s_vid_out_hdmi"),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--hold-seconds", type=int, default=60)
    parser.add_argument("--placement", default="center", choices=("center",))
    args = parser.parse_args()

    repo_paths()
    report = {
        "phase": "4E-800x480-logical-gui",
        "started_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "placement": args.placement,
        "hold_seconds": int(args.hold_seconds),
    }

    print("[phase4e] importing AudioLabOverlay")
    t0 = time.time()
    from audio_lab_pynq import AudioLabOverlay
    overlay_import_s = time.time() - t0
    print("[phase4e] AudioLabOverlay imported in {:.3f} s".format(overlay_import_s))

    print("[phase4e] loading AudioLabOverlay() (single load)")
    t0 = time.time()
    overlay = AudioLabOverlay()
    overlay_load_s = time.time() - t0
    print("[phase4e] AudioLabOverlay() ready in {:.3f} s".format(overlay_load_s))

    pre_smoke = smoke(overlay)
    report["overlay_import_s"] = overlay_import_s
    report["overlay_load_s"] = overlay_load_s
    report["smoke_pre_hdmi"] = pre_smoke
    print(json.dumps({"smoke_pre_hdmi": pre_smoke}, indent=2, sort_keys=True))
    if not (pre_smoke["ADC HPF"] and pre_smoke["R19"] == "0x23" and
            not pre_smoke["has axi_gpio_delay_line"] and
            pre_smoke["has legacy axi_gpio_delay"] and
            pre_smoke["has axi_vdma_hdmi ip_dict"] and
            pre_smoke["has v_tc_hdmi ip_dict"] and
            pre_smoke["has rgb2dvi_hdmi in HWH"] and
            pre_smoke["has v_axi4s_vid_out_hdmi in HWH"]):
        raise SystemExit("[phase4e] pre-HDMI smoke failed")

    from pynq_multi_fx_gui import (
        AppState, make_pynq_static_render_cache, render_frame_800x480,
    )
    from audio_lab_pynq.hdmi_backend import AudioLabHdmiBackend

    state = AppState()
    cache = make_pynq_static_render_cache()
    print("[phase4e] rendering 800x480 logical GUI frame")
    t0 = time.time()
    frame = render_frame_800x480(state, cache=cache)
    render_s = time.time() - t0
    print("[phase4e] frame shape={} dtype={} render={:.3f}s".format(
        list(frame.shape), frame.dtype, render_s))
    if list(frame.shape) != [480, 800, 3] or str(frame.dtype) != "uint8":
        raise SystemExit("[phase4e] renderer returned unexpected frame")

    backend = AudioLabHdmiBackend(overlay)
    print("[phase4e] starting HDMI back end with centered logical frame")
    t0 = time.time()
    backend.start(frame, placement=args.placement)
    backend_start_s = time.time() - t0
    time.sleep(0.1)

    status = backend.status()
    errors = backend.errors()
    report["render_s"] = render_s
    report["backend_start_s"] = backend_start_s
    report["hdmi_status"] = status
    report["hdmi_errors"] = errors
    print(json.dumps({"hdmi_status": status, "hdmi_errors": errors,
                      "backend_start_s": backend_start_s},
                     indent=2, sort_keys=True))
    if errors.get("dmainterr") or errors.get("dmaslverr") or errors.get("dmadecerr"):
        raise SystemExit("[phase4e] VDMA error bits set")

    if int(args.hold_seconds) > 0:
        print("[phase4e] holding HDMI scanout for {} seconds".format(
            int(args.hold_seconds)))
        time.sleep(int(args.hold_seconds))

    print("[phase4e] applying Safe Bypass through existing overlay APIs")
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
    print("[phase4e] physical 5-inch LCD readability is user visual confirmation pending")
    print(json.dumps({"summary": report}, indent=2, sort_keys=True))
    print("[phase4e] OK")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
