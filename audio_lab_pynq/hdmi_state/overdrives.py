"""Overdrive model names, display labels, and notebook-side
normalisation helpers used by ``HdmiEffectStateMirror``.

D45 replaced the generic Overdrive with six selectable models; the
3-bit model select rides on ``overdrive_control.ctrlD[2:0]``. The
labels here drive the SELECTED FX / OVERDRIVE dropdown chip on the
800x480 HDMI panel.
"""

from audio_lab_pynq.hdmi_state.common import _normalize_index_or_name


OVERDRIVE_MODELS = (
    "ts9",
    "od1",
    "bd2",
    "jan_ray",
    "ocd",
    "centaur",
)

OVERDRIVE_MODEL_LABELS = {
    "ts9":     "Ibanez / TS9",
    "od1":     "BOSS / OD-1",
    "bd2":     "BOSS / BD-2",
    "jan_ray": "Vemuram / Jan Ray",
    "ocd":     "Fulltone / OCD",
    "centaur": "CENTAUR",
}

OVERDRIVE_MODEL_TO_INDEX = dict((name, index)
                                for index, name in enumerate(OVERDRIVE_MODELS))

OVERDRIVE_MODEL_ALIASES = {
    "0": "ts9",
    "model_0": "ts9",
    "model0": "ts9",
    "ts9": "ts9",
    "ibanez_ts9": "ts9",
    "tube_screamer_9": "ts9",
    "tubescreamer_9": "ts9",
    "1": "od1",
    "model_1": "od1",
    "model1": "od1",
    "od1": "od1",
    "od_1": "od1",
    "boss_od1": "od1",
    "boss_od_1": "od1",
    "2": "bd2",
    "model_2": "bd2",
    "model2": "bd2",
    "bd2": "bd2",
    "bd_2": "bd2",
    "boss_bd2": "bd2",
    "boss_bd_2": "bd2",
    "blues_driver": "bd2",
    "3": "jan_ray",
    "model_3": "jan_ray",
    "model3": "jan_ray",
    "jan_ray": "jan_ray",
    "janray": "jan_ray",
    "vemuram_jan_ray": "jan_ray",
    "vemuram_janray": "jan_ray",
    "4": "ocd",
    "model_4": "ocd",
    "model4": "ocd",
    "ocd": "ocd",
    "fulltone_ocd": "ocd",
    "5": "centaur",
    "model_5": "centaur",
    "model5": "centaur",
    "centaur": "centaur",
    "klon": "centaur",
    "klon_centaur": "centaur",
}


def normalize_overdrive_model(value):
    return _normalize_index_or_name(
        value, OVERDRIVE_MODELS, OVERDRIVE_MODEL_ALIASES, "overdrive")


def overdrive_model_label(value):
    return OVERDRIVE_MODEL_LABELS[normalize_overdrive_model(value)]
