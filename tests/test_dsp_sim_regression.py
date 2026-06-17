"""DSP regression tests via the offline Clash sim harness (Tier 2).

Runs the EXACT FPGA DSP pipeline on the host (tools/dsp_sim) to assert, WITHOUT
a Vivado build or a bench:

  * safe-bypass invariant -- all effects off => sample-exact passthrough
    (the "knife-edge" property that caused the D102-D108 pain), and
  * golden vectors -- a set of effect configs produce byte-stable output
    (sha256), so an unintended DSP change (a refactor that should be
    behaviour-preserving, an accidental constant edit) is caught immediately
    instead of by manual VHDL diffing or an ear bench.

These tests are OPT-IN (they need `clash` + a ~1 min harness build) so they do
not slow the default Python suite:

    DSP_SIM_TESTS=1 python3 -m pytest tests/test_dsp_sim_regression.py -q

Re-bless the goldens after an INTENTIONAL voicing change:

    python3 tests/test_dsp_sim_regression.py --regen

The harness is auto-(re)built when the dsp_sim binary is missing or older than
any DSP source; if `clash` is unavailable the tests skip cleanly.
"""
import hashlib
import json
import os
import shutil
import subprocess
import sys

import numpy as np
import pytest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIM_DIR = os.path.join(REPO, "tools", "dsp_sim")
SIM_BIN = os.path.join(SIM_DIR, "dsp_sim")
GOLDEN = os.path.join(SIM_DIR, "golden_vectors.json")
CLASH_SRC = os.path.join(REPO, "hw", "ip", "clash", "src")
PKGID = ("clash-prelude-1.8.1-"
         "043657e64d575898396c414bafaea7f08fdd2ba6b4085ce0bd624cd91d00144c")
GAP = 8
ORDER = ["gate", "od", "dist", "eq", "rat", "amp",
         "amp_tone", "cab", "reverb", "ns", "comp", "wah"]
CONFIGS = ["bypass", "amp_jc120", "amp_twin", "amp_ac30", "amp_rockerverb",
           "amp_jcm800", "amp_triamp",
           "overdrive_ts9", "od_bd2", "od_ocd",
           "dist_cleanboost", "dist_ts", "distortion_ds1", "dist_bigmuff",
           "dist_fuzz", "dist_metal", "dist_rat", "cab", "reverb"]

sys.path.insert(0, SIM_DIR)

# Opt-in gate: skip the whole module under pytest unless explicitly enabled,
# but allow direct `python3 tests/test_dsp_sim_regression.py --regen`.
if __name__ != "__main__" and os.environ.get("DSP_SIM_TESTS") != "1":
    pytest.skip("set DSP_SIM_TESTS=1 to run DSP sim regression (needs clash + ~1 min)",
                allow_module_level=True)


def _dsp_sources():
    srcs = []
    for root, _, files in os.walk(CLASH_SRC):
        srcs += [os.path.join(root, f) for f in files if f.endswith(".hs")]
    srcs.append(os.path.join(SIM_DIR, "Sim.hs"))
    return srcs


def _binary_fresh():
    if not os.path.exists(SIM_BIN):
        return False
    bt = os.path.getmtime(SIM_BIN)
    return all(os.path.getmtime(s) <= bt for s in _dsp_sources())


def _build_sim():
    subprocess.run(
        ["clash", "-O1", "-ihw/ip/clash/src", "-itools/dsp_sim",
         "-package-id", PKGID, "tools/dsp_sim/Sim.hs",
         "-o", "tools/dsp_sim/dsp_sim", "-outputdir", "/tmp/dsp_sim_build"],
        cwd=REPO, check=True, timeout=900,
        stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)


def ensure_sim(skip=True):
    """Return the imported run_sim module with a fresh binary, or skip."""
    if not _binary_fresh():
        if shutil.which("clash") is None:
            msg = "clash unavailable and dsp_sim binary missing/stale"
            if skip:
                pytest.skip(msg)
            raise RuntimeError(msg)
        _build_sim()
    import run_sim
    return run_sim


def _test_input(n=4096, level=0.04):
    """Deterministic, modest-level stimulus (content is irrelevant -- only
    determinism + exercising the effect matters for change detection)."""
    rng = np.random.RandomState(0xA5)
    x = rng.uniform(-1.0, 1.0, n) * level
    return np.round(x * (1 << 23)).astype(np.int64)


def _config_words(cm, name):
    w = {
        "gate": cm.gate_word(),
        "od": cm.overdrive_word(65, 100, 30),
        "dist": cm.distortion_word(50, 35, 0, 0),
        "eq": cm.eq_word(100, 100, 100),
        "rat": cm.rat_word(35, 100, 0, 100),
        "amp": cm.amp_word(35, 80, 45, 35),
        "amp_tone": cm.amp_tone_word(50, 50, 50, amp_model_idx=0, amp_drive_mode=0),
        "cab": cm.cab_word(100, 100, 1, 50),
        "reverb": cm.reverb_word(0, 65, 0),
        "ns": cm.noise_suppressor_word(35, 40, 70),
        "comp": cm.compressor_word(45, 35, 45, 50, False),
        "wah": cm.wah_word(0, 50, 50, 50, False),
    }
    if name == "bypass":
        pass
    elif name == "amp_jc120":
        w["gate"] = cm.gate_word(amp_on=True)
        w["amp"] = cm.amp_word(20, 60, 45, 35)
        w["amp_tone"] = cm.amp_tone_word(50, 50, 50, amp_model_idx=0, amp_drive_mode=0)
    elif name == "amp_jcm800":
        w["gate"] = cm.gate_word(amp_on=True)
        w["amp"] = cm.amp_word(30, 70, 60, 40)
        w["amp_tone"] = cm.amp_tone_word(55, 55, 60, amp_model_idx=4, amp_drive_mode=1)
    elif name == "amp_rockerverb":  # voicing: thick low-mid +3 dB @ 300 Hz scoop biquad
        w["gate"] = cm.gate_word(amp_on=True)
        w["amp"] = cm.amp_word(28, 68, 55, 40)
        w["amp_tone"] = cm.amp_tone_word(52, 52, 55, amp_model_idx=3, amp_drive_mode=1)
    elif name == "amp_triamp":  # voicing: modern scoop -6 dB @ 750 Hz scoop biquad
        w["gate"] = cm.gate_word(amp_on=True)
        w["amp"] = cm.amp_word(32, 70, 58, 42)
        w["amp_tone"] = cm.amp_tone_word(55, 52, 58, amp_model_idx=5, amp_drive_mode=1)
    elif name == "amp_twin":  # idx 1: Fender blackface clean (G refactor coverage)
        w["gate"] = cm.gate_word(amp_on=True)
        w["amp"] = cm.amp_word(22, 62, 50, 38)
        w["amp_tone"] = cm.amp_tone_word(52, 50, 54, amp_model_idx=1, amp_drive_mode=0)
    elif name == "amp_ac30":  # idx 2: Vox chime (G refactor coverage)
        w["gate"] = cm.gate_word(amp_on=True)
        w["amp"] = cm.amp_word(30, 66, 56, 40)
        w["amp_tone"] = cm.amp_tone_word(54, 52, 56, amp_model_idx=2, amp_drive_mode=1)
    elif name == "overdrive_ts9":
        w["gate"] = cm.gate_word(overdrive_on=True)
        w["od"] = cm.overdrive_word(65, 100, 55, overdrive_model=0)
    elif name == "od_bd2":  # voicing: brighter pre-clip biquad (peak ~2300 Hz)
        w["gate"] = cm.gate_word(overdrive_on=True)
        w["od"] = cm.overdrive_word(65, 100, 60, overdrive_model=2)
    elif name == "od_ocd":  # voicing: upper-mid honk biquad (peak ~1300 Hz)
        w["gate"] = cm.gate_word(overdrive_on=True)
        w["od"] = cm.overdrive_word(65, 100, 65, overdrive_model=4)
    elif name == "distortion_ds1":
        w["gate"] = cm.gate_word(distortion_on=True)
        w["dist"] = cm.distortion_word(50, 50, 60, pedal_mask=1 << 3)  # ds1 = bit 3
    elif name == "dist_metal":  # voicing: ~700 Hz mid-scoop (shared bigMuff notch)
        w["gate"] = cm.gate_word(distortion_on=True)
        w["dist"] = cm.distortion_word(50, 50, 70, pedal_mask=1 << 6)  # metal = bit 6
    elif name == "dist_cleanboost":  # bit 0 (C refactor coverage)
        w["gate"] = cm.gate_word(distortion_on=True)
        w["dist"] = cm.distortion_word(50, 50, 60, pedal_mask=1 << 0)
    elif name == "dist_ts":  # bit 1 tube_screamer (C refactor coverage)
        w["gate"] = cm.gate_word(distortion_on=True)
        w["dist"] = cm.distortion_word(50, 50, 60, pedal_mask=1 << 1)
    elif name == "dist_bigmuff":  # bit 4 (C refactor coverage)
        w["gate"] = cm.gate_word(distortion_on=True)
        w["dist"] = cm.distortion_word(50, 50, 70, pedal_mask=1 << 4)
    elif name == "dist_fuzz":  # bit 5 fuzz_face (C refactor coverage)
        w["gate"] = cm.gate_word(distortion_on=True)
        w["dist"] = cm.distortion_word(50, 50, 70, pedal_mask=1 << 5)
    elif name == "dist_rat":  # dedicated RAT stage (C refactor coverage)
        w["gate"] = cm.gate_word(rat_on=True)
        w["rat"] = cm.rat_word(35, 100, 55, 100)
    elif name == "cab":  # voicing: cone-breakup presence peak (~2.8 kHz biquad)
        w["gate"] = cm.gate_word(cab_on=True)
        w["cab"] = cm.cab_word(100, 100, 1, 50)
    elif name == "reverb":
        w["gate"] = cm.gate_word(reverb_on=True)
        w["reverb"] = cm.reverb_word(50, 65, 30)
    else:
        raise ValueError("unknown config %r" % name)
    return [int(w[k]) & 0xFFFFFFFF for k in ORDER]


def _render(run_sim, cm, name):
    return run_sim.run_dsp(SIM_BIN, _config_words(cm, name), _test_input(), gap=GAP)


def _hash(y):
    return hashlib.sha256(np.asarray(y, dtype="<i8").tobytes()).hexdigest()


@pytest.fixture(scope="session")
def run_sim_mod():
    return ensure_sim(skip=True)


def test_bypass_is_bit_exact(run_sim_mod):
    cm = run_sim_mod.load_control_maps()
    x = _test_input()
    y = _render(run_sim_mod, cm, "bypass")
    assert len(y) == len(x)
    assert np.array_equal(y, x), \
        "safe-bypass (all effects off) is NOT sample-exact passthrough"


@pytest.mark.parametrize("name", CONFIGS)
def test_golden_vector(run_sim_mod, name):
    if not os.path.exists(GOLDEN):
        pytest.skip("no golden_vectors.json -- regen with "
                    "`python3 tests/test_dsp_sim_regression.py --regen`")
    golden = json.load(open(GOLDEN))
    if name not in golden:
        pytest.skip("golden missing for %s -- regen" % name)
    cm = run_sim_mod.load_control_maps()
    h = _hash(_render(run_sim_mod, cm, name))
    assert h == golden[name], (
        "DSP output for %r changed (sha256 %s != golden %s). If this was an "
        "INTENTIONAL voicing change, re-bless: "
        "python3 tests/test_dsp_sim_regression.py --regen"
        % (name, h[:12], golden[name][:12]))


def _regen():
    run_sim = ensure_sim(skip=False)
    cm = run_sim.load_control_maps()
    golden = {}
    for name in CONFIGS:
        h = _hash(_render(run_sim, cm, name))
        golden[name] = h
        print("  %-16s %s" % (name, h))
    with open(GOLDEN, "w") as f:
        json.dump(golden, f, indent=2, sort_keys=True)
        f.write("\n")
    print("wrote %s" % GOLDEN)


if __name__ == "__main__":
    if "--regen" in sys.argv:
        _regen()
    else:
        print(__doc__)
