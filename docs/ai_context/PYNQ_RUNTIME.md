# PYNQ-Z2 runtime notes

This file captures the operational facts about the lab board.

## Board reachability

| Field | Value |
| --- | --- |
| IP address | `192.168.1.9` |
| User | `xilinx` |
| SSH key auth | configured (see `scripts/deploy_to_pynq.sh`) |
| Passwordless `sudo` | configured (`/etc/sudoers.d/xilinx-nopasswd`) |
| Jupyter URL | `http://192.168.1.9:9090/tree` |

Because key auth is in place, the deploy script never asks for a password.
If a future agent runs `ssh-copy-id` again, it will need an interactive
TTY and must be invoked by the user, not from inside an automated step.

## Software stack on the board

- PYNQ image: 2020.1 series.
- Python: 3.6.
- The PYNQ Python library expects to load overlays as **root**: `Overlay`,
  DMA setup, `pynq.allocate` and so on all touch `/dev/uio*` and
  contiguous-memory regions that are not world-accessible.
- `pylibi2c` is used for ADAU1761 register I/O over `/dev/i2c-1`.

## Running anything that touches the overlay

Always wrap your command in `sudo env PYTHONPATH=...`:

```sh
ssh xilinx@192.168.1.9 'sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 - <<PY
from audio_lab_pynq.AudioLabOverlay import AudioLabOverlay
ovl = AudioLabOverlay()
print("ADC HPF:", ovl.codec.get_adc_hpf_state())
PY'
```

Putting `/home/xilinx/Audio-Lab-PYNQ` first on `PYTHONPATH` is important:
the system has an older copy of the package under
`/usr/local/lib/python3.6/dist-packages/audio_lab_pynq/`, and unless our
copy wins the resolution race, tests will exercise the stale code.

## HDMI GUI runtime

The live HDMI GUI uses the integrated AudioLab overlay. Load
`AudioLabOverlay()` once through the HDMI test script; do not load
`Overlay("base.bit")`, do not call `run_pynq_hdmi()`, and do not load a
second overlay after AudioLab.

For the 5-inch 800x480 LCD, the Phase 6I (`DECISIONS.md` D25) baseline
is VESA SVGA `800x600 @ 60 Hz / 40 MHz` and the compact-v2 800x480 GUI
composes at framebuffer `(0,0)` (visible rows `0..479`; the bottom
120 rows of the `800x600` framebuffer stay black). The simplest live
check is `audio_lab_pynq/notebooks/HdmiGuiShow.ipynb` (one cell;
attaches with `download=False` when the bit is already loaded so the
rgb2dvi PLL at the `800 MHz` VCO lower edge is not disturbed); the
script equivalent is:

```sh
ssh xilinx@192.168.1.9 '
  cd /home/xilinx/Audio-Lab-PYNQ &&
  sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
    python3 scripts/test_hdmi_800x480_frame.py \
      --variant compact-v2 --placement manual \
      --offset-x 0 --offset-y 0 --hold-seconds 60
'
```

Expected healthy status: VDMA error bits all false, VDMA
`HSIZE/STRIDE/VSIZE = 2400/2400/600` (Phase 6I C2 SVGA framebuffer;
on the older Phase 4 720p bit it was `3840/3840/720`), `vtc_ctl =
0x00000006`, and `v_tc_hdmi GEN_ACTSZ (0x60) = 0x02580320` (V=600 /
H=800). If `GEN_ACTSZ` reads anything else, one of the five bit
copies on the PYNQ is stale — see `BUILD_AND_DEPLOY.md` for the full
list and `sudo cp` recipe.

## Pmod I2S2 effect-control notebook (mode 2 live UI, D49/D50)

`audio_lab_pynq/notebooks/PmodI2S2EffectControlOneCell.ipynb` is the
single-cell ipywidgets UI for the Pmod I2S2 mode-2 path (Pmod Line
In → Pmod ADC → AudioLab DSP chain → Pmod DAC → Pmod Line Out). The
cell loads `AudioLabOverlay`, finds the `pmod_status_0` MMIO from
`ip_dict`, forces `cfg_mode = 2` (DSP) at startup, and exposes every
effect (Noise Suppressor / Compressor / Overdrive / Distortion
pedal-mask / Amp Sim / Cab IR / EQ / Reverb) through ipywidgets
checkboxes, sliders, and dropdowns. The Pmod status panel shows
VERSION / STATUS / MODE / FRAME_COUNT / NONZERO_COUNT /
SDOUT_XCOUNT / CLIP_COUNT / LAST_LEFT/RIGHT / PEAK_ABS_*` in raw +
dBFS, and the global buttons cover `Safe clean (mode 2)`,
`Panic / mute (mode 3)`, `Mode 0 tone`, `Mode 1 loopback` (requires
the inline `confirm loopback` checkbox), `Clear status counters`,
and `Refresh status`.

Current mode 2 uses the D50 `mode2_right_snapshot` workaround: the
IP RIGHT slot is mirrored into both DAC slots, so the live output is
mono RIGHT-to-left/right with about one frame (`~21 us`) of delay.

Bench wiring (always check before running mode 2):
- Disconnect the on-module Line Out ↔ Line In 3.5 mm jumper before
  engaging mode 2. The DSP chain is in the audio loop and can feed
  back at high-gain pedals.
- Put a real audio source on Line In at LOW volume.
- Listen on Line Out via a separate audio interface, NOT plugged
  back into Line In.

Open `http://192.168.1.9:9090/tree/audio_lab/PmodI2S2EffectControlOneCell.ipynb`
in the browser; the single cell auto-runs `load_overlay →
write_mode(2) → apply_effects → refresh_status` at the bottom so
"open + Run all" is one-shot.

## Pmod I2S2 HDMI GUI notebook (encoder live control, mode 2)

`audio_lab_pynq/notebooks/PmodI2S2HdmiGuiOneCell.ipynb` is the
single-cell companion that drives the **HDMI GUI plus rotary
encoders** on top of the same Pmod I2S2 mode-2 path. Instead of
loading `AudioLabOverlay` inside the kernel, the cell spawns
`scripts/run_encoder_hdmi_gui.py --live-apply --skip-rat --pmod-mode
dsp` as a sudo subprocess so the runner owns the overlay /
HDMI VDMA / encoder polling loop and the Notebook stays
interactive. Buttons:

- `Start HDMI GUI + Pmod DSP` — spawn the runner (auto-fired on cell
  execution; subsequent presses stop and restart so only one runner is
  alive at a time).
- `Stop HDMI GUI` — SIGTERM the runner. The runner's shutdown path
  writes Pmod MODE=3 (mute) before tearing down the HDMI backend.
- `Panic / Mute Pmod` — same SIGTERM path; falls back to
  `scripts/pmod_i2s2_mode.py --mode mute` if the runner is already
  dead.
- `Set Pmod mode 2 / DSP` — shell out to
  `scripts/pmod_i2s2_mode.py --mode dsp` (no overlay reload, no codec
  reconfig).
- `Refresh Pmod status` — `scripts/pmod_i2s2_mode.py --read` snapshot.
- `Show command` — echo the runner / helper commands into the log.

Bench wiring (Pmod I2S2 mode 2):
- Disconnect the on-module Line Out ↔ Line In 3.5 mm jumper.
- External source (audio IF OUT, guitar pedal output, phone headphone
  out) → Pmod Line In, source level at MINIMUM.
- Pmod Line Out → audio IF IN / powered speakers / headphone amp.
  Do NOT plug Line Out back into Line In.

Open `http://192.168.1.9:9090/tree/audio_lab/PmodI2S2HdmiGuiOneCell.ipynb`
in the browser; the cell auto-fires Start so the HDMI GUI is up
within ~30..60 s and the rotary encoders drive the Pmod I2S2 mode-2
audio chain.

## Filesystem layout on the board

| Path | What it is |
| --- | --- |
| `/home/xilinx/Audio-Lab-PYNQ/` | rsynced repo source (the deploy target). |
| `/usr/local/lib/python3.6/dist-packages/audio_lab_pynq/` | pip-installed copy that the deploy script refreshes. |
| `/home/xilinx/jupyter_notebooks/audio_lab/` | notebooks installed via `install_notebooks(...)`. |
| `/home/xilinx/audio_diag/` | diagnostic capture artefacts (created by `InputDebug.ipynb`). |
| `/usr/local/share/pynq-venv/` | not used here; PYNQ's own virtualenv. |

## File ownership pitfalls

Anything created by Jupyter while it is running as root ends up
root-owned. If the deploy script later tries to `rsync` or `chown`
those paths under user `xilinx`, it will fail. Common offenders:

- `/home/xilinx/audio_diag/*` from a diagnostic capture run as root.
- `__pycache__/` directories left behind by the system Python.

When in doubt, `sudo chown -R xilinx:xilinx /home/xilinx/audio_diag`
before re-running diagnostics from the user account.

## Codec health-check shortcut

```sh
ssh xilinx@192.168.1.9 'sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 -c "
from audio_lab_pynq.AudioLabOverlay import AudioLabOverlay
ovl = AudioLabOverlay()
ovl.dump_codec_registers()
print(\"ADC HPF:\", ovl.codec.get_adc_hpf_state())
print(\"input vol:\", ovl.codec.get_input_digital_volume())
"'
```

Expected after a clean overlay load: `R19_ADC_CONTROL` reads back as
`0x23`, `ADC HPF` is `True`, input digital volume is `(0, 0)`.
