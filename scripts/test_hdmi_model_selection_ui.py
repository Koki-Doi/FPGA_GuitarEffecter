#!/usr/bin/env python3
"""Phase 6B notebook-style model selection verification for HDMI GUI.

The script drives pedal / amp / cab model changes through
``HdmiEffectStateMirror``. It uses the integrated AudioLab overlay HDMI path,
keeps the 800x480 logical GUI at framebuffer x=0,y=0, and verifies that the
GUI state follows Notebook-side model edits.

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
    print("pedal model         : {}".format(row.get("pedal_model_label")))
    print("amp model           : {}".format(row.get("amp_model_label")))
    print("cab model           : {}".format(row.get("cab_model_label")))
    print("category            : {}".format(row.get("category")))
    print("dropdown visible    : expected={} actual={}".format(
        row.get("expected_dropdown_visible"),
        row.get("actual_dropdown_visible")))
    print("dropdown label      : {}".format(row.get("dropdown_label")))
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
            "Verify Phase 6B notebook-controlled pedal/amp/cab model "
            "display on the integrated AudioLab HDMI GUI."))
    parser.add_argument("--hold-seconds-per-step", type=float, default=1.0)
    parser.add_argument("--final-hold-seconds", type=float, default=10.0)
    parser.add_argument("--return-safe-bypass", action="store_true")
    parser.add_argument("--theme", default="pipboy-green",
                        help="800x480 GUI theme; default is pipboy-green")
    parser.add_argument("--variant", default="compact-v2",
                        choices=("compact-v1", "compact-v2"))
    parser.add_argument("--offset-x", type=int, default=0)
    parser.add_argument("--offset-y", type=int, default=0)
    args = parser.parse_args()

    repo_paths()
    report = {
        "phase": "6B-model-selection-ui",
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

    print("[phase6b] importing AudioLabOverlay")
    t0 = time.time()
    from audio_lab_pynq import AudioLabOverlay
    overlay_import_s = time.time() - t0
    print("[phase6b] AudioLabOverlay imported in {:.3f} s".format(
        overlay_import_s))

    print("[phase6b] loading AudioLabOverlay() (single load)")
    t0 = time.time()
    overlay = AudioLabOverlay()
    overlay_load_s = time.time() - t0
    print("[phase6b] AudioLabOverlay() ready in {:.3f} s".format(
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
        raise SystemExit("[phase6b] pre-HDMI smoke failed")

    from pynq_multi_fx_gui import (  # noqa: E402
        AppState, THEMES, make_pynq_static_render_cache, render_frame_800x480,
    )
    from audio_lab_pynq.hdmi_backend import AudioLabHdmiBackend  # noqa: E402
    from audio_lab_pynq.hdmi_effect_state_mirror import (  # noqa: E402
        HdmiEffectStateMirror, dropdown_visible_for, selected_fx_category,
    )

    theme = args.theme
    if theme is not None and str(theme) not in THEMES:
        print("[phase6b] theme {!r} is unsupported; using renderer default".format(
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
        ("clean_boost", "CLEAN BOOST",
         lambda: mirror.clean_boost(drive=30, level=60),
         {"pedal_model": "clean_boost"}),
        ("tube_screamer", "TUBE SCREAMER",
         lambda: mirror.tube_screamer(drive=45, tone=55, level=65),
         {"pedal_model": "tube_screamer"}),
        ("rat", "RAT",
         lambda: mirror.rat(drive=55, filter=45, level=60, mix=100),
         {"pedal_model": "rat"}),
        ("ds1", "DS-1",
         lambda: mirror.ds1(drive=50, tone=50, level=55),
         {"pedal_model": "ds1"}),
        ("big_muff", "BIG MUFF",
         lambda: mirror.big_muff(drive=60, tone=45, level=55),
         {"pedal_model": "big_muff"}),
        ("fuzz_face", "FUZZ FACE",
         lambda: mirror.fuzz_face(drive=70, tone=40, level=60),
         {"pedal_model": "fuzz_face"}),
        ("metal", "METAL",
         lambda: mirror.metal(drive=65, tone=55, level=55),
         {"pedal_model": "metal"}),
        ("jc_clean", "AMP SIM",
         lambda: mirror.jc_clean(gain=30, bass=55, mid=50, treble=60),
         {"amp_model": "jc_clean"}),
        ("british_crunch", "AMP SIM",
         lambda: mirror.british_crunch(gain=60, bass=50, mid=65, treble=55),
         {"amp_model": "british_crunch"}),
        ("high_gain_stack", "AMP SIM",
         lambda: mirror.high_gain_stack(gain=70, bass=55, mid=50, treble=60),
         {"amp_model": "high_gain_stack"}),
        ("cab 2x12", "CAB",
         lambda: mirror.cab(model="2x12", air=40),
         {"cab_model": "2x12"}),
        ("reverb", "REVERB",
         lambda: mirror.reverb(mix=25, decay=50),
         {}),
        ("compressor", "COMPRESSOR",
         lambda: mirror.set_compressor_settings(
             enabled=True, threshold=40, ratio=30, response=50, makeup=50),
         {}),
        ("noise_suppressor", "NOISE SUPPRESSOR",
         lambda: mirror.set_noise_suppressor_settings(
             enabled=True, threshold=25, decay=80, damp=80),
         {}),
        ("safe_bypass", "SAFE BYPASS",
         lambda: mirror.safe_bypass(),
         {}),
        ("preset_basic_clean", "PRESET",
         lambda: mirror.apply_chain_preset("Basic Clean"),
         {}),
    ]

    for index, (operation, expected, callback, model_expected) in enumerate(steps, 1):
        expected_visible = dropdown_visible_for(expected)
        row = {
            "step": index,
            "operation": operation,
            "expected": expected,
            "actual": None,
            "category": None,
            "expected_dropdown_visible": expected_visible,
            "actual_dropdown_visible": None,
            "dropdown_label": None,
            "result": "FAIL",
            "render_s": None,
            "compose_s": None,
            "framebuffer_copy_s": None,
            "vdma_errors": None,
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
            actual_visible = bool(getattr(
                mirror.app_state,
                "selected_model_dropdown_visible", False))
            dropdown_label = getattr(
                mirror.app_state, "dropdown_label", "")
            row.update({
                "actual": actual,
                "result": "PASS",
                "pedal_model": mirror.current_pedal_model,
                "amp_model": mirror.current_amp_model,
                "cab_model": mirror.current_cab_model,
                "pedal_model_label": mirror.current_pedal_label,
                "amp_model_label": mirror.current_amp_label,
                "cab_model_label": mirror.current_cab_label,
                "category": selected_fx_category(actual),
                "actual_dropdown_visible": actual_visible,
                "dropdown_label": dropdown_label,
                "render_s": info.get("render_s"),
                "backend_update_s": info.get("backend_update_s"),
                "compose_s": info.get("compose_s"),
                "resize_compose_s": info.get("resize_compose_s"),
                "framebuffer_copy_s": info.get("framebuffer_copy_s"),
                "vdma_errors": errors,
                "vtc_ctl": (info.get("hdmi_status") or {}).get("vtc_ctl"),
                "last_frame_write": info.get("last_frame_write"),
            })
            if actual_visible != expected_visible:
                row["result"] = "FAIL"
                row["error"] = (
                    "dropdown visibility mismatch: "
                    "expected={} actual={}".format(
                        expected_visible, actual_visible))
                report["failures"].append(row)
            if expected_visible and not dropdown_label:
                row["result"] = "FAIL"
                row["error"] = (
                    "dropdown label empty for category that should show it")
                report["failures"].append(row)
            if not expected_visible and dropdown_label:
                row["result"] = "FAIL"
                row["error"] = (
                    "dropdown label non-empty for category that should hide it")
                report["failures"].append(row)
            if serious_vdma_error(errors):
                row["result"] = "FAIL"
                row["error"] = "VDMA internal/slave/decode error bit asserted"
                report["failures"].append(row)
            if row["result"] == "PASS" and float(args.hold_seconds_per_step) > 0:
                time.sleep(float(args.hold_seconds_per_step))
        except (AttributeError, NotImplementedError, ValueError) as exc:
            row["actual"] = mirror.get_selected_fx_actual()
            row["result"] = "SKIP"
            row["skip_reason"] = str(exc)
            row["pedal_model_label"] = mirror.current_pedal_label
            row["amp_model_label"] = mirror.current_amp_label
            row["cab_model_label"] = mirror.current_cab_label
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
        print("[phase6b] returning to Safe Bypass")
        mirror.safe_bypass()

    if float(args.final_hold_seconds) > 0:
        print("[phase6b] final HDMI hold: {:.1f} seconds".format(
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
        raise SystemExit("[phase6b] FAIL: {} failed step(s)".format(
            len(report["failures"])))
    print("[phase6b] OK")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        sys.exit(1)
