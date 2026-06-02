# FP02M expression pedal -> Wah POSITION integration

Status: **DONE / accepted on bench (D76, 2026-05-31).** The XADC Wizard is
re-enabled on the D75 DSP island, A0 reads via `xadc_wiz_a0` MMIO, the FP02M
pedal drives Wah POSITION with an audible sweep, the D74 bitcrusher did NOT
recur, and two bench fixes (Wah-only crossbar routing + Q self-oscillation
cap) are in. See `DECISIONS.md` D76 (and D74 for the original software pass).

The goal is to drive the Wah POSITION byte (`axi_gpio_wah.ctrlA`) from a
ZOOM **FP02M** TRS expression pedal connected to the PYNQ-Z2 Arduino **A0**
analog input, while Q / VOLUME / BIAS stay GUI / encoder driven. The Wah
DSP voicing (D73 Cry Baby retune) is **not** touched.

POSITION already has a dedicated raw-byte Python API from the D73 split
(`set_wah_settings(position_raw=...)`, `set_guitar_effects(wah_position_raw=...)`,
`WAH_DEFAULTS["position_raw"]`). The pedal feed reuses that path; the GPIO
byte layout is unchanged.

---

## 1. A0 read-path investigation (load-bearing finding)

The deployed AudioLab overlay has **no XADC / sysmon IP** (confirmed: no
`xadc`/`sysmon` INSTANCE in `hw/Pynq-Z2/bitstreams/audio_lab.hwh`).

The Zynq **PS-XADC** is exposed on the board via the Linux IIO driver
`xadc` at `/sys/bus/iio/devices/iio:device0`, but it only carries the
on-chip rails:

```
in_temp0_raw
in_voltage0_vccint_raw   in_voltage1_vccaux_raw   in_voltage2_vccbram_raw
in_voltage3_vccpint_raw  in_voltage4_vccpaux_raw  in_voltage5_vccoddr_raw
in_voltage6_vrefp_raw    in_voltage7_vrefn_raw
```

There is **no external auxiliary (VAUX) channel** and no VP/VN channel.

On this overlay the Arduino **A0** header signal reaches the XADC through
the PL-side **VAUX1** path. The board file's `arduino_a0 = Y11` entry is
the digital header view; the accepted AudioLab XADC constraint uses the
dedicated VAUX1 analog pins **E17/D18** (`hw/Pynq-Z2/xadc_a0.xdc`). PYNQ's
own base overlay reads Arduino analog via a PL-side XADC driven by the
Arduino MicroBlaze. Our custom overlay had no such IP before D74/D76, so:

| Candidate path | Verdict |
| --- | --- |
| A. Linux IIO / sysfs (`iio:device0`) | **Unavailable** for A0 -- the PS-XADC IIO shows only internal rails, and the PL `xadc_wiz` is NOT exposed as an IIO channel even after the D74 bit loads. |
| B. Existing PYNQ XADC API | **Unavailable** -- the base overlay's XADC path is not present here. |
| C. Add AXI XADC Wizard (additive `.tcl`) + read via **AXI MMIO** | **DONE (D74).** `xadc_wiz_a0 @ 0x43D40000` reads VAUX1; `Fp02mXadcMmioReader` reads `overlay.xadc_wiz_a0` register `0x244`. |
| D. External SPI ADC (MCP3008) on Arduino SPI | Last resort; not pursued. |

**Conclusion:** A0 is read via the PL XADC Wizard over **AXI MMIO** (not
IIO -- the PL XADC does not appear in `/sys/bus/iio`). See
`XADC_INTEGRATION_DESIGN.md`. If the XADC Wizard is ever absent,
`Fp02mXadcMmioReader.available()` / `Fp02mA0Reader.available()` return
`False` and the GUI stays in SOURCE=MANUAL; nothing crashes.

---

## 2. Wiring (PYNQ-Z2 Arduino header)

> Power off the PYNQ-Z2 before changing any wiring. Never hot-swap.

| Signal | PYNQ pin | Note |
| --- | --- | --- |
| A0 analog in | J1 pin 6 (board header A0; VAUX1 E17/D18 in XDC) | 0..3.3 V analog to XADC VAUX. Never drive >3.3 V. |
| 3.3 V | J7 pin 5 **or** J7 pin 7 | pedal pot supply. **Do NOT use 5 V.** |
| GND | J7 pin 2 **or** J7 pin 3 | pedal pot ground + filter cap return. |

Protection / filtering on the wiper:

```
FP02M wiper --[ 1k..4.7k series R ]--+--> A0 (J1 pin 6)
                                     |
                                  [ 0.01uF .. 0.1uF ]   (A0 -> GND)
                                     |
                                    GND
```

The series R + cap form an RC low-pass (anti-alias / glitch filter) and
limit current into the XADC pin. The pot ends go to 3.3 V and GND; the
wiper is the variable tap.

### Measure the TRS pinout FIRST -- do not assume

The FP02M is a TRS expression pedal. Tip / Ring / Sleeve assignment is
**not** assumed. Before wiring, measure with a multimeter (pedal
unpowered):

1. Measure resistance Tip-Ring, Ring-Sleeve, Tip-Sleeve.
2. Sweep the pedal heel -> centre -> toe while watching each pair.
3. The pair whose resistance is roughly **constant** = the two pot ends.
4. The terminal whose resistance **varies** vs the others = the **wiper**.

Final wiring:

```
FP02M pot end A  -> PYNQ J7 pin 5 or 7  (3.3 V)
FP02M pot end B  -> PYNQ J7 pin 2 or 3  (GND)
FP02M wiper      -> 1k..4.7k series R   -> PYNQ A0 (J1 pin 6)
A0 -> GND        -> 0.01uF .. 0.1uF cap
```

Record the measured values in the calibration JSON `notes` field.

### Hard prohibitions

- No 5 V to the FP02M or A0.
- No >3.3 V into A0.
- Do not guess Tip/Ring/Sleeve -- measure.
- Do not wire the FP02M to a digital GPIO pin.
- Do not change wiring with PYNQ power on.
- Do not connect 3.3 V / GND before the pot ends are confirmed by meter.

---

## 3. Calibration

`scripts/calibrate_fp02m.py` walks heel and toe sampling and writes JSON
(default `~/.config/audio_lab/fp02m_calibration.json`):

```json
{
  "raw_min": 123,
  "raw_max": 3910,
  "invert": false,
  "deadband": 1,
  "smoothing_alpha": 0.25,
  "created_at": "2026-05-29T12:00:00",
  "read_path": "iio",
  "notes": "TRS: tip=wiper, ..."
}
```

- `raw_min` / `raw_max` are the heel / toe raw counts (auto-ordered).
- `invert` is set when heel reads higher than toe.
- `deadband` (u8 counts) and `smoothing_alpha` default to 1 and 0.25.
- A calibration with `raw_min == raw_max` (or too narrow) is rejected; the
  runtime refuses to map and stays MANUAL with a warning. **No silent
  fake range is used.** The probe script can suggest provisional values
  from observed min/max with an explicit warning.

---

## 4. MANUAL / PEDAL source design

`AppState.wah_source` is `"manual"` or `"pedal"`. The FX panel renders
`SOURCE: MANUAL` / `SOURCE: PEDAL`; encoder-2 button while WAH is the
selected effect toggles it (and a click on the SOURCE strip does the same).

| Mode | POSITION source | POS knob | Hardware POSITION byte |
| --- | --- | --- | --- |
| MANUAL | GUI / encoder POS knob (`all_knob_values["Wah"][0]`, 0..100) | editable | `set_wah_settings(position=percent)` |
| PEDAL | FP02M A0 raw -> u8 | shows the **live** pedal value | `set_wah_settings(position_raw=u8)` |

Internal state:

- `wah_source`            : "manual" | "pedal"
- `all_knob_values["Wah"][0]` : manual POSITION percent 0..100 (saved as-is)
- `wah_position_pedal_u8` : last pedal byte 0..255 (live; not persisted)
- `wah_pedal_available`   : bool, for the "PEDAL UNAVAILABLE" UI hint

In PEDAL mode the POS knob still *stores* the manual percent (so flipping
back to MANUAL restores the user's value), but the **value sent to
hardware is the pedal byte**. Q / VOL / BIAS remain editable and are
never overwritten by the pedal path. Critically, the encoder applier in
PEDAL mode does **not** pass `position=` to `set_wah_settings` (that would
clear the cached `position_raw`); the pedal controller is the only writer
of `position_raw`.

---

## 5. Python layers (`audio_lab_pynq/fp02m.py`)

- `Fp02mCalibration` -- dataclass (raw_min, raw_max, invert, deadband,
  smoothing_alpha) + validation + JSON load/save.
- `Fp02mXadcMmioReader` -- **the working backend on the AudioLab overlay.**
  Reads the PL `xadc_wiz_a0` VAUX1 register (`0x244`) via AXI MMIO through
  `overlay.xadc_wiz_a0`. `from_overlay(ovl)` builds it; `available()`
  sanity-checks VCCINT so an unprogrammed PL reads unavailable.
- `Fp02mA0Reader` -- XADC-IIO backend (off-board / legacy). The PL XADC is
  not an IIO channel, so this stays unavailable on the AudioLab overlay.
- `MockFp02mReader` -- deterministic test reader (sequence / noise /
  stuck / exception modes).
- `Fp02mPositionMapper` -- `raw_to_u8(raw)`, `update_smoothed(raw)`
  (EMA smoothing + deadband + invert + clamp).
- `Fp02mWahController` -- ties reader + mapper; `poll_once()` returns a
  new u8 only when it moved past the deadband, else `None`; tracks
  availability and falls back safely on repeated read errors.

---

## 6. Runtime loop (`scripts/run_encoder_hdmi_gui.py`)

`--wah-pedal` enables the FP02M controller; `--wah-calibration PATH`
points at the JSON. The pedal poll is a non-blocking periodic step inside
the existing GUI loop, rate-limited to `--wah-pedal-hz` (default 100). It:

1. only runs when `wah_source == "pedal"` and the reader is available;
2. reads + smooths + deadband-checks; on a real change calls
   `overlay.set_wah_settings(position_raw=u8)` and marks the loop active
   so the frame re-renders;
3. on repeated read errors, flips `wah_source` back to `"manual"` and
   marks the pedal unavailable (no crash, audio/HDMI keep running).

All overlay writes stay on the main thread (no GPIO-write race with the
encoder applier).

Recommended defaults: read 100 Hz, max GPIO write 100 Hz, smoothing_alpha
0.20..0.35, deadband 1..2 u8. Foot operation does not need >100 Hz and the
PL Wah already smooths POSITION.

---

## 7. Fallback / safety design

- Pedal not connected / A0 unreadable -> GUI boots in MANUAL, no crash.
- SOURCE=PEDAL with no calibration -> refuse to map; stay MANUAL + warn.
- Repeated read errors in PEDAL -> auto fall back to MANUAL.
- Only `wah_position_raw` is written from the pedal; Q/VOL/BIAS untouched.
- Extremely noisy pedal -> raise deadband / smoothing.

---

## 8. Real-hardware test procedure (to run once wired + XADC built)

1. `python3 scripts/probe_fp02m_a0.py --mmio --duration 10 --rate 100`
   (add `--download` only on the first overlay load of the session) --
   must not crash; reports read path, raw min/max seen, voltage,
   position_u8.
   - A0 open -> ~0 raw (confirmed: raw ~8). A0 to GND -> low raw; A0 to
     3.3 V -> high raw (~4095); midpoint -> ~2048.
   - FP02M heel vs toe -> distinct raw; smooth sweep moves continuously.
2. `python3 scripts/calibrate_fp02m.py --mmio` -- save heel/toe -> JSON.
3. `python3 scripts/run_fp02m_wah_test.py --calibration ...` -- sweep ->
   POSITION byte changes; no zipper noise.
4. GUI: select WAH, encoder-2 button -> SOURCE=PEDAL, Wah ON, sweep the
   pedal; adjust Q/VOL/BIAS while sweeping (must stay independent).
5. all_off bypass clean; Wah OFF clean; Wah ON pedal sweep audibly moves
   the centre frequency; check for pop / click / noise.

---

## 9. Known risks

- Older / rollback bits without `xadc_wiz_a0` cannot read A0; the current
  D79 bitstream includes the D76 XADC path.
- Wrong TRS wiring -> stuck / inverted reading (measure first).
- Noisy pedal value -> zipper noise (RC filter + deadband + smoothing).
- GUI thread blocking if the read loop is mis-tuned (kept non-blocking).
- Calibration drift over temperature / pedal wear -> re-calibrate.
- Future XADC Wizard add changes the PL -> timing must be re-reviewed.

## 10. Bench result (2026-05-29)

- **TRS wiring adopted: candidate 1** -- Tip (tip) -> A0, Ring (middle) ->
  3.3 V (J7), Sleeve (base) -> GND. Confirmed by sweep, not assumed.
- **A0 sweep (probe `--mmio`, pedal swept heel<->toe):** raw_min `16`,
  raw_max `4068`, **span `4052`** (>= the 2000 "good" bar), continuous
  variation, no stuck-0 / stuck-4095. Heel = low raw, toe = high raw, so
  **invert = false** (heel -> Wah POSITION 0 = low freq, matches the
  D73 Wah default).
- **A0 single-pin:** open ~6..10 (~0.007 V). A0=GND / A0=3.3 V jumper
  checks are optional once the pedal sweep already covers the full range.
- **Calibration saved:** `/root/.config/audio_lab/fp02m_calibration.json`
  (sudo HOME) -- raw_min 16, raw_max 4068, invert false, deadband 2,
  smoothing_alpha 0.25. Written directly from the sweep endpoints (the
  interactive `calibrate_fp02m.py --mmio` is equivalent but needs
  heel/toe Enter presses at the bench).
- **Read path is AXI MMIO** via `Fp02mXadcMmioReader` (overlay
  `xadc_wiz_a0` register `0x244` = VAUX1 / A0) -- NOT IIO.
- **Controller -> overlay confirmed:** `run_fp02m_wah_test.py --no-download`
  reports the MMIO reader available, maps the pedal to a POSITION byte,
  and writes `set_wah_settings(position_raw=...)`.
- **Superseded D74 gate:** `run_encoder_hdmi_gui.py --pmod-mode dsp
  --wah-pedal --live-apply --skip-rat` still remains the right smoke
  command, but the audio bench gate passed later in D76. POS bar follows
  the pedal, Wah ON sweep is audible, Q/VOL/BIAS stay independent, and
  all_off / Wah-OFF bypass stay clean on the accepted D76+ builds.

## 11. Bench result (2026-05-31, D76 -- XADC re-add on the D75 island)

- **XADC re-enabled on the island.** Un-commented the two
  `create_project.tcl` lines (`add_files xadc_a0.xdc`,
  `source xadc_integration.tcl`); Clash DSP untouched, island preserved.
  Rebuild WNS `-0.368 ns` (100 MHz `clk_fpga_0` fabric = audio AXIS closes
  at +0.614 ns / 0 failing endpoints; the 22 failures are intra-50 MHz DSP).
  **The D74 bitcrusher did NOT recur** -- proving the D74 cause was the
  -11 ns audio-AXIS P&R degradation, not the XADC.
- **A0 sweep (probe `--mmio`):** heel raw ~8, toe raw ~2847, sweep span
  ~2999 (>= the 2000 good bar), continuous, no stuck-0/stuck-4095. Note
  this rig's toe tops out ~2847 (vs D74's 4068) -- still a wide span.
- **Calibration saved:** `/root/.config/audio_lab/fp02m_calibration.json`
  (sudo HOME) -- raw_min 8, raw_max 2847, invert false, deadband 2,
  smoothing_alpha 0.25. Calibrated min-then-max-then-sweep.
- **Pedal "C" taper (bench "完璧").** `Fp02mCalibration.position_curve`
  (default `"c"`) shapes the pedal-travel fraction in
  `Fp02mPositionMapper.raw_to_u8` via `_apply_position_curve`: `"c"` =
  anti-log `1 - (1 - x)**WAH_C_CURVE_GAMMA` (gamma 2.5) so the wah rises fast
  off the heel and fine-resolves toward the toe (endpoints fixed 0/255).
  `"linear"`/`"a"` selectable; persisted in the JSON; a legacy JSON without
  the field defaults to `"c"`. FP02M pedal path only (GUI / encoder POS stay
  linear); Clash DSP untouched.
- **Wah-only crossbar routing fix (load-bearing).** The AXIS source crossbar
  (`_route_effect_chain`) only switched to `guitar_chain` (the DSP) when the
  `gate_word` low byte was non-zero, but the Wah enable lives on
  `axi_gpio_wah` ctrlD and is NOT in `gate_word`. So a Wah-only state (every
  other effect off, the FP02M driving POSITION) stayed on `passthrough` and
  bypassed the whole DSP -- the Wah included, giving a clean (no-wah) sound.
  Fix in `AudioLabOverlay.py`: `_route_effect_chain` treats an enabled Wah
  as "an effect is on", and `set_wah_settings` re-routes the crossbar when
  it toggles the enable (not on the 100 Hz `position_raw` stream).
  Python-only, no bit rebuild. This gap was invisible in D74 because the
  XADC bit was rejected on audio before the Wah-sweep test was reached.
- **Wah Q self-oscillation cap.** At high Q the resonant band-pass
  self-oscillates near full POSITION (toe). Bench: Q byte 89 (UI 35 %) clean,
  byte 128 still howled, byte 166 (UI 65 %) howled hard.
  `control_maps.wah_q_byte` now caps the UI Q range at `WAH_Q_BYTE_MAX = 80`
  (UI keeps 0..100; only the dial top is tamed; Clash voicing unchanged).
  Bench: Q = 100 + full toe no longer oscillates.
- **Functional + audio PASS:** `run_fp02m_wah_test.py --no-download` writes
  `position_raw` continuously; with the routing fix the Wah filter sweep
  audibly follows the pedal; with the Q cap there is no self-oscillation at
  the extremes. User verdict: 問題なし.

## See also

- `XADC_INTEGRATION_DESIGN.md` -- the built XADC-Wizard integration (MMIO).
- `GPIO_CONTROL_MAP.md` -- `axi_gpio_wah` row (POSITION / `position_raw`).
- `DECISIONS.md` D72 / D73 (Wah) and D74 (this FP02M pass).
