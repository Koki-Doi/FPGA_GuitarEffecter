# Cab real-IR (R4 step B) -- sim-first design + implementation plan

Status: **B1 BUILT + DEPLOYED + PL-SMOKED + BENCH-ACCEPTED = D149, then EXTENDED
31->47 taps = D155, the current deployed baseline (`09c8a95`, supersedes D153).**
Sim-first design proved the win; B1 was implemented (31-tap rolloff-only folded
FIR, D149), bench-accepted ("合格"), and the same Option-Y folded structure was
later extended to 47 taps for a sharper rolloff (D155, bit
`8d875cc8a0154a86673ab22e5b142d27` / hwh `e0469cf593e97d582c14bb09ea98d3d3`;
`cabSpeakerFirCoeff` Vec16->Vec24, history Vec30->Vec46, 24 folded products; WNS
+0.319, D109 CDC fwd +0.989, DSP 206/220; rolloff open -14.9 / brit -22.0 /
closed -28.9 dB/oct; measure 28/28, only cab golden re-blessed, bypass bit-exact;
bench-accepted). Created 2026-06-20. Triggered by the user choosing "real-IR cab
を sim 先行" after D148 shipped. Companion tool: `tools/dsp_sim/cab_ir.py`.
**B2 (full 128-tap time-mux MAC) remains deferred** -- the folded FIR already
reaches the real-4x12 rolloff and passes all cab targets, so B2's gain is marginal
while it adds a BRAM + MAC FSM + handshake = a new knife-edge class. Rollback D155
-> D153: `git checkout b86c88a -- hw/Pynq-Z2/bitstreams/` + redeploy.

D149 build: bit md5 `f536711c0c93006bcb55c2da211064dd`, hwh
`bfff6f2ea665573cd1340e30c29b2364`; Vivado timing MET (WNS +0.597, WHS +0.008,
WPWS +2.845, 100% routed, 0 VIOLATED), D109 CDC pair fwd +1.416 / rev +7.154,
D146 hard pblock intact (112 cells `SLICE_X100Y116:SLICE_X113Y137`), DSP 181/220
(+8 for the FIR). measure.py --check all PASS, dsp_sim regression = cab golden
re-blessed (bypass bit-exact). Rollback to D148:
`git checkout 96ef899 -- hw/Pynq-Z2/bitstreams/` + redeploy.

This is the **design half** of R4 step B (the 128-tap real cab IR, the biggest
remaining cab realism lever in `REAL_HARDWARE_FIDELITY_ROADMAP.md`). It produces
the per-model IRs, validates them against the real-hardware cab targets with the
SAME comparator the board voicing uses (`targets.compare`), and -- the decisive
finding -- shows the headline win is reachable as a **low-risk extension of the
already-accepted folded-pair speaker FIR**, not the high-risk 128-tap BRAM MAC.

## The problem (why R4 step B)

The shipping cab linear voicing (`AudioLab/Effects/Cab.hs`) is:

- a 15-tap symmetric speaker FIR (`cabSpeakerFirCoeff`, R4 step A, deployed) +
- a per-model presence biquad (`cabPresenceFFCoeff`/`cabPresenceFBCoeff`, D123)

on top of the accepted nonlinear 4-tap core (`cabProductsFrame` / `cabSatFrame`
/ `cabIrFrame` / `cabLevelMixFrame`, D71). 15 taps **cannot make the sharp
>5 kHz rolloff of a real guitar cab**: it measures ~-5.5 dB/oct over 2-9 kHz and
~-9..-11 dB/oct over the pure 5-12 kHz rolloff band, whereas a real 4x12 rolls
off ~-12..-24 dB/oct above 5 kHz. That residual top is the "buzzy DI / digital"
tell the survey (`REALISM_ALL_EFFECTS_SIM_SURVEY.md`, gap #3) flagged as the
single biggest cab lever.

## Sim-first design results (`tools/dsp_sim/cab_ir.py`)

Per-model magnitude targets are **our own hand-drawn curves** (open 1x12 /
british 2x12 / closed 4x12), NOT captured commercial IRs (D7). Each is turned
into a linear-phase FIR by windowed frequency sampling (Hamming), quantized to
**Signed-16, unity-DC sum 2^16, output `>> 16`** (peak tap ~12160 needs 15 bits,
S16 fits with margin and packs cleanly into a 16-bit BRAM word; one Zynq-7
DSP48 25x18 MAC handles a 16-bit coeff x 24-bit sample). Validation uses the
exact `measure.py` grid (40 Hz-9 kHz, 30 log bins) and `targets.compare`.

### Full 128-tap IR (replaces FIR + biquad) -- all targets PASS

| model | presence pk | HFslp 2-9k | rolloff 5-12k | S16 | quant SNR | target |
| --- | --- | --- | --- | --- | --- | --- |
| open 1x12 | 3274 Hz +2.3 dB | -6.0/oct | **-17.0/oct** | fits | 59.7 dB | PASS |
| british 2x12 | 2780 Hz +2.6 dB | -10.9/oct | **-22.7/oct** | fits | 58.6 dB | PASS |
| closed 4x12 | 2263 Hz +2.8 dB | -16.3/oct | **-27.8/oct** | fits | 55.8 dB | PASS |

vs the shipping 15-tap FIR + biquad rolloff 5-12k of -9.1 / -10.7 / -11.1/oct:
the IR roughly **doubles the rolloff steepness** and reaches the real-4x12
-12..-24/oct band, with proper per-model separation (open gentlest, closed
sharpest). Latency: 0.66 ms (63.5-sample linear-phase group delay).

### The decisive finding -- rolloff vs taps, and Option Y

Sweeping tap count shows **the rolloff (the headline win) is mostly captured at
low tap counts; only the presence-peak RESOLUTION needs 95+ taps** (resolving a
Q~1 peak at 2.3-3.4 kHz needs a long kernel). But the design already HAS a
per-model presence biquad. So keep it: design the FIR to supply **only the
rolloff** (flat passband, no bump) and let the existing biquad keep the peak --
**Option Y**. Validated as FIR x existing-biquad, it passes all three targets at
every tap count, and the rolloff scales with taps:

| taps | folded DSP (vs 8 now) | open roll | brit roll | closed roll | latency |
| --- | --- | --- | --- | --- | --- |
| 15 (current) | 8 | -7.3 | -9.5 | -11.3 | 0.07 ms |
| 23 | 12 | -10.8 | -15.8 | -21.1 | 0.11 ms |
| **31** | **16 (+8)** | **-13.0** | **-19.5** | **-26.6** | **0.16 ms** |
| 47 | 24 (+16) | -14.9 | -22.0 | -28.9 | 0.24 ms |
| 63 | 32 (+24) | -15.7 | -22.5 | -28.8 | 0.32 ms |

**31 taps is the sweet spot**: closed -11.3 -> -26.6/oct (full real-4x12 range),
british -19.5, open -13.0 -- essentially the whole rolloff win -- at only +8 DSP
and +0.09 ms latency, with **diminishing returns past 31**.

## Recommended path: B1 = 31-tap rolloff-only folded FIR (Option Y)

**B1 captures the biggest audible cab gap (the buzzy-DI -> real-speaker rolloff)
as a pure extension of the ALREADY-ACCEPTED folded-pair FIR structure.** It is
the right first build because it avoids every high-risk element:

- **NO BRAM, NO multi-cycle MAC FSM, NO handshake change.** It is structurally
  the same class as the accepted 15-tap FIR (`cabSpeakerFirProductsFrame` /
  `cabSpeakerFirMixFrame`), just more folded-pair products across more pipeline
  stages. The load-bearing D75 `acceptReady = readyOut` rule is **untouched**.
- **+8 DSP only** (8 -> 16 folded MACs), a modest island-footprint growth -- far
  less than a full-replace FIR (32-64 DSP) or a BRAM+FSM block.
- **The accepted nonlinear core AND the presence biquad stay byte-identical.**
- **Bit-exact bypass preserved** (the FIR is gated on `flag7 (fGate f)` exactly
  as today).
- Latency +8 samples (0.16 ms) -- negligible.

It is low-risk but NOT zero-risk: any island netlist change can perturb
placement around the D146 audio-output CDC pblock, so a **safe-bypass ear-bench
is still mandatory** (same risk class as the D135/D148 voicing rebuilds, NOT the
structural class).

### B1 Clash implementation spec (`AudioLab/Effects/Cab.hs`)

1. **Coefficients.** Replace `cabSpeakerFirCoeff :: Unsigned 8 -> Vec 8 (Signed
   10)` with the 16-entry folded half of the 31-tap rolloff-only kernels
   (`Vec 16 (Signed 16)`), generated by
   `python3 tools/dsp_sim/cab_ir.py --rolloff-only --taps 31 --emit-clash`:

   ```
   -- open 1x12   (sum 65537): -6 -17 -39 -82 -145 -221 -271 -228 26 634 1738 3366 5417 7546 9527 11047  (center)
   -- british 2x12(sum 65537): -46 -64 -96 -137 -169 -156 -46 223 720 1504 2600 3962 5457 6853 7926 8475
   -- closed 4x12 (sum 65538): -62 -70 -83 -87 -54 55 284 675 1262 2054 3026 4108 5188 6125 6797 7102
   ```

   (each is the half c0..c15 where c15 is the center; full 31-tap =
   c0..c14,c15,c14..c0). Re-emit at build time -- do not hand-copy.
2. **History.** `cabSpeakerFirHistNext` grows `Vec 14 Sample` -> `Vec 30 Sample`
   (x[n-1..n-30]); the `+>>` shift idiom is unchanged.
3. **Folded products.** `cabSpeakerFirProductsFrame` computes 16 folded products
   `(x[n-k]+x[n-(30-k)]) * c_k` for k=0..14 plus the center `x[n-15]*c_15`,
   reusing `foldTap`. The current 2-stage split (3 partial sums p0/p1/p2 ->
   mix) becomes a **3-4 stage split** (~4-6 products per partial-sum stage) to
   keep the island adder tree shallow -- exactly how the 15-tap was split when a
   single combinational sum hit WNS -1.1 ns at 50 MHz. At 33.33 MHz the depth
   budget is larger, so start with 4 partials and tighten only if WNS goes
   negative. These extra stages are pure latency (a few island cycles), not
   throughput -- trivial against the 347-cycle inter-sample budget.
4. **Scale.** The mix stage shifts `>> 16` (unity-DC sum 2^16) instead of the
   current `>> 8` (sum 256). Use the wide accumulator already in the partial
   sums.
5. **Unchanged:** `cabPresenceFeedforwardFrame` / `cabPresenceRecursiveFrame`
   (the peak), the nonlinear core, `cabModFrame` (micro-mod), and the
   `flag7`-gated bit-exact bypass.

### B1 acceptance gates (the standard DSP-edit pipeline)

Clash VHDL regen (verify the new coeffs/`Vec 30` in the generated VHDL) -> IP
repackage -> Vivado bit/hwh -> timing summary (WNS/WHS MET, route 0, and the
D109 CDC pair within its 6 ns `set_max_delay` window) -> deploy 4 bit copies +
JSON-validate Notebooks -> PL smoke (mode 2, ~96 kHz, engine alive) ->
**safe-bypass ear-bench (the knife-edge gate) + cab tonal bench**. Offline
regression before build: `cab_ir.py --rolloff-only --taps 31 --check` (3/3),
`measure.py --check` (cab0/cab/cab2 still PASS), and re-bless the dsp_sim
goldens only after bench acceptance (the cab golden vectors WILL change -- the
FIR taps change the cab output by design; bypass stays bit-exact).

## B2 (optional, deferred): full 128-tap real IR

Only pursue if the B1 bench wants finer per-model presence than the biquad +
31-tap gives. Two implementations, each with a DISTINCT risk profile -- this is
the engineering tension the build phase must resolve, and why B2 is deferred:

- **Folded symmetric FIR, 128-tap = 64 DSP.** No FSM, predictable timing, but a
  large island placement footprint (8x the cab DSP). The knife-edge punishes
  placement perturbation around the D146 pblock, so the footprint itself is the
  risk.
- **Time-multiplexed MAC, ~1-4 DSP + a 128-deep `blockRam` history + a tap
  counter / accumulator FSM.** Tiny footprint (best for placement minimalism),
  and the cycle budget is comfortable: island 33.33 MHz / fs 96 kHz = **347
  island cycles per sample**, so a 128-cycle (or 64-cycle folded) MAC finishes
  with large margin. The catch: a multi-cycle stage cannot keep `acceptReady =
  readyOut` always-true if samples can arrive faster than the MAC completes. It
  needs EITHER (a) bounded backpressure (a conditional ready during the
  ~128-cycle compute, proven safe against the `cc_dsp_in` clock-converter FIFO
  -- the upstream is only 96 kHz so the island drains faster than the FIFO
  fills), OR (b) a verified guarantee that the inter-sample gap is always >= the
  MAC length. This **re-touches the load-bearing D75 handshake** the docs
  explicitly warn about, so it requires a handshake review and likely an HDL/CDC
  simulation -- NOT just the offline tonal sim. A `Vec 128 Sample` register
  history already exists in `cabModFrame` (the micro-mod line), so 128-deep
  history is not new-in-kind; the new risk is purely the multi-cycle handshake.

Recommendation if B2 is ever needed: prefer the **time-mux MAC** (placement
minimalism is what the knife-edge rewards), but only after the handshake is
reviewed and CDC-simulated. The full 128-tap IRs are already designed and
S16-quantized (`cab_ir.py --emit-clash`).

## Go / no-go

- **Tonal design: GO.** Large, validated win (rolloff ~2x steeper into the real
  -12..-24/oct band, per-model separation), all cab targets PASS, S16 fits at 57
  dB SNR, latency negligible.
- **Implementation: GO on B1** (31-tap rolloff-only folded FIR) -- it banks the
  headline rolloff win at the lowest risk (accepted structure class, +8 DSP, no
  handshake/BRAM/FSM), with a mandatory safe-bypass ear-bench and a clean D148
  rollback.
- **B2 (full 128-tap): NO-GO for now** -- deferred until/unless a B1 bench asks
  for more per-model presence, and gated on a handshake/CDC review (not an
  offline-sim decision).

## Next concrete step

Implement B1 in `Cab.hs` (the 5-point spec above), run the offline checks, then
take it through the standard DSP-edit acceptance pipeline ending in the
safe-bypass ear-bench. This is a single isolated bitstream (cab-only), per the
roadmap "small isolated phases" rule -- do NOT bundle it with any other voicing
change.

## Reproduce

```sh
python3 tools/dsp_sim/cab_ir.py                              # full 128-tap replace, validate + A/B
python3 tools/dsp_sim/cab_ir.py --check                      # exit non-zero on FAIL
python3 tools/dsp_sim/cab_ir.py --rolloff-only --taps 31     # B1: validate FIR x existing biquad
python3 tools/dsp_sim/cab_ir.py --rolloff-only --taps 31 --emit-clash   # B1 coeff tables
```
