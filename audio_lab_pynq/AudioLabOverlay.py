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

    def set_reverb(self, enabled=True, reverb=35, tone=70, mix=25, sink=XbarSink.headphone):
        word = self.reverb_control_word(enabled, reverb, tone, mix)

        if hasattr(self, 'axi_gpio_reverb'):
            self.axi_gpio_reverb.write(0x04, 0x00000000)
            self.axi_gpio_reverb.write(0x00, word)
        elif enabled:
            raise RuntimeError('axi_gpio_reverb is not available in this overlay')

        effect = XbarEffect.reverb if enabled else XbarEffect.passthrough
        self.route(XbarSource.line_in, effect, sink)
        return word
