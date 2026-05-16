# HDMI GUI Phase 4E 800x480 logical GUI

Date: 2026-05-15 JST

## Summary

The small HDMI LCD is likely a 5-inch 800x480 panel. Phase 4D proved that
Python-side fit modes can keep the 1280x720 GUI inside the LCD's visible
area, but simply shrinking the full GUI still leaves text and dense
controls harder to read. Phase 4E adds an 800x480 logical GUI renderer
and places that logical frame in the center of the existing 1280x720
HDMI framebuffer.

No Vivado rebuild was run. `audio_lab.bit` / `audio_lab.hwh` were not
regenerated or changed. `block_design.tcl`, `audio_lab.xdc`,
`create_project.tcl`, Clash/DSP, `topEntity`, GPIO names/addresses, HDMI
IP topology, VDMA HSIZE/STRIDE/VSIZE, and VTC timing were not changed.
The HDMI signal remains 1280x720; only the Python-side RGB frame content
changed.

## Renderer

New public renderer:

```python
render_frame_800x480(AppState()) -> np.ndarray shape [480, 800, 3], dtype uint8
```

The older `render_frame_800x480` wrapper name already existed as a
simple 1280x720 downscale path, so Phase 4E rewired that public function
to the new 5-inch logical layout while keeping the 1280x720 renderer
unchanged.

The 800x480 layout is not a downscale of the full GUI. It keeps the same
dark AudioLab / plugin visual language, but reduces information density:

- 24 px logical safe margin.
- Top preset/status card with large preset id, preset name, active/bypass
  state, and active FX count.
- Compact chain strip.
- Selected-effect panel with the first four important parameters.
- Simplified signal monitor.
- Input/output level card.

Priority is readability on the small LCD: current preset, chain/effect
status, Safe Bypass state, signal monitor, and simple meters. Dense
parameter tables and detailed controls are deferred to later UI work.

## Framebuffer Placement

`AudioLabHdmiBackend.write_frame()` and `start()` now support smaller
logical RGB frames. A `[480,800,3]` frame is copied into a black
1280x720 canvas before the existing RGB888 -> DDR `GBR888` copy:

| Field | Value |
| --- | ---: |
| Logical frame | `800x480` |
| HDMI framebuffer | `1280x720` |
| Placement | `center` |
| Offset X | `240` |
| Offset Y | `120` |
| VDMA HSIZE | `3840` |
| VDMA STRIDE | `3840` |
| VDMA VSIZE | `720` |

The backend logs `input_shape`, `output_width`, `output_height`,
`offset_x`, `offset_y`, `compose_s`, and `framebuffer_copy_s` in
`last_frame_write`.

## Deploy

Only Python/script files were copied to the board:

- `GUI/pynq_multi_fx_gui.py`
- `audio_lab_pynq/hdmi_backend.py`
- `scripts/test_hdmi_800x480_frame.py`

The full deploy script was not used for Phase 4E because this phase was
explicitly constrained not to overwrite bit/hwh. Board-side bit/hwh sizes
remained:

- `audio_lab.bit`: `4,045,680` bytes.
- `audio_lab.hwh`: `1,054,120` bytes.

## PYNQ Test

Command:

```sh
sudo env PYTHONUNBUFFERED=1 PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
  python3 scripts/test_hdmi_800x480_frame.py --hold-seconds 60
```

Result:

- `AudioLabOverlay()` loaded once.
- No `Overlay("base.bit")`.
- No `run_pynq_hdmi()`.
- No second overlay load.
- ADC HPF `True`.
- `R19=0x23`.
- `axi_gpio_delay_line=False`.
- legacy `axi_gpio_delay=True`.
- `axi_gpio_noise_suppressor` and `axi_gpio_compressor` present.
- HDMI IPs present in `ip_dict` / HWH.
- 60-second hold completed.
- Post-HDMI Safe Bypass smoke completed.
- Physical readability and final visual fit were resolved in later
  phases: Phase 5C adopts top-left `800x480` at `offset_x=0`,
  `offset_y=0`, not the centered `(240,120)` placement from this phase.

## Measurements

| Metric | 800x480 logical GUI | Prior 1280x720 GUI |
| --- | ---: | ---: |
| Render time | `0.317 s` | `2.979 s` cold static render |
| Compose / placement time | `0.026 s` | `0.265 s` `fit-90` resize/compose |
| Framebuffer copy time | `0.207 s` | `0.207 s` |
| Total content update | `0.550 s` | `3.451 s` cold `fit-90` path |
| Practical update estimate | about `1.8 fps` | about `0.29 fps` cold path |

For the current full-frame copy implementation, the 800x480 renderer and
logical placement are much cheaper than the 1280x720 render/resize path,
but the final copy still swizzles the entire 1280x720 framebuffer. A
future partial-copy path that writes only the 800x480 active region would
target the remaining `0.207 s` copy cost.

## HDMI Status

Common status from the successful run:

- Framebuffer physical address: `0x16900000`.
- Framebuffer size: `2764800` bytes.
- Framebuffer format: RGB888 input -> packed DDR `GBR888`.
- Logical placement: `800x480` at offset `(240,120)`.
- `VDMACR`: `0x00010001`.
- `DMASR`: `0x00011000`.
- VDMA error bits: `dmainterr=False`, `dmaslverr=False`,
  `dmadecerr=False`, `halted=False`, `idle=False`.
- VTC status: `vtc_ctl=0x00000006`.

## Remaining Work

- User visual confirmation later showed the centered 800x480 placement
  does not match this 5-inch LCD's practical viewport.
- Tune the 800x480 UI after visual feedback, especially text hierarchy
  and how much selected-effect detail is useful on the panel.
- Add a partial framebuffer copy path for logical frames if the full
  1280x720 copy becomes the limiting cost.
- Build the Phase 5 change-driven GUI loop on top of the logical mode.

Post-Phase-5C note: the standard runtime placement is
`--variant compact-v2 --placement manual --offset-x 0 --offset-y 0` on
the fixed 1280x720 HDMI signal.
