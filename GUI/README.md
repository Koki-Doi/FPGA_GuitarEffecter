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

The deployed Phase 4/5 HDMI design emits a fixed `1280x720` HDMI signal.
For the 5-inch 800x480 LCD, Phase 5A output mapping and user visual
inspection set the practical visible viewport to the top-left `800x480`
region:

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

The Jupyter equivalent is `audio_lab_pynq/notebooks/HdmiGui.ipynb`, which
also exposes `OFFSET_X` / `OFFSET_Y` calibration knobs at the top of the
cell for LCDs whose visible viewport drifts from the framebuffer origin.

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
