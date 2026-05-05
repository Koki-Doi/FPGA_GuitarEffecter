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
    # overdrive ctrlA-C preserved; ctrlD is tight.
    assert (words["overdrive"] >> 24) & 0xFF == tight_byte
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
    assert (last_od[1] >> 24) & 0xFF == AudioLabOverlay._percent_to_u8(70, 255)
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
    # ctrlA/B/C preserved, only ctrlD (tight) changed.
    assert od_after & 0x00FFFFFF == od_before & 0x00FFFFFF
    assert (od_after >> 24) & 0xFF == AudioLabOverlay._percent_to_u8(10, 255)


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
    assert (last_od >> 24) & 0xFF == AudioLabOverlay._percent_to_u8(85, 255)
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
        "gate": 0xff800204, "overdrive": 0x994c80a6, "distortion": 0x02732d8c,
        "eq": 0x00808080, "rat": 0xff8c8059, "amp": 0x59736659,
        "amp_tone": 0x59808080, "cab": 0x805580ff, "reverb": 0x0026a642,
    },
    "rat_distortion": {
        "gate": 0xff800214, "overdrive": 0x804c80a6, "distortion": 0x048c2d73,
        "eq": 0x00808080, "rat": 0xff8c8059, "amp": 0x59736659,
        "amp_tone": 0x59808080, "cab": 0x805580ff, "reverb": 0x0026a642,
    },
    "metal_tight": {
        "gate": 0xff800204, "overdrive": 0xbf4c80a6, "distortion": 0x408c268c,
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


if __name__ == "__main__":
    test_rat_control_word()
    test_set_guitar_effects_writes_rat_gpio()
    test_rat_requires_delay_gpio_when_enabled()
    test_amp_cab_control_words()
    test_set_guitar_effects_writes_amp_cab_gpio()
    test_distortion_bit_layout_in_control_words()
    test_distortion_pedal_bit_positions_match_doc()
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
    print("AudioLabOverlay guitar effect control tests passed")
