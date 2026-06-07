"""Register-write helpers used by :class:`AudioLabOverlay`.

These helpers keep the write-side bookkeeping out of the overlay facade while
preserving the existing private-method contract. They intentionally operate on
the overlay instance instead of introducing a separate state object: AXI GPIO
handles, cached words, and routing are all already owned by ``AudioLabOverlay``.
"""

from audio_lab_pynq import control_maps as _cm


def write_gpio(gpio, word):
    """Write one AXI GPIO word with all pins configured as outputs."""
    gpio.write(0x04, 0x00000000)
    gpio.write(0x00, int(word) & 0xFFFFFFFF)


def require_effect_gpios(ovl):
    """Raise when a required effect-control GPIO is missing."""
    missing = [name for name in ovl._REQUIRED_EFFECT_GPIOS
               if not hasattr(ovl, name)]
    if missing:
        raise RuntimeError(
            'missing effect control GPIO(s): ' + ', '.join(missing))


def apply_distortion_state_to_words(ovl):
    """Patch gate / overdrive / distortion cached words from distortion state.

    This preserves bytes owned by other sections in the output-only GPIO cache.
    """
    s = ovl._dist_state
    pedal_mask = int(s['pedal_mask']) & 0x7F

    gate = ovl._cached_gate_word & 0x0000FFFF
    if pedal_mask & (1 << ovl._DIST_PEDAL_BIT['rat']):
        gate |= 0x10
    gate = _cm.set_byte(gate, 2, _cm.percent_to_u8(s['bias'], 255))
    gate = _cm.set_byte(gate, 3, _cm.percent_to_u8(s['mix'], 255))
    ovl._cached_gate_word = gate

    od_model = ovl._normalize_overdrive_model(ovl._od_state['model'])
    od_ctrlD = _cm.overdrive_ctrlD(
        distortion_tight=s['tight'],
        overdrive_model=od_model,
        overdrive_model_count=ovl.OVERDRIVE_MODEL_COUNT,
    )
    ovl._cached_overdrive_word = _cm.set_byte(
        ovl._cached_overdrive_word & 0x00FFFFFF, 3, od_ctrlD)

    ovl._cached_distortion_word = _cm.distortion_word(
        tone=s['tone'],
        level=s['level'],
        drive=s['drive'],
        pedal_mask=pedal_mask,
    )

    if hasattr(ovl, 'axi_gpio_gate'):
        ovl._write_gpio(ovl.axi_gpio_gate, ovl._cached_gate_word)
    if hasattr(ovl, 'axi_gpio_overdrive'):
        ovl._write_gpio(ovl.axi_gpio_overdrive, ovl._cached_overdrive_word)
    if hasattr(ovl, 'axi_gpio_distortion'):
        ovl._write_gpio(ovl.axi_gpio_distortion,
                        ovl._cached_distortion_word)


def apply_overdrive_state_to_words(ovl, touch_gate=False, sink=None):
    """Rebuild and write the overdrive word, optionally updating gate bit 1."""
    s = ovl._od_state
    od_model = ovl._normalize_overdrive_model(s['model'])
    tight = ovl._dist_state['tight'] if hasattr(ovl, '_dist_state') else 0
    od_word = _cm.overdrive_word(
        tone=s['tone'],
        level=s['level'],
        drive=s['drive'],
        distortion_tight=tight,
        overdrive_model=od_model,
        overdrive_model_count=ovl.OVERDRIVE_MODEL_COUNT,
    )
    ovl._cached_overdrive_word = od_word
    if hasattr(ovl, 'axi_gpio_overdrive'):
        ovl._write_gpio(ovl.axi_gpio_overdrive, od_word)

    if touch_gate and hasattr(ovl, 'axi_gpio_gate'):
        gate = ovl._cached_gate_word & ~0x02
        if s['enabled']:
            gate |= 0x02
        ovl._cached_gate_word = gate
        ovl._write_gpio(ovl.axi_gpio_gate, gate)
        ovl._route_effect_chain(sink, gate)


def apply_noise_suppressor_state_to_word(ovl, mirror_to_gate=True):
    """Write the dedicated noise-suppressor word and optional gate mirror."""
    s = ovl._noise_suppressor_state
    word = _cm.noise_suppressor_word(
        threshold=s['threshold'],
        decay=s['decay'],
        damp=s['damp'],
        mode=s['mode'],
    )
    ovl._cached_noise_suppressor_word = word
    gpio = getattr(ovl, ovl.NOISE_SUPPRESSOR_GPIO_NAME, None)
    if gpio is not None:
        ovl._write_gpio(gpio, word)

    if mirror_to_gate and hasattr(ovl, 'axi_gpio_gate'):
        gate_word = ovl._cached_gate_word
        gate_word = _cm.set_byte(
            gate_word, 1, _cm.noise_threshold_to_u8(s['threshold']))
        if s['enabled']:
            gate_word |= 0x01
        else:
            gate_word &= ~0x01
        ovl._cached_gate_word = gate_word
        ovl._write_gpio(ovl.axi_gpio_gate, gate_word)


def apply_compressor_state_to_word(ovl):
    """Write the dedicated compressor word."""
    s = ovl._compressor_state
    word = _cm.compressor_word(
        threshold=s['threshold'],
        ratio=s['ratio'],
        response=s['response'],
        makeup=s['makeup'],
        enabled=s['enabled'],
    )
    ovl._cached_compressor_word = word
    gpio = getattr(ovl, ovl.COMPRESSOR_GPIO_NAME, None)
    if gpio is not None:
        ovl._write_gpio(gpio, word)


def apply_wah_state_to_word(ovl):
    """Write the dedicated Wah word."""
    s = ovl._wah_state
    raw = s.get('position_raw')
    if raw is not None:
        word = _cm.wah_word(
            position_raw=raw,
            q=s['q'],
            volume=s['volume'],
            bias=s['bias'],
            enabled=s['enabled'],
        )
    else:
        word = _cm.wah_word(
            position=s.get('position', 0),
            q=s['q'],
            volume=s['volume'],
            bias=s['bias'],
            enabled=s['enabled'],
        )
    ovl._cached_wah_word = word
    gpio = getattr(ovl, ovl.WAH_GPIO_NAME, None)
    if gpio is not None:
        ovl._write_gpio(gpio, word)


def write_effect_gpios(ovl, words):
    """Write every effect-section GPIO in the historical order."""
    ovl._write_gpio(ovl.axi_gpio_gate, words['gate'])
    ovl._write_gpio(ovl.axi_gpio_overdrive, words['overdrive'])
    ovl._write_gpio(ovl.axi_gpio_distortion, words['distortion'])
    ovl._write_gpio(ovl.axi_gpio_eq, words['eq'])
    for gpio_attr, words_key, gate_bit, description in ovl._OPTIONAL_EFFECT_GPIOS:
        if hasattr(ovl, gpio_attr):
            ovl._write_gpio(getattr(ovl, gpio_attr), words[words_key])
        elif words['gate'] & gate_bit:
            raise RuntimeError(
                '{} is required for {}'.format(gpio_attr, description))
    ovl._write_gpio(ovl.axi_gpio_reverb, words['reverb'])


def refresh_cached_words(ovl, words):
    """Snapshot the just-written shared effect words."""
    ovl._cached_gate_word = words['gate']
    ovl._cached_overdrive_word = words['overdrive']
    ovl._cached_distortion_word = words['distortion']

