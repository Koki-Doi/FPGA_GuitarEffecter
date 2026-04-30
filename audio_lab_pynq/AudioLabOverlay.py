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
    def _write_gpio(gpio, word):
        gpio.write(0x04, 0x00000000)
        gpio.write(0x00, int(word) & 0xFFFFFFFF)

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
        flags |= 0x20 if reverb_on else 0

        gate_word = (
            flags |
            (cls._percent_to_u8(noise_gate_threshold, 255) << 8)
        )
        overdrive_word = cls._pack3(
            cls._percent_to_u8(overdrive_tone, 255),
            cls._level_to_q7(overdrive_level),
            cls._percent_to_u8(overdrive_drive, 255),
        )
        distortion_word = cls._pack3(
            cls._percent_to_u8(distortion_tone, 255),
            cls._level_to_q7(distortion_level),
            cls._percent_to_u8(distortion, 255),
        )
        eq_word = cls._pack3(
            cls._level_to_q7(eq_low),
            cls._level_to_q7(eq_mid),
            cls._level_to_q7(eq_high),
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
            'delay': 0,
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

        words = self.guitar_effect_control_words(**kwargs)
        self._write_gpio(self.axi_gpio_gate, words['gate'])
        self._write_gpio(self.axi_gpio_overdrive, words['overdrive'])
        self._write_gpio(self.axi_gpio_distortion, words['distortion'])
        self._write_gpio(self.axi_gpio_eq, words['eq'])
        if hasattr(self, 'axi_gpio_delay'):
            self._write_gpio(self.axi_gpio_delay, 0)
        self._write_gpio(self.axi_gpio_reverb, words['reverb'])

        if words['gate'] & 0x2F:
            self.route(XbarSource.line_in, XbarEffect.guitar_chain, sink)
        else:
            self.route(XbarSource.line_in, XbarEffect.passthrough, sink)
        return words

    def set_reverb(self, enabled=True, reverb=35, tone=70, mix=25, sink=XbarSink.headphone):
        if hasattr(self, 'axi_gpio_gate'):
            return self.set_guitar_effects(
                noise_gate_on=False,
                overdrive_on=False,
                distortion_on=False,
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
