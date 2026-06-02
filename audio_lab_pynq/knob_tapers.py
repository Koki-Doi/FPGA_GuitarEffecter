"""User-facing knob taper helpers.

The low-level ``AudioLabOverlay`` percent APIs remain linear so existing
scripts and byte-level tests keep their contract. Use this module at UI /
preset boundaries where a 0..100 value means "physical knob position" rather
than "write this exact control byte".

The current pass is intentionally conservative: only gain/drive-style controls
use a stronger audio taper, and tone-style controls get a mild centre-preserving
curve. Level / mix / makeup / EQ values stay linear to preserve the existing
safe-gain contracts.
"""

import copy


GAIN_TAPER_GAMMA = 1.45

_TONE_TAPER_ANCHORS = (
    (0.0, 0.0),
    (25.0, 30.0),
    (50.0, 50.0),
    (75.0, 70.0),
    (100.0, 100.0),
)

_GUITAR_GAIN_KEYS = (
    "overdrive_drive",
    "distortion",
    "rat_drive",
    "amp_input_gain",
)

_GUITAR_TONE_KEYS = (
    "overdrive_tone",
    "distortion_tone",
    "rat_filter",
    "amp_presence",
    "amp_resonance",
    "cab_air",
    "reverb_tone",
)


def _clamp_percent(value):
    try:
        v = float(value)
    except (TypeError, ValueError):
        return 0.0
    if v < 0.0:
        return 0.0
    if v > 100.0:
        return 100.0
    return v


def _round_percent(value):
    return int(round(_clamp_percent(value)))


def _interp_anchors(value, anchors):
    x = _clamp_percent(value)
    prev_x, prev_y = anchors[0]
    for next_x, next_y in anchors[1:]:
        if x <= next_x:
            span = next_x - prev_x
            if span <= 0.0:
                return _round_percent(next_y)
            frac = (x - prev_x) / span
            return _round_percent(prev_y + frac * (next_y - prev_y))
        prev_x, prev_y = next_x, next_y
    return _round_percent(anchors[-1][1])


def gain_taper_percent(value):
    """Map physical gain/drive knob travel to a gentler audio-taper value.

    The endpoints remain fixed. Around noon, the hardware receives a lower
    drive value than the GUI shows, matching how many real gain pots spend more
    travel in the clean / edge-of-breakup region and ramp harder near the top.
    """
    x = _clamp_percent(value) / 100.0
    return _round_percent((x ** GAIN_TAPER_GAMMA) * 100.0)


def tone_taper_percent(value):
    """Mild tone-control taper with 0 / 50 / 100 fixed."""
    return _interp_anchors(value, _TONE_TAPER_ANCHORS)


def taper_distortion_kwargs(kwargs):
    """Return a copy of ``set_distortion_settings`` kwargs with UI tapers."""
    out = dict(kwargs or {})
    if out.get("drive") is not None:
        out["drive"] = gain_taper_percent(out["drive"])
    if out.get("tone") is not None:
        out["tone"] = tone_taper_percent(out["tone"])
    return out


def taper_guitar_effects_kwargs(kwargs):
    """Return a copy of ``set_guitar_effects`` kwargs with UI tapers."""
    out = dict(kwargs or {})
    for key in _GUITAR_GAIN_KEYS:
        if out.get(key) is not None:
            out[key] = gain_taper_percent(out[key])
    for key in _GUITAR_TONE_KEYS:
        if out.get(key) is not None:
            out[key] = tone_taper_percent(out[key])
    return out


def taper_chain_preset_spec(spec):
    """Deep-copy and taper a chain-preset spec for hardware writes.

    ``effect_presets.CHAIN_PRESETS`` stores user-facing knob positions so the
    GUI can mirror presets directly. ``AudioLabOverlay.apply_chain_preset`` uses
    this helper to convert those positions to the linear overlay API values
    immediately before writing GPIOs.
    """
    out = copy.deepcopy(spec or {})

    od = out.get("overdrive")
    if isinstance(od, dict):
        if od.get("drive") is not None:
            od["drive"] = gain_taper_percent(od["drive"])
        if od.get("tone") is not None:
            od["tone"] = tone_taper_percent(od["tone"])

    dist = out.get("distortion")
    if isinstance(dist, dict):
        tapered = taper_distortion_kwargs(dist)
        dist.update(tapered)

    amp = out.get("amp")
    if isinstance(amp, dict):
        if amp.get("input_gain") is not None:
            amp["input_gain"] = gain_taper_percent(amp["input_gain"])
        for key in ("presence", "resonance"):
            if amp.get(key) is not None:
                amp[key] = tone_taper_percent(amp[key])

    cab = out.get("cab")
    if isinstance(cab, dict) and cab.get("air") is not None:
        cab["air"] = tone_taper_percent(cab["air"])

    rev = out.get("reverb")
    if isinstance(rev, dict) and rev.get("tone") is not None:
        rev["tone"] = tone_taper_percent(rev["tone"])

    return out


__all__ = [
    "GAIN_TAPER_GAMMA",
    "gain_taper_percent",
    "tone_taper_percent",
    "taper_distortion_kwargs",
    "taper_guitar_effects_kwargs",
    "taper_chain_preset_spec",
]
