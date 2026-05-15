"""Phase 4B static HDMI frame check for the integrated AudioLab overlay.

Loads ``AudioLabOverlay`` exactly once, builds a single
``render_frame_pynq_static(AppState())`` RGB frame on the PYNQ-Z2, and
hands it to ``audio_lab_pynq.hdmi_backend.AudioLabHdmiBackend``. The
script then prints the VDMA / VTC status and re-checks the audio side
(ADC HPF, R19, presence of legacy ``axi_gpio_delay``, absence of
``axi_gpio_delay_line``).

Intended invocation on the board:

    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
        /home/xilinx/Audio-Lab-PYNQ/scripts/test_hdmi_static_frame.py

LCD overscan fit check:

    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
        /home/xilinx/Audio-Lab-PYNQ/scripts/test_hdmi_static_frame.py \
        --fit-mode fit-90 --hold-seconds 60

This script does NOT load ``base.bit``, does NOT load a second overlay,
does NOT touch audio-side GPIOs beyond Safe Bypass, and does NOT call
``run_pynq_hdmi()`` from the renderer.
"""
from __future__ import print_function

import argparse
import json
import os
import sys
import time
import traceback


FIT_MODE_CHOICES = ("native", "fit-97", "fit-95", "fit-90", "fit-85", "fit-80")


def smoke(overlay):
    ip_keys = set(getattr(overlay, "ip_dict", {}).keys())
    return {
        "ADC HPF": bool(overlay.codec.get_adc_hpf_state()),
        "R19": "0x{:02x}".format(int(overlay.codec.R19_ADC_CONTROL[0]) & 0xFF),
        "has axi_gpio_delay_line (must be False)": hasattr(overlay, "axi_gpio_delay_line"),
        "has legacy axi_gpio_delay": hasattr(overlay, "axi_gpio_delay"),
        "has axi_gpio_noise_suppressor": hasattr(overlay, "axi_gpio_noise_suppressor"),
        "has axi_gpio_compressor": hasattr(overlay, "axi_gpio_compressor"),
        "has axi_vdma_hdmi ip_dict (Phase 4)": "axi_vdma_hdmi" in ip_keys,
        "has v_tc_hdmi ip_dict (Phase 4)": "v_tc_hdmi" in ip_keys,
        "has rgb2dvi_hdmi in HWH (Phase 4)": hwh_contains("rgb2dvi_hdmi"),
        "has v_axi4s_vid_out_hdmi in HWH (Phase 4)": hwh_contains("v_axi4s_vid_out_hdmi"),
    }


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


def make_app_state_default():
    """Reproduces the AppState shape the bridge / renderer expect.

    Imported lazily to avoid pulling NumPy / Pillow when only the audio
    smoke half of this script is exercised on a board where the GUI is
    not yet deployed.
    """
    sys.path.insert(0, "/home/xilinx/Audio-Lab-PYNQ")
    sys.path.insert(0, "/tmp/hdmi_gui_phase4")
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "GUI"))
    from pynq_multi_fx_gui import AppState  # noqa
    return AppState()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fit-mode", default="native",
                        choices=FIT_MODE_CHOICES,
                        help="optional LCD overscan fit mode")
    parser.add_argument("--scale", type=float, default=None,
                        help="custom 0..1 scale overriding --fit-mode")
    parser.add_argument("--hold-seconds", type=int, default=0,
                        help="hold HDMI scanout before post-smoke")
    args = parser.parse_args()

    report = {
        "phase": "4D-static-gui-fit",
        "started_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "fit_mode": args.fit_mode,
        "scale_override": args.scale,
        "hold_seconds": int(args.hold_seconds),
        "steps": [],
    }

    print("[phase4b] importing AudioLabOverlay")
    t0 = time.time()
    from audio_lab_pynq import AudioLabOverlay
    print("[phase4b] AudioLabOverlay imported in {:.3f} s".format(time.time() - t0))

    print("[phase4b] loading AudioLabOverlay() (single load)")
    t0 = time.time()
    overlay = AudioLabOverlay()
    print("[phase4b] AudioLabOverlay() ready in {:.3f} s".format(time.time() - t0))

    pre_smoke = smoke(overlay)
    report["smoke_pre_hdmi"] = pre_smoke
    print(json.dumps({"smoke_pre_hdmi": pre_smoke}, indent=2))

    if not all([
        pre_smoke["ADC HPF"],
        pre_smoke["R19"] == "0x23",
        pre_smoke["has legacy axi_gpio_delay"],
        not pre_smoke["has axi_gpio_delay_line (must be False)"],
        pre_smoke["has axi_vdma_hdmi ip_dict (Phase 4)"],
        pre_smoke["has v_tc_hdmi ip_dict (Phase 4)"],
        pre_smoke["has rgb2dvi_hdmi in HWH (Phase 4)"],
        pre_smoke["has v_axi4s_vid_out_hdmi in HWH (Phase 4)"],
    ]):
        raise SystemExit("[phase4b] pre-HDMI smoke failed; refusing to start HDMI")

    print("[phase4b] importing hdmi_backend + renderer")
    from audio_lab_pynq.hdmi_backend import AudioLabHdmiBackend
    state = make_app_state_default()
    from pynq_multi_fx_gui import (
        make_pynq_static_render_cache, render_frame_pynq_static,
    )

    print("[phase4b] rendering one static frame")
    t0 = time.time()
    cache = make_pynq_static_render_cache()
    frame = render_frame_pynq_static(state, cache=cache)
    render_s = time.time() - t0
    print("[phase4b] frame shape={}, dtype={}, render={:.3f} s".format(
        list(frame.shape), str(frame.dtype), render_s))
    if list(frame.shape) != [720, 1280, 3] or str(frame.dtype) != "uint8":
        raise SystemExit("[phase4b] renderer returned an unexpected frame")
    report["render_s"] = render_s

    print("[phase4b] starting HDMI back end with the frame "
          "(fit_mode={}, scale_override={})".format(args.fit_mode, args.scale))
    backend = AudioLabHdmiBackend(overlay)
    t0 = time.time()
    backend.start(frame, fit_mode=args.fit_mode, scale=args.scale)
    backend_start_s = time.time() - t0
    time.sleep(0.1)
    post = backend.status()
    err = backend.errors()
    report["hdmi_status_post_start"] = post
    report["hdmi_errors_post_start"] = err
    report["backend_start_s"] = backend_start_s
    print(json.dumps({"hdmi_status_post_start": post,
                      "hdmi_errors_post_start": err,
                      "backend_start_s": backend_start_s}, indent=2))
    if err.get("dmainterr") or err.get("dmaslverr") or err.get("dmadecerr"):
        raise SystemExit("[phase4b] VDMA error bits set")

    if int(args.hold_seconds) > 0:
        print("[phase4b] holding HDMI scanout for {} seconds".format(
            int(args.hold_seconds)))
        time.sleep(int(args.hold_seconds))

    # Quick Safe Bypass through the existing API so we know audio control
    # still works while HDMI is scanning out.
    print("[phase4b] applying Safe Bypass through existing overlay APIs")
    overlay.clear_distortion_pedals()
    overlay.set_noise_suppressor_settings(enabled=False)
    overlay.set_compressor_settings(enabled=False)
    overlay.set_guitar_effects(noise_gate_on=False, overdrive_on=False,
                               distortion_on=False, rat_on=False,
                               amp_on=False, cab_on=False, eq_on=False,
                               reverb_on=False)

    post_smoke = smoke(overlay)
    report["smoke_post_hdmi"] = post_smoke
    print(json.dumps({"smoke_post_hdmi": post_smoke}, indent=2))

    out_path = "/tmp/hdmi_gui_phase4/phase4b_report.json"
    try:
        os.makedirs(os.path.dirname(out_path))
    except OSError:
        pass
    with open(out_path, "w") as fp:
        json.dump(report, fp, indent=2, sort_keys=True, default=repr)
    print("[phase4b] report saved to {}".format(out_path))
    print("[phase4b] HDMI back end is now scanning. Audio DSP path is still live.")
    print("[phase4b] OK")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
