# FP02M expression pedal -> Wah POSITION integration

Status: **software + docs landed; A0 read path NOT yet available on the
deployed overlay; Vivado XADC-Wizard rebuild deferred (separate approval).**
See `DECISIONS.md` D74.

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

On Zynq-7000 the Arduino **A0** pin (J1 pin 6, Zynq **Y11**) reaches the
XADC only as a **VAUX auxiliary channel routed through the PL**. PYNQ's
own base overlay reads Arduino analog via a PL-side XADC driven by the
Arduino MicroBlaze. Our custom overlay has no such IP, so:

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
| A0 analog in | J1 pin 6 (Zynq Y11) | 0..3.3 V analog to XADC VAUX. Never drive >3.3 V. |
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

- A0 read path unavailable until the XADC Wizard is built (current state).
- Wrong TRS wiring -> stuck / inverted reading (measure first).
- Noisy pedal value -> zipper noise (RC filter + deadband + smoothing).
- GUI thread blocking if the read loop is mis-tuned (kept non-blocking).
- Calibration drift over temperature / pedal wear -> re-calibrate.
- Future XADC Wizard add changes the PL -> timing must be re-reviewed.

## See also

- `XADC_INTEGRATION_DESIGN.md` -- the deferred XADC-Wizard proposal.
- `GPIO_CONTROL_MAP.md` -- `axi_gpio_wah` row (POSITION / `position_raw`).
- `DECISIONS.md` D72 / D73 (Wah) and D74 (this FP02M pass).
