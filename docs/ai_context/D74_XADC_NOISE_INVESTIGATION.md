# D74 XADC integration -- audio-noise investigation (NOT adopted)

Status (2026-05-30): **D74 XADC-Wizard bitstream is NOT adopted.** The
FP02M software/MMIO path works, but the D74 build has an audio problem in
the ADC -> DSP input path. bit/hwh were never committed; D73 remains the
committed baseline. This file records what we found so the next attempt
does not re-walk it.

## What D74 added

XADC Wizard `xadc_wiz_a0 @ 0x43D40000` (VAUX1 = A0 = E17/D18) via
`xadc_integration.tcl` + `xadc_a0.xdc`, sourced from `create_project.tcl`
after `wah_integration.tcl`. `block_design.tcl` untouched;
`clash_lowpass_fir_0` unchanged (no new Clash port). Build: WNS `-11.361 ns`
(D73 was `-10.910 ns`, delta `-0.451 ns`), LUT +203 / FF +191, BRAM/DSP
unchanged, worst path = DS-1 distortion (same as D73). bit/hwh md5
`dd3fc099...` / `ef094d0e...`.

## FP02M functional result (works)

- Wiring candidate 1: Tip->A0, Ring->3.3V, Sleeve->GND.
- A0 read via **MMIO** (`overlay.xadc_wiz_a0` reg `0x244` = VAUX1), NOT IIO.
- Sweep raw 16..4068 (span 4052), invert=false; calibration saved.
- `Fp02mWahController` -> `set_wah_settings(position_raw=...)` confirmed.

## Audio problem (why D74 is rejected)

Bench matrix on D74, GUI-less / pedal-less / FP02M disconnected
(`scripts/noise_check.py --pmod-mode {mute,tone,dsp}`, all_off + Wah OFF):

| pmod mode | what it exercises | D74 result |
| --- | --- | --- |
| **mute** (3) | DAC fed zero | **clean** (true mute, readback=3) |
| **tone** (0) | FPGA tone -> DAC, no ADC | **clean** |
| **dsp** (2) all_off | ADC -> DSP bypass -> DAC | **bitcrusher-like distortion** |

- Line-in disconnected in dsp mode -> no output (so the distortion rides
  on the actual ADC input signal).
- ⇒ the added defect is in the **ADC -> DSP input path**, not the
  DAC/output and not pure analog coupling.

## Hypotheses tested

1. **Continuous XADC conversion injects noise** -> **RULED OUT.** Runtime
   `scripts/xadc_quiet_test.py` stops the VAUX1 sequencer at runtime
   (CFR1 `0x21AF` -> `0x01AF`, AXI `0x304`; verified against the IP's
   `INIT_41`) with the Pmod muted. Noise unchanged between BASELINE
   (continuous) and QUIET (stopped). So continuous external sampling is
   not the audible cause.
2. **D74 P&R shift broke the audio AXIS datapath** -> **prime suspect,
   not yet confirmed.** Matches the documented D63 rejection ("all_off
   produced a bit-crusher-like artifact ... AXIS-stream sample
   quantisation / glitching" from a placement shift). WNS worsened
   `-0.451 ns` and the XADC IP + routing perturbs placement.
3. **Pre-existing input-path issue (level / cable / codec)** -> **OPEN /
   UNTESTED.** See the load-site confound below: the "D73" comparison runs
   actually loaded D74, so D73's `dsp all_off` behaviour (bitcrusher or
   clean?) was **never actually measured**. This is the decisive
   unfinished test.

## LOAD-SITE CONFOUND (important)

`AudioLabOverlay`, when run as `sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ
python3 ...`, loads the bit/hwh from the **repo package dir**
`/home/xilinx/Audio-Lab-PYNQ/audio_lab_pynq/bitstreams/` (PYTHONPATH puts
the repo's `audio_lab_pynq` first), NOT from `hw/Pynq-Z2/bitstreams/` or
the dist-packages copy. There are **five** bit sites (CLAUDE.md HDMI note);
the repo-package one is the load path for these scripts.

During this session the manual D73<->D74 swaps updated only 4 sites and
**missed the repo-package site**, which stayed at D74. So every
`scripts/...` run (including the "D73 mute/tone/dsp matrix") actually
loaded **D74**. Consequence: the entire D73-vs-D74 audio A/B was
**D74-vs-D74** -- the differences heard between "D73" and "D74" runs were
condition/volume/state, not the bitstream. The bitcrusher / mute-clean /
tone-clean findings are all valid **for D74**; D73's audio under the same
matrix is genuinely untested. The next session MUST update all five sites
(or use `deploy_to_pynq.sh`, which does) and re-run the D73-vs-D74 A/B
before concluding D74-specific vs pre-existing.

## DMA capture caveat (D65 lesson re-confirmed)

`scripts/capture_adc_analyze.py` attempted a bit-level S2MM capture
(unique values / max-run / stuck-low-bits). Findings: `guitar_chain->dma`
is NOT a valid capture sink (transfer length 0 -> pynq DMA `wait()`
busy-spins and wedges the channel; needs a `download=True` to reset). The
`passthrough` `capture_input` path is timing/mode-finicky in pmod mode 2
(one run showed `max_run=22890` of 24000 = a stuck-stream signature, but
it was not reproducible). This re-confirms `DECISIONS.md` D65: the
loopback / DMA self-test is NOT a substitute for the bench ear for this
class of subtle noise. **Use the ear.**

## Decisive next test (when resumed)

Ear A/B: `noise_check.py --pmod-mode dsp` (+ `loopback`) on **D73** vs D74,
same input/line-in state:
- D73 dsp **clean**, D74 bitcrusher -> **D74-specific P&R regression** ->
  reject D74; a future XADC re-add must protect the audio AXIS placement
  (pblock / constraints) or use a different ADC route (external SPI ADC).
- D73 dsp **also bitcrusher** -> pre-existing input/ADC issue (level /
  cable / codec), XADC exonerated; fix the input path independently.

## What is kept vs reverted

- **Kept (committed, reusable):** the FP02M software layer (`fp02m.py`,
  probe/calibrate/run scripts, GUI SOURCE=MANUAL/PEDAL, encoder toggle,
  applier PEDAL path), docs, and the diagnostic scripts. These are
  bitstream-independent (the `position_raw` API is Python-side).
- **Not adopted:** the D74 XADC bit/hwh (never committed). The
  `xadc_integration.tcl` / `xadc_a0.xdc` + the `create_project.tcl`
  source lines remain in-tree as the integration record; a future build
  that should NOT include XADC must drop those two `create_project.tcl`
  lines.

See `DECISIONS.md` D74, `XADC_INTEGRATION_DESIGN.md`,
`FP02M_PEDAL_INTEGRATION.md`.
