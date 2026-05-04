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
| `axi_gpio_gate` | `0x43C40000` | gate + master flags | effect ON/OFF flags (8 bits) | noise gate threshold | distortion bias | distortion mix |
| `axi_gpio_overdrive` | `0x43C50000` | overdrive | overdrive tone | overdrive level | overdrive drive | distortion tight |
| `axi_gpio_distortion` | `0x43C60000` | distortion | distortion tone | distortion level | distortion drive | distortion pedal mask (planned) |
| `axi_gpio_eq` | `0x43C70000` | EQ | low | mid | high | (unused) |
| `axi_gpio_delay` | `0x43C80000` | RAT | filter | level | drive | mix |
| `axi_gpio_amp` | `0x43C90000` | amp simulator | input gain | master | presence | resonance |
| `axi_gpio_amp_tone` | `0x43CA0000` | amp tone | bass | middle | treble | character |
| `axi_gpio_cab` | `0x43CB0000` | cab IR | mix | level | model | air |
| `axi_gpio_reverb` | `0x43C30000` | reverb | enable | decay | tone | mix |

## `gate_control` flag byte (`ctrlA`)

| Bit | Meaning |
| --- | --- |
| 0 | noise gate enable |
| 1 | overdrive enable |
| 2 | **distortion section master enable** (legacy distortion + new pedal stages) |
| 3 | EQ enable |
| 4 | RAT enable |
| 5 | reverb enable |
| 6 | amp simulator enable |
| 7 | cab IR enable |

## Distortion refactor: pedal-mask plan

The previous design tried to switch eight distortion models with a single
`model_select` field that fanned out into a giant case/mux at every Clash
stage. That destroyed timing (see `TIMING_AND_FPGA_NOTES.md`) and is being
replaced.

The replacement keeps `gate_control` bit 2 as the **section master** but
turns `distortion_control.ctrlD` into a per-pedal enable mask:

| `distortion_control.ctrlD` bit | Pedal |
| --- | --- |
| 0 | `clean_boost` |
| 1 | `tube_screamer` |
| 2 | `rat_style` (may be remapped onto the existing RAT stage) |
| 3 | `ds1_style` |
| 4 | `big_muff` |
| 5 | `fuzz_face` |
| 6 | `metal` |
| 7 | reserved |

Common parameters stay outside the per-pedal mask:

| Field | Carries |
| --- | --- |
| `distortion_control.ctrlA` | tone (shared) |
| `distortion_control.ctrlB` | level (shared) |
| `distortion_control.ctrlC` | drive (shared) |
| `gate_control.ctrlC` | bias |
| `gate_control.ctrlD` | mix |
| `overdrive_control.ctrlD` | tight |

Every byte the new scheme touches is currently spare in the existing
bitstream layout, so **no `block_design.tcl` change is needed**.

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
