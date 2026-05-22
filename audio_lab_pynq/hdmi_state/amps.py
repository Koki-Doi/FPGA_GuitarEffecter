"""Amp Simulator model names, display labels, and notebook-side
normalisation helpers used by ``HdmiEffectStateMirror``.

D55 replaced the previous 4-model band-based design with 6 inspired-by
voicings (JC-120 / Twin Reverb / AC30 / Rockerverb / JCM800 /
TriAmp Mk3); the Clash side decodes ``amp_model_idx`` directly from
``axi_gpio_amp_tone.ctrlD[2:0]`` (3-bit field, 0..5 valid) and the
binary ``amp_drive_mode`` from bit 7. The per-model voicing is driven
by independent coefficient tables in ``Amp.hs``; this Python helper
only carries the display labels and the back-compat aliases.

``AMP_MODEL_CHARACTER`` is preserved as the legacy ``amp_character``
percent centre value so chain presets that still pass the legacy
kwarg do not regress.
"""

from audio_lab_pynq.hdmi_state.common import _normalize_index_or_name

AMP_MODELS = (
    "jc_120",
    "twin_reverb",
    "ac30",
    "rockerverb",
    "jcm800",
    "triamp_mk3",
)

AMP_MODEL_LABELS = {
    "jc_120":       "JC-120",
    "twin_reverb":  "Twin Reverb",
    "ac30":         "AC30",
    "rockerverb":   "Rockerverb",
    "jcm800":       "JCM800",
    "triamp_mk3":   "TriAmp Mk3",
}

# Legacy ``amp_character`` percent centres for the D52 4-model API.
# Kept for chain presets that still pass amp_character=; the D55 path
# uses ``amp_model_idx`` and these values do not participate in the
# bit-packed ctrlD byte.
AMP_MODEL_CHARACTER = {
    "jc_120":      10,
    "twin_reverb": 35,
    "ac30":        60,
    "rockerverb":  72,
    "jcm800":      80,
    "triamp_mk3":  90,
}

AMP_MODEL_TO_INDEX = dict((name, index)
                          for index, name in enumerate(AMP_MODELS))

# Display-label / common-name -> canonical snake_case name. Accept both
# the D55 names and the retired D52 names so older saved state / chain
# presets do not error out (they map onto the closest replacement: the
# old high_gain_stack collapses onto JCM800 because it was a Marshall-
# style label, and british_crunch onto AC30 because it was the
# chimey-crunch band centre).
AMP_MODEL_ALIASES = {
    # JC-120 family
    "jc_120": "jc_120",
    "jc120": "jc_120",
    "jc-120": "jc_120",
    "jc": "jc_120",
    "jazz_chorus": "jc_120",
    "jazzchorus": "jc_120",
    "jc_clean": "jc_120",           # D52 alias
    "jcclean": "jc_120",
    "roland": "jc_120",
    # Twin Reverb family
    "twin_reverb": "twin_reverb",
    "twinreverb": "twin_reverb",
    "twin": "twin_reverb",
    "fender_twin": "twin_reverb",
    "fendertwin": "twin_reverb",
    "fender": "twin_reverb",
    "blackface": "twin_reverb",
    "clean_combo": "twin_reverb",   # D52 alias
    "cleancombo": "twin_reverb",
    "combo": "twin_reverb",
    # AC30 family
    "ac30": "ac30",
    "ac_30": "ac30",
    "ac-30": "ac30",
    "vox": "ac30",
    "vox_ac30": "ac30",
    "voxac30": "ac30",
    "british_crunch": "ac30",       # D52 alias (chime band centre)
    "britishcrunch": "ac30",
    "brit_crunch": "ac30",
    "brit": "ac30",
    "crunch": "ac30",
    # Rockerverb family
    "rockerverb": "rockerverb",
    "rocker_verb": "rockerverb",
    "orange": "rockerverb",
    "orange_rockerverb": "rockerverb",
    # JCM800 family
    "jcm800": "jcm800",
    "jcm_800": "jcm800",
    "jcm": "jcm800",
    "marshall": "jcm800",
    "marshall_jcm800": "jcm800",
    "high_gain_stack": "jcm800",    # D52 alias (Marshall-style label)
    "highgainstack": "jcm800",
    "hi_gain_stack": "jcm800",
    "higainstack": "jcm800",
    "high_gain": "jcm800",
    "higain": "jcm800",
    "high": "jcm800",
    # TriAmp Mk3 family
    "triamp_mk3": "triamp_mk3",
    "triampmk3": "triamp_mk3",
    "triamp": "triamp_mk3",
    "triamp_mkiii": "triamp_mk3",
    "triampmkiii": "triamp_mk3",
    "tri_amp": "triamp_mk3",
    "triamp_mk_3": "triamp_mk3",
    "hughes_kettner": "triamp_mk3",
    "hughes": "triamp_mk3",
    "hk_triamp": "triamp_mk3",
}


def normalize_amp_model(value):
    return _normalize_index_or_name(
        value, AMP_MODELS, AMP_MODEL_ALIASES, "amp")


def amp_model_label(value):
    return AMP_MODEL_LABELS[normalize_amp_model(value)]
