from pynq import Overlay
from enum import Enum
import os
from .constants import SAMPLE_RATE_HZ
from .AxisSwitch import AxisSwitch
from .AudioCodec import ADAU1761
from . import control_maps as _cm
from . import knob_tapers as _kt
from .overlay import register_writers as _writers
from .effect_defaults import (
    DISTORTION_DEFAULTS as _DISTORTION_DEFAULTS,
    DISTORTION_PEDALS as _DISTORTION_PEDALS,
    DISTORTION_PEDALS_IMPLEMENTED as _DISTORTION_PEDALS_IMPLEMENTED,
    NOISE_SUPPRESSOR_DEFAULTS as _NOISE_SUPPRESSOR_DEFAULTS,
    COMPRESSOR_DEFAULTS as _COMPRESSOR_DEFAULTS,
    WAH_DEFAULTS as _WAH_DEFAULTS,
    RAT_DEFAULTS as _RAT_DEFAULTS,
    AMP_DEFAULTS as _AMP_DEFAULTS,
    CAB_DEFAULTS as _CAB_DEFAULTS,
    EQ_DEFAULTS as _EQ_DEFAULTS,
    REVERB_DEFAULTS as _REVERB_DEFAULTS,
    AMP_MODELS as _AMP_MODELS,
    AMP_MODEL_LABELS as _AMP_MODEL_LABELS,
    AMP_MODELS_LEGACY_PERCENT as _AMP_MODELS_LEGACY_PERCENT,
    OVERDRIVE_DEFAULTS as _OVERDRIVE_DEFAULTS,
    OVERDRIVE_MODELS as _OVERDRIVE_MODELS,
    OVERDRIVE_MODEL_LABELS as _OVERDRIVE_MODEL_LABELS,
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

    # Wah (resonant band-pass, all-FPGA). Driven by the dedicated
    # axi_gpio_wah at 0x43D30000:
    #   ctrlA = position byte   (pedal sweep, 0..255; FP02M future input)
    #   ctrlB = q byte          (resonance / sharpness, 0..255)
    #   ctrlC = volume byte     (ON-gain compensation, 0..255; 128 ~= unity)
    #   ctrlD bit 7 = enable; ctrlD bits[6:0] = bias (u7 0..127, 64 = centred)
    # Sits between the compressor and the overdrive in the Clash chain
    # (classic pre-distortion wah position). The Wah enable lives inside
    # this GPIO -- it is NOT carried in gate_control.ctrlA (same
    # convention as the Compressor section, DECISIONS.md D14).
    WAH_DEFAULTS = _WAH_DEFAULTS
    WAH_GPIO_NAME = 'axi_gpio_wah'

    # Amp Simulator models (D55). The 6 voicings are JC-120 / Twin Reverb /
    # AC30 / Rockerverb / JCM800 / TriAmp Mk3 -- inspired-by, not
    # commercial circuit / IR / coefficient copies (`DECISIONS.md` D7;
    # research notes in `docs/ai_context/AMP_MODEL_RESEARCH_D55.md`).
    # ``AMP_MODELS`` maps the snake_case enum name to the integer
    # ``amp_model_idx`` (0..5). ``AMP_MODEL_LABELS`` is the
    # title-case display list, same order. Indices 6/7 are reserved;
    # Python helpers clamp to ``AMP_MODEL_IDX_MAX = 5`` so they cannot
    # be written through the normal path. The Clash side falls back to
    # 0 = JC-120 if it ever sees 6 or 7 -- safest choice because
    # JC-120 has the highest clean headroom and lowest drive depth, so
    # an unintended write does not run ``clip_count`` away.
    AMP_MODELS = _AMP_MODELS
    AMP_MODEL_LABELS = _AMP_MODEL_LABELS

    # D55 — Amp Sim has 6 selectable voicings + real DSP Clean/Drive split.
    # The Python writer packs amp_model_idx into ctrlD[2:0] (3 bits, 0..5)
    # and the binary amp_drive_mode into ctrlD[7]; ctrlD[6:3] is reserved (0).
    # The Clash side decodes both fields independently and branches the
    # clip knees / pre-LPF darken / second-stage gain / treble trim /
    # presence trim on (model_idx, drive_mode). The pre-D54 character
    # byte byte-shift API is retired: drive_mode is a real DSP branch
    # in Amp.hs, not a character-byte nudge.
    AMP_MODEL_IDX_MASK = 0x07
    AMP_MODEL_IDX_MAX = 5
    AMP_DRIVE_MODE_BIT = 7
    # Legacy D53 constants kept as 0-shift placeholders so any external
    # caller that imported them gets a safe no-op instead of an
    # AttributeError. Do not use them as a drive-mode encoding source.
    AMP_MODEL_CHARACTER_BYTES = (26, 89, 153, 216)
    AMP_DRIVE_MODE_OFFSET = 0
    # Centre amp_character percent values from the retired D52 4-model
    # API. Preserved only so the chain-preset back-compat path
    # (which still passes ``amp_character=`` percent values) keeps
    # working byte-for-byte for older saved presets.
    AMP_MODELS_LEGACY_PERCENT = _AMP_MODELS_LEGACY_PERCENT

    # Selectable Overdrive models (D45). The single generic Overdrive
    # is retired; every load picks one of these six voicings. The
    # 3-bit model_select field lives in overdrive_control.ctrlD[2:0]
    # (= word bits 26..24) -- it shares the byte with `distTight`, but
    # every distortion-section consumer of distTight uses a >>3 or
    # >>4 shift in Clash so the low 3 bits are already discarded and
    # tight semantics are preserved bit-for-bit.
    #
    # OVERDRIVE_MODELS = internal enum names (snake_case, stable for
    # state JSON / API). OVERDRIVE_MODEL_LABELS = UI display strings.
    # Both lists are in the same order; OVERDRIVE_MODELS[i] is the
    # value written to the GPIO when model index ``i`` is selected.
    OVERDRIVE_DEFAULTS = _OVERDRIVE_DEFAULTS
    OVERDRIVE_MODELS = _OVERDRIVE_MODELS
    OVERDRIVE_MODEL_LABELS = _OVERDRIVE_MODEL_LABELS
    OVERDRIVE_MODEL_COUNT = len(_OVERDRIVE_MODELS)

    def __init__(self, bitfile_name=None, **kwargs):
        # Generate default bitfile name
        if bitfile_name is None:
            this_dir = os.path.dirname(__file__)
            bitfile_name = os.path.join(this_dir, 'bitstreams', 'audio_lab.bit')
        super().__init__(bitfile_name, **kwargs)
        # D76 performance: cache every IP handle before anything else touches
        # one. pynq's Overlay.__getattr__ runs is_loaded() -> bitfile_name on
        # each IP attribute access, which is a multiprocessing IPC to the PL
        # server (~50 ms each on the PYNQ-Z2). The live-GUI hot paths hit it
        # repeatedly -- set_guitar_effects ~12 accesses (~940 ms/call) and the
        # FP02M pedal's set_wah_settings ~2 (~100 ms/call) -- which made knobs
        # and the pedal feel laggy. Caching drops them to ~2.5 ms / ~0.5 ms.
        self._cache_ip_handles()
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
        # Overdrive section state (D45). model is an int 0..5; the
        # generic single-character OD was retired so every load picks
        # one of OVERDRIVE_MODELS. Cached so partial writes
        # (set_distortion_tight) preserve it.
        self._od_state = dict(self.OVERDRIVE_DEFAULTS)
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
        # Wah cache. Output-only GPIO; hold the last word and the
        # per-parameter ints. Defaults keep the wah off so loading the
        # overlay never produces an unexpected filter sweep. The
        # ``source`` field is Python-side bookkeeping ("manual" / "pedal");
        # it does NOT travel to the GPIO.
        self._wah_state = dict(self.WAH_DEFAULTS)
        self._cached_wah_word = 0
        if hasattr(self, self.WAH_GPIO_NAME):
            self._apply_wah_state_to_word()

    def _cache_ip_handles(self):
        """Resolve every top-level IP once and stash the handle in __dict__.

        D76 performance fix. pynq's ``Overlay.__getattr__`` calls
        ``is_loaded()`` -> ``bitfile_name`` on every IP attribute access,
        which is a multiprocessing IPC round-trip to the PL server (~50 ms
        each on the PYNQ-Z2). The live GUI hot paths access IP handles many
        times per call (``set_guitar_effects`` writes ~12 GPIOs,
        ``set_wah_settings`` touches the wah GPIO), so the apply path cost
        ~0.9 s and the FP02M pedal write ~0.1 s -- the dominant source of the
        sluggish UI/audio response. Once a handle is in ``self.__dict__`` the
        normal attribute lookup finds it first and ``__getattr__`` (and its
        IPC) is never invoked. Measured on board: ``set_guitar_effects``
        941 ms -> 2.5 ms, ``set_wah_settings`` 99 ms -> 0.5 ms. The raw MMIO
        ``gpio.write`` was already ~0.03 ms, confirming the IPC was the cost.

        Hierarchical entries (e.g. ``enc_in_0/s_axi``) are skipped -- they are
        not reachable as ``self.<name>`` anyway. Missing IPs are ignored so a
        minimal bitstream still constructs.
        """
        try:
            ip_names = list(self.ip_dict.keys())
        except Exception:
            return
        for name in ip_names:
            if "/" in name or name in self.__dict__:
                continue
            try:
                self.__dict__[name] = getattr(self, name)
            except Exception:
                pass

    @property
    def adc_hpf_enabled(self):
        """Return the ADAU1761 ADC digital HPF state used by smoke tests."""
        return self.codec.get_adc_hpf_state()

    def read_adc_control(self):
        """Return ADAU1761 R19_ADC_CONTROL as an integer."""
        return int(self.codec.R19_ADC_CONTROL[0])
        
    # ---- read-only aliases ---------------------------------------------
    # The block design ships an AXI GPIO at 0x43C80000 named
    # `axi_gpio_delay` for historical reasons. After D8 / D9 it actually
    # carries RAT-style distortion control (gate bit 4 + RAT tone / level
    # / drive / mix). Block-design names are locked (D2 + D12), so the
    # underlying attribute stays `axi_gpio_delay`. This property exposes
    # the same MMIO object under a name that matches what new readers
    # expect; internal write paths still go through `self.axi_gpio_delay`.
    @property
    def axi_gpio_rat(self):
        """Read-only alias of ``axi_gpio_delay`` (RAT control GPIO).

        The HWH / block design uses ``axi_gpio_delay`` for the AXI GPIO
        at ``0x43C80000``, which carries RAT-style distortion control
        (`DECISIONS.md` D8 / D9). New code should prefer this alias to
        avoid confusing the underlying register address with delay
        functionality.
        """
        return self.axi_gpio_delay

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
        _writers.write_gpio(gpio, word)

    @classmethod
    def _normalize_overdrive_model(cls, model):
        """Resolve an overdrive-model spec to an integer in 0..5.

        Accepts a string (enum name or display label, case-insensitive)
        or an int. Values outside the documented 0..5 range fall back
        to 0 (TS9) -- this mirrors the Clash side, where the 6/7 slots
        of the 3-bit model select fall through to model 0 in the
        coefficient case lookup.
        """
        if isinstance(model, str):
            key = model.strip().lower().replace("-", "_").replace(" ", "_")
            for i, name in enumerate(cls.OVERDRIVE_MODELS):
                if key == name:
                    return i
            # Also accept display labels (case-insensitive) for
            # convenience. e.g. "Ibanez / TS9" -> 0.
            for i, label in enumerate(cls.OVERDRIVE_MODEL_LABELS):
                if model.strip().lower() == label.strip().lower():
                    return i
            # Bare model number embedded in a string, e.g. "3".
            try:
                idx = int(model)
            except ValueError:
                raise ValueError(
                    'unknown overdrive model: {!r}; valid names are {}'.format(
                        model, ', '.join(cls.OVERDRIVE_MODELS)))
        else:
            try:
                idx = int(model)
            except (TypeError, ValueError):
                return 0
        if idx < 0 or idx >= cls.OVERDRIVE_MODEL_COUNT:
            return 0
        return idx

    @classmethod
    def get_overdrive_model_names(cls):
        """Return the ordered list of overdrive-model enum names."""
        return list(cls.OVERDRIVE_MODELS)

    @classmethod
    def get_overdrive_model_labels(cls):
        """Return the ordered list of overdrive-model display labels."""
        return list(cls.OVERDRIVE_MODEL_LABELS)

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
        _writers.apply_distortion_state_to_words(self)

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

    # ---- Overdrive public API ------------------------------------------
    #
    # Overdrive is selectable-model only (D45). The single generic OD
    # was retired; every load picks one of OVERDRIVE_MODELS. The model
    # select rides on overdrive_control.ctrlD[2:0] (= word bits
    # 26..24) -- a 3-bit field shared with the upper 5 bits of
    # `distTight`. The Python writer keeps the two cleanly separated
    # via masking; Clash discards the same low 3 bits via the existing
    # `distTight >> 3` / `>> 4` shifts so tight semantics survive.

    def set_overdrive_model(self, model):
        """Select one of the six Overdrive models.

        ``model`` accepts an int (0..5) or an enum-name string. Values
        outside the documented range fall back to 0 (TS9). Returns
        ``get_overdrive_settings()``.
        """
        return self.set_overdrive_settings(model=model)

    def get_overdrive_model(self):
        """Return ``(model_idx, enum_name, display_label)``.

        ``model_idx`` is the cached integer 0..5; ``enum_name`` is the
        snake_case identifier; ``display_label`` is the GUI string
        (e.g. ``"Ibanez / TS9"``).
        """
        idx = self._normalize_overdrive_model(self._od_state['model'])
        return (idx,
                self.OVERDRIVE_MODELS[idx],
                self.OVERDRIVE_MODEL_LABELS[idx])

    def set_overdrive_settings(self, enabled=None, drive=None, tone=None,
                                level=None, model=None,
                                sink=XbarSink.headphone):
        """Update any subset of the overdrive parameters in one call.

        Numeric parameters (``drive`` / ``tone`` / ``level``) are 0..100
        (level allows the legacy 0..200 boost convention as a passthrough).
        ``model`` accepts an int or enum-name string and falls back to
        0 (TS9) when invalid. ``enabled`` is the section on/off flag
        (gate_control bit 1). Unspecified parameters keep their cached
        values; the cache lives on the overlay alongside the
        distortion-section cache.

        Returns the dict produced by ``get_overdrive_settings()``.

        Unlike ``set_guitar_effects``, this method does **not** touch
        other effect sections: it only rebuilds the overdrive word
        (ctrlA-C from the OD cache, ctrlD composed with the cached
        tight byte) and -- when ``enabled`` is supplied -- the gate
        flag bit 1. Distortion / amp / cab / etc. state is preserved.
        """
        if drive is not None:
            self._od_state['drive'] = self._clamp_percent(drive)
        if tone is not None:
            self._od_state['tone'] = self._clamp_percent(tone)
        if level is not None:
            # level allows up to 200 historically; clamp like other level
            # knobs (level_to_q7 clamps to 0..200 internally).
            self._od_state['level'] = self._clamp_range(level, 0, 200)
        if model is not None:
            self._od_state['model'] = self._normalize_overdrive_model(model)
        if enabled is not None:
            self._od_state['enabled'] = bool(enabled)
        self._apply_overdrive_state_to_words(touch_gate=enabled is not None,
                                              sink=sink)
        return self.get_overdrive_settings()

    def _apply_overdrive_state_to_words(self, touch_gate=False,
                                         sink=XbarSink.headphone):
        """Rebuild the overdrive_control word from ``_od_state`` and write
        it to the GPIO. Optionally also update gate_control bit 1 and
        re-route the AXIS source crossbar (only when ``touch_gate`` is
        True).
        """
        _writers.apply_overdrive_state_to_words(
            self, touch_gate=touch_gate, sink=sink)

    def get_overdrive_settings(self):
        """Return the cached overdrive-section state (model + knobs)."""
        s = self._od_state
        idx = self._normalize_overdrive_model(s['model'])
        return {
            'enabled': bool(s['enabled']),
            'drive': s['drive'],
            'tone': s['tone'],
            'level': s['level'],
            'model_idx': idx,
            'model': self.OVERDRIVE_MODELS[idx],
            'model_label': self.OVERDRIVE_MODEL_LABELS[idx],
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
        _writers.apply_noise_suppressor_state_to_word(
            self, mirror_to_gate=mirror_to_gate)

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
        _writers.apply_compressor_state_to_word(self)

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

    # ---- Wah public API ------------------------------------------------
    #
    # Drives the dedicated ``axi_gpio_wah`` (0x43D30000). Bytes:
    # ctrlA = position, ctrlB = q, ctrlC = volume, ctrlD bit 7 = enable,
    # ctrlD bits[6:0] = bias (u7 0..127). The Wah sits between the
    # Compressor and the Overdrive (classic pre-distortion wah). FP02M /
    # Arduino A0 hardware feed is NOT implemented yet -- ``source``
    # stays "manual" today; the Python helpers below leave that field
    # as bookkeeping so the FP02M switch is a single-line state update.

    @staticmethod
    def _wah_position_byte(value):
        return _cm.wah_position_byte(value)

    @staticmethod
    def _wah_position_raw_byte(value):
        return _cm.wah_position_raw_byte(value)

    @staticmethod
    def _wah_q_byte(value):
        return _cm.wah_q_byte(value)

    @staticmethod
    def _wah_volume_byte(value):
        return _cm.wah_volume_byte(value)

    @staticmethod
    def _wah_bias_to_u7(value):
        return _cm.wah_bias_to_u7(value)

    @staticmethod
    def _wah_word(position=None, q=0, volume=0, bias=0, enabled=False,
                  position_raw=None):
        return _cm.wah_word(
            position=position, q=q, volume=volume, bias=bias,
            enabled=enabled, position_raw=position_raw)

    def _wah_position_byte_for_state(self):
        """Resolve which of ``position`` (percent) / ``position_raw``
        (byte) wins for the next GPIO write. ``position_raw`` wins
        when it is set (not None); otherwise the percent path is used.
        Single source of truth for the byte resolution rule (D73).
        """
        s = self._wah_state
        raw = s.get('position_raw')
        if raw is not None:
            return self._wah_position_raw_byte(raw)
        return self._wah_position_byte(s.get('position', 0))

    def _apply_wah_state_to_word(self):
        """Recompute the wah 32-bit word from cached state and write it
        to the dedicated GPIO. No mirror to legacy GPIOs -- the wah is
        a brand-new section with no historical slot.
        """
        _writers.apply_wah_state_to_word(self)

    def set_wah_position(self, value):
        return self.set_wah_settings(position=value)

    def set_wah_position_raw(self, value):
        return self.set_wah_settings(position_raw=value)

    def set_wah_q(self, value):
        return self.set_wah_settings(q=value)

    def set_wah_volume(self, value):
        return self.set_wah_settings(volume=value)

    def set_wah_bias(self, value):
        return self.set_wah_settings(bias=value)

    def set_wah_settings(self, position=None, q=None, volume=None,
                         bias=None, enabled=None, source=None,
                         position_raw=None):
        """Update any subset of the Wah parameters (D73 API split).

        ``position`` is the GUI / encoder pedal position as a 0..100
        percent. ``position_raw`` is the FP02M / Arduino A0 raw byte
        in 0..255. The two are mutually exclusive; supplying both
        raises ``ValueError``. Supplying ``position=...`` (percent)
        clears the cached raw override so subsequent reads come from
        the percent value. ``q`` / ``volume`` / ``bias`` are all on
        the 0..100 scale -- D73 retunes the VOLUME curve so byte 128
        (UI 50 %) lands at unity and byte 255 (UI 100 %) lands at
        +6 dB. ``enabled`` is a bool that flips the ``ctrlD`` bit 7
        enable flag inside the wah GPIO -- the wah section does not
        share a flag bit with ``gate_control``. ``source`` is
        Python-side bookkeeping ("manual" / "pedal") and does not
        change the GPIO bytes. Unspecified parameters keep their
        cached values; the full 32-bit word is rewritten.
        """
        if position is not None and position_raw is not None:
            raise ValueError(
                "set_wah_settings: pass position (percent) OR "
                "position_raw (byte), not both")
        s = self._wah_state
        if position is not None:
            s['position'] = self._clamp_percent(position)
            s['position_raw'] = None
        if position_raw is not None:
            s['position_raw'] = self._wah_position_raw_byte(position_raw)
        if q is not None:
            s['q'] = self._clamp_percent(q)
        if volume is not None:
            s['volume'] = self._clamp_percent(volume)
        if bias is not None:
            s['bias'] = self._clamp_percent(bias)
        if enabled is not None:
            s['enabled'] = bool(enabled)
        if source is not None:
            s['source'] = str(source)
        self._apply_wah_state_to_word()
        # D76: a standalone set_wah_settings (the FP02M pedal path, the
        # encoder applier, a notebook) must re-route the AXIS crossbar
        # when it toggles the Wah enable -- the Wah enable is not in the
        # gate word, so without this a Wah-only state would stay on
        # passthrough and never reach the DSP. Only on an explicit enable
        # toggle, so the 100 Hz position_raw stream does not thrash the
        # crossbar.
        if enabled is not None:
            self._route_effect_chain(
                XbarSink.headphone,
                getattr(self, '_cached_gate_word', 0) & 0xFF)
        return self.get_wah_settings()

    def get_wah_settings(self):
        """Return the cached Wah state plus the byte view of every
        parameter and a pointer to the GPIO that backs it.

        D73 split: the dict exposes BOTH ``position`` (the cached
        percent, used when ``position_raw`` is None) and
        ``position_raw`` (the cached FP02M-style byte, or None).
        ``position_byte`` is the canonical resolved byte that just got
        written to the GPIO -- equal to ``percent_to_u8(position, 255)``
        when ``position_raw`` is None, or to ``position_raw`` otherwise.
        """
        s = self._wah_state
        position_byte = self._wah_position_byte_for_state()
        q_byte = self._wah_q_byte(s['q'])
        volume_byte = self._wah_volume_byte(s['volume'])
        bias_u7 = self._wah_bias_to_u7(s['bias'])
        enable_bias_byte = _cm.wah_enable_bias_byte(s['enabled'], s['bias'])
        return {
            'enabled': bool(s['enabled']),
            'position': s.get('position', 0),
            'position_raw': s.get('position_raw'),
            'position_byte': position_byte,
            'q': s['q'],
            'q_byte': q_byte,
            'volume': s['volume'],
            'volume_byte': volume_byte,
            'bias': s['bias'],
            'bias_u7': bias_u7,
            'enable_bias_byte': enable_bias_byte,
            'source': str(s.get('source', 'manual')),
            'word': self._cached_wah_word,
            'reflected_to_fpga': True,
            'gpio_name': self.WAH_GPIO_NAME,
            'has_gpio': hasattr(self, self.WAH_GPIO_NAME),
            'implementation_status': 'position_q_volume_bias_fpga_d73',
        }

    # ---- Amp Simulator named models (D55) ------------------------------
    #
    # The Amp Simulator section selects one of six researched voicings
    # via ``amp_model_idx`` (0..5 = JC-120 / Twin Reverb / AC30 /
    # Rockerverb / JCM800 / TriAmp Mk3) and chooses Clean vs Drive
    # behaviour via the binary ``amp_drive_mode`` knob (0 = Clean,
    # 1 = Drive). The Clash side decodes both fields from
    # ``axi_gpio_amp_tone.ctrlD`` directly; the legacy
    # ``amp_character`` percent knob is retired (`DECISIONS.md` D53 /
    # D54), but the kwarg name is kept as a chain-preset fallback so
    # older JSON does not break.

    @classmethod
    def get_amp_model_names(cls):
        """Return the ordered list of amp-model snake_case names."""
        return list(cls.AMP_MODELS.keys())

    @classmethod
    def get_amp_model_labels(cls):
        """Return the ordered list of amp-model display labels."""
        return list(cls.AMP_MODEL_LABELS)

    @classmethod
    def amp_model_drive_byte(cls, amp_model_idx=0, amp_drive_mode=0):
        """Return the ``axi_gpio_amp_tone.ctrlD`` byte that the Clash
        Amp Sim stage decodes after D55.

        Encoding: ``ctrlD = (drive_mode << 7) | (model_idx & 0x07)``;
        bits[6:3] are reserved (0). The Clash side reads bits[2:0] as
        the amp model index (0..5 = JC-120 / Twin Reverb / AC30 /
        Rockerverb / JCM800 / TriAmp Mk3; 6..7 fall back to JC-120 on
        the Clash side as a safety default) and bit 7 as the binary
        Clean/Drive switch. The character voicing is no longer carried
        in the byte itself -- each model has its own per-coefficient
        voicing table inside Amp.hs.
        """
        return _cm.amp_model_drive_byte(
            amp_model_idx=amp_model_idx,
            amp_drive_mode=amp_drive_mode,
            max_idx=cls.AMP_MODEL_IDX_MAX,
            idx_mask=cls.AMP_MODEL_IDX_MASK,
            drive_mode_bit=cls.AMP_DRIVE_MODE_BIT,
        )

    @classmethod
    def amp_character_byte_for_model(cls, amp_model_idx, amp_drive_mode=0):
        """Back-compat alias of :meth:`amp_model_drive_byte` (D53 name).

        D53 callers expected an 8-bit character byte; D54 / D55 return
        the new bit-packed byte from the same kwargs so any external
        caller still gets a valid ctrlD value.
        """
        return cls.amp_model_drive_byte(
            amp_model_idx=amp_model_idx, amp_drive_mode=amp_drive_mode)

    @classmethod
    def amp_model_to_idx(cls, name):
        """Map an amp-model name (snake_case enum or title-case display
        label) to its integer ``amp_model_idx``.

        Raises ``ValueError`` if ``name`` is not a documented model.
        """
        if isinstance(name, int):
            idx = int(name)
            if 0 <= idx <= cls.AMP_MODEL_IDX_MAX:
                return idx
            raise ValueError(
                "unknown amp model idx: {!r}; valid range is 0..{}".format(
                    name, cls.AMP_MODEL_IDX_MAX))
        if name in cls.AMP_MODELS:
            return cls.AMP_MODELS[name]
        # Allow title-case display labels too so notebook code can pass
        # the human-readable name from the dropdown straight through.
        for i, label in enumerate(cls.AMP_MODEL_LABELS):
            if label == name:
                return i
        raise ValueError(
            "unknown amp model: {!r}; valid names are {}".format(
                name, ", ".join(cls.AMP_MODELS.keys())))

    @classmethod
    def amp_model_to_character(cls, name):
        """D52/D53 back-compat: map a name to its integer model idx.

        D55 retires the continuous 0..100 ``amp_character`` knob, so
        this returns the integer ``amp_model_idx`` (0..5) instead of
        the legacy percent value. Old code that fed the return value
        back into ``set_guitar_effects(amp_character=...)`` still works
        because the legacy fallback path is unused when
        ``amp_model_idx`` is set explicitly via ``set_amp_model``.
        """
        return cls.amp_model_to_idx(name)

    def set_amp_model(self, name, sink=XbarSink.headphone, **overrides):
        """Apply an amp model by name (D55).

        Internally calls ``set_guitar_effects`` with
        ``amp_model_idx`` derived from the model name. ``overrides``
        lets callers supply any other ``set_guitar_effects`` kwargs
        alongside the model; explicit ``amp_model_idx=...`` overrides
        the model lookup. Returns the dict produced by
        ``set_guitar_effects`` so callers can inspect the bytes that
        were written.
        """
        idx = self.amp_model_to_idx(name)
        if "amp_model_idx" not in overrides:
            overrides["amp_model_idx"] = idx
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
        # CHAIN_PRESETS store user-facing knob positions. Convert only at the
        # preset boundary so the public overlay percent API stays linear.
        spec = _kt.taper_chain_preset_spec(self.get_chain_preset(name))
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
            overdrive_model=od.get("model", 0),
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
        if hasattr(self, "_wah_state"):
            try:
                state["wah"] = self.get_wah_settings()
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
        if hasattr(self, "_od_state"):
            try:
                state["overdrive"] = self.get_overdrive_settings()
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
            ("_cached_wah_word", "wah_word"),
        ):
            if hasattr(self, attr):
                cached[key] = getattr(self, attr)
        if cached:
            state["cached_words"] = cached
        return state

    @classmethod
    def reverb_control_word(cls, enabled=True, reverb=35, tone=70, mix=25):
        """Build the ``axi_gpio_reverb`` word (DECAY / TONE / MIX).

        Delegates to :func:`control_maps.reverb_word`, the single source
        for the hardware layout: ``ctrlA`` = DECAY, ``ctrlB`` = TONE,
        ``ctrlC`` = MIX, ``ctrlD`` unused. The reverb ENABLE is **not**
        carried in this word -- the Clash stage gates on ``gate_control``
        flag bit 5 -- so ``enabled`` does not affect the bytes here; the
        caller toggles the gate flag / routing separately.

        Note: on the deployed bitstream ``set_reverb`` reaches this method
        only on the legacy fallback path for an overlay that lacks
        ``axi_gpio_gate`` (when the gate GPIO is present it delegates to
        ``set_guitar_effects``, which sets ``flag5`` and uses the same
        ``reverb_word`` layout). The earlier implementation packed an
        ``enable`` bit into ``ctrlA`` and shifted DECAY/TONE/MIX up one
        byte each, which did not match the Clash reverb decode.
        """
        return _cm.reverb_word(reverb, tone, mix)

    @classmethod
    def guitar_effect_control_words(
        cls,
        # Per-effect knob defaults are sourced from the effect_defaults
        # dicts (single source of truth) so this signature cannot drift
        # from AudioLabOverlay.<EFFECT>_DEFAULTS / the cached state.
        # ``noise_gate_threshold`` keeps a literal: it is the legacy gate
        # threshold (scaled by noise_threshold_to_u8), distinct from the
        # noise-suppressor NS threshold in NOISE_SUPPRESSOR_DEFAULTS.
        noise_gate_on=False,
        noise_gate_threshold=8,
        overdrive_on=False,
        overdrive_tone=_OVERDRIVE_DEFAULTS["tone"],
        overdrive_level=_OVERDRIVE_DEFAULTS["level"],
        overdrive_drive=_OVERDRIVE_DEFAULTS["drive"],
        overdrive_model=_OVERDRIVE_DEFAULTS["model"],
        distortion_on=False,
        distortion_tone=_DISTORTION_DEFAULTS["tone"],
        distortion_level=_DISTORTION_DEFAULTS["level"],
        distortion=_DISTORTION_DEFAULTS["drive"],
        distortion_pedal_mask=_DISTORTION_DEFAULTS["pedal_mask"],
        distortion_bias=_DISTORTION_DEFAULTS["bias"],
        distortion_tight=_DISTORTION_DEFAULTS["tight"],
        distortion_mix=_DISTORTION_DEFAULTS["mix"],
        rat_on=False,
        rat_filter=_RAT_DEFAULTS["filter"],
        rat_level=_RAT_DEFAULTS["level"],
        rat_drive=_RAT_DEFAULTS["drive"],
        rat_mix=_RAT_DEFAULTS["mix"],
        amp_on=False,
        amp_input_gain=_AMP_DEFAULTS["input_gain"],
        amp_bass=_AMP_DEFAULTS["bass"],
        amp_middle=_AMP_DEFAULTS["middle"],
        amp_treble=_AMP_DEFAULTS["treble"],
        amp_presence=_AMP_DEFAULTS["presence"],
        amp_resonance=_AMP_DEFAULTS["resonance"],
        amp_master=_AMP_DEFAULTS["master"],
        amp_character=_AMP_DEFAULTS["character"],
        amp_model_idx=None,
        amp_drive_mode=0,
        cab_on=False,
        cab_mix=_CAB_DEFAULTS["mix"],
        cab_level=_CAB_DEFAULTS["level"],
        cab_model=_CAB_DEFAULTS["model"],
        cab_air=_CAB_DEFAULTS["air"],
        eq_on=False,
        eq_low=_EQ_DEFAULTS["low"],
        eq_mid=_EQ_DEFAULTS["mid"],
        eq_high=_EQ_DEFAULTS["high"],
        reverb_on=False,
        reverb_decay=_REVERB_DEFAULTS["decay"],
        reverb_tone=_REVERB_DEFAULTS["tone"],
        reverb_mix=_REVERB_DEFAULTS["mix"],
        **unused,
    ):
        pedal_mask = int(distortion_pedal_mask) & 0x7F
        gate_word = _cm.gate_word(
            noise_gate_on=noise_gate_on,
            noise_gate_threshold=noise_gate_threshold,
            overdrive_on=overdrive_on,
            distortion_on=distortion_on,
            eq_on=eq_on,
            rat_on=rat_on,
            reverb_on=reverb_on,
            amp_on=amp_on,
            cab_on=cab_on,
            distortion_bias=distortion_bias,
            distortion_mix=distortion_mix,
        )
        overdrive_word = _cm.overdrive_word(
            tone=overdrive_tone,
            level=overdrive_level,
            drive=overdrive_drive,
            distortion_tight=distortion_tight,
            overdrive_model=overdrive_model,
            overdrive_model_count=cls.OVERDRIVE_MODEL_COUNT,
        )
        distortion_word = _cm.distortion_word(
            tone=distortion_tone,
            level=distortion_level,
            drive=distortion,
            pedal_mask=pedal_mask,
        )
        eq_word = _cm.eq_word(eq_low, eq_mid, eq_high)
        rat_word = _cm.rat_word(rat_filter, rat_level, rat_drive, rat_mix)
        amp_word = _cm.amp_word(
            input_gain=amp_input_gain,
            master=amp_master,
            presence=amp_presence,
            resonance=amp_resonance,
        )
        # D54/D55: when amp_model_idx is supplied, ctrlD is a bit-packed
        # field (bit 7 = drive_mode, bits[2:0] = model idx) that the
        # Clash side decodes directly. Legacy callers without
        # amp_model_idx fall back to the pre-D53 percent-character
        # path so older Notebook presets / chain presets keep
        # working byte-for-byte.
        amp_tone_word = _cm.amp_tone_word(
            bass=amp_bass,
            middle=amp_middle,
            treble=amp_treble,
            character=amp_character,
            amp_model_idx=amp_model_idx,
            amp_drive_mode=amp_drive_mode,
            max_idx=cls.AMP_MODEL_IDX_MAX,
            idx_mask=cls.AMP_MODEL_IDX_MASK,
            drive_mode_bit=cls.AMP_DRIVE_MODE_BIT,
        )
        cab_word = _cm.cab_word(cab_mix, cab_level, cab_model, cab_air)
        reverb_word = _cm.reverb_word(reverb_decay, reverb_tone, reverb_mix)

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

    # ---- set_guitar_effects helpers -------------------------------------
    # The public `set_guitar_effects` is a thin dispatch that walks each
    # effect section in turn through the helpers below. The split keeps
    # the wire-level behaviour (return value, exception text, GPIO write
    # order, cached-word updates, audio routing) byte-for-byte identical
    # to the pre-split implementation; the helpers exist to localise
    # responsibilities (cached-state merge, write-with-presence-check,
    # cache refresh, chain routing) and to make the per-effect setters
    # (`set_noise_suppressor_settings`, `set_compressor_settings`,
    # `set_distortion_settings`, `set_amp_model`, ...) easier to reason
    # about against the same internal contract.

    _REQUIRED_EFFECT_GPIOS = (
        'axi_gpio_gate',
        'axi_gpio_overdrive',
        'axi_gpio_distortion',
        'axi_gpio_eq',
        'axi_gpio_reverb',
    )

    # (gpio_attr_name, words key, gate flag that requires this GPIO,
    #  description used in the missing-GPIO RuntimeError).
    _OPTIONAL_EFFECT_GPIOS = (
        ('axi_gpio_delay',    'rat',      0x10, 'RAT-style distortion control'),
        ('axi_gpio_amp',      'amp',      0x40, 'amp simulator control'),
        ('axi_gpio_amp_tone', 'amp_tone', 0x40, 'amp simulator tone control'),
        ('axi_gpio_cab',      'cab',      0x80, 'cab IR simulator control'),
    )

    _DIST_STATE_SCALAR_PAIRS = (
        ('distortion',       'drive'),
        ('distortion_tone',  'tone'),
        ('distortion_level', 'level'),
        ('distortion_bias',  'bias'),
        ('distortion_tight', 'tight'),
        ('distortion_mix',   'mix'),
    )

    def _require_effect_gpios(self):
        _writers.require_effect_gpios(self)

    def _merge_cached_distortion_state(self, kwargs):
        """Fold cached distortion-section state into ``kwargs`` in place.

        Callers that only flip section on/off must not silently reset
        ``pedal_mask`` / bias / tight / mix back to the classmethod
        defaults. Scalar params override the cache when supplied; the
        cache fills in the rest. Setting the rat pedal bit also
        asserts ``rat_on`` so the existing RAT stage actually
        processes audio.

        The Overdrive model select (D45) shares overdrive_control.ctrlD
        with `distTight`, so it is merged here too: caller-supplied
        ``overdrive_model`` overrides the cache; otherwise the cached
        OD model fills it in. This keeps a partial
        ``set_guitar_effects(overdrive_tone=...)`` call from silently
        resetting the model select to 0.
        """
        if not hasattr(self, '_dist_state'):
            return
        s = self._dist_state
        for key, state_key in self._DIST_STATE_SCALAR_PAIRS:
            if key in kwargs:
                s[state_key] = self._clamp_percent(kwargs[key])
            else:
                kwargs[key] = s[state_key]
        if 'distortion_pedal_mask' in kwargs:
            s['pedal_mask'] = int(kwargs['distortion_pedal_mask']) & 0x7F
        kwargs['distortion_pedal_mask'] = s['pedal_mask']
        if s['pedal_mask'] & (1 << self._DIST_PEDAL_BIT['rat']):
            kwargs['rat_on'] = True
        # Overdrive cache state. ``model`` shares overdrive_control.ctrlD
        # with `distTight`; the OD knobs share the rest of the word but
        # land via their own kwargs. Keep ``_od_state`` in sync with
        # every ``set_guitar_effects`` call so a follow-up
        # ``set_overdrive_model`` rebuilds the OD word from fresh knob
        # values rather than stale defaults.
        if hasattr(self, '_od_state'):
            od = self._od_state
            if 'overdrive_model' in kwargs:
                od['model'] = self._normalize_overdrive_model(
                    kwargs['overdrive_model'])
            kwargs['overdrive_model'] = self._normalize_overdrive_model(
                od['model'])
            if 'overdrive_on' in kwargs:
                od['enabled'] = bool(kwargs['overdrive_on'])
            if 'overdrive_drive' in kwargs:
                od['drive'] = self._clamp_percent(kwargs['overdrive_drive'])
            if 'overdrive_tone' in kwargs:
                od['tone'] = self._clamp_percent(kwargs['overdrive_tone'])
            if 'overdrive_level' in kwargs:
                od['level'] = self._clamp_range(
                    kwargs['overdrive_level'], 0, 200)

    def _merge_cached_noise_suppressor_state(self, kwargs):
        """Mirror noise_gate_on / noise_gate_threshold into the cached
        noise-suppressor state and back into ``kwargs``.

        Caller-supplied values win; otherwise we fall back to the
        cached suppressor state so a partial `set_guitar_effects` call
        does not silently reset the threshold.
        """
        if not hasattr(self, '_noise_suppressor_state'):
            return
        ns = self._noise_suppressor_state
        if 'noise_gate_on' in kwargs:
            ns['enabled'] = bool(kwargs['noise_gate_on'])
        if 'noise_gate_threshold' in kwargs:
            ns['threshold'] = self._clamp_percent(
                kwargs['noise_gate_threshold'])
        else:
            kwargs['noise_gate_threshold'] = ns['threshold']

    def _write_effect_gpios(self, words):
        """Write every effect-section word to its AXI GPIO.

        Required GPIOs (gate / overdrive / distortion / eq / reverb)
        were validated by ``_require_effect_gpios``. Optional GPIOs
        (delay/rat, amp, amp_tone, cab) may be absent on minimal
        bitstreams; absence is fine as long as the matching enable
        bit in the gate word is clear, otherwise we raise so the
        caller can spot the mismatch.
        """
        _writers.write_effect_gpios(self, words)

    def _refresh_cached_words(self, words):
        """Snapshot the just-written gate / overdrive / distortion words
        so subsequent per-effect setters (``set_distortion_settings``,
        ``set_distortion_pedal``, ...) preserve the on/off flags and
        rat / amp / cab / reverb bits this call just wrote."""
        _writers.refresh_cached_words(self, words)

    def _route_effect_chain(self, sink, gate_word):
        """Switch the AXIS source crossbar to guitar_chain when any
        effect enable bit is set, otherwise return to passthrough.

        Phase 2: the per-bit flag layout is encoded in
        ``guitar_effect_control_words`` (`gate_word` low byte). A
        non-zero low byte means "at least one effect is on".

        D76: the Wah enable lives on its own ``axi_gpio_wah`` ctrlD bit
        and never reaches ``gate_word``, so a Wah-only state (every
        other effect off, e.g. the FP02M pedal driving POSITION) would
        otherwise leave the crossbar on passthrough and bypass the whole
        DSP -- the Wah stage included. Treat an enabled Wah as "an effect
        is on" so the chain is routed through ``guitar_chain``.
        """
        wah_on = bool(getattr(self, '_wah_state', {}).get('enabled')) \
            if hasattr(self, '_wah_state') else False
        if (gate_word & 0xFF) or wah_on:
            self.route(XbarSource.line_in, XbarEffect.guitar_chain, sink)
        else:
            self.route(XbarSource.line_in, XbarEffect.passthrough, sink)

    # Wah kwargs handled by ``set_guitar_effects`` are split from the
    # other section kwargs at dispatch time; the wah lives on its own
    # AXI GPIO (axi_gpio_wah at 0x43D30000) and so does not affect any
    # word built by ``guitar_effect_control_words``. Pulled out so a
    # caller can ``set_guitar_effects(wah_enabled=True, wah_position=128)``
    # in the same call that flips the rest of the chain.
    _WAH_KWARGS = (
        ('wah_enabled', 'enabled'),
        ('wah_position', 'position'),
        ('wah_position_raw', 'position_raw'),
        ('wah_q', 'q'),
        ('wah_volume', 'volume'),
        ('wah_bias', 'bias'),
        ('wah_source', 'source'),
    )

    def _pop_wah_kwargs(self, kwargs):
        """Strip and translate wah-related kwargs in place; return the
        ``set_wah_settings`` kwargs ready for delegation. Returns
        ``None`` when no wah kwargs were supplied so callers can skip
        the dedicated GPIO write.
        """
        wah_kwargs = {}
        for src, dst in self._WAH_KWARGS:
            if src in kwargs:
                wah_kwargs[dst] = kwargs.pop(src)
        return wah_kwargs if wah_kwargs else None

    def set_guitar_effects(self, sink=XbarSink.headphone, **kwargs):
        """Apply a full effect-chain state in one call.

        Thin facade over ``guitar_effect_control_words`` and the
        ``_*_effect_gpios`` / ``_route_effect_chain`` helpers. Behaviour
        and return value are unchanged from earlier revisions:

        - Cached distortion-section and noise-suppressor state is
          folded into ``kwargs`` so partial calls do not reset other
          settings.
        - Every effect GPIO is written in the historical order
          (gate, overdrive, distortion, eq, delay/rat, amp, amp_tone,
          cab, reverb).
        - The AXIS source crossbar is switched to ``guitar_chain`` when
          any effect enable bit is set; otherwise it returns to
          ``passthrough``.
        - Returns the same ``{section: word}`` dict
          ``guitar_effect_control_words`` produces.

        Wah extension: ``wah_*`` kwargs (``wah_enabled`` / ``wah_position``
        / ``wah_q`` / ``wah_volume`` / ``wah_bias`` / ``wah_source``)
        are split off and forwarded to :meth:`set_wah_settings`. The
        wah lives on its own AXI GPIO so it does not appear in the
        returned ``{section: word}`` dict; the cached word and
        ``get_wah_settings()`` reflect the new state instead.
        """
        wah_kwargs = self._pop_wah_kwargs(kwargs)
        self._require_effect_gpios()
        self._merge_cached_distortion_state(kwargs)
        self._merge_cached_noise_suppressor_state(kwargs)

        words = self.guitar_effect_control_words(**kwargs)
        self._write_effect_gpios(words)
        self._refresh_cached_words(words)

        # Sync the dedicated noise-suppressor GPIO with the threshold
        # byte we just wrote into the gate word. No-op on overlays
        # without the new GPIO; mirror_to_gate=False because the gate
        # word was already written by ``_write_effect_gpios``.
        if hasattr(self, '_noise_suppressor_state'):
            self._apply_noise_suppressor_state_to_word(mirror_to_gate=False)

        # Mirror any wah_* kwargs into the dedicated wah GPIO. No-op
        # on overlays without the new GPIO and a no-op when no wah_*
        # kwargs were supplied.
        if wah_kwargs is not None and hasattr(self, '_wah_state'):
            self.set_wah_settings(**wah_kwargs)

        self._route_effect_chain(sink, words['gate'])
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

    def capture_input(self, num_frames=SAMPLE_RATE_HZ, **kwargs):
        from . import diagnostics
        return diagnostics.capture_input(self, num_frames=num_frames, **kwargs)

    def diagnostic_capture(self, label, num_frames=SAMPLE_RATE_HZ, save_dir=None,
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
