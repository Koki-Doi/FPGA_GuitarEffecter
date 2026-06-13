"""Public per-effect setter/getter helpers for :class:`AudioLabOverlay`.

These hold the "update a subset of an effect's cached state, rewrite its GPIO
word, return the byte view" logic for the dedicated-GPIO effects (noise
suppressor / compressor / wah). They operate on the overlay instance (state
dicts, cached words, register-write delegates, and the byte helpers all already
live on it), mirroring the ``overlay.register_writers`` / ``overlay.model_lookup``
splits. ``AudioLabOverlay`` keeps the public methods as thin delegates so the
class becomes a thinner facade with the byte output byte-for-byte unchanged.
"""
from audio_lab_pynq import control_maps as _cm


# ---- Noise Suppressor ----------------------------------------------------

def set_noise_suppressor_settings(ovl, threshold=None, decay=None, damp=None,
                                  enabled=None, mode=None):
    s = ovl._noise_suppressor_state
    if threshold is not None:
        s['threshold'] = ovl._clamp_percent(threshold)
    if decay is not None:
        s['decay'] = ovl._clamp_percent(decay)
    if damp is not None:
        s['damp'] = ovl._clamp_percent(damp)
    if mode is not None:
        s['mode'] = ovl._clamp_range(mode, 0, 255)
    if enabled is not None:
        s['enabled'] = bool(enabled)
    ovl._apply_noise_suppressor_state_to_word()
    return get_noise_suppressor_settings(ovl)


def get_noise_suppressor_settings(ovl):
    s = ovl._noise_suppressor_state
    threshold_byte = ovl._noise_threshold_to_u8(s['threshold'])
    decay_byte = ovl._percent_to_u8(s['decay'], 255)
    damp_byte = ovl._percent_to_u8(s['damp'], 255)
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
        'control_word': ovl._cached_noise_suppressor_word,
        'reflected_to_fpga': True,
        'gpio_name': ovl.NOISE_SUPPRESSOR_GPIO_NAME,
        'has_gpio': hasattr(ovl, ovl.NOISE_SUPPRESSOR_GPIO_NAME),
        'implementation_status': 'threshold_decay_damp_fpga',
    }


# ---- Compressor ----------------------------------------------------------

def set_compressor_settings(ovl, threshold=None, ratio=None, response=None,
                            makeup=None, enabled=None):
    s = ovl._compressor_state
    if threshold is not None:
        s['threshold'] = ovl._clamp_percent(threshold)
    if ratio is not None:
        s['ratio'] = ovl._clamp_percent(ratio)
    if response is not None:
        s['response'] = ovl._clamp_percent(response)
    if makeup is not None:
        s['makeup'] = ovl._clamp_percent(makeup)
    if enabled is not None:
        s['enabled'] = bool(enabled)
    ovl._apply_compressor_state_to_word()
    return get_compressor_settings(ovl)


def get_compressor_settings(ovl):
    s = ovl._compressor_state
    threshold_byte = _cm.percent_to_u8(s['threshold'], 255)
    ratio_byte = _cm.percent_to_u8(s['ratio'], 255)
    response_byte = _cm.percent_to_u8(s['response'], 255)
    makeup_u7 = ovl._makeup_to_u7(s['makeup'])
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
        'word': ovl._cached_compressor_word,
        'reflected_to_fpga': True,
        'gpio_name': ovl.COMPRESSOR_GPIO_NAME,
        'has_gpio': hasattr(ovl, ovl.COMPRESSOR_GPIO_NAME),
        'implementation_status': 'threshold_ratio_response_makeup_fpga',
    }


# ---- Wah -----------------------------------------------------------------

def set_wah_settings(ovl, position=None, q=None, volume=None, bias=None,
                     enabled=None, source=None, position_raw=None):
    if position is not None and position_raw is not None:
        raise ValueError(
            "set_wah_settings: pass position (percent) OR "
            "position_raw (byte), not both")
    s = ovl._wah_state
    if position is not None:
        s['position'] = ovl._clamp_percent(position)
        s['position_raw'] = None
    if position_raw is not None:
        s['position_raw'] = ovl._wah_position_raw_byte(position_raw)
    if q is not None:
        s['q'] = ovl._clamp_percent(q)
    if volume is not None:
        s['volume'] = ovl._clamp_percent(volume)
    if bias is not None:
        s['bias'] = ovl._clamp_percent(bias)
    if enabled is not None:
        s['enabled'] = bool(enabled)
    if source is not None:
        s['source'] = str(source)
    ovl._apply_wah_state_to_word()
    # D76: a standalone enable toggle must re-route the AXIS crossbar (the Wah
    # enable is not in the gate word). Lazy import of XbarSink avoids a circular
    # import with AudioLabOverlay (which imports this module at load time).
    if enabled is not None:
        from ..AudioLabOverlay import XbarSink
        ovl._route_effect_chain(
            XbarSink.headphone,
            getattr(ovl, '_cached_gate_word', 0) & 0xFF)
    return get_wah_settings(ovl)


def get_wah_settings(ovl):
    s = ovl._wah_state
    position_byte = ovl._wah_position_byte_for_state()
    q_byte = ovl._wah_q_byte(s['q'])
    volume_byte = ovl._wah_volume_byte(s['volume'])
    bias_u7 = ovl._wah_bias_to_u7(s['bias'])
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
        'word': ovl._cached_wah_word,
        'reflected_to_fpga': True,
        'gpio_name': ovl.WAH_GPIO_NAME,
        'has_gpio': hasattr(ovl, ovl.WAH_GPIO_NAME),
        'implementation_status': 'position_q_volume_bias_fpga_d73',
    }
