"""Compatibility shim for the notebook-driven HDMI effect state mirror.

The implementation lives in ``audio_lab_pynq.hdmi_state.mirror``. This
module keeps the historical import path working:

    from audio_lab_pynq.hdmi_effect_state_mirror import HdmiEffectStateMirror

It also mirrors the implementation module's helper constants and private
diagnostic functions because older notebooks imported several of them
directly from this path.
"""
from __future__ import print_function

from audio_lab_pynq.hdmi_state import mirror as _mirror


for _name, _value in vars(_mirror).items():
    if not _name.startswith("__"):
        globals()[_name] = _value

__all__ = list(getattr(_mirror, "__all__", []))

del _name, _value, _mirror
