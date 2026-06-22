"""Pure helper for ``AudioLabOverlay.apply_chain_preset``.

Refactor P1 tail (2026-06-22): ``apply_chain_preset`` is orchestration (it calls
``set_compressor_settings`` / ``set_noise_suppressor_settings`` /
``set_distortion_*`` / ``set_guitar_effects`` with ``hasattr`` guards, mutating
overlay state) so the body stays on the class. The one cleanly-separable piece is
the **pure** construction of the big ``set_guitar_effects(**kwargs)`` dict from a
(already model-pinned, already tapered) preset ``spec`` -- no ``self`` access, no
writes. That moves here so the class method shrinks to the orchestration. Byte
output is unchanged (pinned by ``tests/test_overlay_controls.py``).
"""

from .. import control_maps as _cm


def build_guitar_effects_kwargs(spec, pinned):
    """Build the ``set_guitar_effects`` kwargs dict from a chain-preset ``spec``.

    ``spec`` is the tapered preset spec (dict-of-section-dicts); ``pinned`` is the
    ``CHAIN_PRESET_MODELS`` entry for the preset (amp / overdrive model pins, or
    an empty dict for the percent-character fallback). Pure: reads ``spec`` /
    ``pinned`` only and returns the kwargs dict.
    """
    ns = spec.get("noise_suppressor", {})
    od = spec.get("overdrive", {})
    dist = spec.get("distortion", {})
    amp = spec.get("amp", {})
    cab = spec.get("cab", {})
    eq = spec.get("eq", {})
    rev = spec.get("reverb", {})

    rat_preset_on = bool(dist.get("enabled", False)) \
        and dist.get("pedal") == "rat"
    kwargs = dict(
        noise_gate_on=bool(ns.get("enabled", False)),
        noise_gate_threshold=ns.get("threshold", 35),
        overdrive_on=bool(od.get("enabled", False)),
        overdrive_drive=od.get("drive", 0),
        overdrive_tone=od.get("tone", 50),
        overdrive_level=od.get("level", 100),
        overdrive_model=pinned.get("overdrive", od.get("model", 0)),
        distortion_on=bool(dist.get("enabled", False)),
        rat_on=rat_preset_on,
        amp_on=bool(amp.get("enabled", False)),
        amp_input_gain=amp.get("input_gain", 35),
        amp_bass=amp.get("bass", 50),
        amp_middle=amp.get("middle", 50),
        amp_treble=amp.get("treble", 50),
        amp_presence=amp.get("presence", 45),
        amp_resonance=amp.get("resonance", 35),
        amp_master=amp.get("master", 80),
        amp_character=amp.get("character", 35),
        amp_model_idx=pinned.get("amp"),
        cab_on=bool(cab.get("enabled", False)),
        cab_mix=cab.get("mix", 100),
        cab_level=cab.get("level", 100),
        cab_model=cab.get("model", 1),
        cab_air=cab.get("air", 50),
        eq_on=bool(eq.get("enabled", False)),
        eq_low=eq.get("low", 100),
        eq_mid=eq.get("mid", 100),
        eq_high=eq.get("high", 100),
        reverb_on=bool(rev.get("enabled", False)),
        reverb_decay=rev.get("decay", 0),
        reverb_tone=rev.get("tone", 65),
        reverb_mix=rev.get("mix", 0),
    )
    if rat_preset_on:
        kwargs.update(
            rat_drive=dist.get("drive", 20),
            rat_filter=_cm.rat_filter_from_tone(dist.get("tone", 50)),
            rat_level=dist.get("level", 35),
            rat_mix=dist.get("mix", 100),
        )
    return kwargs
