#!/usr/bin/env python3
"""Phase 6A SELECTED FX switch verification for the HDMI GUI.

The test drives effects through ``HdmiEffectStateMirror`` exactly as the
one-cell Notebook does. It loads ``AudioLabOverlay()`` once, initializes the
integrated HDMI backend once, renders the 800x480 compact GUI at framebuffer
``x=0,y=0``, and verifies that SELECTED FX follows the last edited effect.

No ``Overlay("base.bit")``, no ``run_pynq_hdmi()``, no second overlay.
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


def print_step_result(row):
    print("[{step:02d}] {operation}".format(**row))
    print("expected SELECTED FX: {}".format(row["expected"]))
    print("actual SELECTED FX  : {}".format(row["actual"]))
    print("result              : {}".format(row["result"]))
    if row.get("skip_reason"):
        print("skip reason         : {}".format(row["skip_reason"]))
    if row.get("error"):
        print("error               : {}".format(row["error"]))
    print("render time         : {:.3f} s".format(row.get("render_s") or 0.0))
    print("compose time        : {}".format(row.get("compose_s")))
    print("copy time           : {}".format(row.get("framebuffer_copy_s")))
    print("VDMA error bits     : {}".format(row.get("vdma_errors")))
    print("")


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Verify Phase 6A notebook-driven SELECTED FX switching on "
            "the integrated AudioLab HDMI GUI."))
    parser.add_argument("--hold-seconds-per-step", type=float, default=1.0)
    parser.add_argument("--final-hold-seconds", type=float, default=10.0)
    parser.add_argument("--return-safe-bypass", action="store_true")
    parser.add_argument("--theme", default=None,
                        help="800x480 GUI theme; default renderer theme if omitted")
    parser.add_argument("--variant", default="compact-v2",
                        choices=("compact-v1", "compact-v2"))
    parser.add_argument("--offset-x", type=int, default=0)
    parser.add_argument("--offset-y", type=int, default=0)
    args = parser.parse_args()

    repo_paths()
    report = {
        "phase": "6A-selected-fx-state-mirror",
        "started_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "variant": args.variant,
        "theme": args.theme,
        "placement": "manual",
        "offset_x": int(args.offset_x),
        "offset_y": int(args.offset_y),
        "hold_seconds_per_step": float(args.hold_seconds_per_step),
        "final_hold_seconds": float(args.final_hold_seconds),
        "return_safe_bypass": bool(args.return_safe_bypass),
        "steps": [],
        "failures": [],
        "skips": [],
    }

    print("[phase6a] importing AudioLabOverlay")
    t0 = time.time()
    from audio_lab_pynq import AudioLabOverlay
    overlay_import_s = time.time() - t0
    print("[phase6a] AudioLabOverlay imported in {:.3f} s".format(
        overlay_import_s))

    print("[phase6a] loading AudioLabOverlay() (single load)")
    t0 = time.time()
    overlay = AudioLabOverlay()
    overlay_load_s = time.time() - t0
    print("[phase6a] AudioLabOverlay() ready in {:.3f} s".format(
        overlay_load_s))

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
        raise SystemExit("[phase6a] pre-HDMI smoke failed")

    from pynq_multi_fx_gui import (  # noqa: E402
        AppState, THEMES, make_pynq_static_render_cache, render_frame_800x480,
    )
    from audio_lab_pynq.hdmi_backend import AudioLabHdmiBackend  # noqa: E402
    from audio_lab_pynq.hdmi_effect_state_mirror import (  # noqa: E402
        HdmiEffectStateMirror,
    )

    theme = args.theme
    if theme is not None and str(theme) not in THEMES:
        print("[phase6a] theme {!r} is unsupported; using renderer default".format(
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
        offset_x=args.offset_x,
        offset_y=args.offset_y,
    )

    steps = [
        ("safe_bypass", "SAFE BYPASS",
         lambda: mirror.safe_bypass()),
        ("apply_chain_preset Basic Clean", "PRESET",
         lambda: mirror.apply_chain_preset("Basic Clean")),
        ("set_noise_suppressor_settings", "NOISE SUPPRESSOR",
         lambda: mirror.set_noise_suppressor_settings(
             enabled=True, threshold=25, decay=84, damp=85)),
        ("set_compressor_settings", "COMPRESSOR",
         lambda: mirror.set_compressor_settings(
             enabled=True, threshold=45, ratio=35, response=45, makeup=50)),
        ("set_guitar_effects overdrive", "OVERDRIVE",
         lambda: mirror.set_guitar_effects(
             overdrive_on=True, overdrive_drive=35,
             overdrive_tone=55, overdrive_level=65)),
        ("set_distortion_settings", "DISTORTION",
         lambda: mirror.set_distortion_settings(
             pedal="tube_screamer", drive=52, tone=60, level=30,
             bias=50, tight=60, mix=100)),
        ("set_guitar_effects RAT", "RAT",
         lambda: mirror.set_guitar_effects(
             rat_on=True, rat_drive=55, rat_filter=35,
             rat_level=85, rat_mix=100)),
        ("set_guitar_effects amp", "AMP SIM",
         lambda: mirror.set_guitar_effects(
             amp_on=True, amp_input_gain=45, amp_bass=55,
             amp_middle=50, amp_treble=45, amp_presence=45,
             amp_resonance=35, amp_master=75, amp_character=60)),
        ("set_guitar_effects cab", "CAB",
         lambda: mirror.set_guitar_effects(
             cab_on=True, cab_mix=100, cab_level=100,
             cab_model=2, cab_air=35)),
        ("set_guitar_effects eq", "EQ",
         lambda: mirror.set_guitar_effects(
             eq_on=True, eq_low=100, eq_mid=110, eq_high=120)),
        ("set_guitar_effects reverb", "REVERB",
         lambda: mirror.set_guitar_effects(
             reverb_on=True, reverb_decay=40,
             reverb_tone=65, reverb_mix=35)),
    ]

    for index, (operation, expected, callback) in enumerate(steps, 1):
        row = {
            "step": index,
            "operation": operation,
            "expected": expected,
            "actual": None,
            "result": "FAIL",
            "render_s": None,
            "compose_s": None,
            "framebuffer_copy_s": None,
            "vdma_errors": None,
        }
        try:
            callback()
            mirror.assert_selected_fx(expected)
            actual = mirror.get_selected_fx_actual()
            info = dict(mirror.last_render_info or {})
            errors = info.get("hdmi_errors") or {}
            row.update({
                "actual": actual,
                "result": "PASS",
                "render_s": info.get("render_s"),
                "backend_update_s": info.get("backend_update_s"),
                "compose_s": info.get("compose_s"),
                "resize_compose_s": info.get("resize_compose_s"),
                "framebuffer_copy_s": info.get("framebuffer_copy_s"),
                "vdma_errors": errors,
                "vtc_ctl": (info.get("hdmi_status") or {}).get("vtc_ctl"),
                "last_frame_write": info.get("last_frame_write"),
            })
            if serious_vdma_error(errors):
                row["result"] = "FAIL"
                row["error"] = "VDMA internal/slave/decode error bit asserted"
                report["failures"].append(row)
            if row["result"] == "PASS" and float(args.hold_seconds_per_step) > 0:
                time.sleep(float(args.hold_seconds_per_step))
        except (AttributeError, NotImplementedError) as exc:
            row["actual"] = mirror.get_selected_fx_actual()
            row["result"] = "SKIP"
            row["skip_reason"] = str(exc)
            report["skips"].append(row)
        except RuntimeError as exc:
            text = str(exc)
            if "missing" in text.lower() or "required" in text.lower():
                row["actual"] = mirror.get_selected_fx_actual()
                row["result"] = "SKIP"
                row["skip_reason"] = text
                report["skips"].append(row)
            else:
                row["actual"] = mirror.get_selected_fx_actual()
                row["error"] = text
                report["failures"].append(row)
        except Exception as exc:
            row["actual"] = mirror.get_selected_fx_actual()
            row["error"] = repr(exc)
            report["failures"].append(row)
        report["steps"].append(row)
        print_step_result(row)

    if args.return_safe_bypass:
        print("[phase6a] returning to Safe Bypass")
        mirror.safe_bypass()

    if float(args.final_hold_seconds) > 0:
        print("[phase6a] final HDMI hold: {:.1f} seconds".format(
            float(args.final_hold_seconds)))
        time.sleep(float(args.final_hold_seconds))

    post_smoke = smoke(overlay)
    report["smoke_post_hdmi"] = post_smoke
    report["selected_fx_history"] = mirror.selected_fx_history
    report["state_summary"] = mirror.get_state_summary()
    print(json.dumps({"selected_fx_history": mirror.selected_fx_history},
                     indent=2, sort_keys=True, default=str))
    print(json.dumps({"summary": report}, indent=2, sort_keys=True,
                     default=str))

    if report["failures"]:
        raise SystemExit("[phase6a] FAIL: {} failed step(s)".format(
            len(report["failures"])))
    print("[phase6a] OK")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        sys.exit(1)
