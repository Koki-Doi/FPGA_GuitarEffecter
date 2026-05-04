from pynq import Overlay
from enum import Enum
import os
from .AxisSwitch import AxisSwitch
from .AudioCodec import ADAU1761

class XbarSource(Enum):
    line_in = 0
    dma     = 1
class XbarEffect(Enum):
    passthrough = 0
    guitar_chain = 1
    reverb = 1
    low_pass_filter = 1
class XbarSink(Enum):
    headphone = 0
    dma = 1
    
class AudioLabOverlay(Overlay):

    # Selectable distortion pedals. Order matches their bit position in
    # distortion_control.ctrlD (the pedal-enable mask). bit 7 is reserved.
    #
    #   bit 0 : clean_boost     (Clash stage implemented)
    #   bit 1 : tube_screamer   (Clash stage implemented)
    #   bit 2 : rat             (mapped onto the existing RAT stage; this
    #                            bit is recorded in the GPIO mask but the
    #                            audio path is gated by the legacy
    #                            rat_on flag in gate_control)
    #   bit 3 : ds1             (reserved; no Clash stage yet)
    #   bit 4 : big_muff        (reserved; no Clash stage yet)
    #   bit 5 : fuzz_face       (reserved; no Clash stage yet)
    #   bit 6 : metal           (Clash stage implemented)
    DISTORTION_PEDALS = (
        'clean_boost',
        'tube_screamer',
        'rat',
        'ds1',
        'big_muff',
        'fuzz_face',
        'metal',
    )
    _DIST_PEDAL_BIT = {name: i for i, name in enumerate(DISTORTION_PEDALS)}

    # Pedals that have a working Clash stage in the current bitstream.
    # The others are accepted at the API level (and their bit is set in
    # the mask) but currently produce bit-exact bypass.
    DISTORTION_PEDALS_IMPLEMENTED = ('clean_boost', 'tube_screamer', 'rat', 'metal')

    DISTORTION_DEFAULTS = {
        'pedal_mask': 0,
        'drive': 20,
        'tone': 50,
        'level': 35,
        'bias': 50,
        'tight': 50,
        'mix': 100,
    }

    def __init__(self, bitfile_name=None, **kwargs):
        # Generate default bitfile name
        if bitfile_name is None:
            this_dir = os.path.dirname(__file__)
            bitfile_name = os.path.join(this_dir, 'bitstreams', 'audio_lab.bit')
        super().__init__(bitfile_name, **kwargs)
        self.x_source = self.axis_switch_source
        self.x_sink = self.axis_switch_sink
        self.codec = ADAU1761()
        self.codec.config_pll()
        self.codec.config_codec()
        self.route(XbarSource.line_in, XbarEffect.passthrough, XbarSink.headphone)
        # Distortion-section state. The control GPIOs are output-only, so
        # the Python side caches every byte it owns and rewrites the
        # whole 32-bit word on each change. set_guitar_effects keeps
        # this cache in sync.
        self._dist_state = dict(self.DISTORTION_DEFAULTS)
        self._cached_gate_word = 0
        self._cached_overdrive_word = 0
        self._cached_distortion_word = 0
        if hasattr(self, 'axi_gpio_distortion'):
            self._apply_distortion_state_to_words()
        
    def route(self, source, effect, sink):    
        self.x_source.start_cfg()
        self.x_sink.start_cfg()
        
        self.x_source.disable_all()
        self.x_sink.disable_all()
        
        self.x_source.route_pair(effect.value,source.value)
        self.x_sink.route_pair(sink.value,effect.value)
        
        self.x_source.stop_cfg()
        self.x_sink.stop_cfg()

    @staticmethod
    def _clamp_percent(value):
        value = int(round(value))
        if value < 0:
            return 0
        if value > 100:
            return 100
        return value

    @staticmethod
    def _clamp_range(value, minimum, maximum):
        value = int(round(value))
        if value < minimum:
            return minimum
        if value > maximum:
            return maximum
        return value

    @classmethod
    def _percent_to_u8(cls, value, maximum=255):
        value = cls._clamp_percent(value)
        return cls._clamp_range(value * maximum / 100, 0, 255)

    @classmethod
    def _level_to_q7(cls, value):
        value = cls._clamp_range(value, 0, 200)
        return cls._clamp_range(value * 128 / 100, 0, 255)

    @staticmethod
    def _pack3(a, b, c):
        return (int(c) << 16) | (int(b) << 8) | int(a)

    @staticmethod
    def _pack4(a, b, c, d):
        return (int(d) << 24) | (int(c) << 16) | (int(b) << 8) | int(a)

    @staticmethod
    def _write_gpio(gpio, word):
        gpio.write(0x04, 0x00000000)
        gpio.write(0x00, int(word) & 0xFFFFFFFF)

    @classmethod
    def _normalize_pedal_name(cls, name):
        """Resolve a pedal name (string) to its bit position.

        Numeric inputs are accepted for completeness — they are clamped
        to the documented 0..6 range. Anything outside the range or
        unknown name raises ``ValueError``.
        """
        if isinstance(name, str):
            try:
                return cls._DIST_PEDAL_BIT[name]
            except KeyError:
                raise ValueError(
                    'unknown distortion pedal: {!r}; valid pedals are {}'.format(
                        name, ', '.join(cls.DISTORTION_PEDALS)))
        idx = int(name)
        if idx < 0 or idx >= len(cls.DISTORTION_PEDALS):
            raise ValueError(
                'distortion pedal index {} out of range 0..{}'.format(
                    idx, len(cls.DISTORTION_PEDALS) - 1))
        return idx

    @classmethod
    def _pedal_mask_from_iterable(cls, pedals):
        """Build an 8-bit pedal mask from a sequence of names / bit
        indices, or from a dict ``{name: bool}``.
        """
        mask = 0
        if isinstance(pedals, dict):
            for name, enabled in pedals.items():
                bit = cls._normalize_pedal_name(name)
                if enabled:
                    mask |= (1 << bit)
        else:
            for entry in pedals:
                bit = cls._normalize_pedal_name(entry)
                mask |= (1 << bit)
        return mask & 0x7F

    def _apply_distortion_state_to_words(self):
        """Patch the cached gate / overdrive / distortion words with the
        current distortion state and write them out to the GPIOs. The
        cache holds the last word written to each GPIO so the bytes
        owned by other effects are preserved across distortion-only
        edits (the AXI GPIO is output-only, so we cannot read it back).
        """
        s = self._dist_state
        pedal_mask = int(s['pedal_mask']) & 0x7F
        tone_byte = self._percent_to_u8(s['tone'], 255)
        level_byte = self._level_to_q7(s['level'])
        drive_byte = self._percent_to_u8(s['drive'], 255)
        bias_byte = self._percent_to_u8(s['bias'], 255)
        tight_byte = self._percent_to_u8(s['tight'], 255)
        mix_byte = self._percent_to_u8(s['mix'], 255)

        # gate: keep ctrlA (effect flags) and ctrlB (gate threshold);
        # overwrite ctrlC (bias) and ctrlD (mix). When the pedal mask's
        # rat bit is set, also drive the legacy rat_on flag (gate.bit4)
        # high so that the existing RAT stage processes audio. The
        # rat_on flag is owned both by set_guitar_effects() and here;
        # this method only forces it on, never off, so a user who
        # asked for rat via set_guitar_effects(rat_on=True) still keeps
        # rat enabled even after a set_distortion_pedal('clean_boost')
        # call.
        gate = self._cached_gate_word & 0x0000FFFF
        if pedal_mask & (1 << self._DIST_PEDAL_BIT['rat']):
            gate |= 0x10  # rat_on (flag4)
        gate |= (bias_byte & 0xFF) << 16
        gate |= (mix_byte & 0xFF) << 24
        self._cached_gate_word = gate

        # overdrive: keep ctrlA-C (existing OD params); overwrite ctrlD
        # (tight).
        od = self._cached_overdrive_word & 0x00FFFFFF
        od |= (tight_byte & 0xFF) << 24
        self._cached_overdrive_word = od

        # distortion: tone / level / drive plus pedal mask in ctrlD.
        # ctrlD bit 7 stays reserved (cleared).
        dist = (
            (tone_byte & 0xFF)
            | ((level_byte & 0xFF) << 8)
            | ((drive_byte & 0xFF) << 16)
            | ((pedal_mask & 0x7F) << 24)
        )
        self._cached_distortion_word = dist

        if hasattr(self, 'axi_gpio_gate'):
            self._write_gpio(self.axi_gpio_gate, self._cached_gate_word)
        if hasattr(self, 'axi_gpio_overdrive'):
            self._write_gpio(self.axi_gpio_overdrive, self._cached_overdrive_word)
        if hasattr(self, 'axi_gpio_distortion'):
            self._write_gpio(self.axi_gpio_distortion, self._cached_distortion_word)

    # ---- Distortion section public API ----------------------------------

    def set_distortion_pedal(self, name, enabled=True, exclusive=True):
        """Toggle one distortion pedal in the pedal-enable mask.

        ``name`` is one of the entries in ``DISTORTION_PEDALS`` (or its
        bit index). ``enabled`` defaults to True. ``exclusive=True``
        (the default) clears every other distortion-pedal bit before
        setting this one, so the user gets exactly one voicing — this
        is the safe path. ``exclusive=False`` allows stacking multiple
        pedals in series; that path is documented as advanced.
        """
        bit = self._normalize_pedal_name(name)
        mask = int(self._dist_state['pedal_mask']) & 0x7F
        if enabled and exclusive:
            mask = (1 << bit)
        elif enabled:
            mask |= (1 << bit)
        else:
            mask &= ~(1 << bit) & 0x7F
        self._dist_state['pedal_mask'] = mask & 0x7F
        self._apply_distortion_state_to_words()
        return self.get_distortion_pedals()

    def set_distortion_pedals(self, **kwargs):
        """Set multiple pedals at once via keyword arguments.

        Example: ``set_distortion_pedals(clean_boost=True, metal=False)``.
        Names that are not in ``DISTORTION_PEDALS`` raise ValueError.
        Pedals that are not mentioned keep their current state.
        """
        mask = int(self._dist_state['pedal_mask']) & 0x7F
        for name, enabled in kwargs.items():
            bit = self._normalize_pedal_name(name)
            if enabled:
                mask |= (1 << bit)
            else:
                mask &= ~(1 << bit) & 0x7F
        self._dist_state['pedal_mask'] = mask & 0x7F
        self._apply_distortion_state_to_words()
        return self.get_distortion_pedals()

    def clear_distortion_pedals(self):
        """Disable every distortion pedal in one call. The
        distortion-section master flag in gate_control bit 2 is left
        alone — call ``set_guitar_effects(distortion_on=False)`` if
        you also want to drop the master.
        """
        self._dist_state['pedal_mask'] = 0
        self._apply_distortion_state_to_words()
        return self.get_distortion_pedals()

    def get_distortion_pedals(self):
        """Return a dict ``{pedal_name: bool}`` reflecting the cached
        pedal mask. The AXI GPIO is output-only so this is a Python-side
        cache, not a register read-back.
        """
        mask = int(self._dist_state['pedal_mask']) & 0x7F
        return {name: bool(mask & (1 << i))
                for i, name in enumerate(self.DISTORTION_PEDALS)}

    def set_distortion_settings(self, drive=None, tone=None, level=None,
                                bias=None, tight=None, mix=None,
                                pedal=None, pedals=None, exclusive=True):
        """Update any subset of the distortion-section parameters.

        Numeric parameters (drive / tone / level / bias / tight / mix)
        are 0..100. ``pedal`` selects a single pedal by name and applies
        ``exclusive=exclusive`` semantics. ``pedals`` accepts an iterable
        or dict, building the full mask. Unspecified parameters keep
        their cached values.

        This method does not change the distortion-section master flag
        in gate_control bit 2; that is still owned by
        ``set_guitar_effects(distortion_on=...)``.
        """
        if drive is not None:
            self._dist_state['drive'] = self._clamp_percent(drive)
        if tone is not None:
            self._dist_state['tone'] = self._clamp_percent(tone)
        if level is not None:
            self._dist_state['level'] = self._clamp_percent(level)
        if bias is not None:
            self._dist_state['bias'] = self._clamp_percent(bias)
        if tight is not None:
            self._dist_state['tight'] = self._clamp_percent(tight)
        if mix is not None:
            self._dist_state['mix'] = self._clamp_percent(mix)
        if pedals is not None:
            self._dist_state['pedal_mask'] = self._pedal_mask_from_iterable(pedals)
        if pedal is not None:
            bit = self._normalize_pedal_name(pedal)
            if exclusive:
                self._dist_state['pedal_mask'] = (1 << bit)
            else:
                self._dist_state['pedal_mask'] = (
                    int(self._dist_state['pedal_mask']) | (1 << bit)) & 0x7F
        self._apply_distortion_state_to_words()
        return self.get_distortion_settings()

    def set_distortion_drive(self, value):
        return self.set_distortion_settings(drive=value)

    def set_distortion_tone(self, value):
        return self.set_distortion_settings(tone=value)

    def set_distortion_level(self, value):
        return self.set_distortion_settings(level=value)

    def set_distortion_bias(self, value):
        return self.set_distortion_settings(bias=value)

    def set_distortion_tight(self, value):
        return self.set_distortion_settings(tight=value)

    def set_distortion_mix(self, value):
        return self.set_distortion_settings(mix=value)

    def get_distortion_settings(self):
        """Return the cached distortion-section state.

        Includes the raw 7-bit pedal mask, a per-pedal bool dict, and
        the shared parameters. Cached values reflect the last call to
        ``set_distortion_settings`` / ``set_distortion_pedal*`` /
        ``set_guitar_effects``; the AXI GPIO cannot be read back from
        this overlay configuration.
        """
        s = self._dist_state
        return {
            'pedal_mask': int(s['pedal_mask']) & 0x7F,
            'pedals': self.get_distortion_pedals(),
            'drive': s['drive'],
            'tone': s['tone'],
            'level': s['level'],
            'bias': s['bias'],
            'tight': s['tight'],
            'mix': s['mix'],
        }

    @classmethod
    def reverb_control_word(cls, enabled=True, reverb=35, tone=70, mix=25):
        reverb = cls._clamp_percent(reverb)
        tone = cls._clamp_percent(tone)
        mix = cls._clamp_percent(mix)

        enable_hw = 1 if enabled else 0
        reverb_hw = int(round(reverb * 220 / 100))
        tone_hw = int(round(tone * 255 / 100))
        mix_hw = int(round(mix * 192 / 100))

        return (
            (mix_hw << 24) |
            (tone_hw << 16) |
            (reverb_hw << 8) |
            enable_hw
        )

    @classmethod
    def guitar_effect_control_words(
        cls,
        noise_gate_on=False,
        noise_gate_threshold=8,
        overdrive_on=False,
        overdrive_tone=65,
        overdrive_level=100,
        overdrive_drive=30,
        distortion_on=False,
        distortion_tone=65,
        distortion_level=100,
        distortion=25,
        distortion_pedal_mask=0,
        distortion_bias=50,
        distortion_tight=50,
        distortion_mix=100,
        rat_on=False,
        rat_filter=35,
        rat_level=100,
        rat_drive=55,
        rat_mix=100,
        amp_on=False,
        amp_input_gain=35,
        amp_bass=50,
        amp_middle=50,
        amp_treble=50,
        amp_presence=45,
        amp_resonance=35,
        amp_master=80,
        amp_character=35,
        cab_on=False,
        cab_mix=100,
        cab_level=100,
        cab_model=1,
        cab_air=50,
        eq_on=False,
        eq_low=100,
        eq_mid=100,
        eq_high=100,
        reverb_on=False,
        reverb_decay=30,
        reverb_tone=65,
        reverb_mix=20,
        **unused,
    ):
        flags = 0
        flags |= 0x01 if noise_gate_on else 0
        flags |= 0x02 if overdrive_on else 0
        flags |= 0x04 if distortion_on else 0
        flags |= 0x08 if eq_on else 0
        flags |= 0x10 if rat_on else 0
        flags |= 0x20 if reverb_on else 0
        flags |= 0x40 if amp_on else 0
        flags |= 0x80 if cab_on else 0

        pedal_mask = int(distortion_pedal_mask) & 0x7F
        bias_byte = cls._percent_to_u8(distortion_bias, 255)
        mix_byte = cls._percent_to_u8(distortion_mix, 255)
        tight_byte = cls._percent_to_u8(distortion_tight, 255)

        gate_word = (
            flags
            | (cls._percent_to_u8(noise_gate_threshold, 255) << 8)
            | (bias_byte << 16)
            | (mix_byte << 24)
        )
        overdrive_word = (
            cls._pack3(
                cls._percent_to_u8(overdrive_tone, 255),
                cls._level_to_q7(overdrive_level),
                cls._percent_to_u8(overdrive_drive, 255),
            )
            | (tight_byte << 24)
        )
        distortion_word = (
            cls._pack3(
                cls._percent_to_u8(distortion_tone, 255),
                cls._level_to_q7(distortion_level),
                cls._percent_to_u8(distortion, 255),
            )
            | ((pedal_mask & 0x7F) << 24)
        )
        eq_word = cls._pack3(
            cls._level_to_q7(eq_low),
            cls._level_to_q7(eq_mid),
            cls._level_to_q7(eq_high),
        )
        rat_word = cls._pack4(
            cls._percent_to_u8(rat_filter, 255),
            cls._level_to_q7(cls._clamp_range(rat_level, 0, 150)),
            cls._percent_to_u8(rat_drive, 255),
            cls._percent_to_u8(rat_mix, 255),
        )
        amp_word = cls._pack4(
            cls._percent_to_u8(amp_input_gain, 255),
            cls._level_to_q7(cls._clamp_range(amp_master, 0, 150)),
            cls._percent_to_u8(amp_presence, 255),
            cls._percent_to_u8(amp_resonance, 255),
        )
        amp_tone_word = cls._pack4(
            cls._percent_to_u8(amp_bass, 255),
            cls._percent_to_u8(amp_middle, 255),
            cls._percent_to_u8(amp_treble, 255),
            cls._percent_to_u8(amp_character, 255),
        )
        cab_word = cls._pack4(
            cls._percent_to_u8(cab_mix, 255),
            cls._level_to_q7(cls._clamp_range(cab_level, 0, 150)),
            cls._clamp_range(cab_model, 0, 2) * 85,
            cls._percent_to_u8(cab_air, 255),
        )
        reverb_word = cls._pack3(
            cls._percent_to_u8(reverb_decay, 220),
            cls._percent_to_u8(reverb_tone, 255),
            cls._percent_to_u8(reverb_mix, 192),
        )

        return {
            'gate': gate_word,
            'overdrive': overdrive_word,
            'distortion': distortion_word,
            'eq': eq_word,
            'rat': rat_word,
            'delay': rat_word,
            'amp': amp_word,
            'amp_tone': amp_tone_word,
            'cab': cab_word,
            'reverb': reverb_word,
        }

    def set_guitar_effects(self, sink=XbarSink.headphone, **kwargs):
        required = [
            'axi_gpio_gate',
            'axi_gpio_overdrive',
            'axi_gpio_distortion',
            'axi_gpio_eq',
            'axi_gpio_reverb',
        ]
        missing = [name for name in required if not hasattr(self, name)]
        if missing:
            raise RuntimeError('missing effect control GPIO(s): ' + ', '.join(missing))

        # Merge cached distortion-section state into kwargs so that callers
        # who only flip on/off do not silently reset pedal_mask / bias /
        # tight / mix back to the classmethod defaults.
        if hasattr(self, '_dist_state'):
            s = self._dist_state
            scalar_pairs = (
                ('distortion', 'drive'),
                ('distortion_tone', 'tone'),
                ('distortion_level', 'level'),
                ('distortion_bias', 'bias'),
                ('distortion_tight', 'tight'),
                ('distortion_mix', 'mix'),
            )
            for key, state_key in scalar_pairs:
                if key in kwargs:
                    s[state_key] = self._clamp_percent(kwargs[key])
                else:
                    kwargs[key] = s[state_key]
            if 'distortion_pedal_mask' in kwargs:
                s['pedal_mask'] = int(kwargs['distortion_pedal_mask']) & 0x7F
            kwargs['distortion_pedal_mask'] = s['pedal_mask']
            # If the rat pedal bit is set, also assert the legacy
            # rat_on flag so the existing RAT stage actually processes
            # audio. We never force rat_on off from here.
            if s['pedal_mask'] & (1 << self._DIST_PEDAL_BIT['rat']):
                kwargs['rat_on'] = True

        words = self.guitar_effect_control_words(**kwargs)
        self._write_gpio(self.axi_gpio_gate, words['gate'])
        self._write_gpio(self.axi_gpio_overdrive, words['overdrive'])
        self._write_gpio(self.axi_gpio_distortion, words['distortion'])
        self._write_gpio(self.axi_gpio_eq, words['eq'])
        if hasattr(self, 'axi_gpio_delay'):
            self._write_gpio(self.axi_gpio_delay, words['rat'])
        elif words['gate'] & 0x10:
            raise RuntimeError('axi_gpio_delay is required for RAT-style distortion control')
        if hasattr(self, 'axi_gpio_amp'):
            self._write_gpio(self.axi_gpio_amp, words['amp'])
        elif words['gate'] & 0x40:
            raise RuntimeError('axi_gpio_amp is required for amp simulator control')
        if hasattr(self, 'axi_gpio_amp_tone'):
            self._write_gpio(self.axi_gpio_amp_tone, words['amp_tone'])
        elif words['gate'] & 0x40:
            raise RuntimeError('axi_gpio_amp_tone is required for amp simulator tone control')
        if hasattr(self, 'axi_gpio_cab'):
            self._write_gpio(self.axi_gpio_cab, words['cab'])
        elif words['gate'] & 0x80:
            raise RuntimeError('axi_gpio_cab is required for cab IR simulator control')
        self._write_gpio(self.axi_gpio_reverb, words['reverb'])

        # Refresh the cached words so subsequent set_distortion_*
        # calls preserve the effect flags / rat / amp / cab / reverb
        # bits that this call just wrote.
        self._cached_gate_word = words['gate']
        self._cached_overdrive_word = words['overdrive']
        self._cached_distortion_word = words['distortion']

        if words['gate'] & 0xFF:
            self.route(XbarSource.line_in, XbarEffect.guitar_chain, sink)
        else:
            self.route(XbarSource.line_in, XbarEffect.passthrough, sink)
        return words

    # ---- Phase 1 diagnostics --------------------------------------------

    def dump_codec_registers(self, names=None):
        return self.codec.print_registers(names)

    def codec_register_diff(self, before, names=None):
        if names is None:
            names = list(before.keys())
        after = self.codec.dump_registers(names)
        diffs = self.codec.diff_register_snapshots(before, after)
        print(self.codec.format_register_diff(diffs))
        return diffs

    def capture_input(self, num_frames=48000, **kwargs):
        from . import diagnostics
        return diagnostics.capture_input(self, num_frames=num_frames, **kwargs)

    def diagnostic_capture(self, label, num_frames=48000, save_dir=None,
                           settling_ms=0, discard_initial_frames=0):
        from . import diagnostics
        samples = diagnostics.capture_input(
            self, num_frames=num_frames,
            settling_ms=settling_ms,
            discard_initial_frames=discard_initial_frames)
        stats = diagnostics.compute_input_stats(samples)
        print('=== {} ==='.format(label))
        print(diagnostics.format_input_stats(stats))
        if save_dir is not None:
            os.makedirs(save_dir, exist_ok=True)
            diagnostics.save_input_capture(samples, os.path.join(save_dir, label))
        return samples, stats

    def output_zero_test(self, **kwargs):
        from . import diagnostics
        return diagnostics.output_zero_test(self, **kwargs)

    def output_sine_test(self, **kwargs):
        from . import diagnostics
        return diagnostics.output_sine_test(self, **kwargs)

    def set_reverb(self, enabled=True, reverb=35, tone=70, mix=25, sink=XbarSink.headphone):
        if hasattr(self, 'axi_gpio_gate'):
            return self.set_guitar_effects(
                noise_gate_on=False,
                overdrive_on=False,
                distortion_on=False,
                amp_on=False,
                cab_on=False,
                eq_on=False,
                reverb_on=enabled,
                reverb_decay=reverb,
                reverb_tone=tone,
                reverb_mix=mix,
                sink=sink,
            )['reverb']

        word = self.reverb_control_word(enabled, reverb, tone, mix)

        if hasattr(self, 'axi_gpio_reverb'):
            self._write_gpio(self.axi_gpio_reverb, word)
        elif enabled:
            raise RuntimeError('axi_gpio_reverb is not available in this overlay')

        effect = XbarEffect.reverb if enabled else XbarEffect.passthrough
        self.route(XbarSource.line_in, effect, sink)
        return word
