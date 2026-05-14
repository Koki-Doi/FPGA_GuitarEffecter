#!/usr/bin/env python3
"""Profile the Phase 4 HDMI static framebuffer path on PYNQ-Z2.

This script loads ``AudioLabOverlay`` once, renders a static GUI frame,
copies it into the integrated HDMI framebuffer, starts VDMA/VTC scanout,
and records PS-side resource usage while the static frame is held.

It does not load ``base.bit``, does not load a second overlay, and does
not call ``run_pynq_hdmi()``.
"""
from __future__ import print_function

import argparse
import csv
import json
import os
import resource
import sys
import time


def now_s():
    return time.time()


def percentile(values, pct):
    vals = sorted(float(v) for v in values)
    if not vals:
        return None
    if len(vals) == 1:
        return vals[0]
    rank = (len(vals) - 1) * float(pct) / 100.0
    low = int(rank)
    high = min(low + 1, len(vals) - 1)
    frac = rank - low
    return vals[low] * (1.0 - frac) + vals[high] * frac


def stats(values):
    vals = [float(v) for v in values]
    if not vals:
        return {"count": 0, "avg_s": None, "min_s": None,
                "max_s": None, "p95_s": None}
    return {
        "count": len(vals),
        "avg_s": sum(vals) / len(vals),
        "min_s": min(vals),
        "max_s": max(vals),
        "p95_s": percentile(vals, 95),
    }


def read_proc_stat():
    with open("/proc/stat", "r") as fp:
        fields = fp.readline().split()
    vals = [int(x) for x in fields[1:]]
    idle = vals[3] + (vals[4] if len(vals) > 4 else 0)
    total = sum(vals)
    return total, idle


def cpu_percent(prev, cur):
    if prev is None or cur is None:
        return None
    total_delta = cur[0] - prev[0]
    idle_delta = cur[1] - prev[1]
    if total_delta <= 0:
        return None
    return 100.0 * (total_delta - idle_delta) / total_delta


def read_meminfo():
    out = {}
    with open("/proc/meminfo", "r") as fp:
        for line in fp:
            parts = line.split()
            if len(parts) >= 2:
                out[parts[0].rstrip(":")] = int(parts[1])
    return out


def read_self_status():
    out = {}
    with open("/proc/self/status", "r") as fp:
        for line in fp:
            if ":" not in line:
                continue
            key, rest = line.split(":", 1)
            parts = rest.split()
            if parts and parts[0].isdigit():
                out[key] = int(parts[0])
    return out


def read_temperatures():
    temps = {}
    thermal_base = "/sys/class/thermal"
    if os.path.isdir(thermal_base):
        for name in sorted(os.listdir(thermal_base)):
            path = os.path.join(thermal_base, name, "temp")
            if not os.path.exists(path):
                continue
            try:
                with open(path, "r") as fp:
                    raw = fp.read().strip()
                temps["thermal:{}".format(name)] = int(raw)
            except Exception:
                continue
    hwmon_base = "/sys/class/hwmon"
    if os.path.isdir(hwmon_base):
        for name in sorted(os.listdir(hwmon_base)):
            hwmon_dir = os.path.join(hwmon_base, name)
            label = name
            name_path = os.path.join(hwmon_dir, "name")
            if os.path.exists(name_path):
                try:
                    with open(name_path, "r") as fp:
                        label = "{}:{}".format(name, fp.read().strip())
                except Exception:
                    pass
            for entry in sorted(os.listdir(hwmon_dir)):
                if not (entry.startswith("temp") and entry.endswith("_input")):
                    continue
                path = os.path.join(hwmon_dir, entry)
                try:
                    with open(path, "r") as fp:
                        raw = fp.read().strip()
                    temps["hwmon:{}:{}".format(label, entry)] = int(raw)
                except Exception:
                    continue
    return temps


def sample_resources(prev_cpu=None, prev_proc_cpu=None, interval_s=None):
    mem = read_meminfo()
    status = read_self_status()
    total_cpu = read_proc_stat()
    usage = resource.getrusage(resource.RUSAGE_SELF)
    proc_cpu = float(usage.ru_utime + usage.ru_stime)
    proc_pct = None
    if prev_proc_cpu is not None and interval_s and interval_s > 0:
        proc_pct = 100.0 * (proc_cpu - prev_proc_cpu) / interval_s
    return {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "system_cpu_percent": cpu_percent(prev_cpu, total_cpu),
        "process_cpu_percent": proc_pct,
        "mem_free_kb": mem.get("MemFree"),
        "mem_available_kb": mem.get("MemAvailable"),
        "process_vmrss_kb": status.get("VmRSS"),
        "process_vmhwm_kb": status.get("VmHWM"),
        "process_ru_maxrss_kb": int(usage.ru_maxrss),
        "temperatures_millic": read_temperatures(),
        "_cpu_raw": total_cpu,
        "_proc_cpu_raw": proc_cpu,
    }


def strip_private_sample(sample):
    clean = dict(sample)
    clean.pop("_cpu_raw", None)
    clean.pop("_proc_cpu_raw", None)
    return clean


def csv_value(value):
    if isinstance(value, dict):
        return json.dumps(value, sort_keys=True)
    return value


def make_app_state_default(script_dir):
    from pynq_multi_fx_gui import AppState  # noqa
    return AppState()


def mutate_state(state, index):
    # Touch only visual state fields so the renderer cache sees a real
    # change while no DSP control API is called.
    state.selected_knob = int(index % 6)
    values = list(getattr(state, "knob_values", [50, 50, 50, 50, 50, 50]))
    if values:
        values[state.selected_knob % len(values)] = (values[state.selected_knob % len(values)] + 7 + index) % 101
        state.knob_values = values
    state.t = float(index) * 0.25


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--hold-seconds", type=int, default=60)
    parser.add_argument("--iterations", type=int, default=10)
    parser.add_argument("--out-dir", default="/tmp/hdmi_phase4c_resource_profile")
    args = parser.parse_args()

    out_dir = os.path.abspath(args.out_dir)
    if not os.path.isdir(out_dir):
        os.makedirs(out_dir)
    log_path = os.path.join(out_dir, "static_frame.log")
    csv_path = os.path.join(out_dir, "resource_profile.csv")
    json_path = os.path.join(out_dir, "resource_summary.json")
    run_started_at = time.strftime("%Y-%m-%dT%H:%M:%S")

    log_fp = open(log_path, "w")

    def log(msg):
        print(msg)
        log_fp.write(str(msg) + "\n")
        log_fp.flush()

    start_wall = now_s()
    start_usage = resource.getrusage(resource.RUSAGE_SELF)
    before_sample = sample_resources()
    log("[phase4c] resource profile starting")
    log("[phase4c] out_dir={}".format(out_dir))

    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(script_dir, ".."))
    for path in (repo_root, os.path.join(repo_root, "GUI"),
                 "/home/xilinx/Audio-Lab-PYNQ/GUI"):
        if path not in sys.path:
            sys.path.insert(0, path)

    t0 = now_s()
    from audio_lab_pynq import AudioLabOverlay
    overlay_import_s = now_s() - t0

    t0 = now_s()
    overlay = AudioLabOverlay()
    overlay_load_s = now_s() - t0
    log("[phase4c] AudioLabOverlay import={:.3f}s load={:.3f}s".format(
        overlay_import_s, overlay_load_s))

    smoke = {
        "ADC HPF": bool(overlay.codec.get_adc_hpf_state()),
        "R19": "0x{:02x}".format(int(overlay.codec.R19_ADC_CONTROL[0]) & 0xFF),
        "has axi_gpio_delay_line": hasattr(overlay, "axi_gpio_delay_line"),
        "has legacy axi_gpio_delay": hasattr(overlay, "axi_gpio_delay"),
        "has axi_gpio_noise_suppressor": hasattr(overlay, "axi_gpio_noise_suppressor"),
        "has axi_gpio_compressor": hasattr(overlay, "axi_gpio_compressor"),
        "has axi_vdma_hdmi ip_dict": "axi_vdma_hdmi" in getattr(overlay, "ip_dict", {}),
        "has v_tc_hdmi ip_dict": "v_tc_hdmi" in getattr(overlay, "ip_dict", {}),
    }
    log(json.dumps({"smoke": smoke}, indent=2, sort_keys=True))
    if not (smoke["ADC HPF"] and smoke["R19"] == "0x23" and
            not smoke["has axi_gpio_delay_line"] and
            smoke["has legacy axi_gpio_delay"] and
            smoke["has axi_vdma_hdmi ip_dict"] and
            smoke["has v_tc_hdmi ip_dict"]):
        raise SystemExit("[phase4c] smoke failed; refusing HDMI profile")

    from pynq_multi_fx_gui import make_pynq_static_render_cache, render_frame_pynq_static
    from audio_lab_pynq.hdmi_backend import AudioLabHdmiBackend, _allocate_framebuffer

    state = make_app_state_default(script_dir)
    cache = make_pynq_static_render_cache()

    t0 = now_s()
    frame = render_frame_pynq_static(state, cache=cache)
    cold_render_s = now_s() - t0
    log("[phase4c] cold render {:.3f}s shape={} dtype={}".format(
        cold_render_s, list(frame.shape), frame.dtype))
    if list(frame.shape) != [720, 1280, 3] or str(frame.dtype) != "uint8":
        raise SystemExit("[phase4c] renderer returned unexpected frame")

    cached_times = []
    for _idx in range(int(args.iterations)):
        t0 = now_s()
        render_frame_pynq_static(state, cache=cache)
        cached_times.append(now_s() - t0)

    change_times = []
    for idx in range(int(args.iterations)):
        mutate_state(state, idx)
        t0 = now_s()
        frame = render_frame_pynq_static(state, cache=cache)
        change_times.append(now_s() - t0)

    backend = AudioLabHdmiBackend(overlay)
    t0 = now_s()
    backend._framebuffer = _allocate_framebuffer(
        backend.width, backend.height, backend.bytes_per_pixel)
    framebuffer_allocate_s = now_s() - t0

    copy_times = []
    for _idx in range(int(args.iterations)):
        t0 = now_s()
        backend.write_frame(frame)
        copy_times.append(now_s() - t0)

    phys = int(backend._framebuffer.physical_address)
    t0 = now_s()
    backend._program_vdma(phys)
    backend._start_vtc()
    backend._started = True
    vdma_init_start_s = now_s() - t0
    status = backend.status()
    errors = backend.errors()
    log(json.dumps({"hdmi_status": status, "hdmi_errors": errors},
                   indent=2, sort_keys=True))
    if errors.get("dmainterr") or errors.get("dmaslverr") or errors.get("dmadecerr"):
        raise SystemExit("[phase4c] VDMA error bits set")

    hold_rows = []
    prev = sample_resources()
    prev_cpu = prev["_cpu_raw"]
    prev_proc = prev["_proc_cpu_raw"]
    hold_start = now_s()
    for idx in range(int(args.hold_seconds)):
        time.sleep(1.0)
        t1 = now_s()
        interval = t1 - (hold_start + idx)
        sample = sample_resources(prev_cpu=prev_cpu,
                                  prev_proc_cpu=prev_proc,
                                  interval_s=interval)
        prev_cpu = sample["_cpu_raw"]
        prev_proc = sample["_proc_cpu_raw"]
        row = strip_private_sample(sample)
        row["phase"] = "hold"
        row["elapsed_s"] = t1 - hold_start
        hold_rows.append(row)

    after_sample = sample_resources()
    end_usage = resource.getrusage(resource.RUSAGE_SELF)
    wall_s = now_s() - start_wall
    cpu_user_s = end_usage.ru_utime - start_usage.ru_utime
    cpu_system_s = end_usage.ru_stime - start_usage.ru_stime
    process_cpu_percent_total = 100.0 * (cpu_user_s + cpu_system_s) / wall_s

    with open(csv_path, "w") as fp:
        fieldnames = [
            "timestamp", "phase", "elapsed_s", "system_cpu_percent",
            "process_cpu_percent", "mem_free_kb", "mem_available_kb",
            "process_vmrss_kb", "process_vmhwm_kb",
            "process_ru_maxrss_kb", "temperatures_millic",
        ]
        writer = csv.DictWriter(fp, fieldnames=fieldnames)
        writer.writeheader()
        for row in hold_rows:
            writer.writerow({k: csv_value(row.get(k)) for k in fieldnames})

    hold_system_cpu = [r["system_cpu_percent"] for r in hold_rows
                       if r.get("system_cpu_percent") is not None]
    hold_proc_cpu = [r["process_cpu_percent"] for r in hold_rows
                     if r.get("process_cpu_percent") is not None]

    summary = {
        "phase": "4C",
        "started_at": run_started_at,
        "out_dir": out_dir,
        "iterations": int(args.iterations),
        "hold_seconds_requested": int(args.hold_seconds),
        "hold_samples": len(hold_rows),
        "overlay_import_s": overlay_import_s,
        "overlay_load_s": overlay_load_s,
        "smoke": smoke,
        "cold_render_s": cold_render_s,
        "cached_same_state_render": stats(cached_times),
        "change_driven_render": stats(change_times),
        "framebuffer_allocate_s": framebuffer_allocate_s,
        "framebuffer_copy": stats(copy_times),
        "vdma_init_start_s": vdma_init_start_s,
        "hdmi_status": status,
        "hdmi_errors": errors,
        "resource_before": strip_private_sample(before_sample),
        "resource_after": strip_private_sample(after_sample),
        "wall_time_s": wall_s,
        "process_cpu_user_s": cpu_user_s,
        "process_cpu_system_s": cpu_system_s,
        "process_cpu_percent_total": process_cpu_percent_total,
        "process_max_rss_kb": int(end_usage.ru_maxrss),
        "hold_system_cpu_percent": {
            "avg": (sum(hold_system_cpu) / len(hold_system_cpu)
                    if hold_system_cpu else None),
            "max": max(hold_system_cpu) if hold_system_cpu else None,
        },
        "hold_process_cpu_percent": {
            "avg": (sum(hold_proc_cpu) / len(hold_proc_cpu)
                    if hold_proc_cpu else None),
            "max": max(hold_proc_cpu) if hold_proc_cpu else None,
        },
        "physical_hdmi_display_status": "not verified by this script; user visual confirmation pending",
    }
    with open(json_path, "w") as fp:
        json.dump(summary, fp, indent=2, sort_keys=True, default=repr)

    log(json.dumps({"summary": summary}, indent=2, sort_keys=True, default=repr))
    log("[phase4c] wrote {}".format(csv_path))
    log("[phase4c] wrote {}".format(json_path))
    log("[phase4c] OK")
    log_fp.close()


if __name__ == "__main__":
    main()
