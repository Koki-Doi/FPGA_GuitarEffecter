"""Model / pedal name -> index resolution for :class:`AudioLabOverlay`.

These are pure functions: given a user-facing model spec (enum name,
display label, or integer) and the relevant constant tables, they return
the integer index / mask the GPIO writers expect. They were lifted out of
the overlay facade unchanged -- the class methods now delegate here while
keeping their ``cls``-based constant resolution, so subclassing or
constant overrides still take effect and the byte output is identical.

Mirrors the ``overlay.register_writers`` split (D115): implementation
detail moves under ``audio_lab_pynq.overlay`` while the public method
surface stays on ``AudioLabOverlay``.
"""


def normalize_overdrive_model(model, models, labels, count):
    """Resolve an overdrive-model spec to an integer in ``0..count-1``.

    ``model`` may be an enum name / display label (case-insensitive) or an
    int. Out-of-range or unknown integers fall back to 0 (TS9), mirroring
    the Clash 6/7 slot fall-through; an unknown non-numeric string raises
    ``ValueError``.
    """
    if isinstance(model, str):
        key = model.strip().lower().replace("-", "_").replace(" ", "_")
        for i, name in enumerate(models):
            if key == name:
                return i
        # Also accept display labels (case-insensitive) for convenience,
        # e.g. "Ibanez / TS9" -> 0.
        for i, label in enumerate(labels):
            if model.strip().lower() == label.strip().lower():
                return i
        # Bare model number embedded in a string, e.g. "3".
        try:
            idx = int(model)
        except ValueError:
            raise ValueError(
                'unknown overdrive model: {!r}; valid names are {}'.format(
                    model, ', '.join(models)))
    else:
        try:
            idx = int(model)
        except (TypeError, ValueError):
            return 0
    if idx < 0 or idx >= count:
        return 0
    return idx


def normalize_pedal_name(name, pedals, pedal_bit):
    """Resolve a distortion-pedal name / index to its mask bit position.

    Strings are looked up in ``pedal_bit``; integers are range-checked
    against ``pedals``. Unknown names / out-of-range indices raise
    ``ValueError``.
    """
    if isinstance(name, str):
        try:
            return pedal_bit[name]
        except KeyError:
            raise ValueError(
                'unknown distortion pedal: {!r}; valid pedals are {}'.format(
                    name, ', '.join(pedals)))
    idx = int(name)
    if idx < 0 or idx >= len(pedals):
        raise ValueError(
            'distortion pedal index {} out of range 0..{}'.format(
                idx, len(pedals) - 1))
    return idx


def pedal_mask_from_iterable(pedals, normalize):
    """Build a 7-bit pedal mask from a sequence of names / bit indices, or
    from a ``{name: bool}`` dict. ``normalize`` maps one entry to its bit.
    """
    mask = 0
    if isinstance(pedals, dict):
        for name, enabled in pedals.items():
            bit = normalize(name)
            if enabled:
                mask |= (1 << bit)
    else:
        for entry in pedals:
            bit = normalize(entry)
            mask |= (1 << bit)
    return mask & 0x7F


def amp_model_to_idx(name, models, labels, max_idx):
    """Map an amp-model name (snake_case enum or title-case display label)
    or integer to its ``amp_model_idx``.

    ``models`` is the ``{name: idx}`` dict; ``labels`` the ordered display
    list. Raises ``ValueError`` for an unknown name / out-of-range int.
    """
    if isinstance(name, int):
        idx = int(name)
        if 0 <= idx <= max_idx:
            return idx
        raise ValueError(
            "unknown amp model idx: {!r}; valid range is 0..{}".format(
                name, max_idx))
    if name in models:
        return models[name]
    # Allow title-case display labels too so notebook code can pass the
    # human-readable name from the dropdown straight through.
    for i, label in enumerate(labels):
        if label == name:
            return i
    raise ValueError(
        "unknown amp model: {!r}; valid names are {}".format(
            name, ", ".join(models.keys())))
