"""Phase 1 diagnostic helpers for Audio-Lab-PYNQ.

These helpers triage input noise *before* any FPGA fabric change.
They use the existing block design only — no bitstream rebuild required.

Capabilities:
  * dump_codec_registers / diff (delegated to ADAU1761)
  * enable_adc_hpf / disable_adc_hpf (delegated to ADAU1761)
  * set_input_digital_volume (delegated to ADAU1761)
  * capture_input  -- record line-in via the existing S2MM DMA path
  * compute_input_stats -- mean / RMS / peak / min / max / peak_dBFS
  * save_input_capture  -- .npy and .csv
  * output_zero_test, output_sine_test -- emit silence or a clean sine
    on the existing MM2S DMA path

Stream layout (from the current Vivado block design):
  i2s_to_stream_0 emits 48-bit AXIS:
      bits[47:24] = right channel, signed 24-bit two's complement
      bits[23:0]  = left  channel, signed 24-bit two's complement
  axis_subset_converter_1 sign-extends each channel to 32 bits and packs
  them into a 64-bit DMA word:
      DMA word bits[63:32] = right, sign-extended int32
      DMA word bits[31:0]  = left,  sign-extended int32
  Read back as numpy.int32 with shape (frames, 2):
      column 0 = left, column 1 = right.
The MM2S path applies the inverse mapping, so writing the same shape sends
audio out.

Decision table -- see DECISION_TABLE.
"""
import os
import time

import numpy as np


FULL_SCALE_24 = (1 << 23) - 1
DEFAULT_SAMPLE_RATE_HZ = 48000


def _require_overlay_dma(overlay):
    if not hasattr(overlay, 'axi_dma_0'):
        raise RuntimeError('axi_dma_0 not present in this overlay; '
                           'capture/playback diagnostics need it.')


def _allocate(shape, dtype):
    from pynq import allocate
    return allocate(shape=shape, dtype=dtype)


def capture_input(overlay, num_frames=DEFAULT_SAMPLE_RATE_HZ,
                  source=None, restore_route=True, settling_ms=0,
                  discard_initial_frames=0):
    """Capture stereo line-in samples via the existing S2MM DMA path.

    Returns numpy.ndarray of shape (num_frames, 2), dtype int32.
    Column 0 = left, column 1 = right. Each value is a 24-bit signed
    sample, sign-extended to int32.

    settling_ms: sleep this long after switching the route and before the
        DMA transfer starts. Use a few hundred ms after toggling the ADC
        HPF (R19[5]) so the IIR has time to settle from the DC step.
    discard_initial_frames: drop this many frames from the start of the
        buffer after capture, to avoid the HPF transient. The returned
        array has shape (num_frames - discard_initial_frames, 2).
    """
    _require_overlay_dma(overlay)
    from .AudioLabOverlay import XbarSource, XbarEffect, XbarSink

    if source is None:
        source = XbarSource.line_in

    overlay.route(source, XbarEffect.passthrough, XbarSink.dma)
    if settling_ms > 0:
        time.sleep(settling_ms / 1000.0)

    buf = _allocate(shape=(num_frames, 2), dtype=np.int32)
    try:
        overlay.axi_dma_0.recvchannel.transfer(buf)
        overlay.axi_dma_0.recvchannel.wait()
        samples = np.array(buf)
    finally:
        buf.freebuffer()
        if restore_route:
            overlay.route(source, XbarEffect.passthrough, XbarSink.headphone)
    if discard_initial_frames > 0:
        samples = samples[discard_initial_frames:]
    return samples


def compute_input_stats(samples, full_scale=FULL_SCALE_24):
    if samples.ndim != 2 or samples.shape[1] != 2:
        raise ValueError('samples must have shape (N, 2)')
    stats = {}
    for i, ch in enumerate(('left', 'right')):
        x = samples[:, i].astype(np.float64)
        peak_abs = float(np.max(np.abs(x))) if x.size else 0.0
        if peak_abs > 0:
            peak_dbfs = 20.0 * np.log10(peak_abs / full_scale)
        else:
            peak_dbfs = float('-inf')
        stats[ch] = {
            'mean':      float(np.mean(x)) if x.size else 0.0,
            'rms':       float(np.sqrt(np.mean(x * x))) if x.size else 0.0,
            'peak_abs':  peak_abs,
            'min':       int(np.min(samples[:, i])) if samples.size else 0,
            'max':       int(np.max(samples[:, i])) if samples.size else 0,
            'peak_dBFS': peak_dbfs,
        }
    return stats


def format_input_stats(stats):
    header = '{:<8} {:>14} {:>14} {:>14} {:>14} {:>14} {:>12}'.format(
        'channel', 'mean', 'rms', 'peak_abs', 'min', 'max', 'peak_dBFS')
    rows = [header]
    for ch in ('left', 'right'):
        s = stats[ch]
        peak_dbfs = s['peak_dBFS']
        peak_str = '-inf' if peak_dbfs == float('-inf') else '{:.2f}'.format(peak_dbfs)
        rows.append('{:<8} {:>14.1f} {:>14.1f} {:>14.1f} {:>14d} {:>14d} {:>12}'.format(
            ch, s['mean'], s['rms'], s['peak_abs'], s['min'], s['max'], peak_str))
    return '\n'.join(rows)


def save_input_capture(samples, prefix, save_csv=True):
    npy_path = prefix + '.npy'
    np.save(npy_path, samples)
    paths = [npy_path]
    if save_csv:
        csv_path = prefix + '.csv'
        np.savetxt(csv_path, samples, fmt='%d', delimiter=',',
                   header='left,right', comments='')
        paths.append(csv_path)
    return paths


def _silence(num_frames):
    return np.zeros((num_frames, 2), dtype=np.int32)


def _sine(num_frames, sample_rate_hz, freq_hz, amplitude_dbfs,
          full_scale=FULL_SCALE_24):
    if amplitude_dbfs > 0:
        raise ValueError('amplitude_dbfs must be <= 0 to avoid clipping')
    amp = full_scale * (10.0 ** (amplitude_dbfs / 20.0))
    n = np.arange(num_frames, dtype=np.float64)
    tone = amp * np.sin(2.0 * np.pi * freq_hz * n / sample_rate_hz)
    out = np.empty((num_frames, 2), dtype=np.int32)
    out[:, 0] = tone.astype(np.int32)
    out[:, 1] = tone.astype(np.int32)
    return out


def _play(overlay, frames, restore_route=True):
    _require_overlay_dma(overlay)
    from .AudioLabOverlay import XbarSource, XbarEffect, XbarSink

    overlay.route(XbarSource.dma, XbarEffect.passthrough, XbarSink.headphone)
    buf = _allocate(shape=frames.shape, dtype=np.int32)
    try:
        buf[:] = frames
        overlay.axi_dma_0.sendchannel.transfer(buf)
        overlay.axi_dma_0.sendchannel.wait()
    finally:
        buf.freebuffer()
        if restore_route:
            overlay.route(XbarSource.line_in, XbarEffect.passthrough,
                          XbarSink.headphone)


def output_zero_test(overlay, duration_s=2.0,
                     sample_rate_hz=DEFAULT_SAMPLE_RATE_HZ,
                     restore_route=True):
    """Send pure digital silence on the MM2S DMA path.

    If you still hear hum or hiss in the headphones during this test, the
    noise is downstream of the FPGA fabric: codec DAC, headphone amp,
    output volumes (R29/R30/R31/R32), R35 power, ground or supply.
    """
    n = int(duration_s * sample_rate_hz)
    _play(overlay, _silence(n), restore_route=restore_route)


def output_sine_test(overlay, freq_hz=1000.0, duration_s=2.0,
                     amplitude_dbfs=-18.0,
                     sample_rate_hz=DEFAULT_SAMPLE_RATE_HZ,
                     restore_route=True):
    """Send a 1 kHz, -18 dBFS sine on the MM2S DMA path.

    If this is clean and the zero test was clean, the entire output stage
    is fine and any residual noise must be on the input side.
    """
    n = int(duration_s * sample_rate_hz)
    frames = _sine(n, sample_rate_hz, freq_hz, amplitude_dbfs)
    _play(overlay, frames, restore_route=restore_route)


DECISION_TABLE = """\
Symptom                                Likely cause(s)
-------------------------------------- ----------------------------------------
zero-output test still noisy           output side: codec DAC, headphone amp,
                                       GND / supply, R29-R32 (HP/LO volume),
                                       R35 (playback power management).
                                       Input is *not* the issue.
sine-output test noisy                 same area as zero-output. If sine is
                                       clean but zero is not, suspect ground
                                       loop / supply-coupled hum.
both output tests clean,               input side. Continue with raw input
input still noisy                      capture and the rows below.
input mean(L|R) far from 0             ADC DC offset. enable_adc_hpf().
                                       If still drifting, check AUX coupling
                                       (R4-R7) and external bias on the jack.
input RMS large with input SHORTED     codec self-noise / wrong PGA path.
                                       Re-check R4-R7 (AUX 0 dB), R10 (mic
                                       bias must be off for AUX), R58/R59
                                       (serial routing).
input min/max stuck at +/- full scale  clipping at the codec ADC. Attenuate
                                       via set_input_digital_volume() or add
                                       an external pad. Check guitar level
                                       and active-pickup batteries.
one channel only is bad                R5/R7 mismatch, R20/R21 mismatch, jack
                                       contact, or R58 routing error.
shorted input quiet, guitar very loud  cable / pickups / instrument. NOT a
                                       board issue. No conditioning will help
                                       until the source level is sane.
"""


def print_decision_table():
    print(DECISION_TABLE)
