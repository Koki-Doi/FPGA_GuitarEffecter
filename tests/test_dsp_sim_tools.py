import math
import os
import sys

import numpy as np

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIM_DIR = os.path.join(REPO, "tools", "dsp_sim")
sys.path.insert(0, SIM_DIR)

import dynamics_eval  # noqa: E402
import measure  # noqa: E402
import run_sim  # noqa: E402
from metrics import is_strictly_rising, rms_dbfs  # noqa: E402


def test_run_sim_metrics_handles_short_inputs():
    x = np.zeros(256, dtype=np.int64)
    x[10] = 12345
    m = run_sim.metrics(x, 96000)
    assert math.isfinite(m["peak_dBFS"])
    assert math.isfinite(m["rms_dBFS"])
    assert math.isfinite(m["crest_dB"])
    assert math.isfinite(m["level_stability_std_dB"])
    assert m["clip_count"] == 0


def test_measure_rat_alias_matches_dedicated_rat_stage():
    cm = run_sim.load_control_maps()
    rat = measure.build_config(cm, "rat", drive=60, tone=35, level=100)
    rat_fx = measure.build_config(cm, "rat_fx", drive=60, tone=35, level=100)
    assert rat == rat_fx
    gate_word = rat[measure.ORDER.index("gate")]
    dist_word = rat[measure.ORDER.index("dist")]
    assert gate_word & 0x10
    assert ((dist_word >> 24) & 0xFF) == 0


def test_shared_metric_helpers_are_deterministic():
    x = np.array([0, 100, -100, 100, -100], dtype=np.int64)
    assert rms_dbfs(x) == rms_dbfs(x)
    assert is_strictly_rising([1.0, 2.0, 3.1], min_step=0.5)
    assert not is_strictly_rising([1.0, 1.2, 3.1], min_step=0.5)


def test_dynamics_section_parser_rejects_unknown_names():
    assert dynamics_eval._parse_sections("compressor,wah") == ["compressor", "wah"]
    try:
        dynamics_eval._parse_sections("compressor,nope")
    except SystemExit as exc:
        assert "unknown section" in str(exc)
    else:
        raise AssertionError("unknown section accepted")
