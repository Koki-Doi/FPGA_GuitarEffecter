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
3. **Pre-existing input-path issue (level / cable / codec)** -> open.
   D73 also had *some* HF noise earlier in the session, but the refined
   "true mute" matrix was not completed on D73, so D73-vs-D74 on
   `dsp all_off` (bitcrusher or clean?) is the **decisive unfinished
   test**.

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
