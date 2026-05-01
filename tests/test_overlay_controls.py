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


if __name__ == "__main__":
    test_rat_control_word()
    test_set_guitar_effects_writes_rat_gpio()
    test_rat_requires_delay_gpio_when_enabled()
    print("AudioLabOverlay RAT control tests passed")
