from pynq import Overlay
from enum import Enum
import os
from .AxisSwitch import AxisSwitch
from .AudioCodec import ADAU1761
from . import control_maps as _cm
from .effect_defaults import (
    DISTORTION_DEFAULTS as _DISTORTION_DEFAULTS,
    DISTORTION_PEDALS as _DISTORTION_PEDALS,
    DISTORTION_PEDALS_IMPLEMENTED as _DISTORTION_PEDALS_IMPLEMENTED,
    NOISE_SUPPRESSOR_DEFAULTS as _NOISE_SUPPRESSOR_DEFAULTS,
    COMPRESSOR_DEFAULTS as _COMPRESSOR_DEFAULTS,
    AMP_MODELS as _AMP_MODELS,
)

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
    #   bit 3 : ds1             (Clash stage implemented; BOSS DS-1 style)
    #   bit 4 : big_muff        (Clash stage implemented; Big Muff Pi style)
    #   bit 5 : fuzz_face       (Clash stage implemented; Fuzz Face style)
    #   bit 6 : metal           (Clash stage implemented)
    # Pedal name -> mask bit, defaults, and "implemented" subset all live
    # in audio_lab_pynq.effect_defaults so the notebook UI and the tests
    # share one source of truth. Re-exported as class attributes so
    # legacy callers (AudioLabOverlay.DISTORTION_DEFAULTS,
    # AudioLabOverlay.DISTORTION_PEDALS, ...) still work.
    DISTORTION_PEDALS = _DISTORTION_PEDALS
    _DIST_PEDAL_BIT = {name: i for i, name in enumerate(_DISTORTION_PEDALS)}
    DISTORTION_PEDALS_IMPLEMENTED = _DISTORTION_PEDALS_IMPLEMENTED
    DISTORTION_DEFAULTS = _DISTORTION_DEFAULTS

    # Noise Suppressor (BOSS NS-2 / NS-1X style operation, all-FPGA).
    # Driven by the dedicated axi_gpio_noise_suppressor at 0x43CC0000:
    #   ctrlA = threshold byte  (envelope-compare level)
    #   ctrlB = decay byte      (close-ramp slowness)
    #   ctrlC = damp byte       (max attenuation depth)
    #   ctrlD = mode byte       (reserved, 0 today)
    # On/off rides on gate_control flag bit 0 (noise_gate_on) so the
    # existing set_guitar_effects(noise_gate_on=...) toggle still works.
    NOISE_SUPPRESSOR_DEFAULTS = _NOISE_SUPPRESSOR_DEFAULTS
    NOISE_SUPPRESSOR_GPIO_NAME = 'axi_gpio_noise_suppressor'

    # Compressor (stereo-linked feed-forward peak compressor, all-FPGA).
    # Driven by the dedicated axi_gpio_compressor at 0x43CD0000:
    #   ctrlA = threshold byte         (envelope-compare level)
    #   ctrlB = ratio byte             (compression strength)
    #   ctrlC = response byte          (smoothing time)
    #   ctrlD bit 7 = enable; ctrlD bits[6:0] = makeup (Q7 0..127)
    # Sits between the noise suppressor and the overdrive in the chain.
    COMPRESSOR_DEFAULTS = _COMPRESSOR_DEFAULTS
    COMPRESSOR_GPIO_NAME = 'axi_gpio_compressor'

    # Amp Simulator named "models" — convenience labels that map onto
    # the existing ``amp_character`` percent value. The Clash side
    # quantises the same byte into a 2-bit ``ampModelSel`` index that
    # darkens the post-clip pre-LPF a touch more for the higher-gain
    # models so high-gain pedals into the amp do not produce the
    # second brightening that the audio-analysis pass flagged.
    # ``AMP_MODELS`` is a friendly mapping; the numeric
    # ``amp_character`` knob still works directly.
    AMP_MODELS = _AMP_MODELS

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
        # Noise Suppressor cache. The new GPIO is output-only so we
        # keep the last word + the per-parameter ints. Safe defaults:
        # enabled=False so loading the overlay never produces an
        # unexpected gating transient.
        self._noise_suppressor_state = dict(self.NOISE_SUPPRESSOR_DEFAULTS)
        self._cached_noise_suppressor_word = 0
        if hasattr(self, self.NOISE_SUPPRESSOR_GPIO_NAME):
            self._apply_noise_suppressor_state_to_word()
        # Compressor cache. Output-only GPIO; hold the last word and the
        # per-parameter ints. Defaults keep the compressor off so loading
        # the overlay never produces an unexpected gain change.
        self._compressor_state = dict(self.COMPRESSOR_DEFAULTS)
        self._cached_compressor_word = 0
        if hasattr(self, self.COMPRESSOR_GPIO_NAME):
            self._apply_compressor_state_to_word()
        
    def route(self, source, effect, sink):    
        self.x_source.start_cfg()
        self.x_sink.start_cfg()
        
        self.x_source.disable_all()
        self.x_sink.disable_all()
        
        self.x_source.route_pair(effect.value,source.value)
        self.x_sink.route_pair(sink.value,effect.value)
        
        self.x_source.stop_cfg()
        self.x_sink.stop_cfg()

    # Numeric helpers. The canonical implementations live in
    # audio_lab_pynq.control_maps; these classmethods are thin
    # delegates so external callers and tests using
    # AudioLabOverlay._clamp_percent / _percent_to_u8 / _pack4 keep
    # working byte-for-byte.

    @staticmethod
    def _clamp_percent(value):
        return _cm.clamp_percent(value)

    @staticmethod
    def _clamp_range(value, minimum, maximum):
        return _cm.clamp_int(value, minimum, maximum)

    @staticmethod
    def _percent_to_u8(value, maximum=255):
        return _cm.percent_to_u8(value, maximum)

    @staticmethod
    def _level_to_q7(value):
        return _cm.level_to_q7(value)

    @staticmethod
    def _pack3(a, b, c):
        return _cm.pack_u8x3(a, b, c)

    @staticmethod
    def _pack4(a, b, c, d):
        return _cm.pack_u8x4(a, b, c, d)

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

    # ---- Noise Suppressor public API ------------------------------------

    # Both helpers delegate to control_maps so the encoding stays
    # identical to the module-level functions used by the notebook
    # and the tests. New 100 == legacy 10 (one tenth of the old span).
    @staticmethod
    def _noise_threshold_to_u8(value):
        return _cm.noise_threshold_to_u8(value)

    @staticmethod
    def _noise_suppressor_word(threshold, decay, damp, mode=0):
        return _cm.noise_suppressor_word(threshold, decay, damp, mode)

    def _apply_noise_suppressor_state_to_word(self, mirror_to_gate=True):
        """Recompute the noise-suppressor 32-bit word from cached state
        and write it to the dedicated GPIO. When ``mirror_to_gate`` is
        True (the default) the threshold byte is also written into the
        legacy ``gate_control.ctrlB`` slot so older bitstreams that
        only had the legacy hard noise gate still see a usable
        threshold.
        """
        s = self._noise_suppressor_state
        word = self._noise_suppressor_word(
            threshold=s['threshold'],
            decay=s['decay'],
            damp=s['damp'],
            mode=s['mode'],
        )
        self._cached_noise_suppressor_word = word
        gpio = getattr(self, self.NOISE_SUPPRESSOR_GPIO_NAME, None)
        if gpio is not None:
            self._write_gpio(gpio, word)

        if mirror_to_gate and hasattr(self, 'axi_gpio_gate'):
            threshold_byte = self._noise_threshold_to_u8(s['threshold'])
            gate_word = self._cached_gate_word & ~0x0000FF00
            gate_word |= (threshold_byte & 0xFF) << 8
            if s['enabled']:
                gate_word |= 0x01
            else:
                gate_word &= ~0x01
            self._cached_gate_word = gate_word
            self._write_gpio(self.axi_gpio_gate, gate_word)

    def set_noise_suppressor_threshold(self, value):
        return self.set_noise_suppressor_settings(threshold=value)

    def set_noise_suppressor_decay(self, value):
        return self.set_noise_suppressor_settings(decay=value)

    def set_noise_suppressor_damp(self, value):
        return self.set_noise_suppressor_settings(damp=value)

    def set_noise_suppressor_settings(self, threshold=None, decay=None,
                                       damp=None, enabled=None, mode=None):
        """Update any subset of the noise-suppressor parameters.

        Numeric parameters (``threshold`` / ``decay`` / ``damp``) take
        the new 0..100 scale; bytes are derived as documented in
        ``_noise_threshold_to_u8`` / ``_percent_to_u8``. ``enabled``
        flips the same flag bit that ``set_guitar_effects(noise_gate_on=)``
        owns, so the two stay in sync. The full 32-bit word is rewritten
        to the dedicated GPIO; the legacy ``gate_control.ctrlB`` slot is
        also refreshed for backward compatibility with older bitstreams.
        """
        s = self._noise_suppressor_state
        if threshold is not None:
            s['threshold'] = self._clamp_percent(threshold)
        if decay is not None:
            s['decay'] = self._clamp_percent(decay)
        if damp is not None:
            s['damp'] = self._clamp_percent(damp)
        if mode is not None:
            s['mode'] = self._clamp_range(mode, 0, 255)
        if enabled is not None:
            s['enabled'] = bool(enabled)
        self._apply_noise_suppressor_state_to_word()
        return self.get_noise_suppressor_settings()

    def get_noise_suppressor_settings(self):
        """Return the cached noise-suppressor state plus the byte view
        of every parameter and a pointer to the GPIO that backs it.
        """
        s = self._noise_suppressor_state
        threshold_byte = self._noise_threshold_to_u8(s['threshold'])
        decay_byte = self._percent_to_u8(s['decay'], 255)
        damp_byte = self._percent_to_u8(s['damp'], 255)
        mode_byte = int(s['mode']) & 0xFF
        return {
            'enabled': bool(s['enabled']),
            'threshold': s['threshold'],
            'threshold_byte': threshold_byte,
            'decay': s['decay'],
            'decay_byte': decay_byte,
            'damp': s['damp'],
            'damp_byte': damp_byte,
            'mode': mode_byte,
            'control_word': self._cached_noise_suppressor_word,
            'reflected_to_fpga': True,
            'gpio_name': self.NOISE_SUPPRESSOR_GPIO_NAME,
            'has_gpio': hasattr(self, self.NOISE_SUPPRESSOR_GPIO_NAME),
            'implementation_status': 'threshold_decay_damp_fpga',
        }

    # ---- Compressor public API ------------------------------------------
    #
    # Drives the dedicated ``axi_gpio_compressor`` (0x43CD0000). Bytes:
    # ctrlA = threshold, ctrlB = ratio, ctrlC = response, ctrlD bit 7 =
    # enable, ctrlD bits[6:0] = makeup (Q7 0..127). Reference repos
    # were studied for parameter naming and design philosophy only --
    # no source code copied (DECISIONS.md D7).

    @staticmethod
    def _makeup_to_u7(value):
        return _cm.makeup_to_u7(value)

    @staticmethod
    def _compressor_word(threshold, ratio, response, makeup, enabled=False):
        return _cm.compressor_word(threshold, ratio, response, makeup, enabled)

    def _apply_compressor_state_to_word(self):
        """Recompute the compressor 32-bit word from cached state and
        write it to the dedicated GPIO. No mirror to legacy GPIOs --
        the compressor is a brand-new section with no historical slot.
        """
        s = self._compressor_state
        word = self._compressor_word(
            threshold=s['threshold'],
            ratio=s['ratio'],
            response=s['response'],
            makeup=s['makeup'],
            enabled=s['enabled'],
        )
        self._cached_compressor_word = word
        gpio = getattr(self, self.COMPRESSOR_GPIO_NAME, None)
        if gpio is not None:
            self._write_gpio(gpio, word)

    def set_compressor_threshold(self, value):
        return self.set_compressor_settings(threshold=value)

    def set_compressor_ratio(self, value):
        return self.set_compressor_settings(ratio=value)

    def set_compressor_response(self, value):
        return self.set_compressor_settings(response=value)

    def set_compressor_makeup(self, value):
        return self.set_compressor_settings(makeup=value)

    def set_compressor_settings(self, threshold=None, ratio=None,
                                response=None, makeup=None, enabled=None):
        """Update any subset of the compressor parameters.

        ``threshold`` / ``ratio`` / ``response`` / ``makeup`` are all on
        the 0..100 scale. ``enabled`` is a bool that flips the
        ``ctrlD`` bit 7 enable flag inside the compressor GPIO -- the
        compressor section does not share a flag bit with
        ``gate_control``. Unspecified parameters keep their cached
        values. The full 32-bit word is rewritten.
        """
        s = self._compressor_state
        if threshold is not None:
            s['threshold'] = self._clamp_percent(threshold)
        if ratio is not None:
            s['ratio'] = self._clamp_percent(ratio)
        if response is not None:
            s['response'] = self._clamp_percent(response)
        if makeup is not None:
            s['makeup'] = self._clamp_percent(makeup)
        if enabled is not None:
            s['enabled'] = bool(enabled)
        self._apply_compressor_state_to_word()
        return self.get_compressor_settings()

    def get_compressor_settings(self):
        """Return the cached compressor state plus the byte view of every
        parameter and a pointer to the GPIO that backs it.
        """
        s = self._compressor_state
        threshold_byte = _cm.percent_to_u8(s['threshold'], 255)
        ratio_byte = _cm.percent_to_u8(s['ratio'], 255)
        response_byte = _cm.percent_to_u8(s['response'], 255)
        makeup_u7 = self._makeup_to_u7(s['makeup'])
        enable_makeup_byte = _cm.compressor_enable_makeup_byte(
            s['enabled'], s['makeup'])
        return {
            'enabled': bool(s['enabled']),
            'threshold': s['threshold'],
            'threshold_byte': threshold_byte,
            'ratio': s['ratio'],
            'ratio_byte': ratio_byte,
            'response': s['response'],
            'response_byte': response_byte,
            'makeup': s['makeup'],
            'makeup_u7': makeup_u7,
            'enable_makeup_byte': enable_makeup_byte,
            'word': self._cached_compressor_word,
            'reflected_to_fpga': True,
            'gpio_name': self.COMPRESSOR_GPIO_NAME,
            'has_gpio': hasattr(self, self.COMPRESSOR_GPIO_NAME),
            'implementation_status': 'threshold_ratio_response_makeup_fpga',
        }

    # ---- Amp Simulator named models ------------------------------------
    #
    # The Amp Simulator section has one shared `amp_character` knob in
    # the existing pedalboard API. ``AMP_MODELS`` defines four named
    # voicings (jc_clean / clean_combo / british_crunch /
    # high_gain_stack) that each correspond to one centre value of
    # `amp_character`. The Clash side quantises the same byte into a
    # two-bit ``ampModelSel`` index that nudges the post-clip pre-LPF
    # alpha so the labelled voicings sound distinguishably different
    # without adding a new GPIO or `topEntity` port. The numeric
    # `amp_character` knob still works for users who prefer continuous
    # control; named models are a convenience layer on top.

    @classmethod
    def get_amp_model_names(cls):
        """Return the ordered list of amp-model names."""
        return list(cls.AMP_MODELS.keys())

    @classmethod
    def amp_model_to_character(cls, name):
        """Map an amp-model name to its centre `amp_character` value.

        Raises ``ValueError`` if ``name`` is not a documented model.
        """
        try:
            return cls.AMP_MODELS[name]
        except KeyError:
            raise ValueError(
                "unknown amp model: {!r}; valid names are {}".format(
                    name, ", ".join(cls.AMP_MODELS.keys())))

    def set_amp_model(self, name, sink=XbarSink.headphone, **overrides):
        """Apply an amp model by name.

        Internally this just calls
        ``set_guitar_effects(amp_character=AMP_MODELS[name], ...)`` so
        the whole flag-byte / route-to-chain logic stays untouched.
        ``overrides`` lets callers supply any other ``set_guitar_effects``
        kwargs alongside the model (e.g. ``amp_master=80`` or
        ``amp_on=True``); explicit ``amp_character=...`` overrides the
        model lookup. Returns the dict produced by
        ``set_guitar_effects`` so callers can inspect the bytes that
        were written.
        """
        character = self.amp_model_to_character(name)
        if "amp_character" not in overrides:
            overrides["amp_character"] = character
        overrides.setdefault("amp_on", True)
        return self.set_guitar_effects(sink=sink, **overrides)

    # ---- Chain presets (combined-section voicings) ---------------------
    #
    # Drives the live pedalboard from named voicings defined in
    # ``effect_presets.CHAIN_PRESETS``. These are notebook-grade
    # presets that combine every section of the chain (Compressor +
    # Noise Suppressor + Overdrive + Distortion Pedalboard + Amp +
    # Cab IR + EQ + Reverb) into one named state. No new GPIO; the
    # implementation just orchestrates the existing
    # ``set_*_settings`` / ``set_guitar_effects`` APIs.

    @staticmethod
    def _chain_presets():
        from . import effect_presets as _ep
        return _ep.CHAIN_PRESETS, _ep.CHAIN_PRESET_SECTIONS

    @classmethod
    def get_chain_preset_names(cls):
        """Return the ordered list of chain preset names."""
        presets, _sections = cls._chain_presets()
        return list(presets.keys())

    @classmethod
    def get_chain_preset(cls, name):
        """Return a deep-copied chain preset spec (dict-of-dicts).

        Raises ``KeyError`` with a list of valid names if ``name`` is
        not a defined chain preset.
        """
        import copy
        presets, _sections = cls._chain_presets()
        if name not in presets:
            raise KeyError(
                "unknown chain preset: {!r}; valid names are {}".format(
                    name, ", ".join(presets.keys())))
        return copy.deepcopy(presets[name])

    def apply_chain_preset(self, name):
        """Apply a named chain preset by orchestrating the existing
        ``set_*_settings`` / ``set_guitar_effects`` APIs.

        Robust to overlays that lack one of the section GPIOs (e.g.
        an older bitstream without ``axi_gpio_compressor``): the
        Compressor / Noise Suppressor calls are guarded by
        ``hasattr`` so missing GPIOs do not break preset application.
        Returns the dict produced by ``get_current_pedalboard_state``
        after the writes, so callers can verify what landed.
        """
        spec = self.get_chain_preset(name)
        comp = spec.get("compressor", {})
        ns = spec.get("noise_suppressor", {})
        od = spec.get("overdrive", {})
        dist = spec.get("distortion", {})
        amp = spec.get("amp", {})
        cab = spec.get("cab", {})
        eq = spec.get("eq", {})
        rev = spec.get("reverb", {})

        # Compressor lives on its own GPIO; skip if not present so an
        # older bitstream without axi_gpio_compressor still applies the
        # rest of the preset.
        if hasattr(self, self.COMPRESSOR_GPIO_NAME) and comp:
            self.set_compressor_settings(**comp)

        # Noise Suppressor: same shape. The threshold byte is also
        # mirrored into legacy gate_control.ctrlB; safe on every
        # overlay version we ship.
        if hasattr(self, self.NOISE_SUPPRESSOR_GPIO_NAME) and ns:
            self.set_noise_suppressor_settings(
                enabled=ns.get("enabled"),
                threshold=ns.get("threshold"),
                decay=ns.get("decay"),
                damp=ns.get("damp"),
            )

        # Distortion section runs through set_distortion_pedal +
        # set_distortion_settings to keep pedal-mask semantics. When
        # the section is off / no pedal, clear the mask so the legacy
        # stage can take over the gate flag.
        if dist:
            pedal = dist.get("pedal")
            section_on = bool(dist.get("enabled")) and bool(pedal)
            if section_on:
                self.set_distortion_pedal(pedal, enabled=True, exclusive=True)
            else:
                self.clear_distortion_pedals()
            self.set_distortion_settings(
                drive=dist.get("drive"),
                tone=dist.get("tone"),
                level=dist.get("level"),
                bias=dist.get("bias"),
                tight=dist.get("tight"),
                mix=dist.get("mix"),
            )

        # The remaining sections ride on set_guitar_effects. We pass
        # noise_gate_on / noise_gate_threshold so the gate flag bit
        # tracks the suppressor's enabled state and the legacy
        # gate_control.ctrlB stays in sync.
        kwargs = dict(
            noise_gate_on=bool(ns.get("enabled", False)),
            noise_gate_threshold=ns.get("threshold", 35),
            overdrive_on=bool(od.get("enabled", False)),
            overdrive_drive=od.get("drive", 0),
            overdrive_tone=od.get("tone", 50),
            overdrive_level=od.get("level", 100),
            distortion_on=bool(dist.get("enabled", False)),
            amp_on=bool(amp.get("enabled", False)),
            amp_input_gain=amp.get("input_gain", 35),
            amp_bass=amp.get("bass", 50),
            amp_middle=amp.get("middle", 50),
            amp_treble=amp.get("treble", 50),
            amp_presence=amp.get("presence", 45),
            amp_resonance=amp.get("resonance", 35),
            amp_master=amp.get("master", 80),
            amp_character=amp.get("character", 35),
            cab_on=bool(cab.get("enabled", False)),
            cab_mix=cab.get("mix", 100),
            cab_level=cab.get("level", 100),
            cab_model=cab.get("model", 1),
            cab_air=cab.get("air", 50),
            eq_on=bool(eq.get("enabled", False)),
            eq_low=eq.get("low", 100),
            eq_mid=eq.get("mid", 100),
            eq_high=eq.get("high", 100),
            reverb_on=bool(rev.get("enabled", False)),
            reverb_decay=rev.get("decay", 0),
            reverb_tone=rev.get("tone", 65),
            reverb_mix=rev.get("mix", 0),
        )
        self.set_guitar_effects(**kwargs)
        return self.get_current_pedalboard_state()

    def get_current_pedalboard_state(self):
        """Return a dict-of-dicts snapshot of every cached effect
        section. Output-only GPIOs cannot be read back, so each
        sub-dict reflects the last call to a setter (or the safe
        defaults loaded in ``__init__``). Sections whose GPIO is not
        present on the current overlay are omitted from the result.
        """
        state = {}
        if hasattr(self, "_compressor_state"):
            try:
                state["compressor"] = self.get_compressor_settings()
            except Exception:
                pass
        if hasattr(self, "_noise_suppressor_state"):
            try:
                state["noise_suppressor"] = self.get_noise_suppressor_settings()
            except Exception:
                pass
        if hasattr(self, "_dist_state"):
            try:
                state["distortion"] = self.get_distortion_settings()
            except Exception:
                pass
        # Cached words for the en-masse-written sections (overdrive,
        # amp, cab, eq, reverb, gate flags). These are not full
        # round-trip dicts -- the overlay does not cache every per-knob
        # value for those sections -- but they let a notebook show what
        # was last written.
        cached = {}
        for attr, key in (
            ("_cached_gate_word", "gate"),
            ("_cached_overdrive_word", "overdrive"),
            ("_cached_distortion_word", "distortion_word"),
            ("_cached_noise_suppressor_word", "noise_suppressor_word"),
            ("_cached_compressor_word", "compressor_word"),
        ):
            if hasattr(self, attr):
                cached[key] = getattr(self, attr)
        if cached:
            state["cached_words"] = cached
        return state

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
            | (cls._noise_threshold_to_u8(noise_gate_threshold) << 8)
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

        # Mirror noise_gate_on / noise_gate_threshold into the dedicated
        # noise-suppressor GPIO so the new bitstream and the legacy
        # bitstream behave consistently. Caller-supplied values win;
        # otherwise we fall back to the cached suppressor state.
        if hasattr(self, '_noise_suppressor_state'):
            ns = self._noise_suppressor_state
            if 'noise_gate_on' in kwargs:
                ns['enabled'] = bool(kwargs['noise_gate_on'])
            if 'noise_gate_threshold' in kwargs:
                ns['threshold'] = self._clamp_percent(
                    kwargs['noise_gate_threshold'])
            else:
                kwargs['noise_gate_threshold'] = ns['threshold']

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

        # Refresh the dedicated noise-suppressor GPIO so its threshold
        # byte matches the byte we just wrote into the gate word. This
        # is a no-op on overlays that lack the new GPIO; on the new
        # bitstream it keeps the FPGA-side compare level in sync with
        # the user's noise_gate_threshold. We pass mirror_to_gate=False
        # because we just wrote the gate word above.
        if hasattr(self, '_noise_suppressor_state'):
            self._apply_noise_suppressor_state_to_word(mirror_to_gate=False)

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
