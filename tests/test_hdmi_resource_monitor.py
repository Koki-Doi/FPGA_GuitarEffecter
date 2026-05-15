"""Phase 6C unit tests for the /proc-based ResourceSampler and
SELECTED FX dropdown plumbing."""
import importlib.util
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))


_SPEC = importlib.util.spec_from_file_location(
    "_test_resource_hdmi_mirror",
    str(REPO_ROOT / "audio_lab_pynq" / "hdmi_effect_state_mirror.py"))
_MODULE = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(_MODULE)


ResourceSampler = _MODULE.ResourceSampler
SELECTED_FX_CATEGORY = _MODULE.SELECTED_FX_CATEGORY
DROPDOWN_SHORT_LABELS = _MODULE.DROPDOWN_SHORT_LABELS
selected_fx_category = _MODULE.selected_fx_category
dropdown_short_label = _MODULE.dropdown_short_label
dropdown_label_for = _MODULE.dropdown_label_for
HdmiEffectStateMirror = _MODULE.HdmiEffectStateMirror
_parse_proc_meminfo_text = _MODULE._parse_proc_meminfo_text
_parse_proc_status_text = _MODULE._parse_proc_status_text
_parse_proc_stat_cpu_line = _MODULE._parse_proc_stat_cpu_line
_parse_proc_self_stat_times = _MODULE._parse_proc_self_stat_times


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


class FakeOverlay(object):
    def __init__(self):
        self.calls = []

    def _record(self, method, *args, **kwargs):
        self.calls.append((method, args, dict(kwargs)))
        return {"method": method}

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

    def set_amp_model(self, name, **kwargs):
        self._record("set_amp_model", name, **kwargs)
        v = dict(kwargs); v.setdefault("amp_on", True)
        return self.set_guitar_effects(**v)


class FakeFrame(object):
    shape = (480, 800, 3)
    dtype = "uint8"


class FakeRenderer(object):
    def __call__(self, state, **kwargs):
        return FakeFrame()


class FakeHdmiBackend(object):
    def __init__(self):
        self.started = False

    def start(self, frame, **kwargs):
        self.started = True
        return None

    def write_frame(self, frame, **kwargs):
        return {"compose_s": 0.001, "framebuffer_copy_s": 0.002,
                "placement": kwargs.get("placement"),
                "offset_x": kwargs.get("offset_x"),
                "offset_y": kwargs.get("offset_y")}

    def status(self):
        return {"started": self.started, "vdma_dmasr": "0x00011000",
                "vtc_ctl": "0x00000006",
                "last_frame_write": {"placement": "manual",
                                       "offset_x": 0, "offset_y": 0}}

    def errors(self):
        return {"halted": False, "idle": False, "dmainterr": False,
                "dmaslverr": False, "dmadecerr": False,
                "raw": "0x00011000"}


def make_mirror():
    return HdmiEffectStateMirror(
        overlay=FakeOverlay(), hdmi_backend=FakeHdmiBackend(),
        app_state=FakeAppState(), renderer=FakeRenderer(),
        theme="pipboy-green", variant="compact-v2",
        placement="manual", offset_x=0, offset_y=0)


def test_parse_proc_meminfo_text():
    text = ("MemTotal:        496744 kB\n"
            "MemFree:          12345 kB\n"
            "MemAvailable:    234567 kB\n"
            "Junk:                  whatever\n")
    info = _parse_proc_meminfo_text(text)
    assert info["MemTotal"] == 496744
    assert info["MemFree"] == 12345
    assert info["MemAvailable"] == 234567
    assert "Junk" not in info


def test_parse_proc_status_text():
    text = ("Name:   python3\n"
            "VmRSS:    34560 kB\n"
            "VmSize:   123456 kB\n")
    status = _parse_proc_status_text(text)
    assert status["Name"] == "python3"
    assert status["VmRSS"].split()[0] == "34560"
    assert status["VmSize"].split()[0] == "123456"


def test_parse_proc_stat_cpu_line():
    line = "cpu  100 0 50 900 10 0 0 0 0 0"
    result = _parse_proc_stat_cpu_line(line)
    assert result is not None
    total, idle = result
    assert total == 1060
    assert idle == 910
    assert _parse_proc_stat_cpu_line("cpu0 100 0") is None
    assert _parse_proc_stat_cpu_line("") is None


def test_parse_proc_self_stat_times():
    line = ("12345 (some (weird) comm) S 1 12345 0 0 -1 0 0 0 0 0 "
            "111 222 0 0 20 0 1 0 100 1234 567 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0")
    val = _parse_proc_self_stat_times(line)
    assert val == 111 + 222


def test_resource_sampler_first_sample_has_none_pct():
    sampler = ResourceSampler()
    s = sampler.sample()
    assert s["proc_rss_kb"] >= 0
    assert s["mem_total_kb"] >= 0
    assert s["sys_cpu_pct"] is None or isinstance(s["sys_cpu_pct"], float)


def test_selected_fx_category_mapping():
    assert selected_fx_category("TUBE SCREAMER") == "PEDAL"
    assert selected_fx_category("amp_sim") == "AMP"
    assert selected_fx_category("CAB") == "CAB"
    assert selected_fx_category("REVERB") == "REVERB"
    assert selected_fx_category("Safe Bypass") == "SAFE"
    assert selected_fx_category("PRESET") == "PRESET"


def test_dropdown_short_label_known_and_fallback():
    assert dropdown_short_label("TUBE SCREAMER") == "TUBE SCRMR"
    assert dropdown_short_label("BRITISH CRUNCH") == "BRIT CRUNCH"
    assert dropdown_short_label("HIGH GAIN STACK") == "HI-GAIN"
    assert dropdown_short_label("2x12 COMBO") == "2x12 CMB"
    assert dropdown_short_label("RAT") == "RAT"
    assert dropdown_short_label("CUSTOM THING") == "CUSTOM THING"


def test_dropdown_label_for_routes_by_category():
    assert dropdown_label_for("TUBE SCREAMER", "TUBE SCREAMER",
                                "JC CLEAN", "1x12 OPEN") == "TUBE SCREAMER"
    assert dropdown_label_for("AMP SIM", "TUBE SCREAMER",
                                "JC CLEAN", "1x12 OPEN") == "JC CLEAN"
    assert dropdown_label_for("CAB", "TUBE SCREAMER",
                                "JC CLEAN", "2x12 COMBO") == "2X12 COMBO"
    assert dropdown_label_for("REVERB", "TUBE SCREAMER",
                                "JC CLEAN", "1x12 OPEN") == "REVERB"
    assert dropdown_label_for("SAFE BYPASS", "TUBE SCREAMER",
                                "JC CLEAN", "1x12 OPEN") == "SAFE BYPASS"


def test_mirror_updates_app_state_dropdown_fields_on_pedal_edit():
    mirror = make_mirror()
    mirror.tube_screamer(drive=45, tone=55, level=65)
    assert mirror.app_state.selected_model_category == "PEDAL"
    assert mirror.app_state.dropdown_label == "TUBE SCREAMER"
    assert mirror.app_state.dropdown_short_label == "TUBE SCRMR"


def test_mirror_updates_app_state_dropdown_fields_on_amp_edit():
    mirror = make_mirror()
    mirror.high_gain_stack(gain=70, bass=55, mid=50, treble=60)
    assert mirror.app_state.selected_model_category == "AMP"
    assert mirror.app_state.dropdown_label == "HIGH GAIN STACK"
    assert mirror.app_state.dropdown_short_label == "HI-GAIN"


def test_mirror_updates_app_state_dropdown_fields_on_cab_edit():
    mirror = make_mirror()
    mirror.cab(model="2x12", air=40)
    assert mirror.app_state.selected_model_category == "CAB"
    assert mirror.app_state.dropdown_label == "2X12 COMBO"
    assert mirror.app_state.dropdown_short_label == "2x12 CMB"


def test_mirror_safe_bypass_dropdown_is_safe():
    mirror = make_mirror()
    mirror.safe_bypass()
    assert mirror.app_state.selected_model_category == "SAFE"
    assert mirror.app_state.dropdown_label == "SAFE BYPASS"
    assert mirror.app_state.dropdown_short_label == "SAFE"


def test_mirror_resource_summary_has_expected_keys():
    mirror = make_mirror()
    mirror.tube_screamer(drive=45)
    summary = mirror.resource_summary()
    for key in ("proc_rss_kb", "mem_avail_kb", "sys_cpu_pct",
                 "proc_cpu_pct", "render_s", "compose_s",
                 "framebuffer_copy_s", "vdma_dmasr",
                 "selected_fx", "dropdown_label",
                 "selected_model_category", "pl_utilization"):
        assert key in summary, "missing key: {}".format(key)
    assert summary["pl_utilization"]["lut"] > 0
    assert summary["dropdown_label"] == "TUBE SCREAMER"
    assert summary["selected_model_category"] == "PEDAL"


def test_mirror_render_records_resource_sample_and_total_update():
    mirror = make_mirror()
    mirror.tube_screamer(drive=45)
    info = mirror.last_render_info
    assert "resource_sample" in info
    assert "total_update_s" in info
    assert info["total_update_s"] >= 0


def test_mirror_set_pedal_model_invokes_real_overlay_apis():
    """Phase 6C: catches display-only mirrors that skip DSP updates."""
    overlay = FakeOverlay()
    mirror = HdmiEffectStateMirror(
        overlay=overlay, hdmi_backend=FakeHdmiBackend(),
        app_state=FakeAppState(), renderer=FakeRenderer(),
        theme="pipboy-green", variant="compact-v2",
        placement="manual", offset_x=0, offset_y=0)
    mirror.set_pedal_model("tube_screamer", drive=45, tone=55, level=65)
    methods = [call[0] for call in overlay.calls]
    assert "set_distortion_settings" in methods
    assert "set_guitar_effects" in methods


if __name__ == "__main__":
    tests = [
        test_parse_proc_meminfo_text,
        test_parse_proc_status_text,
        test_parse_proc_stat_cpu_line,
        test_parse_proc_self_stat_times,
        test_resource_sampler_first_sample_has_none_pct,
        test_selected_fx_category_mapping,
        test_dropdown_short_label_known_and_fallback,
        test_dropdown_label_for_routes_by_category,
        test_mirror_updates_app_state_dropdown_fields_on_pedal_edit,
        test_mirror_updates_app_state_dropdown_fields_on_amp_edit,
        test_mirror_updates_app_state_dropdown_fields_on_cab_edit,
        test_mirror_safe_bypass_dropdown_is_safe,
        test_mirror_resource_summary_has_expected_keys,
        test_mirror_render_records_resource_sample_and_total_update,
        test_mirror_set_pedal_model_invokes_real_overlay_apis,
    ]
    for fn in tests:
        fn()
        print("PASS", fn.__name__)
