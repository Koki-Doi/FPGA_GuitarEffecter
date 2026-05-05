# PYNQ-Z2 runtime notes

This file captures the operational facts about the lab board.

## Board reachability

| Field | Value |
| --- | --- |
| IP address | `192.168.1.8` |
| User | `xilinx` |
| SSH key auth | configured (see `scripts/deploy_to_pynq.sh`) |
| Passwordless `sudo` | configured (`/etc/sudoers.d/xilinx-nopasswd`) |
| Jupyter URL | `http://192.168.1.8:9090/tree` |

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
ssh xilinx@192.168.1.8 'sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 - <<PY
from audio_lab_pynq.AudioLabOverlay import AudioLabOverlay
ovl = AudioLabOverlay()
print("ADC HPF:", ovl.codec.get_adc_hpf_state())
PY'
```

Putting `/home/xilinx/Audio-Lab-PYNQ` first on `PYTHONPATH` is important:
the system has an older copy of the package under
`/usr/local/lib/python3.6/dist-packages/audio_lab_pynq/`, and unless our
copy wins the resolution race, tests will exercise the stale code.

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
ssh xilinx@192.168.1.8 'sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 -c "
from audio_lab_pynq.AudioLabOverlay import AudioLabOverlay
ovl = AudioLabOverlay()
ovl.dump_codec_registers()
print(\"ADC HPF:\", ovl.codec.get_adc_hpf_state())
print(\"input vol:\", ovl.codec.get_input_digital_volume())
"'
```

Expected after a clean overlay load: `R19_ADC_CONTROL` reads back as
`0x23`, `ADC HPF` is `True`, input digital volume is `(0, 0)`.
