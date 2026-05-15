#!/usr/bin/env python3
"""Phase 6C realtime notebook pedalboard control test (CLI driver).

The script replays the same Notebook ipywidgets-driven sequence used by
``notebooks/HdmiRealtimePedalboardOneCell.ipynb`` but without widgets,
so the integrated AudioLab overlay HDMI path can be exercised from a
PYNQ shell. Each step drives ``HdmiEffectStateMirror`` -- the same
mirror the Notebook drives -- so the test catches regressions in the
Notebook -> mirror -> overlay -> HDMI render flow.

No ``Overlay("base.bit")``, no ``run_pynq_hdmi()``, no second overlay,
no GPIO writes per frame, no continuous 30 fps render loop.
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
    return repo_root


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


def serious_vdma_error(errors):
    return bool(errors and (
        errors.get("dmainterr") or errors.get("dmaslverr") or
        errors.get("dmadecerr")))


def print_step(row):
    print("[{step:02d}] {operation}".format(**row))
    print("expected SELECTED FX: {}".format(row["expected"]))
    print("actual SELECTED FX  : {}".format(row["actual"]))
    print("pedal model         : {}".format(row.get("pedal_model_label")))
    print("amp model           : {}".format(row.get("amp_model_label")))
    print("cab model           : {}".format(row.get("cab_model_label")))
    print("dropdown            : {} ({})".format(
        row.get("dropdown_short_label"), row.get("dropdown_label")))
    print("category            : {}".format(row.get("selected_model_category")))
    print("result              : {}".format(row["result"]))
    if row.get("error"):
        print("error               : {}".format(row["error"]))
    print("render/compose/copy : {} / {} / {}".format(
        row.get("render_s"), row.get("compose_s"),
        row.get("framebuffer_copy_s")))
    print("VDMA error bits     : {}".format(row.get("vdma_errors")))
    print("resource (proc/sys) : {} / {}".format(
        row.get("proc_cpu_pct"), row.get("sys_cpu_pct")))
    print("proc RSS / Mem av   : {} / {}".format(
        row.get("proc_rss_kb"), row.get("mem_avail_kb")))
    print("")


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Phase 6C: replay the realtime pedalboard Notebook sequence "
            "through HdmiEffectStateMirror and validate the HDMI path."))
    parser.add_argument("--hold-seconds-per-step", type=float, default=1.0)
    parser.add_argument("--final-hold-seconds", type=float, default=10.0)
    parser.add_argument("--return-safe-bypass", action="store_true")
    parser.add_argument("--theme", default="pipboy-green")
    parser.add_argument("--variant", default="compact-v2",
                        choices=("compact-v1", "compact-v2"))
    parser.add_argument("--offset-x", type=int, default=0)
    parser.add_argument("--offset-y", type=int, default=0)
    args = parser.parse_args()

    repo_paths()

    print("[phase6c] importing AudioLabOverlay")
    t0 = time.time()
    from audio_lab_pynq import AudioLabOverlay
    overlay_import_s = time.time() - t0
    print("[phase6c] AudioLabOverlay imported in {:.3f} s".format(
        overlay_import_s))

    print("[phase6c] loading AudioLabOverlay() (single load)")
    t0 = time.time()
    overlay = AudioLabOverlay()
    overlay_load_s = time.time() - t0
    print("[phase6c] AudioLabOverlay() ready in {:.3f} s".format(
        overlay_load_s))

    pre_smoke = smoke(overlay)
    print(json.dumps({"smoke_pre_hdmi": pre_smoke}, indent=2, sort_keys=True))
    if not (pre_smoke["ADC HPF"] and pre_smoke["R19"] == "0x23" and
            pre_smoke["has axi_vdma_hdmi ip_dict"] and
            pre_smoke["has v_tc_hdmi ip_dict"] and
            pre_smoke["has rgb2dvi_hdmi in HWH"]):
        raise SystemExit("[phase6c] pre-HDMI smoke failed")

    from pynq_multi_fx_gui import (  # noqa: E402
        AppState, THEMES, make_pynq_static_render_cache, render_frame_800x480,
    )
    from audio_lab_pynq.hdmi_backend import AudioLabHdmiBackend  # noqa: E402
    from audio_lab_pynq.hdmi_effect_state_mirror import (  # noqa: E402
        HdmiEffectStateMirror,
    )

    theme = args.theme
    if theme is not None and str(theme) not in THEMES:
        print("[phase6c] theme {!r} unsupported; using renderer default".format(
            theme))
        theme = None

    state = AppState()
    cache = make_pynq_static_render_cache()
    backend = AudioLabHdmiBackend(overlay)
    mirror = HdmiEffectStateMirror(
        overlay=overlay,
        hdmi_backend=backend,
        app_state=state,
        renderer=render_frame_800x480,
        render_cache=cache,
        theme=theme,
        variant=args.variant,
        placement="manual",
        offset_x=int(args.offset_x),
        offset_y=int(args.offset_y),
    )

    report = {
        "phase": "6C-realtime-notebook-pedalboard",
        "started_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "variant": args.variant,
        "theme": args.theme,
        "placement": "manual",
        "offset_x": int(args.offset_x),
        "offset_y": int(args.offset_y),
        "overlay_import_s": overlay_import_s,
        "overlay_load_s": overlay_load_s,
        "smoke_pre_hdmi": pre_smoke,
        "steps": [],
        "failures": [],
        "skips": [],
    }

    steps = [
        ("safe_bypass", "SAFE BYPASS",
         lambda: mirror.safe_bypass(), {}, "SAFE"),
        ("clean_boost", "CLEAN BOOST",
         lambda: mirror.clean_boost(drive=30, level=60),
         {"pedal_model": "clean_boost"}, "PEDAL"),
        ("tube_screamer", "TUBE SCREAMER",
         lambda: mirror.tube_screamer(drive=45, tone=55, level=65),
         {"pedal_model": "tube_screamer"}, "PEDAL"),
        ("rat", "RAT",
         lambda: mirror.rat(drive=55, filter=45, level=60, mix=100),
         {"pedal_model": "rat"}, "PEDAL"),
        ("ds1", "DS-1",
         lambda: mirror.ds1(drive=50, tone=50, level=55),
         {"pedal_model": "ds1"}, "PEDAL"),
        ("big_muff", "BIG MUFF",
         lambda: mirror.big_muff(drive=60, tone=45, level=55),
         {"pedal_model": "big_muff"}, "PEDAL"),
        ("fuzz_face", "FUZZ FACE",
         lambda: mirror.fuzz_face(drive=70, tone=40, level=60),
         {"pedal_model": "fuzz_face"}, "PEDAL"),
        ("metal", "METAL",
         lambda: mirror.metal(drive=65, tone=55, level=55),
         {"pedal_model": "metal"}, "PEDAL"),
        ("jc_clean", "AMP SIM",
         lambda: mirror.jc_clean(gain=30, bass=55, mid=50, treble=60),
         {"amp_model": "jc_clean"}, "AMP"),
        ("clean_combo", "AMP SIM",
         lambda: mirror.clean_combo(gain=35, bass=55, mid=55, treble=55),
         {"amp_model": "clean_combo"}, "AMP"),
        ("british_crunch", "AMP SIM",
         lambda: mirror.british_crunch(gain=60, bass=50, mid=65, treble=55),
         {"amp_model": "british_crunch"}, "AMP"),
        ("high_gain_stack", "AMP SIM",
         lambda: mirror.high_gain_stack(gain=70, bass=55, mid=50, treble=60),
         {"amp_model": "high_gain_stack"}, "AMP"),
        ("cab 1x12", "CAB",
         lambda: mirror.cab(model="1x12", air=30),
         {"cab_model": "1x12"}, "CAB"),
        ("cab 2x12", "CAB",
         lambda: mirror.cab(model="2x12", air=40),
         {"cab_model": "2x12"}, "CAB"),
        ("cab 4x12", "CAB",
         lambda: mirror.cab(model="4x12", air=35),
         {"cab_model": "4x12"}, "CAB"),
        ("reverb", "REVERB",
         lambda: mirror.reverb(mix=25, decay=50, tone=65),
         {}, "REVERB"),
    ]

    for index, (operation, expected, callback, model_expected,
                expected_category) in enumerate(steps, 1):
        row = {
            "step": index,
            "operation": operation,
            "expected": expected,
            "expected_category": expected_category,
            "actual": None,
            "result": "FAIL",
        }
        try:
            callback()
            mirror.assert_selected_fx(expected)
            for key, expected_model in model_expected.items():
                actual_model = getattr(mirror, "current_" + key)
                if actual_model != expected_model:
                    raise AssertionError(
                        "{} mismatch: expected {!r}, actual {!r}".format(
                            key, expected_model, actual_model))
            actual = mirror.get_selected_fx_actual()
            info = dict(mirror.last_render_info or {})
            errors = info.get("hdmi_errors") or {}
            sample = info.get("resource_sample") or {}
            row.update({
                "actual": actual,
                "result": "PASS",
                "pedal_model": mirror.current_pedal_model,
                "amp_model": mirror.current_amp_model,
                "cab_model": mirror.current_cab_model,
                "pedal_model_label": mirror.current_pedal_label,
                "amp_model_label": mirror.current_amp_label,
                "cab_model_label": mirror.current_cab_label,
                "dropdown_label": getattr(
                    mirror.app_state, "dropdown_label", None),
                "dropdown_short_label": getattr(
                    mirror.app_state, "dropdown_short_label", None),
                "selected_model_category": getattr(
                    mirror.app_state, "selected_model_category", None),
                "render_s": info.get("render_s"),
                "backend_update_s": info.get("backend_update_s"),
                "compose_s": info.get("compose_s"),
                "framebuffer_copy_s": info.get("framebuffer_copy_s"),
                "total_update_s": info.get("total_update_s"),
                "vdma_errors": errors,
                "vtc_ctl": (info.get("hdmi_status") or {}).get("vtc_ctl"),
                "last_frame_write": info.get("last_frame_write"),
                "proc_cpu_pct": sample.get("proc_cpu_pct"),
                "sys_cpu_pct": sample.get("sys_cpu_pct"),
                "proc_rss_kb": sample.get("proc_rss_kb"),
                "mem_avail_kb": sample.get("mem_avail_kb"),
            })
            if expected_category and row["selected_model_category"] != expected_category:
                row["result"] = "FAIL"
                row["error"] = (
                    "selected_model_category mismatch: expected {!r}, "
                    "actual {!r}".format(expected_category,
                                          row["selected_model_category"]))
                report["failures"].append(row)
            elif serious_vdma_error(errors):
                row["result"] = "FAIL"
                row["error"] = "VDMA internal/slave/decode error bit asserted"
                report["failures"].append(row)
            if row["result"] == "PASS" and float(args.hold_seconds_per_step) > 0:
                time.sleep(float(args.hold_seconds_per_step))
        except Exception as exc:
            row["actual"] = mirror.get_selected_fx_actual()
            row["error"] = "{}: {}".format(type(exc).__name__, exc)
            report["failures"].append(row)
        report["steps"].append(row)
        print_step(row)

    if args.return_safe_bypass:
        print("[phase6c] returning to Safe Bypass")
        mirror.safe_bypass()

    if float(args.final_hold_seconds) > 0:
        print("[phase6c] final HDMI hold: {:.1f} seconds".format(
            float(args.final_hold_seconds)))
        time.sleep(float(args.final_hold_seconds))

    post_smoke = smoke(overlay)
    report["smoke_post_hdmi"] = post_smoke
    report["selected_fx_history"] = mirror.selected_fx_history
    report["resource_summary"] = mirror.resource_summary()

    print(json.dumps({"selected_fx_history": mirror.selected_fx_history},
                     indent=2, sort_keys=True, default=str))
    print(json.dumps({"resource_summary": report["resource_summary"]},
                     indent=2, sort_keys=True, default=str))
    print(json.dumps({"summary": report}, indent=2, sort_keys=True,
                     default=str))

    if report["failures"]:
        raise SystemExit("[phase6c] FAIL: {} failed step(s)".format(
            len(report["failures"])))
    print("[phase6c] OK")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        sys.exit(1)
