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
    print("AudioLabOverlay guitar effect control tests passed")
