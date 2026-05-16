"""Cross-effect helpers shared by the per-effect modules and the
HDMI effect state mirror. Kept tiny on purpose.
"""


def _clamp_percent(value):
    try:
        value = float(value)
    except Exception:
        value = 0.0
    if value < 0.0:
        value = 0.0
    if value > 100.0:
        value = 100.0
    return int(round(value))


def _eq_display_value(value):
    try:
        return _clamp_percent(float(value) / 2.0)
    except Exception:
        return 50


def _cab_model_display_value(value):
    try:
        ivalue = int(value)
    except Exception:
        ivalue = 1
    if ivalue < 0:
        ivalue = 0
    if ivalue > 2:
        ivalue = 2
    return ivalue * 50


def _has_asserted_vdma_error(errors):
    return bool(
        errors
        and (errors.get("dmainterr")
             or errors.get("dmaslverr")
             or errors.get("dmadecerr"))
    )


def _model_key(value):
    text = str(value or "").strip().lower()
    for ch in (" ", "-", "/", "."):
        text = text.replace(ch, "_")
    while "__" in text:
        text = text.replace("__", "_")
    return text.strip("_")


def _normalize_index_or_name(value, names, aliases, model_type):
    if isinstance(value, int):
        index = value
        if 0 <= index < len(names):
            return names[index]
        raise ValueError(
            "unsupported {} model index {!r}; valid range is 0..{}"
            .format(model_type, value, len(names) - 1))
    key = _model_key(value)
    if key in aliases:
        return aliases[key]
    if key in names:
        return key
    valid = ", ".join(names)
    raise ValueError(
        "unsupported {} model {!r}; valid models are {}"
        .format(model_type, value, valid))
