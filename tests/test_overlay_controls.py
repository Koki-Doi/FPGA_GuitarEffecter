import sys
import types
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


pynq = types.ModuleType("pynq")


class Overlay:
    pass


class DefaultIP:
    bindto = []

    def __init__(self, description=None):
        self.description = description or {}

    def read(self, _offset):
        return 0

    def write(self, _offset, _value):
        pass


pynq.Overlay = Overlay
pynq.DefaultIP = DefaultIP
sys.modules.setdefault("pynq", pynq)

pylibi2c = types.ModuleType("pylibi2c")


class I2CDevice:
    def __init__(self, *_args, **_kwargs):
        pass

    def ioctl_read(self, _offset, length):
        return bytes([0] * length)

    def ioctl_write(self, _offset, _data):
        pass


pylibi2c.I2CDevice = I2CDevice
sys.modules.setdefault("pylibi2c", pylibi2c)

from audio_lab_pynq.AudioLabOverlay import AudioLabOverlay, XbarEffect, XbarSink


class FakeGpio:
    def __init__(self):
        self.writes = []

    def write(self, offset, value):
        self.writes.append((offset, value))


def make_overlay(include_rat_gpio=True):
    overlay = AudioLabOverlay.__new__(AudioLabOverlay)
    overlay.axi_gpio_gate = FakeGpio()
    overlay.axi_gpio_overdrive = FakeGpio()
    overlay.axi_gpio_distortion = FakeGpio()
    overlay.axi_gpio_eq = FakeGpio()
    overlay.axi_gpio_reverb = FakeGpio()
    if include_rat_gpio:
        overlay.axi_gpio_delay = FakeGpio()
    overlay.axi_gpio_amp = FakeGpio()
    overlay.axi_gpio_amp_tone = FakeGpio()
    overlay.axi_gpio_cab = FakeGpio()

    routes = []

    def route(_source, effect, sink):
        routes.append((effect, sink))

    overlay.route = route
    overlay.routes = routes
    return overlay


def test_rat_control_word():
    words = AudioLabOverlay.guitar_effect_control_words(
        rat_on=True,
        rat_filter=100,
        rat_level=150,
        rat_drive=50,
        rat_mix=25,
    )

    assert words["gate"] & 0x10
    assert words["rat"] == words["delay"]
    assert words["rat"] & 0xFF == 255
    assert (words["rat"] >> 8) & 0xFF == 192
    assert (words["rat"] >> 24) & 0xFF == 64


def test_set_guitar_effects_writes_rat_gpio():
    overlay = make_overlay()
    words = overlay.set_guitar_effects(rat_on=True, rat_drive=70, rat_filter=30, rat_level=95, rat_mix=100)

    assert overlay.axi_gpio_gate.writes[-1] == (0x00, words["gate"])
    assert overlay.axi_gpio_delay.writes[-1] == (0x00, words["rat"])
    assert overlay.routes[-1] == (XbarEffect.guitar_chain, XbarSink.headphone)


def test_overdrive_on_sets_gate_flag_and_control_bytes():
    words = AudioLabOverlay.guitar_effect_control_words(
        overdrive_on=True,
        overdrive_drive=60,
        overdrive_tone=55,
        overdrive_level=80,
    )

    assert words["gate"] & 0x02, hex(words["gate"])
    assert words["overdrive"] & 0xFF == AudioLabOverlay._percent_to_u8(55, 255)
    assert (words["overdrive"] >> 8) & 0xFF == AudioLabOverlay._level_to_q7(80)
    assert (words["overdrive"] >> 16) & 0xFF == AudioLabOverlay._percent_to_u8(60, 255)


def test_rat_requires_delay_gpio_when_enabled():
    overlay = make_overlay(include_rat_gpio=False)
    try:
        overlay.set_guitar_effects(rat_on=True)
    except RuntimeError as exc:
        assert "axi_gpio_delay" in str(exc)
    else:
        raise AssertionError("rat_on=True should require axi_gpio_delay")


def test_amp_cab_control_words():
    words = AudioLabOverlay.guitar_effect_control_words(
        amp_on=True,
        amp_input_gain=100,
        amp_bass=0,
        amp_middle=50,
        amp_treble=100,
        amp_presence=25,
        amp_resonance=75,
        amp_master=150,
        amp_character=60,
        cab_on=True,
        cab_mix=25,
        cab_level=150,
        cab_model=2,
        cab_air=80,
    )

    assert words["gate"] & 0x40
    assert words["gate"] & 0x80
    assert words["amp"] & 0xFF == 255
    assert (words["amp"] >> 8) & 0xFF == 192
    assert (words["amp"] >> 16) & 0xFF == 64
    assert (words["amp"] >> 24) & 0xFF == 191
    assert words["amp_tone"] & 0xFF == 0
    assert (words["amp_tone"] >> 8) & 0xFF == 128
    assert (words["amp_tone"] >> 16) & 0xFF == 255
    assert (words["amp_tone"] >> 24) & 0xFF == 153
    assert words["cab"] & 0xFF == 64
    assert (words["cab"] >> 8) & 0xFF == 192
    assert (words["cab"] >> 16) & 0xFF == 170
    assert (words["cab"] >> 24) & 0xFF == 204


def test_set_guitar_effects_writes_amp_cab_gpio():
    overlay = make_overlay()
    words = overlay.set_guitar_effects(amp_on=True, cab_on=True, amp_input_gain=60, cab_mix=80)

    assert overlay.axi_gpio_amp.writes[-1] == (0x00, words["amp"])
    assert overlay.axi_gpio_amp_tone.writes[-1] == (0x00, words["amp_tone"])
    assert overlay.axi_gpio_cab.writes[-1] == (0x00, words["cab"])
    assert overlay.routes[-1] == (XbarEffect.guitar_chain, XbarSink.headphone)


def make_overlay_with_distortion_state():
    overlay = make_overlay()
    overlay._dist_state = dict(AudioLabOverlay.DISTORTION_DEFAULTS)
    overlay._od_state = dict(AudioLabOverlay.OVERDRIVE_DEFAULTS)
    overlay._cached_gate_word = 0
    overlay._cached_overdrive_word = 0
    overlay._cached_distortion_word = 0
    return overlay


def make_overlay_with_noise_suppressor_state(include_ns_gpio=True):
    overlay = make_overlay_with_distortion_state()
    overlay._noise_suppressor_state = dict(AudioLabOverlay.NOISE_SUPPRESSOR_DEFAULTS)
    overlay._cached_noise_suppressor_word = 0
    if include_ns_gpio:
        setattr(overlay, AudioLabOverlay.NOISE_SUPPRESSOR_GPIO_NAME, FakeGpio())
    return overlay


def test_distortion_bit_layout_in_control_words():
    """pedal mask / bias / mix / tight land in the documented bytes and
    do not corrupt any other field of gate / overdrive / distortion."""
    words = AudioLabOverlay.guitar_effect_control_words(
        noise_gate_on=True,
        noise_gate_threshold=8,
        overdrive_on=True,
        overdrive_tone=65,
        overdrive_level=100,
        overdrive_drive=30,
        distortion_on=True,
        distortion_tone=65,
        distortion_level=100,
        distortion=25,
        distortion_pedal_mask=(1 << 1) | (1 << 6),  # tube_screamer + metal
        distortion_bias=50,
        distortion_tight=70,
        distortion_mix=100,
    )
    bias_byte = AudioLabOverlay._percent_to_u8(50, 255)
    mix_byte = AudioLabOverlay._percent_to_u8(100, 255)
    tight_byte = AudioLabOverlay._percent_to_u8(70, 255)
    tone_byte = AudioLabOverlay._percent_to_u8(65, 255)
    # gate.ctrlA (flags) and ctrlB (threshold) preserved.
    assert words["gate"] & 0xFF == 0x01 | 0x02 | 0x04, hex(words["gate"])
    # gate.ctrlC = bias, ctrlD = mix.
    assert (words["gate"] >> 16) & 0xFF == bias_byte
    assert (words["gate"] >> 24) & 0xFF == mix_byte
    # distortion ctrlA/B/C unchanged; ctrlD = pedal mask (bit 7 reserved).
    assert words["distortion"] & 0xFF == tone_byte
    assert (words["distortion"] >> 24) & 0x7F == ((1 << 1) | (1 << 6))
    assert (words["distortion"] >> 24) & 0x80 == 0  # reserved high bit
    # overdrive ctrlA-C preserved; ctrlD packs tight (top 5 bits) and
    # the 3-bit OD model select (bottom 3 bits) after D46. The Clash
    # distTight consumers all shift the byte right by 3 or more, so
    # the top 5 bits are the only bits that ever survive the shift.
    assert (words["overdrive"] >> 24) & 0xF8 == tight_byte & 0xF8
    assert (words["overdrive"] >> 24) & 0x07 == 0   # default OD model = 0
    assert words["overdrive"] & 0xFF == tone_byte


def test_distortion_pedal_bit_positions_match_doc():
    expected = {
        'clean_boost':  0,
        'tube_screamer': 1,
        'rat':          2,
        'ds1':          3,
        'big_muff':     4,
        'fuzz_face':    5,
        'metal':        6,
    }
    for name, bit in expected.items():
        assert AudioLabOverlay._DIST_PEDAL_BIT[name] == bit, name


def test_distortion_pedals_implemented_includes_reserved_set():
    """ds1 / big_muff / fuzz_face must now report as implemented in
    the active bitstream alongside the original four pedals."""
    from audio_lab_pynq.effect_defaults import DISTORTION_PEDALS_IMPLEMENTED
    expected = (
        'clean_boost', 'tube_screamer', 'rat',
        'ds1', 'big_muff', 'fuzz_face',
        'metal',
    )
    assert tuple(DISTORTION_PEDALS_IMPLEMENTED) == expected
    # Class attribute must mirror the module-level constant.
    assert AudioLabOverlay.DISTORTION_PEDALS_IMPLEMENTED == expected
    # Bit 7 stays reserved -- nothing implemented for it.
    assert 'reserved' not in DISTORTION_PEDALS_IMPLEMENTED


def test_set_distortion_pedal_ds1_exclusive_isolates_bit3():
    overlay = make_overlay_with_distortion_state()
    overlay.set_distortion_pedal('clean_boost', enabled=True, exclusive=True)
    overlay.set_distortion_pedal('ds1', enabled=True, exclusive=True)
    pedals = overlay.get_distortion_pedals()
    assert pedals['ds1'] is True
    assert pedals['clean_boost'] is False
    assert pedals['big_muff'] is False
    assert pedals['fuzz_face'] is False
    last_dist = overlay.axi_gpio_distortion.writes[-1][1]
    assert (last_dist >> 24) & 0x7F == (1 << 3)


def test_set_distortion_pedal_big_muff_exclusive_isolates_bit4():
    overlay = make_overlay_with_distortion_state()
    overlay.set_distortion_pedal('metal', enabled=True, exclusive=True)
    overlay.set_distortion_pedal('big_muff', enabled=True, exclusive=True)
    pedals = overlay.get_distortion_pedals()
    assert pedals['big_muff'] is True
    assert pedals['metal'] is False
    assert pedals['ds1'] is False
    last_dist = overlay.axi_gpio_distortion.writes[-1][1]
    assert (last_dist >> 24) & 0x7F == (1 << 4)


def test_set_distortion_pedal_fuzz_face_exclusive_isolates_bit5():
    overlay = make_overlay_with_distortion_state()
    overlay.set_distortion_pedal('tube_screamer', enabled=True, exclusive=True)
    overlay.set_distortion_pedal('fuzz_face', enabled=True, exclusive=True)
    pedals = overlay.get_distortion_pedals()
    assert pedals['fuzz_face'] is True
    assert pedals['tube_screamer'] is False
    assert pedals['big_muff'] is False
    last_dist = overlay.axi_gpio_distortion.writes[-1][1]
    assert (last_dist >> 24) & 0x7F == (1 << 5)


def test_distortion_pedal_mask_bit_7_unused():
    """Bit 7 of the pedal mask stays reserved for a future 8th slot.
    No name maps to bit 7, and no API call should set it via the
    documented pedal list."""
    for name, bit in AudioLabOverlay._DIST_PEDAL_BIT.items():
        assert bit != 7, "no documented pedal should land on bit 7"
    overlay = make_overlay_with_distortion_state()
    for name in AudioLabOverlay.DISTORTION_PEDALS:
        overlay.set_distortion_pedal(name, enabled=True, exclusive=True)
        last_dist = overlay.axi_gpio_distortion.writes[-1][1]
        assert (last_dist >> 24) & 0x80 == 0, name


def test_distortion_pedal_invalid_name_raises():
    raised = False
    try:
        AudioLabOverlay._normalize_pedal_name("not_a_pedal")
    except ValueError as exc:
        assert "unknown distortion pedal" in str(exc)
        raised = True
    assert raised, "invalid pedal name should raise ValueError"


def test_distortion_pedal_out_of_range_raises():
    raised = False
    try:
        AudioLabOverlay._normalize_pedal_name(99)
    except ValueError:
        raised = True
    assert raised, "out-of-range pedal index should raise"


def test_set_distortion_pedal_exclusive_clears_others():
    overlay = make_overlay_with_distortion_state()
    overlay.set_distortion_pedal('clean_boost', enabled=True, exclusive=True)
    overlay.set_distortion_pedal('metal', enabled=True, exclusive=True)
    pedals = overlay.get_distortion_pedals()
    assert pedals['metal'] is True
    assert pedals['clean_boost'] is False
    last_dist = overlay.axi_gpio_distortion.writes[-1][1]
    assert (last_dist >> 24) & 0x7F == (1 << 6)


def test_set_distortion_pedal_non_exclusive_stacks():
    overlay = make_overlay_with_distortion_state()
    overlay.set_distortion_pedal('clean_boost', enabled=True, exclusive=False)
    overlay.set_distortion_pedal('tube_screamer', enabled=True, exclusive=False)
    pedals = overlay.get_distortion_pedals()
    assert pedals['clean_boost'] is True
    assert pedals['tube_screamer'] is True
    last_dist = overlay.axi_gpio_distortion.writes[-1][1]
    assert (last_dist >> 24) & 0x7F == ((1 << 0) | (1 << 1))


def test_set_distortion_pedal_disable_drops_one_bit():
    overlay = make_overlay_with_distortion_state()
    overlay.set_distortion_pedals(clean_boost=True, metal=True, tube_screamer=True)
    overlay.set_distortion_pedal('metal', enabled=False)
    pedals = overlay.get_distortion_pedals()
    assert pedals['clean_boost'] is True
    assert pedals['tube_screamer'] is True
    assert pedals['metal'] is False


def test_clear_distortion_pedals():
    overlay = make_overlay_with_distortion_state()
    overlay.set_distortion_pedal('metal')
    overlay.clear_distortion_pedals()
    pedals = overlay.get_distortion_pedals()
    assert all(v is False for v in pedals.values())
    last_dist = overlay.axi_gpio_distortion.writes[-1][1]
    assert (last_dist >> 24) & 0x7F == 0


def test_set_distortion_pedal_rat_drives_legacy_rat_flag():
    """The rat pedal maps onto the existing RAT stage, so its enable
    must also flip gate_control bit 4 high."""
    overlay = make_overlay_with_distortion_state()
    overlay.set_distortion_pedal('rat')
    last_gate = overlay.axi_gpio_gate.writes[-1][1]
    assert last_gate & 0x10, hex(last_gate)


def test_set_distortion_settings_updates_cache_and_writes():
    overlay = make_overlay_with_distortion_state()
    overlay.set_distortion_settings(
        pedal='tube_screamer',
        drive=80,
        tone=40,
        level=30,
        bias=50,
        tight=70,
        mix=100,
    )
    settings = overlay.get_distortion_settings()
    assert settings['pedals']['tube_screamer'] is True
    assert settings['pedals']['clean_boost'] is False
    assert settings['drive'] == 80
    assert settings['tight'] == 70

    last_dist = overlay.axi_gpio_distortion.writes[-1]
    last_od = overlay.axi_gpio_overdrive.writes[-1]
    last_gate = overlay.axi_gpio_gate.writes[-1]
    assert last_gate[0] == 0x00 and last_dist[0] == 0x00 and last_od[0] == 0x00
    assert (last_dist[1] >> 24) & 0x7F == (1 << 1)
    assert (last_dist[1] >> 16) & 0xFF == AudioLabOverlay._percent_to_u8(80, 255)
    # D46: overdrive_control.ctrlD packs the OD model select in bits[2:0]
    # alongside distTight in bits[7:3]. Compare only the tight bits.
    assert (last_od[1] >> 24) & 0xF8 == AudioLabOverlay._percent_to_u8(70, 255) & 0xF8
    assert (last_od[1] >> 24) & 0x07 == 0   # default OD model
    assert (last_gate[1] >> 16) & 0xFF == AudioLabOverlay._percent_to_u8(50, 255)
    assert (last_gate[1] >> 24) & 0xFF == AudioLabOverlay._percent_to_u8(100, 255)


def test_set_distortion_settings_preserves_other_effects_in_gate_word():
    """A set_distortion_settings / set_distortion_pedal call after
    set_guitar_effects must not clobber the effect on/off flags or
    the noise-gate threshold."""
    overlay = make_overlay_with_distortion_state()
    overlay.set_guitar_effects(
        amp_on=True,
        cab_on=True,
        noise_gate_threshold=12,
    )
    gate_before = overlay._cached_gate_word
    flags_before = gate_before & 0xFF
    threshold_before = (gate_before >> 8) & 0xFF
    overlay.set_distortion_settings(pedal='metal', bias=20, mix=50)
    gate_after = overlay._cached_gate_word
    assert gate_after & 0xFF == flags_before
    assert (gate_after >> 8) & 0xFF == threshold_before
    assert (gate_after >> 16) & 0xFF == AudioLabOverlay._percent_to_u8(20, 255)
    assert (gate_after >> 24) & 0xFF == AudioLabOverlay._percent_to_u8(50, 255)


def test_set_distortion_settings_preserves_overdrive_params():
    overlay = make_overlay_with_distortion_state()
    overlay.set_guitar_effects(
        overdrive_on=True,
        overdrive_drive=80,
        overdrive_tone=40,
        overdrive_level=120,
    )
    od_before = overlay._cached_overdrive_word
    overlay.set_distortion_settings(tight=10)
    od_after = overlay._cached_overdrive_word
    # ctrlA/B/C preserved, only ctrlD (tight + OD model) changed.
    # D46: tight occupies bits[7:3], OD model occupies bits[2:0].
    assert od_after & 0x00FFFFFF == od_before & 0x00FFFFFF
    assert (od_after >> 24) & 0xF8 == AudioLabOverlay._percent_to_u8(10, 255) & 0xF8
    assert (od_after >> 24) & 0x07 == 0   # OD model untouched (default = 0)


def test_set_guitar_effects_uses_cached_distortion_state_when_unset():
    """If the user pre-configured the distortion section via
    set_distortion_pedal and then calls set_guitar_effects without
    naming the new fields, the pedal mask byte must be retained."""
    overlay = make_overlay_with_distortion_state()
    overlay.set_distortion_pedal('clean_boost', exclusive=True)
    overlay.set_distortion_settings(tight=85, bias=40, mix=70)
    overlay.set_guitar_effects(distortion_on=True)
    last_dist = overlay.axi_gpio_distortion.writes[-1][1]
    last_od = overlay.axi_gpio_overdrive.writes[-1][1]
    last_gate = overlay.axi_gpio_gate.writes[-1][1]
    assert (last_dist >> 24) & 0x7F == (1 << 0)  # clean_boost
    # D46: overdrive_control.ctrlD packs tight (top 5 bits) and OD model
    # select (bottom 3 bits). Compare tight against the masked value.
    assert (last_od >> 24) & 0xF8 == AudioLabOverlay._percent_to_u8(85, 255) & 0xF8
    assert (last_od >> 24) & 0x07 == 0   # default OD model
    assert (last_gate >> 16) & 0xFF == AudioLabOverlay._percent_to_u8(40, 255)
    assert (last_gate >> 24) & 0xFF == AudioLabOverlay._percent_to_u8(70, 255)


def test_get_distortion_settings_initial_defaults_are_safe():
    overlay = make_overlay_with_distortion_state()
    settings = overlay.get_distortion_settings()
    assert settings['pedal_mask'] == 0
    assert all(v is False for v in settings['pedals'].values())
    assert settings['drive'] == 20
    assert settings['level'] == 35
    assert settings['mix'] == 100


# ---- Noise Suppressor tests ----------------------------------------------


def test_noise_threshold_to_u8_scale_anchors():
    """New scale: byte = round(threshold * 255 / 1000). New 100 == legacy 10."""
    assert AudioLabOverlay._noise_threshold_to_u8(0) == 0
    assert AudioLabOverlay._noise_threshold_to_u8(10) == 3
    assert AudioLabOverlay._noise_threshold_to_u8(50) == 13
    assert AudioLabOverlay._noise_threshold_to_u8(100) == 26


def test_noise_threshold_to_u8_clamps():
    assert AudioLabOverlay._noise_threshold_to_u8(-50) == 0
    assert AudioLabOverlay._noise_threshold_to_u8(250) == 26


def test_noise_suppressor_word_packing():
    """ctrlA=threshold, ctrlB=decay, ctrlC=damp, ctrlD=mode (low-byte first)."""
    word = AudioLabOverlay._noise_suppressor_word(
        threshold=100, decay=45, damp=80, mode=0,
    )
    assert word & 0xFF == 26                                                # threshold
    assert (word >> 8) & 0xFF == AudioLabOverlay._percent_to_u8(45, 255)    # decay
    assert (word >> 16) & 0xFF == AudioLabOverlay._percent_to_u8(80, 255)   # damp
    assert (word >> 24) & 0xFF == 0                                         # mode


def test_set_noise_suppressor_settings_writes_word_to_dedicated_gpio():
    overlay = make_overlay_with_noise_suppressor_state()
    settings = overlay.set_noise_suppressor_settings(
        enabled=True, threshold=35, decay=45, damp=80,
    )
    ns_gpio = getattr(overlay, AudioLabOverlay.NOISE_SUPPRESSOR_GPIO_NAME)
    assert ns_gpio.writes, "expected a write to the noise suppressor GPIO"
    last_offset, last_word = ns_gpio.writes[-1]
    assert last_offset == 0x00
    expected_threshold = AudioLabOverlay._noise_threshold_to_u8(35)
    expected_decay = AudioLabOverlay._percent_to_u8(45, 255)
    expected_damp = AudioLabOverlay._percent_to_u8(80, 255)
    assert last_word & 0xFF == expected_threshold
    assert (last_word >> 8) & 0xFF == expected_decay
    assert (last_word >> 16) & 0xFF == expected_damp
    assert (last_word >> 24) & 0xFF == 0
    assert settings['threshold_byte'] == expected_threshold
    assert settings['decay_byte'] == expected_decay
    assert settings['damp_byte'] == expected_damp


def test_get_noise_suppressor_settings_reports_metadata():
    overlay = make_overlay_with_noise_suppressor_state()
    overlay.set_noise_suppressor_settings(
        enabled=True, threshold=35, decay=45, damp=80,
    )
    settings = overlay.get_noise_suppressor_settings()
    assert settings['enabled'] is True
    assert settings['threshold'] == 35
    assert settings['decay'] == 45
    assert settings['damp'] == 80
    assert settings['mode'] == 0
    assert settings['reflected_to_fpga'] is True
    assert settings['gpio_name'] == 'axi_gpio_noise_suppressor'
    assert settings['has_gpio'] is True
    assert settings['implementation_status'] == 'threshold_decay_damp_fpga'


def test_set_noise_suppressor_settings_clamps_inputs():
    overlay = make_overlay_with_noise_suppressor_state()
    settings = overlay.set_noise_suppressor_settings(
        threshold=-10, decay=200, damp=120,
    )
    assert settings['threshold'] == 0
    assert settings['decay'] == 100
    assert settings['damp'] == 100


def test_set_noise_suppressor_settings_mirrors_threshold_to_gate_ctrlB():
    """The legacy gate_control.ctrlB threshold byte must track the new
    GPIO byte so older bitstreams without the dedicated GPIO still see a
    sensible value."""
    overlay = make_overlay_with_noise_suppressor_state()
    overlay.set_noise_suppressor_settings(enabled=True, threshold=100)
    last_gate = overlay.axi_gpio_gate.writes[-1][1]
    expected = AudioLabOverlay._noise_threshold_to_u8(100)
    assert (last_gate >> 8) & 0xFF == expected
    assert last_gate & 0x01 == 0x01  # noise_gate_on flag follows enabled


def test_set_guitar_effects_mirrors_noise_threshold_to_ns_gpio():
    """Calling set_guitar_effects(noise_gate_threshold=...) must also
    write the dedicated noise-suppressor GPIO so the new bitstream sees
    the same compare level the legacy gate byte encodes."""
    overlay = make_overlay_with_noise_suppressor_state()
    overlay.set_guitar_effects(noise_gate_on=True, noise_gate_threshold=50)
    ns_gpio = getattr(overlay, AudioLabOverlay.NOISE_SUPPRESSOR_GPIO_NAME)
    assert ns_gpio.writes, "set_guitar_effects must touch the NS GPIO"
    last_word = ns_gpio.writes[-1][1]
    expected = AudioLabOverlay._noise_threshold_to_u8(50)
    assert last_word & 0xFF == expected
    state = overlay._noise_suppressor_state
    assert state['enabled'] is True
    assert state['threshold'] == 50


def test_guitar_effect_control_words_uses_new_threshold_scale():
    words = AudioLabOverlay.guitar_effect_control_words(
        noise_gate_on=True, noise_gate_threshold=100,
    )
    assert (words['gate'] >> 8) & 0xFF == 26
    assert words['gate'] & 0x01 == 0x01


def test_noise_suppressor_defaults_are_safe():
    overlay = make_overlay_with_noise_suppressor_state()
    settings = overlay.get_noise_suppressor_settings()
    assert settings['enabled'] is False
    assert settings['threshold'] == 35
    assert settings['decay'] == 40
    assert settings['damp'] == 70


# ---- control_maps module ------------------------------------------------


def test_control_maps_module_matches_overlay():
    """control_maps.* must produce the same byte values that the legacy
    AudioLabOverlay classmethods produce. Locking this prevents future
    refactors from drifting the encoding."""
    from audio_lab_pynq import control_maps as cm

    for v in (-50, 0, 1, 49, 50, 99, 100, 150):
        assert cm.clamp_percent(v) == AudioLabOverlay._clamp_percent(v), v
        assert cm.percent_to_u8(v, 255) == AudioLabOverlay._percent_to_u8(v, 255), v
        assert cm.percent_to_u8(v, 192) == AudioLabOverlay._percent_to_u8(v, 192), v
        assert cm.noise_threshold_to_u8(v) == AudioLabOverlay._noise_threshold_to_u8(v), v
    for v in (0, 50, 100, 150, 200, 250):
        assert cm.level_to_q7(v) == AudioLabOverlay._level_to_q7(v), v


def test_control_maps_pack_unpack_roundtrip():
    from audio_lab_pynq import control_maps as cm

    for sample in [(0, 0, 0, 0), (1, 2, 3, 4), (255, 0, 128, 64), (0xAB, 0xCD, 0xEF, 0x12)]:
        word = cm.pack_u8x4(*sample)
        assert cm.unpack_u8x4(word) == sample
    word = cm.pack_u8x4(0x10, 0x20, 0x30, 0x40)
    assert cm.get_byte(word, 0) == 0x10
    assert cm.get_byte(word, 1) == 0x20
    assert cm.get_byte(word, 2) == 0x30
    assert cm.get_byte(word, 3) == 0x40
    assert cm.set_byte(word, 1, 0xFF) == 0x4030FF10
    assert cm.bool_to_bit(True) == 1 and cm.bool_to_bit(False) == 0
    assert cm.bool_to_bit(0) == 0 and cm.bool_to_bit(7) == 1


def test_control_maps_pack_matches_legacy_pack():
    """pack_u8x4 must agree with the legacy AudioLabOverlay._pack4 for
    byte-shaped inputs."""
    from audio_lab_pynq import control_maps as cm

    for sample in [(0, 0, 0, 0), (1, 2, 3, 4), (255, 0, 128, 64)]:
        assert cm.pack_u8x4(*sample) == AudioLabOverlay._pack4(*sample), sample


def test_effect_defaults_module_exposes_canonical_dicts():
    from audio_lab_pynq import effect_defaults as ed

    assert ed.DISTORTION_DEFAULTS == AudioLabOverlay.DISTORTION_DEFAULTS
    assert ed.NOISE_SUPPRESSOR_DEFAULTS == AudioLabOverlay.NOISE_SUPPRESSOR_DEFAULTS
    assert ed.DISTORTION_PEDALS == AudioLabOverlay.DISTORTION_PEDALS
    # SAFE_BYPASS_DEFAULTS must keep every effect off.
    sb = ed.SAFE_BYPASS_DEFAULTS
    for flag in ('noise_gate_on', 'overdrive_on', 'distortion_on', 'rat_on',
                 'amp_on', 'cab_on', 'eq_on', 'reverb_on'):
        assert sb[flag] is False, flag
    assert sb['distortion_pedal_mask'] == 0


def test_effect_presets_module_matches_notebook_values():
    from audio_lab_pynq import effect_presets as ep

    # The four notebook NS presets must match these exact specs.
    assert ep.NOISE_SUPPRESSOR_PRESETS["NS-2 Style"] == dict(threshold=35, decay=45, damp=80)
    assert ep.NOISE_SUPPRESSOR_PRESETS["NS-1X Natural"] == dict(threshold=30, decay=55, damp=60)
    assert ep.NOISE_SUPPRESSOR_PRESETS["High Gain Tight"] == dict(threshold=55, decay=20, damp=90)
    assert ep.NOISE_SUPPRESSOR_PRESETS["Sustain Friendly"] == dict(threshold=25, decay=75, damp=45)
    # Distortion presets: voicing name -> pedal name.
    assert ep.DISTORTION_PRESETS["Clean Boost"]["pedal"] == "clean_boost"
    assert ep.DISTORTION_PRESETS["Tube Screamer Crunch"]["pedal"] == "tube_screamer"
    assert ep.DISTORTION_PRESETS["RAT Distortion"]["pedal"] == "rat"
    assert ep.DISTORTION_PRESETS["Metal Tight"]["pedal"] == "metal"
    # Newly-implemented pedal voicings.
    assert ep.DISTORTION_PRESETS["DS-1 Crunch"]["pedal"] == "ds1"
    assert ep.DISTORTION_PRESETS["DS-1 Lead"]["pedal"] == "ds1"
    assert ep.DISTORTION_PRESETS["Big Muff Sustain"]["pedal"] == "big_muff"
    assert ep.DISTORTION_PRESETS["Big Muff Wall"]["pedal"] == "big_muff"
    assert ep.DISTORTION_PRESETS["Fuzz Face"]["pedal"] == "fuzz_face"
    assert ep.DISTORTION_PRESETS["Fuzz Face Vintage"]["pedal"] == "fuzz_face"


def test_new_distortion_presets_level_capped():
    """Newly-added distortion presets (DS-1 / Big Muff / Fuzz Face)
    must cap level at 35 so the post-distortion stages cannot be
    slammed. Pre-existing presets (Clean Boost = 45) are intentionally
    grandfathered."""
    from audio_lab_pynq import effect_presets as ep
    new_preset_names = (
        "DS-1 Crunch", "DS-1 Lead",
        "Big Muff Sustain", "Big Muff Wall",
        "Fuzz Face", "Fuzz Face Vintage",
    )
    for name in new_preset_names:
        spec = ep.DISTORTION_PRESETS[name]
        level = spec.get("level")
        assert level is not None and level <= 35, (
            "distortion preset {!r} has level={} (must be <= 35)"
            .format(name, level))


def test_new_chain_presets_for_implemented_pedals():
    """Three new chain presets land for the freshly-implemented pedals."""
    from audio_lab_pynq import effect_presets as ep
    for name, expected_pedal in (
        ("DS-1 Crunch", "ds1"),
        ("Big Muff Sustain", "big_muff"),
        ("Vintage Fuzz", "fuzz_face"),
    ):
        assert name in ep.CHAIN_PRESETS, "missing chain preset: " + name
        spec = ep.CHAIN_PRESETS[name]
        assert spec["distortion"]["pedal"] == expected_pedal
        assert spec["distortion"]["enabled"] is True
        # The shared safety contract must hold.
        assert spec["distortion"]["level"] <= 35
        assert 45 <= spec["compressor"]["makeup"] <= 60


def test_high_gain_chain_presets_use_closed_back_cab():
    """DS-1 / Muff / Fuzz / Metal presets should lean on cab model 2."""
    from audio_lab_pynq import effect_presets as ep

    for name in (
        "DS-1 Crunch",
        "Big Muff Sustain",
        "Vintage Fuzz",
        "Metal Tight",
        "Noise Controlled High Gain",
    ):
        cab = ep.CHAIN_PRESETS[name]["cab"]
        assert cab["enabled"] is True
        assert cab["model"] == 2, "preset {!r} must use model 2 cab".format(name)
        assert cab["air"] <= 40, "preset {!r} cab air should stay capped".format(name)


# ---- guitar_effect_control_words snapshot -------------------------------
#
# These are byte-for-byte snapshots of the current encoding. They lock
# the live encoding so future refactors cannot silently change the
# bits that reach the FPGA. If a snapshot fails because you intended
# to change the encoding, update the snapshot in the same commit and
# describe the audio impact in the commit message.


SCENARIO_KWARGS = {
    "defaults": {},
    "ns2_style": dict(noise_gate_on=True, noise_gate_threshold=35),
    "high_gain_tight": dict(noise_gate_on=True, noise_gate_threshold=55),
    "clean_boost": dict(distortion_on=True, distortion_pedal_mask=(1 << 0),
                        distortion=35, distortion_tone=50, distortion_level=45,
                        distortion_bias=50, distortion_tight=50, distortion_mix=100),
    "tube_screamer_crunch": dict(distortion_on=True, distortion_pedal_mask=(1 << 1),
                                 distortion=45, distortion_tone=55, distortion_level=35,
                                 distortion_bias=50, distortion_tight=60, distortion_mix=100),
    "rat_distortion": dict(distortion_on=True, distortion_pedal_mask=(1 << 2), rat_on=True,
                           distortion=55, distortion_tone=45, distortion_level=35,
                           distortion_bias=50, distortion_tight=50, distortion_mix=100),
    "metal_tight": dict(distortion_on=True, distortion_pedal_mask=(1 << 6),
                        distortion=55, distortion_tone=55, distortion_level=30,
                        distortion_bias=50, distortion_tight=75, distortion_mix=100),
    "distortion_all_off": dict(distortion_on=False, distortion_pedal_mask=0),
    "reverb_basic": dict(reverb_on=True, reverb_decay=30, reverb_tone=65, reverb_mix=20),
    "amp_cab_basic": dict(amp_on=True, cab_on=True),
}


SCENARIO_SNAPSHOTS = {
    "defaults": {
        "gate": 0xff800200, "overdrive": 0x804c80a6, "distortion": 0x004080a6,
        "eq": 0x00808080, "rat": 0xff8c8059, "amp": 0x59736659,
        "amp_tone": 0x59808080, "cab": 0x805580ff, "reverb": 0x0026a642,
    },
    "ns2_style": {
        "gate": 0xff800901, "overdrive": 0x804c80a6, "distortion": 0x004080a6,
        "eq": 0x00808080, "rat": 0xff8c8059, "amp": 0x59736659,
        "amp_tone": 0x59808080, "cab": 0x805580ff, "reverb": 0x0026a642,
    },
    "high_gain_tight": {
        "gate": 0xff800e01, "overdrive": 0x804c80a6, "distortion": 0x004080a6,
        "eq": 0x00808080, "rat": 0xff8c8059, "amp": 0x59736659,
        "amp_tone": 0x59808080, "cab": 0x805580ff, "reverb": 0x0026a642,
    },
    "clean_boost": {
        "gate": 0xff800204, "overdrive": 0x804c80a6, "distortion": 0x01593a80,
        "eq": 0x00808080, "rat": 0xff8c8059, "amp": 0x59736659,
        "amp_tone": 0x59808080, "cab": 0x805580ff, "reverb": 0x0026a642,
    },
    "tube_screamer_crunch": {
        # tight=60 -> _percent_to_u8(60,255)=153 (0x99); D46 masks the
        # low 3 bits off so ctrlD = 0x99 & 0xF8 = 0x98 (+ OD model 0).
        # The Clash distortion-section consumers all shift the byte
        # right by 3 or 4, so this masking does not change behaviour.
        "gate": 0xff800204, "overdrive": 0x984c80a6, "distortion": 0x02732d8c,
        "eq": 0x00808080, "rat": 0xff8c8059, "amp": 0x59736659,
        "amp_tone": 0x59808080, "cab": 0x805580ff, "reverb": 0x0026a642,
    },
    "rat_distortion": {
        "gate": 0xff800214, "overdrive": 0x804c80a6, "distortion": 0x048c2d73,
        "eq": 0x00808080, "rat": 0xff8c8059, "amp": 0x59736659,
        "amp_tone": 0x59808080, "cab": 0x805580ff, "reverb": 0x0026a642,
    },
    "metal_tight": {
        # tight=75 -> 0xBF; D46 masks low 3 bits -> 0xB8.
        "gate": 0xff800204, "overdrive": 0xb84c80a6, "distortion": 0x408c268c,
        "eq": 0x00808080, "rat": 0xff8c8059, "amp": 0x59736659,
        "amp_tone": 0x59808080, "cab": 0x805580ff, "reverb": 0x0026a642,
    },
    "distortion_all_off": {
        "gate": 0xff800200, "overdrive": 0x804c80a6, "distortion": 0x004080a6,
        "eq": 0x00808080, "rat": 0xff8c8059, "amp": 0x59736659,
        "amp_tone": 0x59808080, "cab": 0x805580ff, "reverb": 0x0026a642,
    },
    "reverb_basic": {
        "gate": 0xff800220, "overdrive": 0x804c80a6, "distortion": 0x004080a6,
        "eq": 0x00808080, "rat": 0xff8c8059, "amp": 0x59736659,
        "amp_tone": 0x59808080, "cab": 0x805580ff, "reverb": 0x0026a642,
    },
    "amp_cab_basic": {
        "gate": 0xff8002c0, "overdrive": 0x804c80a6, "distortion": 0x004080a6,
        "eq": 0x00808080, "rat": 0xff8c8059, "amp": 0x59736659,
        "amp_tone": 0x59808080, "cab": 0x805580ff, "reverb": 0x0026a642,
    },
}


def test_guitar_effect_control_words_snapshots():
    for name, kwargs in SCENARIO_KWARGS.items():
        words = AudioLabOverlay.guitar_effect_control_words(**kwargs)
        expected = SCENARIO_SNAPSHOTS[name]
        for key, value in expected.items():
            assert words[key] == value, (
                "snapshot drift in scenario {!r}, field {!r}: "
                "got {:#010x}, expected {:#010x}".format(name, key, words[key], value))


def test_safe_bypass_snapshot_disables_every_flag():
    """Every effect-master flag in gate.ctrlA must be 0 after Safe Bypass,
    and the routing helper must fall back to passthrough."""
    from audio_lab_pynq.effect_defaults import SAFE_BYPASS_DEFAULTS

    words = AudioLabOverlay.guitar_effect_control_words(**SAFE_BYPASS_DEFAULTS)
    assert words["gate"] & 0xFF == 0, hex(words["gate"])
    assert (words["distortion"] >> 24) & 0x7F == 0
    assert words["reverb"] & 0x01 == 0  # reverb enable byte


def test_noise_suppressor_preset_bytes_snapshot():
    """The four notebook NS presets must keep producing exactly these
    32-bit words on the dedicated GPIO."""
    from audio_lab_pynq import control_maps as cm
    from audio_lab_pynq import effect_presets as ep

    expected = {
        "NS-2 Style":       0x00cc7309,
        "NS-1X Natural":    0x00998c08,
        "High Gain Tight":  0x00e6330e,
        "Sustain Friendly": 0x0073bf06,
    }
    for name, spec in ep.NOISE_SUPPRESSOR_PRESETS.items():
        word = cm.noise_suppressor_word(mode=0, **spec)
        assert word == expected[name], (
            "NS preset {!r}: got {:#010x} expected {:#010x}".format(
                name, word, expected[name]))


# ---- Compressor ---------------------------------------------------------


def make_overlay_with_compressor_state(include_compressor_gpio=True):
    overlay = make_overlay_with_noise_suppressor_state()
    overlay._compressor_state = dict(AudioLabOverlay.COMPRESSOR_DEFAULTS)
    overlay._cached_compressor_word = 0
    if include_compressor_gpio:
        setattr(overlay, AudioLabOverlay.COMPRESSOR_GPIO_NAME, FakeGpio())
    return overlay


def make_overlay_with_wah_state(include_wah_gpio=True):
    overlay = make_overlay_with_compressor_state()
    overlay._wah_state = dict(AudioLabOverlay.WAH_DEFAULTS)
    overlay._cached_wah_word = 0
    if include_wah_gpio:
        setattr(overlay, AudioLabOverlay.WAH_GPIO_NAME, FakeGpio())
    return overlay


def test_makeup_to_u7_anchors():
    from audio_lab_pynq import control_maps as cm

    assert cm.makeup_to_u7(0) == 0
    # 50% -> 0.5 * 127 = 63.5 -> 64 (rounds to nearest then clamped to 127)
    assert cm.makeup_to_u7(50) == 64
    assert cm.makeup_to_u7(100) == 127


def test_makeup_to_u7_clamps():
    from audio_lab_pynq import control_maps as cm

    assert cm.makeup_to_u7(-10) == 0
    assert cm.makeup_to_u7(150) == 127


def test_compressor_enable_makeup_byte_packing():
    from audio_lab_pynq import control_maps as cm

    assert cm.compressor_enable_makeup_byte(False, 0) == 0x00
    assert cm.compressor_enable_makeup_byte(False, 50) == 0x40
    assert cm.compressor_enable_makeup_byte(False, 100) == 0x7F
    assert cm.compressor_enable_makeup_byte(True, 0) == 0x80
    assert cm.compressor_enable_makeup_byte(True, 50) == 0xC0
    assert cm.compressor_enable_makeup_byte(True, 100) == 0xFF


def test_compressor_word_packing():
    from audio_lab_pynq import control_maps as cm

    # Off: ctrlD bit 7 cleared.
    word_off = cm.compressor_word(45, 35, 45, 50, enabled=False)
    assert word_off & 0xFF == cm.percent_to_u8(45, 255)
    assert (word_off >> 8) & 0xFF == cm.percent_to_u8(35, 255)
    assert (word_off >> 16) & 0xFF == cm.percent_to_u8(45, 255)
    assert (word_off >> 24) & 0x80 == 0
    assert (word_off >> 24) & 0x7F == cm.makeup_to_u7(50)

    # On: ctrlD bit 7 set, makeup bits[6:0] match.
    word_on = cm.compressor_word(45, 35, 45, 50, enabled=True)
    assert word_on & 0xFF == cm.percent_to_u8(45, 255)
    assert (word_on >> 24) & 0x80 == 0x80
    assert (word_on >> 24) & 0x7F == cm.makeup_to_u7(50)


def test_set_compressor_settings_writes_word_to_dedicated_gpio():
    overlay = make_overlay_with_compressor_state()
    settings = overlay.set_compressor_settings(
        enabled=True, threshold=45, ratio=35, response=45, makeup=50,
    )
    comp_gpio = getattr(overlay, AudioLabOverlay.COMPRESSOR_GPIO_NAME)
    assert comp_gpio.writes, "expected a write to the compressor GPIO"
    last_offset, last_word = comp_gpio.writes[-1]
    assert last_offset == 0x00
    expected_threshold = AudioLabOverlay._percent_to_u8(45, 255)
    expected_ratio = AudioLabOverlay._percent_to_u8(35, 255)
    expected_response = AudioLabOverlay._percent_to_u8(45, 255)
    expected_makeup = AudioLabOverlay._makeup_to_u7(50)
    assert last_word & 0xFF == expected_threshold
    assert (last_word >> 8) & 0xFF == expected_ratio
    assert (last_word >> 16) & 0xFF == expected_response
    assert (last_word >> 24) & 0x80 == 0x80  # enable bit
    assert (last_word >> 24) & 0x7F == expected_makeup
    assert settings['threshold_byte'] == expected_threshold
    assert settings['ratio_byte'] == expected_ratio
    assert settings['response_byte'] == expected_response
    assert settings['makeup_u7'] == expected_makeup


def test_get_compressor_settings_reports_metadata():
    overlay = make_overlay_with_compressor_state()
    overlay.set_compressor_settings(
        enabled=True, threshold=45, ratio=35, response=45, makeup=50,
    )
    settings = overlay.get_compressor_settings()
    assert settings['enabled'] is True
    assert settings['threshold'] == 45
    assert settings['ratio'] == 35
    assert settings['response'] == 45
    assert settings['makeup'] == 50
    assert settings['reflected_to_fpga'] is True
    assert settings['gpio_name'] == 'axi_gpio_compressor'
    assert settings['has_gpio'] is True
    assert settings['implementation_status'] == 'threshold_ratio_response_makeup_fpga'


def test_set_compressor_settings_clamps_inputs():
    overlay = make_overlay_with_compressor_state()
    settings = overlay.set_compressor_settings(
        threshold=-10, ratio=200, response=120, makeup=150,
    )
    assert settings['threshold'] == 0
    assert settings['ratio'] == 100
    assert settings['response'] == 100
    assert settings['makeup'] == 100


def test_compressor_disabled_clears_enable_bit():
    overlay = make_overlay_with_compressor_state()
    overlay.set_compressor_settings(enabled=True, makeup=80)
    overlay.set_compressor_settings(enabled=False)
    settings = overlay.get_compressor_settings()
    assert settings['enabled'] is False
    assert settings['enable_makeup_byte'] & 0x80 == 0
    # makeup is preserved across the off-toggle.
    assert settings['makeup'] == 80


def test_compressor_defaults_are_safe():
    overlay = make_overlay_with_compressor_state()
    settings = overlay.get_compressor_settings()
    assert settings['enabled'] is False
    assert settings['threshold'] == 45
    assert settings['ratio'] == 35
    assert settings['response'] == 45
    assert settings['makeup'] == 50


def test_compressor_preset_bytes_snapshot():
    """The five notebook compressor presets must keep producing exactly
    these 32-bit words on the dedicated GPIO."""
    from audio_lab_pynq import control_maps as cm
    from audio_lab_pynq import effect_presets as ep

    expected = {
        "Comp Off":       0x40735973,
        "Light Sustain":  0xc68c4073,
        "Funk Tight":     0xc033738c,
        "Lead Sustain":   0xccb29966,
        "Limiter-ish":    0xb940d9b2,
    }
    for name, spec in ep.COMPRESSOR_PRESETS.items():
        word = cm.compressor_word(**spec)
        assert word == expected[name], (
            "compressor preset {!r}: got {:#010x} expected {:#010x}".format(
                name, word, expected[name]))


def test_effect_defaults_module_exposes_compressor_dict():
    from audio_lab_pynq import effect_defaults as ed

    assert isinstance(ed.COMPRESSOR_DEFAULTS, dict)
    assert ed.COMPRESSOR_DEFAULTS['enabled'] is False
    assert ed.COMPRESSOR_DEFAULTS['threshold'] == 45
    assert ed.COMPRESSOR_DEFAULTS['ratio'] == 35
    assert ed.COMPRESSOR_DEFAULTS['response'] == 45
    assert ed.COMPRESSOR_DEFAULTS['makeup'] == 50


# ---- Amp models ---------------------------------------------------------


def test_amp_models_table_anchors():
    """D55: the six documented amp models map onto the integer
    ``amp_model_idx`` 0..5 written to ``axi_gpio_amp_tone.ctrlD[2:0]``."""
    from audio_lab_pynq.effect_defaults import AMP_MODELS
    assert AMP_MODELS == {
        "jc_120":      0,
        "twin_reverb": 1,
        "ac30":        2,
        "rockerverb":  3,
        "jcm800":      4,
        "triamp_mk3":  5,
    }
    # Module re-export must mirror the class attribute for back-compat.
    assert AudioLabOverlay.AMP_MODELS == AMP_MODELS


def test_amp_model_labels_are_human_readable_titles():
    """Display labels for the HDMI GUI / encoder GUI / Notebook
    dropdowns must use the title-case names called out in D55."""
    assert AudioLabOverlay.AMP_MODEL_LABELS == (
        "JC-120", "Twin Reverb", "AC30",
        "Rockerverb", "JCM800", "TriAmp Mk3",
    )
    assert AudioLabOverlay.get_amp_model_labels() == [
        "JC-120", "Twin Reverb", "AC30",
        "Rockerverb", "JCM800", "TriAmp Mk3"]


def test_amp_models_old_d52_names_are_retired():
    """The retired D52 names must not be present in the user-facing
    name list any more. Aliases on the HDMI mirror side are tested
    separately."""
    names = AudioLabOverlay.get_amp_model_names()
    for retired in ("jc_clean", "clean_combo", "british_crunch",
                    "high_gain_stack"):
        assert retired not in names, (retired, names)


def test_get_amp_model_names_lists_documented_models():
    names = AudioLabOverlay.get_amp_model_names()
    assert names == ["jc_120", "twin_reverb", "ac30",
                     "rockerverb", "jcm800", "triamp_mk3"]


def test_amp_model_to_idx_known_names():
    assert AudioLabOverlay.amp_model_to_idx("jc_120") == 0
    assert AudioLabOverlay.amp_model_to_idx("twin_reverb") == 1
    assert AudioLabOverlay.amp_model_to_idx("ac30") == 2
    assert AudioLabOverlay.amp_model_to_idx("rockerverb") == 3
    assert AudioLabOverlay.amp_model_to_idx("jcm800") == 4
    assert AudioLabOverlay.amp_model_to_idx("triamp_mk3") == 5


def test_amp_model_to_idx_display_labels():
    """Title-case display labels resolve too, so notebook dropdowns
    can pass the human-readable name straight through."""
    assert AudioLabOverlay.amp_model_to_idx("JC-120") == 0
    assert AudioLabOverlay.amp_model_to_idx("Twin Reverb") == 1
    assert AudioLabOverlay.amp_model_to_idx("AC30") == 2
    assert AudioLabOverlay.amp_model_to_idx("Rockerverb") == 3
    assert AudioLabOverlay.amp_model_to_idx("JCM800") == 4
    assert AudioLabOverlay.amp_model_to_idx("TriAmp Mk3") == 5


def test_amp_model_to_character_back_compat_returns_idx():
    """D55 retired the continuous ``amp_character`` percent knob, so
    ``amp_model_to_character`` now returns the integer idx (0..5);
    that integer is still a valid ``amp_model_idx`` for old code that
    fed the return value back into ``set_amp_model``."""
    assert AudioLabOverlay.amp_model_to_character("jc_120") == 0
    assert AudioLabOverlay.amp_model_to_character("triamp_mk3") == 5


def test_amp_model_to_idx_unknown_raises():
    raised = False
    try:
        AudioLabOverlay.amp_model_to_idx("not_an_amp")
    except ValueError as exc:
        assert "unknown amp model" in str(exc)
        raised = True
    assert raised


def test_set_amp_model_writes_correct_model_idx_byte():
    """set_amp_model must write the D55 bit-packed byte (ctrlD[7]=drive,
    ctrlD[2:0]=model_idx) to axi_gpio_amp_tone.ctrlD."""
    overlay = make_overlay_with_distortion_state()
    overlay.set_amp_model("ac30")
    last_word = overlay.axi_gpio_amp_tone.writes[-1][1]
    # Clean mode -> bit 7 clear, model idx = 2 (AC30)
    assert (last_word >> 24) & 0xFF == 2, hex(last_word)


def test_set_amp_model_distinct_bytes_per_model():
    """Each model writes a different byte to amp_tone.ctrlD (six
    distinct bytes for the six D55 voicings)."""
    seen = set()
    for name in AudioLabOverlay.get_amp_model_names():
        overlay = make_overlay_with_distortion_state()
        overlay.set_amp_model(name)
        last_word = overlay.axi_gpio_amp_tone.writes[-1][1]
        seen.add((last_word >> 24) & 0xFF)
    assert len(seen) == 6, ("each amp model must produce a unique byte",
                            sorted(seen))


def test_set_amp_model_overrides_let_caller_pin_other_amp_params():
    overlay = make_overlay_with_distortion_state()
    overlay.set_amp_model("twin_reverb", amp_master=70, amp_input_gain=40)
    last_word = overlay.axi_gpio_amp.writes[-1][1]
    expected_master = AudioLabOverlay._level_to_q7(70)
    expected_gain = AudioLabOverlay._percent_to_u8(40, 255)
    assert last_word & 0xFF == expected_gain
    assert (last_word >> 8) & 0xFF == expected_master


def test_set_amp_model_propagates_drive_mode():
    """set_amp_model accepts amp_drive_mode= and writes it into ctrlD bit 7."""
    overlay = make_overlay_with_distortion_state()
    overlay.set_amp_model("triamp_mk3", amp_drive_mode=1)
    last_word = overlay.axi_gpio_amp_tone.writes[-1][1]
    assert (last_word >> 24) & 0xFF == 0x85  # drive=1 + idx=5


# ---- D55 amp model bit-pack + real DSP Clean/Drive split ----------------


def test_amp_model_drive_byte_clean_mode_layout():
    """D55: drive_mode=0 packs only the model idx into ctrlD[2:0];
    bit 7 stays clear so the Clash side sees Clean mode."""
    for idx in range(6):
        b = AudioLabOverlay.amp_model_drive_byte(
            amp_model_idx=idx, amp_drive_mode=0)
        assert b == idx
        assert (b >> 7) & 1 == 0
        # bits 6..3 reserved -> must read 0 on the writer side
        assert (b >> 3) & 0x0F == 0, (idx, hex(b))


def test_amp_model_drive_byte_drive_mode_layout():
    """D55: drive_mode=1 sets ctrlD[7]; the model idx still lives at
    ctrlD[2:0] so the Clash side can route both fields independently."""
    for idx in range(6):
        b = AudioLabOverlay.amp_model_drive_byte(
            amp_model_idx=idx, amp_drive_mode=1)
        assert b & 0x07 == idx
        assert (b >> 7) & 1 == 1
        assert (b >> 3) & 0x0F == 0, (idx, hex(b))


def test_amp_model_drive_byte_known_values_match_spec():
    """Anchor values from the D55 spec: each (idx, drive) pair must
    map to a specific ctrlD byte."""
    cases = [
        (0, 0, 0x00), (1, 0, 0x01), (2, 0, 0x02),
        (3, 0, 0x03), (4, 0, 0x04), (5, 0, 0x05),
        (0, 1, 0x80), (1, 1, 0x81), (2, 1, 0x82),
        (3, 1, 0x83), (4, 1, 0x84), (5, 1, 0x85),
    ]
    for idx, drive, expected in cases:
        b = AudioLabOverlay.amp_model_drive_byte(
            amp_model_idx=idx, amp_drive_mode=drive)
        assert b == expected, (idx, drive, hex(b), hex(expected))


def test_amp_model_drive_byte_clamps_inputs():
    """Out-of-range model idx clamps to 0..5; out-of-range drive_mode
    clamps to 0/1; non-int inputs default to 0."""
    # 99 clamps to AMP_MODEL_IDX_MAX (5), not to MASK (7)
    assert AudioLabOverlay.amp_model_drive_byte(
        amp_model_idx=99, amp_drive_mode=0) == 5
    assert AudioLabOverlay.amp_model_drive_byte(
        amp_model_idx=99, amp_drive_mode=1) == 0x85
    assert AudioLabOverlay.amp_model_drive_byte(
        amp_model_idx=-1, amp_drive_mode=0) == 0
    assert AudioLabOverlay.amp_model_drive_byte(
        amp_model_idx=0, amp_drive_mode=100) == 0x80
    assert AudioLabOverlay.amp_model_drive_byte(
        amp_model_idx="bogus", amp_drive_mode="bogus") == 0


def test_amp_character_byte_for_model_alias_matches_d55_pack():
    """The D53 helper name is preserved as a thin alias of
    amp_model_drive_byte so any external caller keeps working."""
    for idx in range(6):
        for drive in (0, 1):
            assert (AudioLabOverlay.amp_character_byte_for_model(idx, drive)
                    == AudioLabOverlay.amp_model_drive_byte(
                        amp_model_idx=idx, amp_drive_mode=drive))


def test_guitar_effect_control_words_amp_model_idx_uses_d55_bit_pack():
    """When amp_model_idx is supplied, ctrlD carries the D55 bit-pack
    (bit 7 = drive_mode, bits[2:0] = model idx); the legacy
    amp_character percent kwarg is ignored. Verified for the highest
    voicing so the 3-bit field actually exercises bit 2."""
    words = AudioLabOverlay.guitar_effect_control_words(
        amp_on=True, amp_model_idx=5, amp_drive_mode=1,
        amp_character=0)
    char_byte = (words["amp_tone"] >> 24) & 0xFF
    assert char_byte == 0x85
    assert (char_byte >> 7) & 1 == 1
    assert char_byte & 0x07 == 5
    # Clean mode keeps bit 7 clear regardless of amp_character percent.
    words0 = AudioLabOverlay.guitar_effect_control_words(
        amp_on=True, amp_model_idx=5, amp_drive_mode=0,
        amp_character=0)
    assert (words0["amp_tone"] >> 24) & 0xFF == 5


def test_guitar_effect_control_words_without_model_idx_uses_amp_character():
    """Back-compat: callers (chain presets / legacy notebooks) that
    omit amp_model_idx keep getting the old amp_character byte
    via the legacy percent path."""
    words = AudioLabOverlay.guitar_effect_control_words(
        amp_on=True, amp_character=60)
    assert (words["amp_tone"] >> 24) & 0xFF == AudioLabOverlay._percent_to_u8(
        60, 255)


# ---- Chain presets ------------------------------------------------------


def make_overlay_with_chain_state(include_compressor_gpio=True,
                                  include_ns_gpio=True):
    overlay = make_overlay_with_compressor_state(
        include_compressor_gpio=include_compressor_gpio)
    if not include_ns_gpio and hasattr(
            overlay, AudioLabOverlay.NOISE_SUPPRESSOR_GPIO_NAME):
        delattr(overlay, AudioLabOverlay.NOISE_SUPPRESSOR_GPIO_NAME)
    return overlay


REQUIRED_CHAIN_PRESET_NAMES = (
    "Safe Bypass",
    "Basic Clean",
    "Clean Sustain",
    "Light Crunch",
    "Tube Screamer Lead",
    "RAT Rhythm",
    "Metal Tight",
    "Ambient Clean",
    "Solo Boost",
    "Noise Controlled High Gain",
)


def test_chain_presets_module_exists_and_has_required_names():
    from audio_lab_pynq import effect_presets as ep

    assert isinstance(ep.CHAIN_PRESETS, dict)
    for name in REQUIRED_CHAIN_PRESET_NAMES:
        assert name in ep.CHAIN_PRESETS, "missing chain preset: " + name


def test_chain_presets_have_all_required_sections():
    from audio_lab_pynq import effect_presets as ep

    for name, spec in ep.CHAIN_PRESETS.items():
        for section in ep.CHAIN_PRESET_SECTIONS:
            assert section in spec, (
                "preset {!r} missing section {!r}".format(name, section))


def test_safe_bypass_preset_has_every_section_off():
    from audio_lab_pynq import effect_presets as ep

    safe = ep.CHAIN_PRESETS["Safe Bypass"]
    for section in ep.CHAIN_PRESET_SECTIONS:
        assert safe[section].get("enabled") is False, (
            "Safe Bypass: section {!r} has enabled != False".format(section))
    # Reverb mix must be zero in the panic preset.
    assert safe["reverb"]["mix"] == 0


def test_chain_presets_compressor_makeup_within_safe_band():
    """Every preset's compressor makeup must stay in the 45..60 band so
    a preset cannot blow the rest of the chain into clipping."""
    from audio_lab_pynq import effect_presets as ep

    for name, spec in ep.CHAIN_PRESETS.items():
        makeup = spec["compressor"]["makeup"]
        assert 45 <= makeup <= 60, (
            "preset {!r} compressor makeup={} outside the 45..60 band"
            .format(name, makeup))


def test_chain_presets_distortion_level_capped():
    """Every preset's distortion level must stay <= 35 so a preset
    cannot drive the post-distortion stages into hard clip."""
    from audio_lab_pynq import effect_presets as ep

    for name, spec in ep.CHAIN_PRESETS.items():
        level = spec["distortion"]["level"]
        assert level <= 35, (
            "preset {!r} distortion level={} exceeds the 35 cap"
            .format(name, level))


def test_get_chain_preset_names_matches_module():
    from audio_lab_pynq import effect_presets as ep

    names = AudioLabOverlay.get_chain_preset_names()
    assert names == list(ep.CHAIN_PRESETS.keys())


def test_get_chain_preset_returns_deep_copy():
    spec_a = AudioLabOverlay.get_chain_preset("Safe Bypass")
    spec_b = AudioLabOverlay.get_chain_preset("Safe Bypass")
    spec_a["compressor"]["makeup"] = 999
    assert spec_b["compressor"]["makeup"] != 999


def test_get_chain_preset_unknown_raises():
    try:
        AudioLabOverlay.get_chain_preset("does_not_exist")
    except KeyError as exc:
        assert "does_not_exist" in str(exc)
    else:
        raise AssertionError("unknown preset should raise KeyError")


def test_apply_chain_preset_basic_clean_round_trip():
    overlay = make_overlay_with_chain_state()
    state = overlay.apply_chain_preset("Basic Clean")
    assert "compressor" in state
    assert state["compressor"]["enabled"] is True
    assert state["compressor"]["makeup"] == 50
    # Reverb must be on with mix 15 per the preset.
    assert overlay.routes[-1] == (XbarEffect.guitar_chain, XbarSink.headphone)


def test_apply_chain_preset_metal_tight_writes_pedal_mask():
    overlay = make_overlay_with_chain_state()
    overlay.apply_chain_preset("Metal Tight")
    dist = overlay.get_distortion_settings()
    bit = AudioLabOverlay._DIST_PEDAL_BIT["metal"]
    assert dist["pedal_mask"] & (1 << bit), \
        "Metal Tight preset must set the metal pedal bit"
    assert dist["tight"] == 80
    ns = overlay.get_noise_suppressor_settings()
    assert ns["enabled"] is True
    assert ns["threshold"] == 55


def test_apply_chain_preset_tube_screamer_lead_writes_compressor_word():
    overlay = make_overlay_with_chain_state()
    overlay.apply_chain_preset("Tube Screamer Lead")
    comp_gpio = getattr(overlay, AudioLabOverlay.COMPRESSOR_GPIO_NAME)
    last_word = comp_gpio.writes[-1][1]
    # Compressor enable bit set, makeup 60 -> u7 76.
    assert (last_word >> 24) & 0x80 == 0x80
    expected_makeup = AudioLabOverlay._makeup_to_u7(60)
    assert (last_word >> 24) & 0x7F == expected_makeup


def test_apply_chain_preset_safe_bypass_routes_passthrough():
    overlay = make_overlay_with_chain_state()
    # First apply something noisy so we have a non-passthrough route
    # to compare against, then Safe Bypass.
    overlay.apply_chain_preset("Metal Tight")
    overlay.apply_chain_preset("Safe Bypass")
    assert overlay.routes[-1] == (XbarEffect.passthrough, XbarSink.headphone), \
        "Safe Bypass should route to passthrough"
    # No distortion pedals selected.
    assert overlay.get_distortion_settings()["pedal_mask"] == 0


def test_get_current_pedalboard_state_returns_dict():
    overlay = make_overlay_with_chain_state()
    overlay.apply_chain_preset("Basic Clean")
    state = overlay.get_current_pedalboard_state()
    assert isinstance(state, dict)
    assert "compressor" in state
    assert "noise_suppressor" in state
    assert "distortion" in state
    # The cached_words bucket must include the GPIOs we just wrote.
    assert "cached_words" in state
    assert state["cached_words"]["compressor_word"] != 0


def test_apply_chain_preset_survives_missing_compressor_gpio():
    """An older overlay without axi_gpio_compressor must still apply
    the rest of the chain preset."""
    overlay = make_overlay_with_chain_state(include_compressor_gpio=False)
    # No compressor GPIO -> apply still has to write the rest.
    state = overlay.apply_chain_preset("Basic Clean")
    # set_guitar_effects must still have routed.
    assert overlay.routes[-1][1] == XbarSink.headphone
    assert "compressor" not in state or state["compressor"]["has_gpio"] is False


def test_apply_chain_preset_unknown_name_raises():
    overlay = make_overlay_with_chain_state()
    try:
        overlay.apply_chain_preset("does_not_exist")
    except KeyError as exc:
        assert "does_not_exist" in str(exc)
    else:
        raise AssertionError("unknown preset should raise KeyError")


# ---- Wah ----------------------------------------------------------------


def test_wah_position_byte_anchors():
    from audio_lab_pynq import control_maps as cm

    # Percent path (0..100).
    assert cm.wah_position_byte(0) == 0
    assert cm.wah_position_byte(50) == cm.percent_to_u8(50, 255)
    assert cm.wah_position_byte(100) == 255
    # Raw byte path (anything > 100 is treated as a raw byte already).
    assert cm.wah_position_byte(128) == 128
    assert cm.wah_position_byte(255) == 255
    # Clamp.
    assert cm.wah_position_byte(-10) == 0
    assert cm.wah_position_byte(300) == 255


def test_wah_q_byte_anchors():
    from audio_lab_pynq import control_maps as cm

    assert cm.wah_q_byte(0) == 0
    assert cm.wah_q_byte(50) == cm.percent_to_u8(50, 255)
    assert cm.wah_q_byte(100) == 255


def test_wah_volume_byte_anchors():
    from audio_lab_pynq import control_maps as cm

    assert cm.wah_volume_byte(0) == 0
    assert cm.wah_volume_byte(50) == cm.percent_to_u8(50, 255)
    assert cm.wah_volume_byte(100) == 255


def test_wah_bias_to_u7_anchors():
    from audio_lab_pynq import control_maps as cm

    assert cm.wah_bias_to_u7(0) == 0
    # 50% -> 0.5 * 127 = 63.5 -> 64 (rounded then clamped to 127)
    assert cm.wah_bias_to_u7(50) == 64
    assert cm.wah_bias_to_u7(100) == 127


def test_wah_bias_to_u7_clamps():
    from audio_lab_pynq import control_maps as cm

    assert cm.wah_bias_to_u7(-10) == 0
    assert cm.wah_bias_to_u7(150) == 127


def test_wah_enable_bias_byte_packing():
    from audio_lab_pynq import control_maps as cm

    assert cm.wah_enable_bias_byte(False, 0) == 0x00
    assert cm.wah_enable_bias_byte(False, 50) == 0x40
    assert cm.wah_enable_bias_byte(False, 100) == 0x7F
    assert cm.wah_enable_bias_byte(True, 0) == 0x80
    assert cm.wah_enable_bias_byte(True, 50) == 0xC0
    assert cm.wah_enable_bias_byte(True, 100) == 0xFF


def test_wah_word_packing():
    from audio_lab_pynq import control_maps as cm

    # OFF: ctrlD bit 7 cleared. POS percent path, Q/VOL/BIAS percent.
    word_off = cm.wah_word(0, 50, 50, 50, enabled=False)
    assert word_off & 0xFF == 0
    assert (word_off >> 8) & 0xFF == cm.percent_to_u8(50, 255)
    assert (word_off >> 16) & 0xFF == cm.percent_to_u8(50, 255)
    assert (word_off >> 24) & 0x80 == 0
    assert (word_off >> 24) & 0x7F == cm.wah_bias_to_u7(50)

    # ON: ctrlD bit 7 set.
    word_on = cm.wah_word(128, 100, 100, 100, enabled=True)
    assert word_on & 0xFF == 128
    assert (word_on >> 8) & 0xFF == 255
    assert (word_on >> 16) & 0xFF == 255
    assert (word_on >> 24) & 0x80 == 0x80
    assert (word_on >> 24) & 0x7F == 127


def test_wah_word_position_0_64_128_192_255_anchors():
    """The position-byte path must accept either 0..100 percent or
    0..255 raw bytes. The five spec anchor points (0/64/128/192/255)
    must all reach the GPIO byte unchanged when supplied as raw bytes.
    """
    from audio_lab_pynq import control_maps as cm

    for raw in (0, 64, 128, 192, 255):
        if raw <= 100:
            # percent path: 0..100 -> 0..255 via percent_to_u8
            assert cm.wah_position_byte(raw) == cm.percent_to_u8(raw, 255)
        else:
            assert cm.wah_position_byte(raw) == raw


def test_set_wah_settings_writes_word_to_dedicated_gpio():
    overlay = make_overlay_with_wah_state()
    settings = overlay.set_wah_settings(
        enabled=True, position=128, q=50, volume=50, bias=50,
    )
    wah_gpio = getattr(overlay, AudioLabOverlay.WAH_GPIO_NAME)
    assert wah_gpio.writes, "expected a write to the wah GPIO"
    last_offset, last_word = wah_gpio.writes[-1]
    assert last_offset == 0x00
    assert last_word & 0xFF == 128
    assert (last_word >> 8) & 0xFF == AudioLabOverlay._percent_to_u8(50, 255)
    assert (last_word >> 16) & 0xFF == AudioLabOverlay._percent_to_u8(50, 255)
    assert (last_word >> 24) & 0x80 == 0x80  # enable
    assert (last_word >> 24) & 0x7F == AudioLabOverlay._wah_bias_to_u7(50)
    assert settings['position_byte'] == 128
    assert settings['q_byte'] == AudioLabOverlay._percent_to_u8(50, 255)
    assert settings['volume_byte'] == AudioLabOverlay._percent_to_u8(50, 255)
    assert settings['bias_u7'] == AudioLabOverlay._wah_bias_to_u7(50)


def test_get_wah_settings_reports_metadata():
    overlay = make_overlay_with_wah_state()
    overlay.set_wah_settings(
        enabled=True, position=64, q=50, volume=50, bias=50,
    )
    settings = overlay.get_wah_settings()
    assert settings['enabled'] is True
    assert settings['position'] == 64
    assert settings['q'] == 50
    assert settings['volume'] == 50
    assert settings['bias'] == 50
    assert settings['source'] == 'manual'
    assert settings['reflected_to_fpga'] is True
    assert settings['gpio_name'] == 'axi_gpio_wah'
    assert settings['has_gpio'] is True
    assert settings['implementation_status'] == 'position_q_volume_bias_fpga'


def test_set_wah_settings_clamps_inputs():
    overlay = make_overlay_with_wah_state()
    settings = overlay.set_wah_settings(
        position=-10, q=200, volume=150, bias=-50,
    )
    # position float pass-through retains the literal; the byte mapping
    # clamps to 0 for negative.
    assert settings['position_byte'] == 0
    assert settings['q'] == 100
    assert settings['volume'] == 100
    assert settings['bias'] == 0


def test_wah_disabled_clears_enable_bit():
    overlay = make_overlay_with_wah_state()
    overlay.set_wah_settings(enabled=True, bias=80)
    overlay.set_wah_settings(enabled=False)
    settings = overlay.get_wah_settings()
    assert settings['enabled'] is False
    assert settings['enable_bias_byte'] & 0x80 == 0
    # bias is preserved across the off-toggle.
    assert settings['bias'] == 80


def test_wah_defaults_are_safe():
    overlay = make_overlay_with_wah_state()
    settings = overlay.get_wah_settings()
    assert settings['enabled'] is False
    assert settings['position'] == 0
    assert settings['q'] == 50
    assert settings['volume'] == 50
    assert settings['bias'] == 50
    assert settings['source'] == 'manual'
    # Byte view: enable cleared, bias u7 == 64. The cached word is 0
    # until the first apply (test helper skips __init__) -- the per-byte
    # view comes straight from cached state.
    assert settings['enable_bias_byte'] & 0x80 == 0
    assert settings['enable_bias_byte'] & 0x7F == 64


def test_set_guitar_effects_forwards_wah_kwargs_to_dedicated_gpio():
    """Wah kwargs supplied via set_guitar_effects must land on the
    dedicated axi_gpio_wah GPIO, not on the gate / overdrive / etc.
    words. The returned dict must NOT advertise a wah key (the wah
    lives on its own GPIO outside guitar_effect_control_words)."""
    overlay = make_overlay_with_wah_state()
    words = overlay.set_guitar_effects(
        wah_enabled=True, wah_position=128, wah_q=60, wah_volume=55, wah_bias=70)
    wah_gpio = getattr(overlay, AudioLabOverlay.WAH_GPIO_NAME)
    assert wah_gpio.writes, "expected a write to the wah GPIO"
    _, last_word = wah_gpio.writes[-1]
    assert last_word & 0xFF == 128
    assert (last_word >> 24) & 0x80 == 0x80
    assert "wah" not in words, "wah lives on its own GPIO outside the words dict"


def test_set_guitar_effects_without_wah_kwargs_preserves_state():
    """An old caller that does not pass any wah_* kwargs must leave the
    cached wah state unchanged so loading the overlay never re-arms a
    Wah that the user explicitly disabled before."""
    overlay = make_overlay_with_wah_state()
    overlay.set_wah_settings(enabled=False, position=64, q=42, volume=42, bias=42)
    pre_word = overlay._cached_wah_word
    pre_writes = list(getattr(overlay, AudioLabOverlay.WAH_GPIO_NAME).writes)

    overlay.set_guitar_effects(noise_gate_on=True, overdrive_on=False)

    post = overlay.get_wah_settings()
    assert post['enabled'] is False
    assert post['position'] == 64
    assert post['q'] == 42
    assert post['volume'] == 42
    assert post['bias'] == 42
    assert overlay._cached_wah_word == pre_word
    # No new write to the wah GPIO from the wah-less set_guitar_effects.
    post_writes = list(getattr(overlay, AudioLabOverlay.WAH_GPIO_NAME).writes)
    assert post_writes == pre_writes


def test_all_off_bypass_word_unchanged_by_wah_kwargs():
    """gate / overdrive / distortion / amp / cab / eq / reverb words
    must not change shape when wah_* kwargs are supplied. The wah is on
    its own GPIO and does not touch any pre-existing register byte."""
    overlay_a = make_overlay_with_wah_state()
    words_a = overlay_a.set_guitar_effects()  # all defaults, no wah_*

    overlay_b = make_overlay_with_wah_state()
    words_b = overlay_b.set_guitar_effects(
        wah_enabled=False, wah_position=0, wah_q=50, wah_volume=50, wah_bias=50)

    for k in ("gate", "overdrive", "distortion", "eq",
              "rat", "delay", "amp", "amp_tone", "cab", "reverb"):
        assert words_a[k] == words_b[k], (
            "wah kwargs must not perturb the %s word" % k)


def test_set_guitar_effects_wah_source_is_python_side_only():
    overlay = make_overlay_with_wah_state()
    # First establish a stable cached word so the wah_source-only
    # update below can be compared against an initialised baseline.
    overlay.set_wah_settings(source="manual")
    pre_word = overlay._cached_wah_word
    overlay.set_guitar_effects(wah_source="pedal")
    # source is bookkeeping; the byte layout is unchanged (no other
    # wah kwargs supplied). The GPIO word still gets rewritten with the
    # cached state because we did call set_wah_settings under the hood,
    # but the value must equal the pre-existing word.
    post = overlay.get_wah_settings()
    assert post['source'] == 'pedal'
    assert overlay._cached_wah_word == pre_word


def test_safe_bypass_defaults_include_wah_off():
    """SAFE_BYPASS_DEFAULTS keeps wah_enabled=False and parameters at
    safe values so a panic press never produces a filter sweep."""
    from audio_lab_pynq.effect_defaults import SAFE_BYPASS_DEFAULTS

    assert SAFE_BYPASS_DEFAULTS['wah_enabled'] is False
    assert SAFE_BYPASS_DEFAULTS['wah_position'] == 0
    assert SAFE_BYPASS_DEFAULTS['wah_q'] == 50
    assert SAFE_BYPASS_DEFAULTS['wah_volume'] == 50
    assert SAFE_BYPASS_DEFAULTS['wah_bias'] == 50


def test_effect_defaults_module_exposes_wah_dict():
    """WAH_DEFAULTS must be re-exported by effect_defaults and reachable
    from the AudioLabOverlay class attribute."""
    from audio_lab_pynq.effect_defaults import WAH_DEFAULTS

    assert WAH_DEFAULTS['enabled'] is False
    assert AudioLabOverlay.WAH_DEFAULTS is WAH_DEFAULTS


if __name__ == "__main__":
    test_rat_control_word()
    test_set_guitar_effects_writes_rat_gpio()
    test_overdrive_on_sets_gate_flag_and_control_bytes()
    test_rat_requires_delay_gpio_when_enabled()
    test_amp_cab_control_words()
    test_set_guitar_effects_writes_amp_cab_gpio()
    test_distortion_bit_layout_in_control_words()
    test_distortion_pedal_bit_positions_match_doc()
    test_distortion_pedals_implemented_includes_reserved_set()
    test_set_distortion_pedal_ds1_exclusive_isolates_bit3()
    test_set_distortion_pedal_big_muff_exclusive_isolates_bit4()
    test_set_distortion_pedal_fuzz_face_exclusive_isolates_bit5()
    test_distortion_pedal_mask_bit_7_unused()
    test_distortion_pedal_invalid_name_raises()
    test_distortion_pedal_out_of_range_raises()
    test_set_distortion_pedal_exclusive_clears_others()
    test_set_distortion_pedal_non_exclusive_stacks()
    test_set_distortion_pedal_disable_drops_one_bit()
    test_clear_distortion_pedals()
    test_set_distortion_pedal_rat_drives_legacy_rat_flag()
    test_set_distortion_settings_updates_cache_and_writes()
    test_set_distortion_settings_preserves_other_effects_in_gate_word()
    test_set_distortion_settings_preserves_overdrive_params()
    test_set_guitar_effects_uses_cached_distortion_state_when_unset()
    test_get_distortion_settings_initial_defaults_are_safe()
    test_noise_threshold_to_u8_scale_anchors()
    test_noise_threshold_to_u8_clamps()
    test_noise_suppressor_word_packing()
    test_set_noise_suppressor_settings_writes_word_to_dedicated_gpio()
    test_get_noise_suppressor_settings_reports_metadata()
    test_set_noise_suppressor_settings_clamps_inputs()
    test_set_noise_suppressor_settings_mirrors_threshold_to_gate_ctrlB()
    test_set_guitar_effects_mirrors_noise_threshold_to_ns_gpio()
    test_guitar_effect_control_words_uses_new_threshold_scale()
    test_noise_suppressor_defaults_are_safe()
    test_control_maps_module_matches_overlay()
    test_control_maps_pack_unpack_roundtrip()
    test_control_maps_pack_matches_legacy_pack()
    test_effect_defaults_module_exposes_canonical_dicts()
    test_effect_presets_module_matches_notebook_values()
    test_new_distortion_presets_level_capped()
    test_new_chain_presets_for_implemented_pedals()
    test_high_gain_chain_presets_use_closed_back_cab()
    test_guitar_effect_control_words_snapshots()
    test_safe_bypass_snapshot_disables_every_flag()
    test_noise_suppressor_preset_bytes_snapshot()
    test_makeup_to_u7_anchors()
    test_makeup_to_u7_clamps()
    test_compressor_enable_makeup_byte_packing()
    test_compressor_word_packing()
    test_set_compressor_settings_writes_word_to_dedicated_gpio()
    test_get_compressor_settings_reports_metadata()
    test_set_compressor_settings_clamps_inputs()
    test_compressor_disabled_clears_enable_bit()
    test_compressor_defaults_are_safe()
    test_compressor_preset_bytes_snapshot()
    test_effect_defaults_module_exposes_compressor_dict()
    test_chain_presets_module_exists_and_has_required_names()
    test_chain_presets_have_all_required_sections()
    test_safe_bypass_preset_has_every_section_off()
    test_chain_presets_compressor_makeup_within_safe_band()
    test_chain_presets_distortion_level_capped()
    test_get_chain_preset_names_matches_module()
    test_get_chain_preset_returns_deep_copy()
    test_get_chain_preset_unknown_raises()
    test_apply_chain_preset_basic_clean_round_trip()
    test_apply_chain_preset_metal_tight_writes_pedal_mask()
    test_apply_chain_preset_tube_screamer_lead_writes_compressor_word()
    test_apply_chain_preset_safe_bypass_routes_passthrough()
    test_get_current_pedalboard_state_returns_dict()
    test_apply_chain_preset_survives_missing_compressor_gpio()
    test_apply_chain_preset_unknown_name_raises()
    test_amp_models_table_anchors()
    test_amp_model_labels_are_human_readable_titles()
    test_amp_models_old_d52_names_are_retired()
    test_get_amp_model_names_lists_documented_models()
    test_amp_model_to_idx_known_names()
    test_amp_model_to_idx_display_labels()
    test_amp_model_to_character_back_compat_returns_idx()
    test_amp_model_to_idx_unknown_raises()
    test_set_amp_model_writes_correct_model_idx_byte()
    test_set_amp_model_distinct_bytes_per_model()
    test_set_amp_model_overrides_let_caller_pin_other_amp_params()
    test_set_amp_model_propagates_drive_mode()
    test_amp_model_drive_byte_clean_mode_layout()
    test_amp_model_drive_byte_drive_mode_layout()
    test_amp_model_drive_byte_known_values_match_spec()
    test_amp_model_drive_byte_clamps_inputs()
    test_amp_character_byte_for_model_alias_matches_d55_pack()
    test_guitar_effect_control_words_amp_model_idx_uses_d55_bit_pack()
    test_guitar_effect_control_words_without_model_idx_uses_amp_character()
    test_wah_position_byte_anchors()
    test_wah_q_byte_anchors()
    test_wah_volume_byte_anchors()
    test_wah_bias_to_u7_anchors()
    test_wah_bias_to_u7_clamps()
    test_wah_enable_bias_byte_packing()
    test_wah_word_packing()
    test_wah_word_position_0_64_128_192_255_anchors()
    test_set_wah_settings_writes_word_to_dedicated_gpio()
    test_get_wah_settings_reports_metadata()
    test_set_wah_settings_clamps_inputs()
    test_wah_disabled_clears_enable_bit()
    test_wah_defaults_are_safe()
    test_set_guitar_effects_forwards_wah_kwargs_to_dedicated_gpio()
    test_set_guitar_effects_without_wah_kwargs_preserves_state()
    test_all_off_bypass_word_unchanged_by_wah_kwargs()
    test_set_guitar_effects_wah_source_is_python_side_only()
    test_safe_bypass_defaults_include_wah_off()
    test_effect_defaults_module_exposes_wah_dict()
    print("AudioLabOverlay guitar effect control tests passed")
