import collections
import ctypes
import pylibi2c
import time

class ADAU1761():

    R19_HPF_BIT = 5

    DIAGNOSTIC_REGISTERS = (
        'R0_CLOCK_CONTROL',
        'R1_PLL_CONTROL',
        'R4_RECORD_MIXER_LEFT_CONTROL_0',
        'R5_RECORD_MIXER_LEFT_CONTROL_1',
        'R6_RECORD_MIXER_RIGHT_CONTROL_0',
        'R7_RECORD_MIXER_RIGHT_CONTROL_1',
        'R15_SERIAL_PORT_CONTROL_0',
        'R17_CONVERTER_CONTROL_0',
        'R18_CONVERTER_CONTROL_1',
        'R19_ADC_CONTROL',
        'R20_LEFT_INPUT_DIGITAL_VOLUME',
        'R21_RIGHT_INPUT_DIGITAL_VOLUME',
        'R22_PLAYBACK_MIXER_LEFT_CONTROL_0',
        'R24_PLAYBACK_MIXER_RIGHT_CONTROL_0',
        'R26_PLAYBACK_LR_MIXER_LEFT_LINE_OUTPUT_CONTROL',
        'R27_PLAYBACK_LR_MIXER_RIGHT_LINE_OUTPUT_CONTROL',
        'R29_PLAYBACK_HEADPHONE_LEFT_VOLUME_CONTROL',
        'R30_PLAYBACK_HEADPHONE_RIGHT_VOLUME_CONTROL',
        'R31_PLAYBACK_LINE_OUTPUT_LEFT_VOLUME_CONTROL',
        'R32_PLAYBACK_LINE_OUTPUT_RIGHT_VOLUME_CONTROL',
        'R35_PLAYBACK_POWER_MANAGEMENT',
        'R36_DAC_CONTROL_0',
        'R58_SERIAL_INPUT_ROUTE_CONTROL',
        'R59_SERIAL_OUTPUT_ROUTE_CONTROL',
        'R61_DSP_ENABLE',
        'R62_DSP_RUN',
        'R65_CLOCK_ENABLE_0',
        'R66_CLOCK_ENABLE_1',
    )

    def __init__(self, i2c_chan = 1, i2c_base_addr = 0x3B):
        self.i2c_chan = i2c_chan
        self.i2c_base_addr = i2c_base_addr
        
        self.i2c_bus = pylibi2c.I2CDevice(
            '/dev/i2c-'+str(self.i2c_chan),
            self.i2c_base_addr,
            iaddr_bytes=2
        )
        
    def _i2c_read(self, offset, length=1):
        return self.i2c_bus.ioctl_read(0x4000 + offset, length)

    def _i2c_write(self, offset, data):
        if not isinstance(data,list):
            data = [data]
        self.i2c_bus.ioctl_write(
            0x4000 + offset,
            bytes(data)
        )
    
    def config_pll(self):
        
        # Careful! PYNQ on boot might load the base overlay which sets different PLL settings for a 10 MHz MCLK (we have 24 MHz). The ADAU1761 datasheet says we'll first need to disable the PLL before updating settings.
        self.R1_PLL_CONTROL   = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        
        # Now continue as per hamster's orginal config 
        self.R0_CLOCK_CONTROL = 0x0E
        self.R1_PLL_CONTROL   = [0x00, 0x7D, 0x00, 0x0C, 0x23, 0x01]
        
        while self.R1_PLL_CONTROL[5] & 0x02 == 0:
            print("Waiting for PLL lock")
            time.sleep(0.004)
                
        self.R0_CLOCK_CONTROL = 0x0F
    
    def config_codec(self):

        # Become I2S master
        self.R15_SERIAL_PORT_CONTROL_0 = 0x01

        # Input mixers...
        ## Enable AUX
        self.R4_RECORD_MIXER_LEFT_CONTROL_0 = 0x01
        self.R6_RECORD_MIXER_RIGHT_CONTROL_0 = 0x01
        ## Set AUX to 0 dB
        self.R5_RECORD_MIXER_LEFT_CONTROL_1 = 0x05
        self.R7_RECORD_MIXER_RIGHT_CONTROL_1 = 0x05

        # Output mixers
        ## Enable playback
        self.R22_PLAYBACK_MIXER_LEFT_CONTROL_0 = 0x21
        self.R24_PLAYBACK_MIXER_RIGHT_CONTROL_0 = 0x41
        ## Route playback mixers to LOUT/ROUT. On PYNQ-Z2 the audible jack uses
        ## this output path.
        self.R26_PLAYBACK_LR_MIXER_LEFT_LINE_OUTPUT_CONTROL = 0x03
        self.R27_PLAYBACK_LR_MIXER_RIGHT_LINE_OUTPUT_CONTROL = 0x09
        ## Set output volume
        self.R29_PLAYBACK_HEADPHONE_LEFT_VOLUME_CONTROL = 0xE7
        self.R30_PLAYBACK_HEADPHONE_RIGHT_VOLUME_CONTROL = 0xE7
        self.R31_PLAYBACK_LINE_OUTPUT_LEFT_VOLUME_CONTROL = 0xE7
        self.R32_PLAYBACK_LINE_OUTPUT_RIGHT_VOLUME_CONTROL = 0xE7

        # Enable ADC (left+right). R19[1:0] = 11.
        self.R19_ADC_CONTROL = 0x03
        # Enable the ADC digital high-pass filter (R19[5]) on top of the
        # ADC enable bits, via read-modify-write so the enable bits are
        # preserved. After this, R19_ADC_CONTROL == 0x23.
        #
        # Notes on R19[5]:
        #   - R19[5] is the ADAU1761 ADC digital HPF.
        #   - It is a DC blocker around 2 Hz at Fs = 48 kHz.
        #   - It is *not* a 20-40 Hz guitar low-cut filter.
        self.enable_adc_hpf()
        # The HPF is a 1st-order IIR; its time constant at Fs=48kHz is
        # roughly 80 ms, so allow ~300 ms (~3-4 tau) for the output to
        # settle to its DC-removed steady state before any capture.
        time.sleep(0.3)
        # Enable DAC
        self.R36_DAC_CONTROL_0 = 0x03
        # Enable headphone jack
        self.R35_PLAYBACK_POWER_MANAGEMENT = 0x03

        # Signal routing
        self.R58_SERIAL_INPUT_ROUTE_CONTROL = 0x01
        self.R59_SERIAL_OUTPUT_ROUTE_CONTROL = 0x01

        # Power up!
        self.R65_CLOCK_ENABLE_0 = 0x7F
        self.R66_CLOCK_ENABLE_1 = 0x03

        # Enable DSP and DSP Run
        self.R61_DSP_ENABLE = 0x01
        self.R62_DSP_RUN = 0x01

    # ---- Phase 1 diagnostic helpers --------------------------------------

    def dump_registers(self, names=None):
        """Read selected registers and return an OrderedDict of name->bytes.

        Use this before and after a configuration change to compute a diff
        with diff_register_snapshots().
        """
        if names is None:
            names = self.DIAGNOSTIC_REGISTERS
        snapshot = collections.OrderedDict()
        for name in names:
            value = getattr(self, name)
            snapshot[name] = bytes(value) if not isinstance(value, bytes) else value
        return snapshot

    @staticmethod
    def format_register_snapshot(snapshot):
        lines = []
        for name, value in snapshot.items():
            hex_str = ' '.join('{:02X}'.format(b) for b in value)
            if len(value) == 1:
                lines.append('{:<55} 0x{}  (0b{:08b})'.format(name, hex_str, value[0]))
            else:
                lines.append('{:<55} {}'.format(name, hex_str))
        return '\n'.join(lines)

    def print_registers(self, names=None):
        snapshot = self.dump_registers(names)
        print(self.format_register_snapshot(snapshot))
        return snapshot

    @staticmethod
    def diff_register_snapshots(before, after):
        keys = list(before.keys())
        for k in after.keys():
            if k not in keys:
                keys.append(k)
        diffs = collections.OrderedDict()
        for name in keys:
            b = before.get(name)
            a = after.get(name)
            if b != a:
                diffs[name] = (b, a)
        return diffs

    @staticmethod
    def format_register_diff(diffs):
        if not diffs:
            return '(no changes)'
        lines = []
        for name, (before, after) in diffs.items():
            b_hex = ' '.join('{:02X}'.format(x) for x in (before or b''))
            a_hex = ' '.join('{:02X}'.format(x) for x in (after or b''))
            lines.append('{:<55} {} -> {}'.format(name, b_hex, a_hex))
        return '\n'.join(lines)

    # ---- ADC digital high-pass filter (R19[5]) ---------------------------
    # NOTE: This is the ADAU1761 ADC digital high-pass filter, used to
    # remove DC offset and very-low-frequency drift. At Fs = 48 kHz the
    # corner is roughly 2 Hz. It is *not* a 20-40 Hz HPF and must not be
    # treated as a substitute for a guitar-band low-cut.

    def get_adc_hpf_state(self):
        return bool(self.R19_ADC_CONTROL[0] & (1 << self.R19_HPF_BIT))

    def enable_adc_hpf(self):
        current = self.R19_ADC_CONTROL[0]
        new_value = (current | (1 << self.R19_HPF_BIT)) & 0xFF
        self.R19_ADC_CONTROL = new_value
        return new_value

    def disable_adc_hpf(self):
        current = self.R19_ADC_CONTROL[0]
        new_value = current & ~(1 << self.R19_HPF_BIT) & 0xFF
        self.R19_ADC_CONTROL = new_value
        return new_value

    # ---- Input digital volume (R20 / R21) --------------------------------
    # On ADAU1761 these registers attenuate the ADC digital signal.
    # 0x00 is the codec default (no attenuation). Larger raw values apply
    # progressively more attenuation. This helper only writes raw byte
    # values; it never bypasses or boosts above the 0x00 default.

    @staticmethod
    def _clamp_byte(value, lo=0, hi=255):
        v = int(value)
        if v < lo:
            return lo
        if v > hi:
            return hi
        return v

    def get_input_digital_volume(self):
        left = self.R20_LEFT_INPUT_DIGITAL_VOLUME[0]
        right = self.R21_RIGHT_INPUT_DIGITAL_VOLUME[0]
        return (left, right)

    def set_input_digital_volume(self, left=None, right=None):
        if left is not None:
            self.R20_LEFT_INPUT_DIGITAL_VOLUME = self._clamp_byte(left)
        if right is not None:
            self.R21_RIGHT_INPUT_DIGITAL_VOLUME = self._clamp_byte(right)
        return self.get_input_digital_volume()


def _create_i2c_property(name, offset, length):
    def _get(self):
        return self._i2c_read(offset, length)
    def _set(self, value):
        self._i2c_write(offset, value)
    return property(_get, _set)

_codec_regs = [
           ("R0_CLOCK_CONTROL"                                , 1, 0x00),
           ("R1_PLL_CONTROL"                                  , 6, 0x02),
           ("R2_DIGITAL_MIC_JACK_DETECTION_CONTROL"           , 1, 0x08),
           ("R3_RECORD_POWER_MANAGEMENT"                      , 1, 0x09),
           ("R4_RECORD_MIXER_LEFT_CONTROL_0"                  , 1, 0x0A),
           ("R5_RECORD_MIXER_LEFT_CONTROL_1"                  , 1, 0x0B),
           ("R6_RECORD_MIXER_RIGHT_CONTROL_0"                 , 1, 0x0C),
           ("R7_RECORD_MIXER_RIGHT_CONTROL_1"                 , 1, 0x0D),
           ("R8_LEFT_DIFFERENTIAL_INPUT_VOLUME_CONTROL"       , 1, 0x0E),
           ("R9_RIGHT_DIFFERENTIAL_INPUT_VOLUME_CONTROL"      , 1, 0x0F),
           ("R10_RECORD_MICROPHONE_BIAS_CONTROL"              , 1, 0x10),
           ("R11_ALC_CONTROL_0"                               , 1, 0x11),
           ("R12_ALC_CONTROL_1"                               , 1, 0x12),
           ("R13_ALC_CONTROL_2"                               , 1, 0x13),
           ("R14_ALC_CONTROL_3"                               , 1, 0x14),
           ("R15_SERIAL_PORT_CONTROL_0"                       , 1, 0x15),
           ("R16_SERIAL_PORT_CONTROL_1"                       , 1, 0x16),
           ("R17_CONVERTER_CONTROL_0"                         , 1, 0x17),
           ("R18_CONVERTER_CONTROL_1"                         , 1, 0x18),
           ("R19_ADC_CONTROL"                                 , 1, 0x19),
           ("R20_LEFT_INPUT_DIGITAL_VOLUME"                   , 1, 0x1A),
           ("R21_RIGHT_INPUT_DIGITAL_VOLUME"                  , 1, 0x1B),
           ("R22_PLAYBACK_MIXER_LEFT_CONTROL_0"               , 1, 0x1C),
           ("R23_PLAYBACK_MIXER_LEFT_CONTROL_1"               , 1, 0x1D),
           ("R24_PLAYBACK_MIXER_RIGHT_CONTROL_0"              , 1, 0x1E),
           ("R25_PLAYBACK_MIXER_RIGHT_CONTROL_1"              , 1, 0x1F),
           ("R26_PLAYBACK_LR_MIXER_LEFT_LINE_OUTPUT_CONTROL"  , 1, 0x20),
           ("R27_PLAYBACK_LR_MIXER_RIGHT_LINE_OUTPUT_CONTROL" , 1, 0x21),
           ("R28_PLAYBACK_LR_MIXER_MONO_OUTPUT_CONTROL"       , 1, 0x22),
           ("R29_PLAYBACK_HEADPHONE_LEFT_VOLUME_CONTROL"      , 1, 0x23),
           ("R30_PLAYBACK_HEADPHONE_RIGHT_VOLUME_CONTROL"     , 1, 0x24),
           ("R31_PLAYBACK_LINE_OUTPUT_LEFT_VOLUME_CONTROL"    , 1, 0x25),
           ("R32_PLAYBACK_LINE_OUTPUT_RIGHT_VOLUME_CONTROL"   , 1, 0x26),
           ("R33_PLAYBACK_MONO_OUTPUT_CONTROL"                , 1, 0x27),
           ("R34_PLAYBACK_POP_CLICK_SUPPRESSION"              , 1, 0x28),
           ("R35_PLAYBACK_POWER_MANAGEMENT"                   , 1, 0x29),
           ("R36_DAC_CONTROL_0"                               , 1, 0x2A),
           ("R37_DAC_CONTROL_1"                               , 1, 0x2B),
           ("R38_DAC_CONTROL_2"                               , 1, 0x2C),
           ("R39_SERIAL_PORT_PAD_CONTROL"                     , 1, 0x2D),
           ("R40_CONTROL_PORT_PAD_CONTROL_0"                  , 1, 0x2F),
           ("R41_CONTROL_PORT_PAD_CONTROL_1"                  , 1, 0x30),
           ("R42_JACK_DETECT_PIN_CONTROL"                     , 1, 0x31),
           ("R67_DEJITTER_CONTROL"                            , 1, 0x36),
           ("R58_SERIAL_INPUT_ROUTE_CONTROL"                  , 1, 0xF2),
           ("R59_SERIAL_OUTPUT_ROUTE_CONTROL"                 , 1, 0xF3),
           ("R61_DSP_ENABLE"                                  , 1, 0xF5),
           ("R62_DSP_RUN"                                     , 1, 0xF6),
           ("R63_DSP_SLEW_MODES"                              , 1, 0xF7),
           ("R64_SERIAL_PORT_SAMPLING_RATE"                   , 1, 0xF8),
           ("R65_CLOCK_ENABLE_0"                              , 1, 0xF9),
           ("R66_CLOCK_ENABLE_1"                              , 1, 0xFA)
]

for (name, length, offset) in _codec_regs:
    setattr(ADAU1761, name, _create_i2c_property(name, offset, length))
