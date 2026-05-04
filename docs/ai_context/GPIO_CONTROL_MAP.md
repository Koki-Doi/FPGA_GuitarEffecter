# GPIO control map

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

## GPIO inventory

| GPIO | Address | Owner | ctrlA | ctrlB | ctrlC | ctrlD |
| --- | --- | --- | --- | --- | --- | --- |
| `axi_gpio_gate` | `0x43C40000` | gate + master flags | effect ON/OFF flags (8 bits) | noise gate threshold *(legacy mirror)* | distortion bias | distortion mix |
| `axi_gpio_overdrive` | `0x43C50000` | overdrive | overdrive tone | overdrive level | overdrive drive | distortion tight |
| `axi_gpio_distortion` | `0x43C60000` | distortion | distortion tone | distortion level | distortion drive | distortion pedal mask |
| `axi_gpio_eq` | `0x43C70000` | EQ | low | mid | high | (unused) |
| `axi_gpio_delay` | `0x43C80000` | RAT | filter | level | drive | mix |
| `axi_gpio_amp` | `0x43C90000` | amp simulator | input gain | master | presence | resonance |
| `axi_gpio_amp_tone` | `0x43CA0000` | amp tone | bass | middle | treble | character |
| `axi_gpio_cab` | `0x43CB0000` | cab IR | mix | level | model | air |
| `axi_gpio_reverb` | `0x43C30000` | reverb | enable | decay | tone | mix |
| `axi_gpio_noise_suppressor` | `0x43CC0000` | noise suppressor | NS threshold | NS decay | NS damp | NS mode (reserved) |

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
consumed by the new bitstream** -- the active gain stage is the
suppressor driven by `axi_gpio_noise_suppressor`. We keep writing the
same threshold byte into the legacy slot for backward compatibility
with older bitstreams that lack the new GPIO; on the new bitstream
the byte is dead.

## `gate_control` flag byte (`ctrlA`)

| Bit | Meaning |
| --- | --- |
| 0 | noise gate enable |
| 1 | overdrive enable |
| 2 | **distortion section master enable** (legacy distortion + pedal stages) |
| 3 | EQ enable |
| 4 | RAT enable (also driven high by the Python helper when the `rat` pedal-mask bit is set) |
| 5 | reverb enable |
| 6 | amp simulator enable |
| 7 | cab IR enable |

## Distortion pedal-mask (deployed)

`gate_control` bit 2 is the section master. `distortion_control.ctrlD`
carries a 7-bit pedal-enable mask; bit 7 is reserved.

| `distortion_control.ctrlD` bit | Pedal | FPGA stage |
| --- | --- | --- |
| 0 | `clean_boost` | implemented |
| 1 | `tube_screamer` | implemented |
| 2 | `rat` | mapped onto the existing RAT stage; Python forces `gate_control` bit 4 high when this bit is set |
| 3 | `ds1` | reserved (mask bit accepted; no Clash stage yet, audio bit-exact) |
| 4 | `big_muff` | reserved (same) |
| 5 | `fuzz_face` | reserved (same) |
| 6 | `metal` | implemented |
| 7 | reserved | unused |

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

Because the GPIOs are output-only, `AudioLabOverlay` keeps three caches:
`_cached_gate_word`, `_cached_overdrive_word`, `_cached_distortion_word`.
Any setter that touches one byte must:

1. Mask out the byte it owns from the cached word.
2. OR the new byte in.
3. Write the full word to the GPIO.
4. Update the cache to the value just written.

`set_guitar_effects` overwrites all three caches en masse with the words
it just wrote, and merges the cached distortion-state byte values back
into its kwargs so that bytes owned by the distortion section are not
silently reset.
