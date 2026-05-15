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
normalize_pedal_model = _MODULE.normalize_pedal_model
normalize_amp_model = _MODULE.normalize_amp_model
normalize_cab_model = _MODULE.normalize_cab_model
pedal_model_label = _MODULE.pedal_model_label
amp_model_label = _MODULE.amp_model_label
cab_model_label = _MODULE.cab_model_label
selected_fx_category = _MODULE.selected_fx_category
dropdown_label_for = _MODULE.dropdown_label_for
dropdown_visible_for = _MODULE.dropdown_visible_for


class FakeAppState(object):
    def __init__(self):
        self.preset_id = "02A"
        self.preset_name = "BASIC CLEAN"
        self.preset_idx = 1
        self.chain = list(range(8))
        self.effect_on = [False] * 8
        self.selected_effect = 4
        self.selected_fx = None
        self.knob_values = [45, 55, 60, 50, 70, 60]
        self.selected_knob = 0
        self.dist_model_idx = 1
        self.amp_model_idx = 2
        self.cab_model_idx = 2
        self.save_flash = 0.0

    def knobs(self):
        return []


class FakeOverlay(object):
    def __init__(self):
        self.calls = []

    def _record(self, method, *args, **kwargs):
        self.calls.append((method, args, dict(kwargs)))
        return {"method": method, "args": args, "kwargs": dict(kwargs)}

    def set_distortion_settings(self, *args, **kwargs):
        return self._record("set_distortion_settings", *args, **kwargs)

    def set_guitar_effects(self, *args, **kwargs):
        return self._record("set_guitar_effects", *args, **kwargs)

    def set_amp_model(self, name, **kwargs):
        self._record("set_amp_model", name, **kwargs)
        values = dict(kwargs)
        values.setdefault("amp_on", True)
        return self.set_guitar_effects(**values)


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
        self.last_frame_write = {}

    def start(self, frame, **kwargs):
        self.started = True
        self.last_frame_write = {
            "compose_s": 0.001,
            "framebuffer_copy_s": 0.002,
            "placement": kwargs.get("placement"),
            "offset_x": kwargs.get("offset_x"),
            "offset_y": kwargs.get("offset_y"),
        }
        return dict(self.last_frame_write)

    def write_frame(self, frame, **kwargs):
        self.last_frame_write = {
            "compose_s": 0.001,
            "framebuffer_copy_s": 0.002,
            "placement": kwargs.get("placement"),
            "offset_x": kwargs.get("offset_x"),
            "offset_y": kwargs.get("offset_y"),
        }
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


def test_model_name_normalize_and_labels():
    assert normalize_pedal_model("Tube Screamer") == "tube_screamer"
    assert normalize_pedal_model("DS-1") == "ds1"
    assert normalize_amp_model("hi-gain stack") == "high_gain_stack"
    assert normalize_cab_model("2x12") == "2x12"
    assert normalize_cab_model(2) == "4x12"
    assert pedal_model_label("tube_screamer") == "TUBE SCREAMER"
    assert amp_model_label("jc_clean") == "JC CLEAN"
    assert cab_model_label("2x12") == "2x12 COMBO"


def test_unsupported_model_raises_value_error():
    try:
        normalize_pedal_model("not_a_pedal")
    except ValueError:
        pass
    else:
        raise AssertionError("unsupported pedal model did not raise")


def test_pedal_model_updates_selected_fx_and_app_state():
    mirror = make_mirror()
    mirror.set_pedal_model("tube_screamer", drive=45, tone=55, level=65)
    assert mirror.get_selected_fx_actual() == "TUBE SCREAMER"
    assert mirror.current_pedal_model == "tube_screamer"
    assert mirror.current_pedal_label == "TUBE SCREAMER"
    assert mirror.app_state.pedal_model == "tube_screamer"
    assert mirror.app_state.pedal_model_label == "TUBE SCREAMER"
    assert mirror.app_state.dist_model_idx == 1
    assert mirror.app_state.selected_effect == 3
    assert mirror.app_state.effect_on[3] is True
    assert mirror.app_state.active_pedals == ["tube_screamer"]


def test_amp_model_updates_selected_fx_and_app_state():
    mirror = make_mirror()
    mirror.set_amp_model("jc_clean", gain=30, bass=55, mid=50, treble=60)
    assert mirror.get_selected_fx_actual() == "AMP SIM"
    assert mirror.current_amp_model == "jc_clean"
    assert mirror.current_amp_label == "JC CLEAN"
    assert mirror.app_state.amp_model == "jc_clean"
    assert mirror.app_state.amp_model_label == "JC CLEAN"
    assert mirror.app_state.amp_model_idx == 0
    assert mirror.app_state.selected_effect == 4
    assert mirror.app_state.effect_on[4] is True


def test_cab_model_updates_selected_fx_and_app_state():
    mirror = make_mirror()
    mirror.set_cab_model("2x12", air=40)
    assert mirror.get_selected_fx_actual() == "CAB"
    assert mirror.current_cab_model == "2x12"
    assert mirror.current_cab_label == "2x12 COMBO"
    assert mirror.app_state.cab_model == "2x12"
    assert mirror.app_state.cab_model_label == "2x12 COMBO"
    assert mirror.app_state.cab_model_idx == 1
    assert mirror.app_state.selected_effect == 5
    assert mirror.app_state.effect_on[5] is True


def test_selected_fx_history_for_models():
    mirror = make_mirror()
    mirror.clean_boost(drive=30, level=60)
    mirror.ds1(drive=50, tone=50, level=55)
    mirror.high_gain_stack(gain=70, bass=55, mid=50, treble=60)
    mirror.cab(model="4x12", air=35)
    history = [item["selected_fx"] for item in mirror.selected_fx_history]
    assert history == ["CLEAN BOOST", "DS-1", "AMP SIM", "CAB"]


def test_selected_fx_category_mapping():
    for fx in ("CLEAN BOOST", "TUBE SCREAMER", "RAT", "DS-1",
               "BIG MUFF", "FUZZ FACE", "METAL"):
        assert selected_fx_category(fx) == "PEDAL"
    assert selected_fx_category("AMP SIM") == "AMP"
    assert selected_fx_category("CAB") == "CAB"
    assert selected_fx_category("REVERB") == "REVERB"
    assert selected_fx_category("EQ") == "EQ"
    assert selected_fx_category("COMPRESSOR") == "COMPRESSOR"
    assert selected_fx_category("NOISE SUPPRESSOR") == "NOISE SUPPRESSOR"
    assert selected_fx_category("SAFE BYPASS") == "SAFE"
    assert selected_fx_category("PRESET") == "PRESET"


def test_pedal_selection_marks_dropdown_visible_with_current_pedal_label():
    mirror = make_mirror()
    mirror.set_pedal_model("ds1", drive=50, tone=50, level=55)
    assert mirror.app_state.selected_model_category == "PEDAL"
    assert mirror.app_state.dropdown_label == "DS-1"
    assert getattr(mirror.app_state,
                   "selected_model_dropdown_visible", False) is True


def test_amp_selection_marks_dropdown_visible_with_current_amp_label():
    mirror = make_mirror()
    mirror.set_amp_model("high_gain_stack", gain=70, bass=55, mid=50, treble=60)
    assert mirror.app_state.selected_model_category == "AMP"
    assert mirror.app_state.dropdown_label == "HIGH GAIN STACK"
    assert getattr(mirror.app_state,
                   "selected_model_dropdown_visible", False) is True


def test_cab_selection_marks_dropdown_visible_with_current_cab_label():
    mirror = make_mirror()
    mirror.set_cab_model("2x12", air=40)
    assert mirror.app_state.selected_model_category == "CAB"
    assert mirror.app_state.dropdown_label == "2x12 COMBO".upper()
    assert getattr(mirror.app_state,
                   "selected_model_dropdown_visible", False) is True


def test_non_model_effects_hide_dropdown():
    mirror = make_mirror()
    mirror.set_pedal_model("tube_screamer", drive=45, tone=55, level=65)
    # Switching to a non-model effect should clear the dropdown label.
    mirror.set_guitar_effects(reverb_on=True, reverb_mix=20)
    assert mirror.get_selected_fx_actual() == "REVERB"
    assert mirror.app_state.dropdown_label == ""
    assert mirror.app_state.dropdown_short_label == ""
    assert getattr(mirror.app_state,
                   "selected_model_dropdown_visible", True) is False
    assert dropdown_visible_for("REVERB") is False


if __name__ == "__main__":
    tests = [
        test_model_name_normalize_and_labels,
        test_unsupported_model_raises_value_error,
        test_pedal_model_updates_selected_fx_and_app_state,
        test_amp_model_updates_selected_fx_and_app_state,
        test_cab_model_updates_selected_fx_and_app_state,
        test_selected_fx_history_for_models,
        test_selected_fx_category_mapping,
        test_pedal_selection_marks_dropdown_visible_with_current_pedal_label,
        test_amp_selection_marks_dropdown_visible_with_current_amp_label,
        test_cab_selection_marks_dropdown_visible_with_current_cab_label,
        test_non_model_effects_hide_dropdown,
    ]
    for test in tests:
        test()
        print("PASS", test.__name__)
