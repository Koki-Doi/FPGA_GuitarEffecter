# Build and deploy

For the playbook on adding a new effect (which path applies, in what
order, and what each layer needs), see
[`EFFECT_ADDING_GUIDE.md`](EFFECT_ADDING_GUIDE.md).

## Decision tree

| What changed | Build steps | Deploy |
| --- | --- | --- |
| Only Python in `audio_lab_pynq/` | none | `bash scripts/deploy_to_pynq.sh` |
| Only `audio_lab_pynq/notebooks/*.ipynb` (e.g. `GuitarPedalboardOneCell.ipynb`, `DistortionModelsDebug.ipynb`, `GuitarEffectSwitcher.ipynb`) | **none — no Clash, no Vivado, no bit/hwh** | `bash scripts/deploy_to_pynq.sh` |
| GPIO-neutral refactor (Python + docs + tests; no Clash, no `block_design.tcl`, no GPIO byte semantics change) | none — **no bit/hwh rebuild** | `bash scripts/deploy_to_pynq.sh` |
| C++ DSP prototype removal (`src/effects/*.cpp`) | none — never on the live PL path | none on the FPGA side; `bash scripts/deploy_to_pynq.sh` only if Python or notebooks shipped alongside |
| `hw/ip/clash/src/LowPassFir.hs` | Clash → VHDL → repackage IP → Vivado bit/hwh | review timing vs the deployed baseline; deploy only if not significantly worse |
| `hw/Pynq-Z2/block_design.tcl`, `audio_lab.xdc`, IP topology | full Vivado rebuild — **only with explicit user approval** | review timing, then deploy |

When a `block_design.tcl` change adds a new `axi_gpio_*` IP (as the
noise-suppressor work did with `axi_gpio_noise_suppressor` at
`0x43CC0000`, and the compressor work did with `axi_gpio_compressor`
at `0x43CD0000`):

- `NUM_MI` on `ps7_0_axi_periph` must increment to match the new
  master count.
- Add the M*nn*_AXI interconnect, the `gpio_io_o` net into the new
  Clash port, the M*nn*_ACLK / M*nn*_ARESETN entries on the
  FCLK_CLK0 / peripheral_aresetn nets, and the new address segment.
- Re-run Clash → VHDL → IP repackage so `component.xml` exposes the
  new port (e.g. `noise_suppressor_control`); without that the block
  design connection will fail to bind.
- After `make`, confirm `.hwh` carries the new IP, e.g.
  `grep -c noise_suppressor hw/Pynq-Z2/bitstreams/audio_lab.hwh`
  or `grep -c axi_gpio_compressor hw/Pynq-Z2/bitstreams/audio_lab.hwh`.
- Loading the overlay on the board should expose the new attribute,
  e.g. `hasattr(ovl, "axi_gpio_noise_suppressor") == True` or
  `hasattr(ovl, "axi_gpio_compressor") == True`.

The compressor add (`axi_gpio_compressor` @ `0x43CD0000`) is a worked
example: `NUM_MI` was bumped from 14 to 15, `M14_AXI` was added on
`ps7_0_axi_periph` and routed to `axi_gpio_compressor/S_AXI`, the
`compressor_control` port was added to the Clash top entity, and the
new attribute is checked in the smoke test below.

## Clash → VHDL

```sh
cd hw/ip/clash
rm -rf /tmp/clash_tc && mkdir -p /tmp/clash_tc
clash -isrc \
  -package-id clash-prelude-1.8.1-043657e64d575898396c414bafaea7f08fdd2ba6b4085ce0bd624cd91d00144c \
  --vhdl -outputdir /tmp/clash_tc src/LowPassFir.hs
```

Then copy the generated VHDL into the IP source directory and apply the
clk/rst type fix the existing Makefile applies:

```sh
cp /tmp/clash_tc/LowPassFir.topEntity/* hw/ip/clash/vhdl/LowPassFir/LowPassFir.topEntity/
find hw/ip/clash/vhdl/LowPassFir -name '*.vhdl' -print0 \
  | xargs -0 sed -i 's/in [^[:space:]]*\.\(clk\|rst\).*;/in std_logic;/'
```

Repackage the Vivado IP (updates `component.xml`):

```sh
cd hw/ip/clash
vivado -mode batch -notrace -nojournal -nolog \
  -source create_ip.tcl -tclargs vhdl/LowPassFir
```

The `-package-id` flag pins clash-prelude to the version that the
installed `clash` binary was built against. Without it, the local GHC
environment may pick up `clash-prelude-1.8.2` and the build fails with a
hash mismatch.

## Vivado bit/hwh

```sh
cd hw/Pynq-Z2
make clean
make
```

`make` runs `vivado -mode batch -notrace -nojournal -nolog -source
create_project.tcl`. Output lands in
`hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}`. The build is currently
**~14 minutes** on the lab workstation.

The `.bit` and `.hwh` filenames must be the same basename
(`audio_lab.bit`, `audio_lab.hwh`); PYNQ's `Overlay()` expects them to
match.

## Timing review (mandatory after any Clash change)

After the build:

```sh
tail -200 /tmp/vivado_build.log | grep -E 'WNS|TNS|WHS|THS|CRITICAL WARNING'
```

Compare the final WNS to the recorded baseline in
`docs/ai_context/TIMING_AND_FPGA_NOTES.md`. If it has degraded
significantly, **do not deploy**; report and propose a pipeline change.

## Deploy to PYNQ-Z2

```sh
PYNQ_HOST=192.168.1.9 bash scripts/deploy_to_pynq.sh
```

The script:

- Verifies / installs the SSH key on the board.
- Detects passwordless sudo.
- rsyncs `audio_lab_pynq/` plus the freshly built `audio_lab.bit` /
  `audio_lab.hwh` to `/home/xilinx/Audio-Lab-PYNQ/`.
- Copies (or pip-installs) the package into
  `/usr/local/lib/python3.6/dist-packages/audio_lab_pynq/`.
- Re-installs the notebooks under `/home/xilinx/jupyter_notebooks/audio_lab/`.
- Runs an import sanity check.

It never stores or logs the board password.

## Smoke test on the board

```sh
ssh xilinx@192.168.1.9 'sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 - <<PY
from audio_lab_pynq.AudioLabOverlay import AudioLabOverlay
ovl = AudioLabOverlay()
print("ADC HPF:", ovl.codec.get_adc_hpf_state())
print("R19_ADC_CONTROL:", hex(ovl.codec.R19_ADC_CONTROL[0]))
PY'
```

A clean run prints `ADC HPF: True` and `R19_ADC_CONTROL: 0x23`.

## What `make` from the repo root does

`Makefile` at the root has these targets:

| Target | Effect |
| --- | --- |
| `make` / `make all` | builds the Vivado bitstream and the Python wheel. |
| `make Pynq-Z2` | bitstream only. |
| `make ip` | Clash → VHDL → IP packaging only. |
| `make tests` | runs CPU-side C++ and Python tests. |
| `make clean` | removes Vivado project and bitstream artefacts. |

Note: `make ip` invokes `nix-shell` via `hw/ip/clash/clash/Makefile`. The
direct path documented above (`clash` invoked from `hw/ip/clash/`) is
what we have been using in this lab; both should produce identical VHDL.
