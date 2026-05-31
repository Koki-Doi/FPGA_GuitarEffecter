# AudioLab HDMI GUI renderer

`GUI/` is the current Python-side renderer and control bridge used by the
AudioLab HDMI GUI work. It is **not** a standalone PYNQ base-overlay video
application.

Current live HDMI output uses:

- `AudioLabOverlay()` loaded exactly once
- `audio_lab_pynq.hdmi_backend.AudioLabHdmiBackend`
- the integrated HDMI path in `audio_lab.bit`
- `GUI/pynq_multi_fx_gui.py` for RGB frame rendering
- `GUI/audio_lab_gui_bridge.py` for dry-run-first `AppState` to
  `AudioLabOverlay` control mapping

The 1280x720 reference layout and the Tkinter desktop preview app
(originally developed on Windows) have been removed. The renderer now
exposes only the 800x480 logical layouts used by the 5-inch LCD.

## Files

| File | Role |
| --- | --- |
| `pynq_multi_fx_gui.py` | Renderer for the 800x480 5-inch HDMI LCD (compact-v1 and compact-v2 variants) plus the render cache and state-JSON persistence. |
| `audio_lab_gui_bridge.py` | Maps visual `AppState` changes to existing `AudioLabOverlay` APIs. It defaults to dry-run and never loads a bitstream itself. |
| `fx_gui_state.json` | Runtime state. Ignored by git. |

## Live HDMI Runtime

The deployed Phase 6I HDMI design emits VESA SVGA `800x600 @ 60 Hz /
40 MHz`. For the 5-inch 800x480 LCD, the compact-v2 GUI is composed into
the top-left `800x480` region of that framebuffer and rows `480..599`
remain black:

```text
x=0, y=0, w=800, h=480
```

The standard 5-inch LCD check is:

```sh
ssh xilinx@192.168.1.9 '
  cd /home/xilinx/Audio-Lab-PYNQ &&
  sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
    python3 scripts/test_hdmi_800x480_frame.py \
      --variant compact-v2 \
      --placement manual \
      --offset-x 0 \
      --offset-y 0 \
      --hold-seconds 60
'
```

The Jupyter equivalents are `audio_lab_pynq/notebooks/HdmiGuiShow.ipynb`
(one-shot, smart `download=False` attach when the bit is already loaded)
and `audio_lab_pynq/notebooks/HdmiGui.ipynb` (live loop/resource monitor).
Do not use `Overlay("base.bit")` or `run_pynq_hdmi()` for the live
AudioLab GUI.

## Renderer API

```python
from pynq_multi_fx_gui import AppState, render_frame_800x480_compact_v2

state = AppState()
frame = render_frame_800x480_compact_v2(state)   # (480, 800, 3), uint8
```

`render_frame_800x480(state, variant="compact-v1")` is preserved for
diagnostic scripts that still target the Phase 4E layout.

The renderer returns RGB `numpy.ndarray` frames. The HDMI backend packs
the RGB888 frame into the deployed DDR framebuffer order expected by the
VDMA / `v_axi4s_vid_out` / `rgb2dvi` path.

The compact-v2 EFFECTS list is 9 entries (`Noise Sup / Compressor / Wah /
Overdrive / Distortion / Amp Sim / Cab IR / EQ / Reverb`). When `Wah` is
the selected effect the FX panel draws a `SOURCE: MANUAL / PEDAL` strip:
`PEDAL` routes Wah POSITION from the ZOOM FP02M expression pedal
(Arduino A0 = XADC VAUX1), while Q / VOLUME / BIAS stay knob-driven
(D72 / D76). The renderer is split per-theme under `GUI/compact_v2/`
(`knobs.py` / `state.py` / `layout.py` / `renderer.py` / `hit_test.py`);
`pynq_multi_fx_gui.py` is a re-export shim (`DECISIONS.md` D26).

## Control Bridge

`audio_lab_gui_bridge.py` is intentionally separated from drawing:

- it does not instantiate `AudioLabOverlay`
- it does not load any bitstream
- it defaults to `dry_run=True`
- it writes hardware only when the caller passes an already-loaded overlay
  and explicitly disables dry-run mode

Chain reorder remains display-only for the live hardware. The deployed DSP
pipeline order is fixed and must not be implied to be dynamically
reorderable.
