"""Read-only reporting / summary helpers for the HDMI effect-state mirror.

Refactor M (2026-06-22): the ``HdmiEffectStateMirror`` reporting methods
(``get_state_summary`` / ``resource_summary`` / ``summary`` / ``summary_json``
plus the SELECTED FX history printers) were ~145 lines of read-only dict/JSON
building off ``self.*`` attributes. They are pulled out here as ``mirror``-taking
functions so the class keeps thin delegates (the established per-effect
``hdmi_state/`` split pattern). Behaviour is byte-for-byte unchanged -- the
functions read (and, for ``resource_summary``, write ``mirror.last_resource_sample``)
exactly the same attributes the methods did.
"""

import json

from audio_lab_pynq.hdmi_state.resource_sampler import STATIC_PL_UTILIZATION


def get_state_summary(mirror):
    status = {}
    errors = {}
    if mirror.hdmi_backend is not None:
        try:
            status = mirror.hdmi_backend.status()
        except Exception as exc:
            status = {"error": str(exc)}
        try:
            errors = mirror.hdmi_backend.errors()
        except Exception as exc:
            errors = {"error": str(exc)}
    return {
        "last_edited_effect": mirror.last_edited_effect,
        "selected_fx_actual": mirror.get_selected_fx_actual(),
        "selected_fx_expected": mirror.last_selected_fx_expected,
        "current_pedal_model": mirror.current_pedal_model,
        "current_amp_model": mirror.current_amp_model,
        "current_cab_model": mirror.current_cab_model,
        "current_pedal_label": mirror.current_pedal_label,
        "current_amp_label": mirror.current_amp_label,
        "current_cab_label": mirror.current_cab_label,
        "active_pedals": list(mirror.active_pedals),
        "selected_fx_history": list(mirror.selected_fx_history),
        "render_count": len(mirror.render_history),
        "last_render_info": dict(mirror.last_render_info),
        "hdmi_status": status,
        "hdmi_errors": errors,
        "app_state": {
            "preset_id": getattr(mirror.app_state, "preset_id", None),
            "preset_name": getattr(mirror.app_state, "preset_name", None),
            "preset_idx": getattr(mirror.app_state, "preset_idx", None),
            "selected_effect": getattr(mirror.app_state, "selected_effect", None),
            "selected_fx": getattr(mirror.app_state, "selected_fx", None),
            "pedal_model": getattr(mirror.app_state, "pedal_model", None),
            "amp_model": getattr(mirror.app_state, "amp_model", None),
            "cab_model": getattr(mirror.app_state, "cab_model", None),
            "pedal_model_label": getattr(
                mirror.app_state, "pedal_model_label", None),
            "amp_model_label": getattr(
                mirror.app_state, "amp_model_label", None),
            "cab_model_label": getattr(
                mirror.app_state, "cab_model_label", None),
            "active_model_category": getattr(
                mirror.app_state, "active_model_category", None),
            "active_pedals": list(
                getattr(mirror.app_state, "active_pedals", []) or []),
            "effect_on": list(getattr(mirror.app_state, "effect_on", []) or []),
            "knob_values": list(getattr(mirror.app_state, "knob_values", []) or []),
        },
    }


def print_selected_fx_history(mirror):
    print("SELECTED FX history:")
    for item in mirror.selected_fx_history:
        print("[{index:02d}] {selected_fx}  reason={reason}".format(**item))


def selected_history(mirror):
    """Return a copy of the SELECTED FX history list."""
    return [dict(item) for item in mirror.selected_fx_history]


def resource_summary(mirror):
    """Return a snapshot of PS / GUI / HDMI resource usage.

    The dict is safe to print or render in a Notebook widget. Includes
    the latest /proc CPU and memory sample, the last render/compose/
    framebuffer-copy timings, VDMA / VTC status, and the SELECTED FX
    bookkeeping fields the user typically wants to display alongside
    these numbers.
    """
    sample = mirror.resource_sampler.sample()
    mirror.last_resource_sample = sample
    info = dict(mirror.last_render_info or {})
    status = info.get("hdmi_status") or {}
    errors = info.get("hdmi_errors") or {}
    last_write = info.get("last_frame_write") or status.get(
        "last_frame_write", {}) or {}
    return {
        "time_s": sample.get("time_s"),
        "proc_rss_kb": sample.get("proc_rss_kb"),
        "proc_vmsize_kb": sample.get("proc_vmsize_kb"),
        "mem_total_kb": sample.get("mem_total_kb"),
        "mem_avail_kb": sample.get("mem_avail_kb"),
        "mem_free_kb": sample.get("mem_free_kb"),
        "sys_cpu_pct": sample.get("sys_cpu_pct"),
        "proc_cpu_pct": sample.get("proc_cpu_pct"),
        "cpu_count": sample.get("cpu_count"),
        "temperature_c": sample.get("temperature_c"),
        "render_s": info.get("render_s"),
        "backend_update_s": info.get("backend_update_s"),
        "compose_s": info.get("compose_s"),
        "framebuffer_copy_s": info.get("framebuffer_copy_s"),
        "total_update_s": info.get("total_update_s"),
        "vdma_dmacr": status.get("vdma_dmacr"),
        "vdma_dmasr": status.get("vdma_dmasr"),
        "vdma_error_raw": errors.get("raw"),
        "vdma_error_bits": {
            "halted": errors.get("halted"),
            "idle": errors.get("idle"),
            "dmainterr": errors.get("dmainterr"),
            "dmaslverr": errors.get("dmaslverr"),
            "dmadecerr": errors.get("dmadecerr"),
        },
        "vtc_ctl": status.get("vtc_ctl"),
        "last_frame_write": last_write,
        "selected_fx": mirror.get_selected_fx_actual(),
        "selected_model_category": getattr(
            mirror.app_state, "selected_model_category", None),
        "dropdown_label": getattr(mirror.app_state, "dropdown_label", None),
        "dropdown_short_label": getattr(
            mirror.app_state, "dropdown_short_label", None),
        "current_pedal_model": mirror.current_pedal_model,
        "current_amp_model": mirror.current_amp_model,
        "current_cab_model": mirror.current_cab_model,
        "current_pedal_label": mirror.current_pedal_label,
        "current_amp_label": mirror.current_amp_label,
        "current_cab_label": mirror.current_cab_label,
        "last_edited_effect": mirror.last_edited_effect,
        "render_count": len(mirror.render_history),
        "pl_utilization": dict(STATIC_PL_UTILIZATION),
    }


def summary(mirror):
    """Phase 6C: combined state + resource snapshot for Notebook UIs."""
    data = get_state_summary(mirror)
    data["resource"] = resource_summary(mirror)
    return data


def summary_json(mirror):
    return json.dumps(get_state_summary(mirror), indent=2, sort_keys=True,
                      default=str)
