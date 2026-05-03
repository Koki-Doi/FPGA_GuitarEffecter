#!/usr/bin/env python3
"""Phase 1 audio input diagnostics for Audio-Lab-PYNQ.

Run on the PYNQ-Z2 (the bitstream/overlay must be loadable):

    sudo python3 scripts/audio_diagnostics.py \\
        --output-dir /home/xilinx/audio_diag \\
        --capture-shorted --capture-silence --capture-guitar \\
        --zero-test --sine-test

Or import and drive from a Jupyter notebook:

    from audio_lab_pynq.AudioLabOverlay import AudioLabOverlay
    from audio_lab_pynq import diagnostics

    ovl = AudioLabOverlay()
    ovl.dump_codec_registers()
    samples, stats = ovl.diagnostic_capture('shorted')
    ovl.output_zero_test()
    ovl.output_sine_test()
    diagnostics.print_decision_table()
"""
import argparse
import os
import sys


def main(argv=None):
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--output-dir', default='./audio_diag')
    parser.add_argument('--num-frames', type=int, default=48000,
                        help='samples per capture (default 48000 = 1 s @ 48 kHz)')
    parser.add_argument('--sample-rate', type=int, default=48000)
    parser.add_argument('--capture-shorted', action='store_true',
                        help='capture with the input jack shorted/disconnected')
    parser.add_argument('--capture-silence', action='store_true',
                        help='capture with a known silent source connected')
    parser.add_argument('--capture-guitar', action='store_true',
                        help='capture with the guitar connected (do not play)')
    parser.add_argument('--zero-test', action='store_true',
                        help='play 2 s of digital silence on DMA -> headphones')
    parser.add_argument('--sine-test', action='store_true',
                        help='play 2 s of -18 dBFS 1 kHz sine -> headphones')
    parser.add_argument('--sine-freq', type=float, default=1000.0)
    parser.add_argument('--sine-dbfs', type=float, default=-18.0)
    parser.add_argument('--enable-adc-hpf', action='store_true',
                        help='enable ADAU1761 ADC HPF (~2 Hz DC blocker)')
    parser.add_argument('--disable-adc-hpf', action='store_true')
    parser.add_argument('--show-registers', action='store_true', default=True)
    parser.add_argument('--no-show-registers', dest='show_registers',
                        action='store_false')
    parser.add_argument('--no-prompt', action='store_true',
                        help='do not pause before each capture')
    args = parser.parse_args(argv)

    from audio_lab_pynq.AudioLabOverlay import AudioLabOverlay
    from audio_lab_pynq import diagnostics

    ovl = AudioLabOverlay()

    if args.show_registers:
        print('=== ADAU1761 register snapshot ===')
        ovl.dump_codec_registers()
        print('ADC HPF (R19[5]) currently:',
              'ON' if ovl.codec.get_adc_hpf_state() else 'OFF')
        print('Input digital volume (R20, R21):',
              ovl.codec.get_input_digital_volume())

    if args.enable_adc_hpf:
        before = ovl.codec.dump_registers(['R19_ADC_CONTROL'])
        ovl.codec.enable_adc_hpf()
        print('=== ADC HPF enable diff ===')
        ovl.codec_register_diff(before, ['R19_ADC_CONTROL'])
    if args.disable_adc_hpf:
        before = ovl.codec.dump_registers(['R19_ADC_CONTROL'])
        ovl.codec.disable_adc_hpf()
        print('=== ADC HPF disable diff ===')
        ovl.codec_register_diff(before, ['R19_ADC_CONTROL'])

    os.makedirs(args.output_dir, exist_ok=True)

    def _capture(label, prompt):
        if not args.no_prompt:
            try:
                input('>> {} -- press Enter to capture...'.format(prompt))
            except EOFError:
                pass
        ovl.diagnostic_capture(label,
                               num_frames=args.num_frames,
                               save_dir=args.output_dir)

    if args.capture_shorted:
        _capture('shorted', 'short or disconnect the input jack')
    if args.capture_silence:
        _capture('silence_source', 'connect a known-silent source (powered off)')
    if args.capture_guitar:
        _capture('guitar', 'connect the guitar, do not play')

    if args.zero_test:
        print('Playing 2 s of digital silence on DMA -> headphones...')
        ovl.output_zero_test()
    if args.sine_test:
        print('Playing 2 s of {:.0f} Hz sine at {:.1f} dBFS -> headphones...'
              .format(args.sine_freq, args.sine_dbfs))
        ovl.output_sine_test(freq_hz=args.sine_freq,
                             amplitude_dbfs=args.sine_dbfs)

    diagnostics.print_decision_table()


if __name__ == '__main__':
    sys.exit(main() or 0)
