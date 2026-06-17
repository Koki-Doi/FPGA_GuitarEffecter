#!/usr/bin/env python3
"""Compare real-hardware captures against the Clash dsp_sim executable.

Input is a directory produced by scripts/collect_real_hw_reference.py. For each
successful digital case, this script reruns tools/dsp_sim/dsp_sim with the
captured input and the exact topEntity control words stored in the manifest,
then aligns hardware and sim output and writes CSV/JSON comparison summaries.
"""

import argparse
import csv
import json
import math
import multiprocessing
import os
import sys
import wave

import numpy as np


REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DSP_SIM_DIR = os.path.join(REPO, "tools", "dsp_sim")
if DSP_SIM_DIR not in sys.path:
    sys.path.insert(0, DSP_SIM_DIR)

import run_sim  # noqa: E402


FS24 = (1 << 23) - 1
WORD_ORDER = ["gate", "od", "dist", "eq", "rat", "amp",
              "amp_tone", "cab", "reverb", "ns", "comp", "wah"]


def _dbfs(value):
    value = float(abs(value))
    if value <= 0.0:
        return float("-inf")
    return 20.0 * math.log10(value / float(FS24))


def _read_json(path):
    with open(path, "r") as f:
        return json.load(f)


def _write_json(path, obj):
    with open(path, "w") as f:
        json.dump(obj, f, indent=2, sort_keys=True)
        f.write("\n")


def _write_wav(path, x24, fs):
    x16 = np.clip(np.asarray(x24, dtype=np.int64) >> 8,
                  -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(fs)
        w.writeframes(x16.tobytes())


def _mono_left(x):
    x = np.asarray(x)
    if x.ndim == 1:
        return x.astype(np.int64)
    return x[:, 0].astype(np.int64)


def _mono_right(x):
    x = np.asarray(x)
    if x.ndim == 1:
        return x.astype(np.int64)
    return x[:, 1].astype(np.int64)


def _rms(x):
    x = np.asarray(x, dtype=np.float64)
    if x.size == 0:
        return 0.0
    return float(np.sqrt(np.mean(x * x)))


def _align(ref, got, max_lag):
    """Return aligned ref/got plus lag. Positive lag means got is delayed."""
    ref = np.asarray(ref, dtype=np.int64)
    got = np.asarray(got, dtype=np.int64)
    if ref.size == 0 or got.size == 0:
        return ref[:0], got[:0], 0

    # Full correlation is O(N^2); a short active window is enough to find the
    # DMA/chain latency and keeps large full-suite captures practical.
    n = int(min(ref.size, got.size, 8192))
    if n < 8:
        return ref[:n], got[:n], 0
    r = ref[:n].astype(np.float64)
    g = got[:n].astype(np.float64)
    r -= np.mean(r)
    g -= np.mean(g)
    if np.max(np.abs(r)) <= 1.0 or np.max(np.abs(g)) <= 1.0:
        lag = 0
    else:
        corr = np.correlate(g, r, mode="full")
        mid = n - 1
        lo = max(0, mid - int(max_lag))
        hi = min(corr.size, mid + int(max_lag) + 1)
        lag = int(np.argmax(np.abs(corr[lo:hi])) + lo - mid)

    if lag >= 0:
        got_a = got[lag:]
        ref_a = ref[:got_a.size]
    else:
        ref_a = ref[-lag:]
        got_a = got[:ref_a.size]
    n2 = int(min(ref_a.size, got_a.size))
    return ref_a[:n2], got_a[:n2], lag


def _metrics(sim, hw):
    sim = np.asarray(sim, dtype=np.int64)
    hw = np.asarray(hw, dtype=np.int64)
    n = int(min(sim.size, hw.size))
    sim = sim[:n]
    hw = hw[:n]
    diff = hw - sim
    rms_sim = _rms(sim)
    rms_hw = _rms(hw)
    rms_diff = _rms(diff)
    corr = 0.0
    if n > 1 and rms_sim > 0.0 and rms_hw > 0.0:
        corr = float(np.corrcoef(sim.astype(np.float64),
                                 hw.astype(np.float64))[0, 1])
    rel = float("inf")
    if rms_hw > 0.0:
        rel = 20.0 * math.log10((rms_diff + 1.0) / rms_hw)
    level_delta = 0.0
    if rms_sim > 0.0 and rms_hw > 0.0:
        level_delta = 20.0 * math.log10(rms_hw / rms_sim)
    return dict(
        samples=n,
        sim_peak_dBFS=_dbfs(np.max(np.abs(sim)) if n else 0),
        hw_peak_dBFS=_dbfs(np.max(np.abs(hw)) if n else 0),
        sim_rms_dBFS=_dbfs(rms_sim),
        hw_rms_dBFS=_dbfs(rms_hw),
        level_delta_dB=level_delta,
        error_rms_dBFS=_dbfs(rms_diff),
        error_to_hw_dB=rel,
        max_abs_diff_lsb=int(np.max(np.abs(diff))) if n else 0,
        mean_abs_diff_lsb=float(np.mean(np.abs(diff))) if n else 0.0,
        correlation=corr,
    )


def _words_from_case(case):
    words = case.get("control_words_topentity")
    if words:
        return [int(w) & 0xFFFFFFFF for w in words]
    by_name = case.get("control_words") or {}
    mapping = dict(
        gate="gate",
        od="overdrive",
        dist="distortion",
        eq="eq",
        rat="rat",
        amp="amp",
        amp_tone="amp_tone",
        cab="cab",
        reverb="reverb",
        ns="ns",
        comp="comp",
        wah="wah",
    )
    out = []
    for name in WORD_ORDER:
        out.append(int(by_name[mapping[name]]) & 0xFFFFFFFF)
    return out


def _suffix(args):
    label = str(getattr(args, "label", "") or "").strip()
    if not label:
        return ""
    safe = "".join(ch if (ch.isalnum() or ch in ("-", "_")) else "_"
                   for ch in label)
    return "_" + safe


def compare_one(root, case, args):
    input_path = os.path.join(root, case["input_file"])
    hw_path = os.path.join(root, case["hw_output_file"])
    x = np.load(input_path)
    hw = np.load(hw_path)
    x_mono = _mono_left(x)
    words = _words_from_case(case)
    sim = run_sim.run_dsp(args.sim_bin, words, x_mono, gap=args.gap)

    channels = [("left", _mono_left(hw)), ("right", _mono_right(hw))]
    best = None
    details = {}
    for label, hw_ch in channels:
        sim_a, hw_a, lag = _align(sim, hw_ch, args.max_lag)
        m = _metrics(sim_a, hw_a)
        m["lag_samples"] = lag
        details[label] = m
        if best is None or m["correlation"] > details[best]["correlation"]:
            best = label

    case_dir = os.path.join(root, case["case_dir"])
    suffix = _suffix(args)
    sim_npy = os.path.join(case_dir, "sim_output{}.npy".format(suffix))
    np.save(sim_npy, sim.astype(np.int64))
    if args.save_wav:
        fs = int((case.get("environment") or {}).get("sample_rate_hz") or
                 args.sample_rate)
        _write_wav(os.path.join(case_dir, "sim_output{}.wav".format(suffix)),
                   sim, fs)

    out = dict(
        name=case["name"],
        stage=case.get("stage"),
        stimulus=case.get("stimulus"),
        route_effect=case.get("route_effect"),
        best_channel=best,
        sim_output_file=os.path.relpath(sim_npy, root),
        metrics=details,
    )
    _write_json(os.path.join(case_dir, "comparison{}.json".format(suffix)), out)
    row = dict(name=out["name"], stage=out["stage"], stimulus=out["stimulus"],
               route_effect=out["route_effect"], best_channel=best)
    for key, value in details[best].items():
        row[key] = value
    return out, row


def _worker(payload):
    root, case, args = payload
    return compare_one(root, case, args)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("capture_dir",
                   help="Directory containing capture_manifest.json.")
    p.add_argument("--sim-bin", default=os.path.join(DSP_SIM_DIR, "dsp_sim"),
                   help="Path to built dsp_sim executable.")
    p.add_argument("--gap", type=int, default=run_sim.GAP,
                   help="dsp_sim idle cycles after each valid sample.")
    p.add_argument("--max-lag", type=int, default=4096,
                   help="Max lag in samples for correlation alignment.")
    p.add_argument("--case-filter", action="append", default=[],
                   help="Only compare cases whose name contains this substring.")
    p.add_argument("--max-cases", type=int, default=0)
    p.add_argument("--save-wav", action="store_true",
                   help="Also write sim_output.wav beside each case.")
    p.add_argument("--sample-rate", type=int, default=96000)
    p.add_argument("--jobs", type=int, default=1,
                   help="Parallel case comparisons. Default: 1.")
    p.add_argument("--label", default="",
                   help="Optional output label. Writes comparison_<label>.json, "
                        "sim_output_<label>.npy, and comparison_summary_<label>.*")
    args = p.parse_args()

    root = os.path.abspath(args.capture_dir)
    manifest_path = os.path.join(root, "capture_manifest.json")
    if not os.path.exists(manifest_path):
        sys.exit("manifest not found: {}".format(manifest_path))
    if not os.path.exists(args.sim_bin):
        sys.exit("sim binary not found: {}".format(args.sim_bin))

    manifest = _read_json(manifest_path)
    cases = [c for c in manifest.get("cases", []) if c.get("status") == "ok"]
    if args.case_filter:
        cases = [c for c in cases
                 if any(token in c["name"] for token in args.case_filter)]
    if args.max_cases and args.max_cases > 0:
        cases = cases[:args.max_cases]

    summary = dict(
        capture_dir=root,
        sim_bin=os.path.abspath(args.sim_bin),
        gap=args.gap,
        max_lag=args.max_lag,
        label=args.label,
        compared=[],
    )
    rows = []
    if args.jobs and args.jobs > 1 and len(cases) > 1:
        payloads = [(root, case, args) for case in cases]
        pool = multiprocessing.Pool(processes=int(args.jobs))
        try:
            for idx, (item, row) in enumerate(pool.imap_unordered(_worker, payloads)):
                print("[compare] {}/{} {}".format(
                    idx + 1, len(cases), item["name"]))
                summary["compared"].append(item)
                rows.append(row)
        finally:
            pool.close()
            pool.join()
    else:
        for idx, case in enumerate(cases):
            print("[compare] {}/{} {}".format(idx + 1, len(cases), case["name"]))
            item, row = compare_one(root, case, args)
            summary["compared"].append(item)
            rows.append(row)

    suffix = _suffix(args)
    json_path = os.path.join(root, "comparison_summary{}.json".format(suffix))
    csv_path = os.path.join(root, "comparison_summary{}.csv".format(suffix))
    _write_json(json_path, summary)
    if rows:
        fieldnames = ["name", "stage", "stimulus", "route_effect",
                      "best_channel", "samples", "lag_samples",
                      "correlation", "level_delta_dB", "error_to_hw_dB",
                      "error_rms_dBFS", "max_abs_diff_lsb",
                      "mean_abs_diff_lsb", "sim_peak_dBFS",
                      "hw_peak_dBFS", "sim_rms_dBFS", "hw_rms_dBFS"]
        with open(csv_path, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=fieldnames)
            w.writeheader()
            for row in rows:
                w.writerow(row)
    print("[compare] wrote {}".format(json_path))
    print("[compare] wrote {}".format(csv_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
