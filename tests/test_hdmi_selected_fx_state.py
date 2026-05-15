import sys
import importlib.util
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))

_SPEC = importlib.util.spec_from_file_location(
    "hdmi_effect_state_mirror",
    str(REPO_ROOT / "audio_lab_pynq" / "hdmi_effect_state_mirror.py"))
_MODULE = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(_MODULE)

HdmiEffectStateMirror = _MODULE.HdmiEffectStateMirror
normalize_selected_fx = _MODULE.normalize_selected_fx


class FakeAppState(object):
    def __init__(self):
        self.preset_id = "02A"
        self.preset_name = "BASIC CLEAN"
        self.preset_idx = 1
        self.chain = list(range(8))
        self.effect_on = [True, True, False, False, True, True, True, True]
        self.selected_effect = 4
        self.selected_fx = None
        self.knob_values = [45, 55, 60, 50, 70, 60]
        self.selected_knob = 0
        self.dist_model_idx = 1
        self.amp_model_idx = 2
        self.cab_model_idx = 2
        self.save_flash = 0.0


class FakeOverlay(object):
    def __init__(self):
        self.calls = []

    def _record(self, method, *args, **kwargs):
        self.calls.append((method, args, dict(kwargs)))
        return {"method": method, "args": args, "kwargs": dict(kwargs)}

    def clear_distortion_pedals(self):
        return self._record("clear_distortion_pedals")

    def set_distortion_settings(self, *args, **kwargs):
        return self._record("set_distortion_settings", *args, **kwargs)

    def set_noise_suppressor_settings(self, *args, **kwargs):
        return self._record("set_noise_suppressor_settings", *args, **kwargs)

    def set_compressor_settings(self, *args, **kwargs):
        return self._record("set_compressor_settings", *args, **kwargs)

    def set_guitar_effects(self, *args, **kwargs):
        return self._record("set_guitar_effects", *args, **kwargs)

    def apply_chain_preset(self, name):
        return self._record("apply_chain_preset", name)

    def get_current_pedalboard_state(self):
        return {
            "noise_suppressor": {
                "enabled": True, "threshold": 25, "decay": 84, "damp": 85,
            },
            "compressor": {
                "enabled": True, "threshold": 45, "ratio": 35,
                "response": 45, "makeup": 50,
            },
            "distortion": {
                "drive": 50, "tone": 55, "level": 35,
                "bias": 50, "tight": 60, "mix": 100,
            },
        }


class FakeFrame(object):
    shape = (480, 800, 3)
    dtype = "uint8"


class FakeRenderer(object):
    def __init__(self):
        self.calls = []

    def __call__(self, state, **kwargs):
        self.calls.append((state.selected_fx, dict(kwargs)))
        return FakeFrame()


class FakeHdmiBackend(object):
    def __init__(self):
        self.started = False
        self.writes = []
        self.last_frame_write = {}

    def start(self, frame, **kwargs):
        self.started = True
        self.last_frame_write = {
            "compose_s": 0.01,
            "framebuffer_copy_s": 0.02,
            "placement": kwargs.get("placement"),
            "offset_x": kwargs.get("offset_x"),
            "offset_y": kwargs.get("offset_y"),
        }
        self.writes.append(("start", kwargs))
        return None

    def write_frame(self, frame, **kwargs):
        self.last_frame_write = {
            "compose_s": 0.01,
            "framebuffer_copy_s": 0.02,
            "placement": kwargs.get("placement"),
            "offset_x": kwargs.get("offset_x"),
            "offset_y": kwargs.get("offset_y"),
        }
        self.writes.append(("write_frame", kwargs))
        return dict(self.last_frame_write)

    def status(self):
        return {
            "started": self.started,
            "vdma_dmasr": "0x00011000",
            "vtc_ctl": "0x00000006",
            "last_frame_write": dict(self.last_frame_write),
        }

    def errors(self):
        return {
            "halted": False,
            "idle": False,
            "dmainterr": False,
            "dmaslverr": False,
            "dmadecerr": False,
            "raw": "0x00011000",
        }


def make_mirror():
    return HdmiEffectStateMirror(
        overlay=FakeOverlay(),
        hdmi_backend=FakeHdmiBackend(),
        app_state=FakeAppState(),
        renderer=FakeRenderer(),
        theme="pipboy-green",
        variant="compact-v2",
        placement="manual",
        offset_x=0,
        offset_y=0,
    )


def test_normalize_selected_fx_aliases():
    assert normalize_selected_fx("Amp Sim") == "AMP SIM"
    assert normalize_selected_fx("amp_sim") == "AMP SIM"
    assert normalize_selected_fx("NS") == "NOISE SUPPRESSOR"
    assert normalize_selected_fx("safe-bypass") == "SAFE BYPASS"


def test_method_mapping_and_history_order():
    mirror = make_mirror()

    mirror.safe_bypass()
    mirror.apply_chain_preset("Basic Clean")
    mirror.set_noise_suppressor_settings(
        enabled=True, threshold=25, decay=84, damp=85)
    mirror.set_compressor_settings(
        enabled=True, threshold=45, ratio=35, response=45, makeup=50)
    mirror.set_guitar_effects(amp_on=True, amp_input_gain=60)
    mirror.set_guitar_effects(reverb_on=True, reverb_mix=35)

    history = [item["selected_fx"] for item in mirror.selected_fx_history]
    assert history == [
        "SAFE BYPASS",
        "PRESET",
        "NOISE SUPPRESSOR",
        "COMPRESSOR",
        "AMP SIM",
        "REVERB",
    ]
    assert mirror.get_selected_fx_actual() == "REVERB"
    assert mirror.app_state.selected_effect == 7
    assert mirror.last_render_info["expected_selected_fx"] == "REVERB"


def test_mark_selected_fx_and_assertion_failure():
    mirror = make_mirror()
    mirror.mark_selected_fx("amp_sim", reason="unit")
    assert mirror.assert_selected_fx("AMP SIM") is True
    try:
        mirror.assert_selected_fx("REVERB")
    except AssertionError:
        pass
    else:
        raise AssertionError("expected assert_selected_fx to fail")


def test_render_validates_expected_selected_fx():
    mirror = make_mirror()
    mirror.mark_selected_fx("AMP SIM", reason="unit")
    info = mirror.render(reason="unit", expected_selected_fx="Amp Sim")
    assert info["actual_selected_fx"] == "AMP SIM"
    assert info["hdmi_errors"]["raw"] == "0x00011000"

    try:
        mirror.render(reason="unit-fail", expected_selected_fx="REVERB")
    except AssertionError:
        pass
    else:
        raise AssertionError("render() did not validate expected SELECTED FX")


def test_set_guitar_effects_last_kwarg_category_wins():
    mirror = make_mirror()
    mirror.set_guitar_effects(amp_on=True, amp_input_gain=50,
                              reverb_on=True, reverb_mix=20)
    assert mirror.get_selected_fx_actual() == "REVERB"

    mirror.set_guitar_effects(reverb_on=True, reverb_mix=20,
                              amp_on=True, amp_input_gain=55)
    assert mirror.get_selected_fx_actual() == "AMP SIM"


if __name__ == "__main__":
    tests = [
        test_normalize_selected_fx_aliases,
        test_method_mapping_and_history_order,
        test_mark_selected_fx_and_assertion_failure,
        test_render_validates_expected_selected_fx,
        test_set_guitar_effects_last_kwarg_category_wins,
    ]
    for test in tests:
        test()
        print("PASS", test.__name__)
