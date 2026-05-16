# HDMI GUI Phase 6C realtime notebook pedalboard

Date: 2026-05-15

## Purpose

Phase 6C extends the Phase 6B notebook-driven HDMI state mirror so a
single Jupyter notebook now provides GuitarPedalboardOneCell-style
ipywidgets controls -- pedal / amp / cab model dropdowns, ON/OFF
toggles, parameter sliders, and a PS / GUI / HDMI resource monitor --
that drive the integrated AudioLab DSP and, on every operation, refresh
the 800x480 HDMI GUI.

The control direction is still one-way:

```text
Notebook ipywidgets  -> HdmiEffectStateMirror
                     -> AudioLabOverlay existing API (real DSP edit)
                     -> AppState (SELECTED FX, model labels, dropdown)
                     -> HDMIBackend.write_frame (manual, 0,0)
```

The HDMI GUI remains display-only. The new ``[model ▼]`` chip drawn
next to ``SELECTED FX`` mirrors whatever the Notebook last applied;
nothing on HDMI accepts events back. No GPIO writes per frame, no
continuous render loop, no second overlay.

## Existing API / bitstream support

No Vivado rebuild, Clash edit, ``block_design.tcl`` edit,
``audio_lab.xdc`` edit, or bit/hwh regeneration was required for
Phase 6C. The Phase 6B audit (``HDMI_GUI_PHASE6B_MODEL_SELECTION_UI.md``)
already verified that every requested pedal / amp / cab model is
reachable through the deployed ``AudioLabOverlay`` API and the existing
GPIO contracts. Phase 6C re-confirmed this before implementing the
realtime controls.

| Category | Models | Existing API hook |
| --- | --- | --- |
| Pedal | clean_boost, tube_screamer, rat, ds1, big_muff, fuzz_face, metal | ``set_distortion_settings`` + ``set_guitar_effects(distortion_on / distortion_pedal_mask / rat_on)`` |
| Amp | jc_clean, clean_combo, british_crunch, high_gain_stack | ``set_amp_model(name, ...)`` |
| Cab | 1x12 (model 0), 2x12 (model 1), 4x12 (model 2) | ``set_guitar_effects(cab_on=True, cab_model=N, ...)`` |
| Effects | reverb, EQ, compressor, noise suppressor | ``set_guitar_effects`` / ``set_compressor_settings`` / ``set_noise_suppressor_settings`` |

If a future model is requested that is **not** exposed through these
existing APIs, the agent must stop and request a bit/hwh change before
implementing -- the Phase 6C realtime UI does not paper over a missing
DSP path.

## SELECTED FX dropdown chip

Renderer changes live in ``GUI/pynq_multi_fx_gui.py``:

- ``_dropdown_category(state)`` maps ``SELECTED FX`` to one of
  ``PEDAL`` / ``AMP`` / ``CAB`` / ``REVERB`` / ``EQ`` /
  ``COMPRESSOR`` / ``NOISE SUPPRESSOR`` / ``OVERDRIVE`` / ``SAFE`` /
  ``PRESET``.
- ``_dropdown_label(state)`` picks the chip text. For model-driven
  categories it follows the current pedal / amp / cab model; otherwise
  it echoes the effect family.
- ``_dropdown_short()`` truncates long labels so the chip fits the
  150 px wide slot (e.g. ``HIGH GAIN STACK`` -> ``HI-GAIN``,
  ``BRITISH CRUNCH`` -> ``BRIT CRUNCH``, ``2x12 COMBO`` -> ``2x12 CMB``,
  ``CLEAN BOOST`` -> ``CLN BOOST``, ``FUZZ FACE`` -> ``FUZZ``,
  ``SAFE BYPASS`` -> ``SAFE``).
- ``_draw_dropdown_chip()`` renders ``[text ▼]`` using a rounded
  rectangle plus a filled triangle polygon (Pillow 5.1 default bitmap
  font cannot draw ``▼`` reliably).

The chip sits between the SELECTED FX name (size 28) and the ON/BYPASS
chip at the top-right of the compact-v2 800x480 fx panel. Right edge
stays at ``fx1 - 16 - 110 - 12 = x=638``, well inside the 800 px
canvas; ``test_renderer_compact_v2_dropdown_chip_does_not_overflow``
makes that contract testable.

``AppState`` gained three new defaults (`selected_model_category`,
`dropdown_label`, `dropdown_short_label`). The compact-v2
``state_semistatic_signature`` includes them so the render cache
invalidates whenever the dropdown changes.

## Mirror extensions

`audio_lab_pynq/hdmi_effect_state_mirror.py` now owns:

- ``SELECTED_FX_CATEGORY`` and ``DROPDOWN_SHORT_LABELS`` mappings.
- ``selected_fx_category(value)``, ``dropdown_short_label(value)``,
  ``dropdown_label_for(selected_fx, pedal_label, amp_label, cab_label)``
  helpers.
- ``_update_dropdown_app_state(selected_fx=None)`` writes
  ``selected_model_category`` / ``dropdown_label`` /
  ``dropdown_short_label`` onto ``AppState`` after every model edit and
  every ``mark_selected_fx`` call.
- ``ResourceSampler`` -- a tiny ``/proc``-based CPU / RSS / MemAvailable
  / temperature sampler with no ``psutil`` dependency. Pure-text parsers
  (``_parse_proc_meminfo_text``, ``_parse_proc_status_text``,
  ``_parse_proc_stat_cpu_line``, ``_parse_proc_self_stat_times``) are
  unit-tested in isolation.
- ``resource_summary()`` / ``summary()`` / ``selected_history()``
  methods. ``render()`` now records ``total_update_s`` and a
  ``resource_sample`` snapshot per render.
- ``STATIC_PL_UTILIZATION`` constant (sourced from the latest deployed
  ``audio_lab.bit`` Vivado utilization report; LUT 18619, registers
  20846, BRAM 9, DSP 83).

## Notebook

New notebook: ``notebooks/HdmiRealtimePedalboardOneCell.ipynb`` --
exactly one code cell, no markdown cells, no second overlay, default
``placement="manual"``, ``offset_x=0``, ``offset_y=0``.

Sections:

| Section | Controls |
| --- | --- |
| A. Global / Preset | Safe Bypass, Basic Clean, Preset dropdown + Apply, Render, Summary, status label |
| B. Selected FX / Model Dropdown | category dropdown (PEDAL/AMP/CAB/REVERB/EQ/COMPRESSOR/NOISE SUPPRESSOR), model dropdown (live-filtered), Apply Selected Model button, instant-apply observer with ``THROTTLE_SECONDS`` debounce |
| C. Pedal controls | ON/OFF, drive / tone / level / mix sliders, Apply Pedal |
| D. Amp controls | ON/OFF, gain / bass / mid / treble / master sliders, Apply Amp |
| E. Cab controls | ON/OFF, cab model dropdown, air slider, Apply Cab |
| F. Reverb / EQ | reverb mix / decay / tone + EQ low / mid / high |
| G. Resource Monitor | HTML table -- selected FX, dropdown label, model labels, render/compose/copy times, total_update, VDMA DMASR, VDMA error bits, VTC ctl, last_frame_write placement/offset, proc/sys CPU %, proc RSS, MemAvailable, MemTotal, temperature, static PL LUT/Reg/BRAM/DSP |

Knobs trigger ``mirror.set_pedal_model`` / ``set_amp_model`` /
``set_cab_model`` / ``reverb`` / ``eq`` -- the same Phase 6B mirror
methods that call into the deployed AudioLab DSP. **Nothing in the
Notebook updates display state without also calling the real
AudioLabOverlay API.** A unit test
(``test_mirror_set_pedal_model_invokes_real_overlay_apis``) explicitly
guards against the display-only regression.

## CLI scripts

- ``scripts/test_hdmi_realtime_pedalboard_controls.py`` -- replays the
  ipywidgets sequence (safe_bypass, every pedal model, every amp model,
  every cab model, reverb) through ``HdmiEffectStateMirror`` on PYNQ.
  Each step asserts expected SELECTED FX, the new
  ``selected_model_category``, and the dropdown chip label. VDMA error
  bits are caught. The resource sampler is dumped at the end.
- ``scripts/test_hdmi_800x480_origin_guard.py`` -- mechanical right-skew
  detector. Generates a synthetic frame with marker columns at
  x=0/10/20/799, asserts ``placement="manual"``,
  ``offset_x=offset_y=0``, ``framebuffer_copied_region.x0 = y0 = 0``,
  ``vdma_error_asserted=False``, then drops back to the real GUI frame
  so the user can verify the panel. ``--dry-run`` mode runs on a
  workstation without ``pynq`` (uses ``importlib`` to load
  ``compose_logical_frame`` directly).

## Unit tests

| Test file | What it covers |
| --- | --- |
| ``tests/test_hdmi_selected_fx_state.py`` | SELECTED FX aliasing, history, mark_selected_fx assertion, set_guitar_effects priority -- existing Phase 6A/B tests still PASS. |
| ``tests/test_hdmi_model_state_mapping.py`` | Model name normalize, pedal/amp/cab state, history -- existing Phase 6B tests still PASS. |
| ``tests/test_hdmi_origin_mapping.py`` (new) | ``compose_logical_frame`` manual 0,0 places at x=0,y=0; negative offsets clip the source; the compact-v2 renderer paints across the full 0..799 range; the dropdown chip does not overflow x=799. |
| ``tests/test_hdmi_resource_monitor.py`` (new) | ``/proc`` parsers, ``ResourceSampler`` first-sample-is-None contract, SELECTED FX category mapping, dropdown short-label fallback, ``dropdown_label_for`` routing, AppState dropdown fields updated on pedal/amp/cab/safe edits, ``resource_summary`` keys, ``render()`` records ``resource_sample`` and ``total_update_s``, ``set_pedal_model`` invokes real overlay APIs (display-only regression guard). |

Local results:

```
PASS test_normalize_selected_fx_aliases
PASS test_method_mapping_and_history_order
PASS test_mark_selected_fx_and_assertion_failure
PASS test_render_validates_expected_selected_fx
PASS test_set_guitar_effects_last_kwarg_category_wins
PASS test_model_name_normalize_and_labels
PASS test_unsupported_model_raises_value_error
PASS test_pedal_model_updates_selected_fx_and_app_state
PASS test_amp_model_updates_selected_fx_and_app_state
PASS test_cab_model_updates_selected_fx_and_app_state
PASS test_selected_fx_history_for_models
PASS test_compose_logical_manual_x0_y0_places_at_origin
PASS test_compose_logical_negative_offset_clips_not_indexes_offsides
PASS test_renderer_compact_v2_paints_across_full_x_range
PASS test_renderer_compact_v2_dropdown_chip_does_not_overflow
PASS test_parse_proc_meminfo_text
PASS test_parse_proc_status_text
PASS test_parse_proc_stat_cpu_line
PASS test_parse_proc_self_stat_times
PASS test_resource_sampler_first_sample_has_none_pct
PASS test_selected_fx_category_mapping
PASS test_dropdown_short_label_known_and_fallback
PASS test_dropdown_label_for_routes_by_category
PASS test_mirror_updates_app_state_dropdown_fields_on_pedal_edit
PASS test_mirror_updates_app_state_dropdown_fields_on_amp_edit
PASS test_mirror_updates_app_state_dropdown_fields_on_cab_edit
PASS test_mirror_safe_bypass_dropdown_is_safe
PASS test_mirror_resource_summary_has_expected_keys
PASS test_mirror_render_records_resource_sample_and_total_update
PASS test_mirror_set_pedal_model_invokes_real_overlay_apis
```

## Workstation verification

```
python3 -m py_compile audio_lab_pynq/hdmi_effect_state_mirror.py
python3 -m py_compile audio_lab_pynq/hdmi_backend.py
python3 -m py_compile GUI/pynq_multi_fx_gui.py
python3 -m py_compile scripts/test_hdmi_realtime_pedalboard_controls.py
python3 -m py_compile scripts/test_hdmi_800x480_origin_guard.py
python3 tests/test_hdmi_selected_fx_state.py    # 5 PASS
python3 tests/test_hdmi_model_state_mapping.py  # 6 PASS
python3 tests/test_hdmi_origin_mapping.py       # 4 PASS
python3 tests/test_hdmi_resource_monitor.py     # 15 PASS
python3 scripts/test_hdmi_800x480_origin_guard.py --dry-run --hold-seconds 0
# -> "phase6c-guard OK", placement=manual offset=(0,0), framebuffer_copied_region x0=0 y0=0
git diff --check    # clean
```

The Vivado-related files (``block_design.tcl``, ``audio_lab.xdc``,
``create_project.tcl``, ``audio_lab.bit``, ``audio_lab.hwh``) have no
changes.

## PYNQ run instructions

```sh
ssh xilinx@192.168.1.9 '
  cd /home/xilinx/Audio-Lab-PYNQ &&
  sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ:/home/xilinx/Audio-Lab-PYNQ/GUI \
    python3 scripts/test_hdmi_800x480_origin_guard.py --hold-seconds 10
'

ssh xilinx@192.168.1.9 '
  cd /home/xilinx/Audio-Lab-PYNQ &&
  sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ:/home/xilinx/Audio-Lab-PYNQ/GUI \
    python3 scripts/test_hdmi_realtime_pedalboard_controls.py \
    --hold-seconds-per-step 1 --final-hold-seconds 10
'
```

Both scripts expect:

- ``AudioLabOverlay`` loads in ~2-5 s.
- ``ADC HPF`` true, ``R19=0x23``.
- ``axi_vdma_hdmi`` and ``v_tc_hdmi`` present in ``ip_dict``.
- ``rgb2dvi_hdmi`` and ``v_axi4s_vid_out_hdmi`` present in HWH.
- ``placement=manual``, ``offset_x=0``, ``offset_y=0``,
  ``framebuffer_copied_region`` starting at ``(0, 0)``.
- VDMA error bits (``dmainterr`` / ``dmaslverr`` / ``dmadecerr``) all
  false.
- VTC ctl = ``0x00000006`` (generation + REG_UPDATE enabled).
- Render / compose / copy in the same range Phase 6B reported
  (~0.15 s / ~0.025 s / ~0.20 s steady-state).
- Every pedal / amp / cab step PASS with expected SELECTED FX, expected
  category, and expected dropdown label.

The Notebook itself is opened from Jupyter at
``notebooks/HdmiRealtimePedalboardOneCell.ipynb`` and run end-to-end;
each widget interaction calls ``HdmiEffectStateMirror`` which calls the
deployed ``AudioLabOverlay`` API and triggers a fresh 800x480 HDMI
render.

## Not implemented in Phase 6C

- GUI-originated DSP control events. The HDMI panel still cannot inject
  edits back into the mirror; only the Notebook ipywidgets do.
- Continuous animation / 30 fps render loop.
- Direct ``ovl.set_*`` interception that would make raw overlay calls
  also feed the mirror's last-edited bookkeeping.
- New cab models beyond ``cab_model=0/1/2``.
- Vivado / Clash / ``block_design.tcl`` / bit / hwh changes.
- Continuous polling resource monitor -- the panel refreshes on every
  edit and on the Summary button, not on a wallclock timer.
