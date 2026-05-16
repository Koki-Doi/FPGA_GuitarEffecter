"""Stub pynq / pylibi2c modules so the offline test suite can import
``audio_lab_pynq.*`` without the real PYNQ-Z2 runtime.

Tests that load ``audio_lab_pynq/hdmi_effect_state_mirror.py`` via
``importlib.util.spec_from_file_location`` used to bypass the package
``__init__`` entirely; after the Phase 6I split the mirror file imports
from ``audio_lab_pynq.hdmi_state.*``, which triggers
``audio_lab_pynq/__init__.py`` and pulls in ``AxisSwitch`` (which
imports ``pynq``). The tests run on a developer workstation that has
no pynq install, so we register a minimal stub before any
audio_lab_pynq import.

This mirrors what ``tests/test_overlay_controls.py`` has been doing
since the pedal-mask refactor.
"""
import sys
import types


def install():
    if "pynq" not in sys.modules:
        pynq = types.ModuleType("pynq")

        class _Overlay(object):
            pass

        class _DefaultIP(object):
            bindto = []

            def __init__(self, description=None):
                self.description = description or {}

            def read(self, _offset):
                return 0

            def write(self, _offset, _value):
                pass

        pynq.Overlay = _Overlay
        pynq.DefaultIP = _DefaultIP
        sys.modules["pynq"] = pynq

    if "pylibi2c" not in sys.modules:
        pylibi2c = types.ModuleType("pylibi2c")

        class _I2CDevice(object):
            def __init__(self, *_args, **_kwargs):
                pass

            def ioctl_read(self, _offset, length):
                return bytes([0] * length)

            def ioctl_write(self, _offset, _data):
                pass

        pylibi2c.I2CDevice = _I2CDevice
        sys.modules["pylibi2c"] = pylibi2c


install()
