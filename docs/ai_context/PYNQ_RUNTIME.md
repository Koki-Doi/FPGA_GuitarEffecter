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
