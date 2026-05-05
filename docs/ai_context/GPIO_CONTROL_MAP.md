# GPIO control map

**この台帳の GPIO 設計は固定です。**
名前 / アドレス / ctrlA・B・C・D の意味は再配置しません。新エフェクト
追加時は、まずここに書かれた `reserved` byte / bit を確認して、それで
足りる場合は新規 AXI GPIO を増やさずに済ませてください。

Every effect parameter reaches the Clash block through an `axi_gpio_*`
instance. Each GPIO is a single-channel, 32-bit, all-output instance
(`C_ALL_OUTPUTS=1`, `C_GPIO_WIDTH=32`, `C_IS_DUAL=0`). The PS writes one
32-bit word; the Clash side decomposes that word into four bytes:

| Field | Bits |
| --- | --- |
| `ctrlA` | `[7:0]` |
| `ctrlB` | `[15:8]` |
| `ctrlC` | `[23:16]` |
| `ctrlD` | `[31:24]` |

The Python side does this via `AudioLabOverlay._write_gpio(gpio, word)`,
which writes `0x00000000` to the TRI register at offset `0x04` (all bits
output) and the data word to offset `0x00`. **AXI GPIO is output-only**,
so `get_*` accessors on the Python side return cached values, not a
read-back from hardware.

## Status legend

| Status | Meaning |
| --- | --- |
| `active` | The byte is consumed by the live Clash bitstream and a Python writer keeps it up to date. Don't repurpose. |
| `reserved` | Byte / bit is reserved for a planned feature. Python may already accept the value. Do not repurpose; if you need it for a different feature, allocate a different byte first. |
| `legacy mirror` | Byte is **not** read by the active Clash bitstream but is still written for backward compatibility with older overlays. Do not delete the writer. Don't reuse the slot for a new feature. |
| `unused` | No current writer or reader. May be allocated to a new feature, but check `Notes` for the historical reason it stayed unused. |
| `deprecated` | Was active in a past bitstream, now retired. Same handling as `legacy mirror` from a "do not repurpose" standpoint, but with no active writer. |

## GPIO inventory (固定台帳)

| GPIO | Address | Owner | ctrlA | ctrlB | ctrlC | ctrlD | Status (A / B / C / D) | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `axi_gpio_reverb` | `0x43C30000` | reverb | reverb enable (low byte) | decay | tone | mix | active / active / active / active | Enable bit lives in this GPIO, not in `gate_control.ctrlA` bit 5; the gate flag is mirrored separately. |
| `axi_gpio_gate` | `0x43C40000` | gate + master flags | effect ON/OFF flags (8 bits) | noise gate threshold (legacy mirror) | distortion bias | distortion mix | active / legacy mirror / active / active | `ctrlB` is the legacy hard-gate threshold byte; the live noise stage reads from `axi_gpio_noise_suppressor.ctrlA`. We keep mirroring threshold + the noise_gate_on flag here so old bitstreams keep working. Do not repurpose `ctrlB` even though the live bitstream ignores it. |
| `axi_gpio_overdrive` | `0x43C50000` | overdrive (+ distortion `tight`) | overdrive tone | overdrive level | overdrive drive | distortion `tight` | active / active / active / active | `ctrlD` is shared with the distortion section: the distortion writers (`set_distortion_settings`, `_apply_distortion_state_to_words`) own that one byte. Overdrive-only writers must not touch `ctrlD`. |
| `axi_gpio_distortion` | `0x43C60000` | distortion | distortion tone | distortion level | distortion drive | pedal mask (`[6:0]`); bit 7 reserved | active / active / active / active (mask: bits 0/1/2/6 active, bits 3/4/5 reserved, bit 7 reserved) | `clean_boost` (bit 0), `tube_screamer` (bit 1), `metal` (bit 6) are implemented Clash stages. `rat` (bit 2) maps onto the existing RAT stage and forces `gate_control.ctrlA` bit 4 high in Python. `ds1` (bit 3) / `big_muff` (bit 4) / `fuzz_face` (bit 5) are reserved bits; the Python API accepts them but audio is bit-exact bypass. Bit 7 is reserved for a future 8th pedal slot. |
| `axi_gpio_eq` | `0x43C70000` | EQ | low | mid | high | unused (must write 0) | active / active / active / unused | `ctrlD` has no Clash consumer. Reserved for a future EQ Q / character byte; do not assume it is free for unrelated effects. |
| `axi_gpio_delay` | `0x43C80000` | RAT distortion (historical name) | RAT filter | RAT level | RAT drive | RAT mix | active / active / active / active | **Name and use diverge.** The IP was originally created for a delay; the live Clash stage drives the RAT. Do not rename this GPIO — the Python attribute, the block design, and the `.hwh` all reference `axi_gpio_delay` and renaming requires a `block_design.tcl` change (forbidden by default). |
| `axi_gpio_amp` | `0x43C90000` | amp simulator core | input gain | master | presence | resonance | active / active / active / active | Companion to `axi_gpio_amp_tone`; both must be present together for the amp section to be useful. |
| `axi_gpio_amp_tone` | `0x43CA0000` | amp simulator tone stack | bass | middle | treble | character | active / active / active / active | `character` is a single-byte voicing knob inside the amp section. |
| `axi_gpio_cab` | `0x43CB0000` | cab IR | mix | level | model (0/85/170 = 3 presets) | air | active / active / active / active | `ctrlC` is quantised: 0, 85, 170 select the three preset IRs. Do not treat it as a free byte. |
| `axi_gpio_noise_suppressor` | `0x43CC0000` | noise suppressor | NS threshold | NS decay | NS damp | mode (reserved) | active / active / active / reserved | `ctrlD` is reserved for future NS-2 vs NS-1X mode, attack / hold knobs. The byte is sent (Python clamps to `[0,255]`) but the live Clash side does nothing with it yet. |
| `axi_gpio_compressor` | `0x43CD0000` | compressor | comp threshold | comp ratio | comp response | enable (bit 7) + makeup u7 (bits[6:0]) | active / active / active / active | Stereo-linked feed-forward peak compressor. Bit 7 of `ctrlD` is the section enable; bits[6:0] are the Q7 makeup byte (`makeup_to_u7`). The compressor is **not** gated by `gate_control.ctrlA` -- enable lives entirely inside this GPIO. Sits between the noise suppressor and the overdrive in the Clash pipeline. |

### Free / reserved bytes summary (for new-effect planning)

| Where | Status | What you can do |
| --- | --- | --- |
| `axi_gpio_eq.ctrlD` | unused (no Clash consumer) | Could be allocated to a new EQ-section feature (e.g. Q / mid-frequency / character). Must not be repurposed for a non-EQ effect — a future EQ revision is the planned use. |
| `axi_gpio_distortion.ctrlD[7]` | reserved | Reserved for a future 8th pedal slot. Keep zero. |
| `axi_gpio_distortion.ctrlD[3]` (ds1) | reserved | Mask bit accepted by the Python API today; landing it requires only a Clash stage (no new GPIO). |
| `axi_gpio_distortion.ctrlD[4]` (big_muff) | reserved | Same. |
| `axi_gpio_distortion.ctrlD[5]` (fuzz_face) | reserved | Same. |
| `axi_gpio_noise_suppressor.ctrlD` | reserved | Future NS mode / attack / hold byte. Bytes 0..255 already pass through Python. |
| `axi_gpio_compressor.ctrlD[6:0]` | active | Compressor `MAKEUP` (u7). Bit 7 of `ctrlD` is the compressor enable flag. Do not repurpose. |
| `axi_gpio_gate.ctrlB` | legacy mirror (dead in live bitstream) | Do **not** reuse for a new feature; older bitstreams still depend on it. |

## Noise Suppressor (deployed)

The dedicated `axi_gpio_noise_suppressor` IP at `0x43CC0000` carries the
THRESHOLD / DECAY / DAMP knobs of a BOSS NS-2 / NS-1X-style noise
suppressor. The Clash side replaces the legacy hard noise gate stages
with envelope + smoothed-gain stages; the on/off flag still rides on
`gate_control` bit 0 (the existing `noise_gate_on`).

| Field | Carries |
| --- | --- |
| `noise_suppressor_control.ctrlA` | THRESHOLD byte (0..255). Same scaling as the legacy `gateThreshold`; the active envelope-compare level. |
| `noise_suppressor_control.ctrlB` | DECAY byte (0..255). Drives the close-ramp slowness; 0 = tight chopper, 255 = slow sustaining. |
| `noise_suppressor_control.ctrlC` | DAMP byte (0..255). Maximum attenuation depth; 0 = ~50 % closed gain, 255 = full mute. |
| `noise_suppressor_control.ctrlD` | mode byte. Reserved for future NS modes (attack / hold / NS-2 vs NS-1X variant). 0 today. |

### Threshold scale (Python -> byte)

The Python API exposes `threshold` on a 0..100 scale that is one tenth
of the legacy `noise_gate_threshold` range:

| Python `threshold` | byte (`round(threshold * 255 / 1000)`) |
| --- | --- |
| 0   | 0  |
| 10  | 3  |
| 50  | 13 |
| 100 | 26 (== legacy `noise_gate_threshold=10` byte) |

`set_guitar_effects(noise_gate_threshold=...)` now uses the same scale,
so callers that previously asked for `noise_gate_threshold=8` should
ask for the equivalent value (~80) under the new scaling. Values
outside 0..100 are clamped at the Python boundary.

### Legacy `gate_control.ctrlB`

`gate_control` bits[15:8] (the legacy `gateThreshold` byte) is **not
consumed by the new bitstream** — the active gain stage is the
suppressor driven by `axi_gpio_noise_suppressor`. We keep writing the
same threshold byte into the legacy slot for backward compatibility
with older bitstreams that lack the new GPIO; on the new bitstream
the byte is dead. **Do not repurpose this byte.**

## Compressor (deployed)

The dedicated `axi_gpio_compressor` IP at `0x43CD0000` carries the
THRESHOLD / RATIO / RESPONSE / MAKEUP knobs of a stereo-linked
feed-forward peak compressor. Sits between the noise suppressor and
the overdrive in the Clash pipeline. The enable flag lives **inside
this GPIO** (`ctrlD` bit 7), not on `gate_control.ctrlA` -- the latter
flag byte is already full and the compressor section was added on a
new GPIO rather than steal a flag bit (`DECISIONS.md` D14).

| Field | Carries |
| --- | --- |
| `compressor_control.ctrlA` | THRESHOLD byte (0..255). `byte = round(threshold * 255 / 100)` for `threshold` 0..100. Same scaling as `nsThreshold` so the byte range maps to a familiar envelope-compare level. |
| `compressor_control.ctrlB` | RATIO byte (0..255). `byte = round(ratio * 255 / 100)`. Larger byte -> stronger gain reduction. |
| `compressor_control.ctrlC` | RESPONSE byte (0..255). Both attack and release smoothing share this knob. 0 = tight / fast; 255 = slow / sustaining. |
| `compressor_control.ctrlD` | bit 7 = compressor enable; bits[6:0] = MAKEUP (u7 0..127, `byte = round(makeup * 127 / 100)` clamped). Q8-ish makeup factor 192..319 (~0.75x..1.25x). |

### Why a new GPIO

`gate_control.ctrlA` (the master flag byte) is already full (every bit
is owned by an existing effect's enable; see the table below). The
existing `reserved` bytes are claimed by other planned features:
`axi_gpio_distortion.ctrlD[3..5,7]` (extra distortion pedals),
`axi_gpio_noise_suppressor.ctrlD` (NS mode / attack / hold),
`axi_gpio_eq.ctrlD` (planned EQ-section knob). Stealing one of those
would violate the "do not repurpose a `reserved` byte for a different
feature" rule (this file, GPIO allocation rules section). So the
compressor landed on its own AXI GPIO at `0x43CD0000`, with a fresh
`compressor_control` port on the Clash top entity. See
`DECISIONS.md` D14.

## `gate_control` flag byte (`ctrlA`)

| Bit | Meaning | Status |
| --- | --- | --- |
| 0 | noise gate / noise suppressor enable | active |
| 1 | overdrive enable | active |
| 2 | distortion section master enable (legacy distortion + pedal stages) | active |
| 3 | EQ enable | active |
| 4 | RAT enable (also driven high by the Python helper when the `rat` pedal-mask bit is set) | active |
| 5 | reverb enable | active (also mirrored into `axi_gpio_reverb.ctrlA` low byte) |
| 6 | amp simulator enable | active |
| 7 | cab IR enable | active |

## Distortion pedal-mask (deployed)

`gate_control` bit 2 is the section master. `distortion_control.ctrlD`
carries a 7-bit pedal-enable mask; bit 7 is reserved.

| `distortion_control.ctrlD` bit | Pedal | FPGA stage | Status |
| --- | --- | --- | --- |
| 0 | `clean_boost` | implemented | active |
| 1 | `tube_screamer` | implemented | active |
| 2 | `rat` | mapped onto the existing RAT stage; Python forces `gate_control` bit 4 high when this bit is set | active |
| 3 | `ds1` | no Clash stage; audio is bit-exact bypass when this bit alone is set | reserved |
| 4 | `big_muff` | same | reserved |
| 5 | `fuzz_face` | same | reserved |
| 6 | `metal` | implemented | active |
| 7 | (8th pedal slot) | none | reserved |

The legacy distortion stage (the original `distortion=` /
`distortion_tone` / `distortion_level` API) is auto-bypassed when any
pedal-mask bit is set, so `exclusive=True` at the Python level
really does isolate the chosen voicing. See
`DISTORTION_REFACTOR_PLAN.md` for design notes and
`DSP_EFFECT_CHAIN.md` for the per-stage register layout.

Common parameters stay outside the per-pedal mask:

| Field | Carries |
| --- | --- |
| `distortion_control.ctrlA` | tone (shared) |
| `distortion_control.ctrlB` | level (shared) |
| `distortion_control.ctrlC` | drive (shared) |
| `gate_control.ctrlC` | bias |
| `gate_control.ctrlD` | mix |
| `overdrive_control.ctrlD` | tight |

Every byte the pedal-mask scheme touches was already spare in the
existing bitstream layout, so **no `block_design.tcl` change was
needed** — and none should be needed when adding the reserved
pedals either.

## Cache discipline (Python side)

Because the GPIOs are output-only, `AudioLabOverlay` keeps caches:
`_cached_gate_word`, `_cached_overdrive_word`, `_cached_distortion_word`,
and `_cached_noise_suppressor_word`. Any setter that touches one byte
must:

1. Mask out the byte it owns from the cached word.
2. OR the new byte in.
3. Write the full word to the GPIO.
4. Update the cache to the value just written.

`set_guitar_effects` overwrites every cache en masse with the words
it just wrote, and merges the cached distortion-state byte values back
into its kwargs so that bytes owned by the distortion section are not
silently reset.

## GPIO allocation rules (for new effects)

Read this **before** touching a new byte / bit / GPIO.

1. **Never rename a GPIO.** `axi_gpio_delay` controls the RAT, not a
   delay; do not rename it. The block design, the `.hwh`, and every
   notebook reference the existing names.
2. **Never change addresses.** The address map is fixed by
   `block_design.tcl` and known to every overlay file in deployed
   bitstreams.
3. **Never repurpose an existing byte.** `legacy mirror` slots are
   load-bearing for backward compatibility. `reserved` slots are held
   for a planned feature; if your effect is a different feature, pick
   a different byte.
4. **Use the existing `reserved` slots first.** The free / reserved
   bytes summary above lists every byte not currently driving live
   Clash logic. If a planned effect fits one of those bytes, use it.
5. **AXI GPIO is output-only.** The Python writer must keep a cache
   and do read-modify-write on the cached word. No `gpio.read()` based
   round-trip works.
6. **Python / Clash / Notebook / tests must agree.** When the same
   byte changes meaning between layers, every consumer must be updated
   in lock-step.
7. **Adding a new `axi_gpio_*` IP is the last resort.** It requires:
   - A `block_design.tcl` change (off-limits unless the user explicitly
     approves).
   - `NUM_MI` increment on `ps7_0_axi_periph` and a new address segment.
   - A `topEntity` port change on `LowPassFir.hs`, Clash → VHDL → IP
     repackage.
   - A full Vivado bit/hwh rebuild and timing review.
   - Python `AudioLabOverlay` attribute, default cache, `set_/get_`
     API, and tests.
   - `docs/ai_context/GPIO_CONTROL_MAP.md` row update plus an entry in
     `DECISIONS.md`.
   The shipped `axi_gpio_noise_suppressor` (`0x43CC0000`) is the
   exception, approved case-by-case under `DECISIONS.md` D11.
8. **Refactoring rule (current branch).** When restructuring Python /
   docs / tests / notebooks for "easier effect-add" reasons, the GPIO
   table in this file must not change. Only the wording and rule
   commentary should evolve.

## See also

- [`EFFECT_ADDING_GUIDE.md`](EFFECT_ADDING_GUIDE.md) — decision flow for
  whether a new effect needs Python-only / reserved-bit / new-GPIO work.
- [`EFFECT_STAGE_TEMPLATE.md`](EFFECT_STAGE_TEMPLATE.md) — fillable
  template for a new effect entry.
- [`DECISIONS.md`](DECISIONS.md) D2, D11 — block-design and noise-suppressor
  decisions that pin this map.
