"""Shared register map and MMIO discovery for the Pmod I2S2 status block.

`axi_pmod_i2s2_status` (`pmod_status_0` @ ``0x43D20000``) is the AXI-Lite
status/control slave for the Pmod I2S2 master. Several scripts and the
Pmod notebooks need the same register offsets, the same symbolic
mode table, and the same "find the IP and hand back a `pynq.MMIO`" dance;
this module is the single source for all three so they cannot drift.

Kept deliberately import-light and PYNQ Python 3.6 compatible: `pynq`
is imported lazily inside the functions so the module also imports on a
development host with no PYNQ installed (used by the unit tests). No
f-strings, no walrus.

See `docs/ai_context/GPIO_CONTROL_MAP.md`,
`docs/ai_context/PMOD_I2S2_INTEGRATION_PLAN.md`, and `DECISIONS.md`
D48 / D49 / D50.
"""
from __future__ import print_function

import os
import sys


# Documented physical base of `pmod_status_0` (used as a fallback when
# the overlay ip_dict lookup is unavailable). Range matches the BD slave.
PMOD_PHYS_ADDR_FALLBACK = 0x43D20000
PMOD_ADDR_RANGE = 0x10000

# Register offsets within the status block (see axi_pmod_i2s2_status.v).
REG = {
    "VERSION":      0x00,
    "STATUS":       0x04,
    "FRAME":        0x08,
    "NONZERO":      0x0C,
    "SDOUT_XCOUNT": 0x10,
    "CLIP":         0x14,
    "LAST_LEFT":    0x18,
    "LAST_RIGHT":   0x1C,
    "PEAK_L":       0x20,
    "PEAK_R":       0x24,
    "MODE":         0x28,
    "CLEAR":        0x2C,
}
EXPECTED_VERSION = 0x00480001

# Runtime mode select written to REG["MODE"] (2 bits).
MODE_INT = {"tone": 0, "loopback": 1, "dsp": 2, "mute": 3}
MODE_LABEL = {v: k for k, v in MODE_INT.items()}


def sign24(value):
    """Interpret a 32-bit register read as a signed 32-bit value."""
    value = int(value) & 0xFFFFFFFF
    if value & 0x80000000:
        return value - (1 << 32)
    return value


def _status_key(ip_dict):
    """Return the ip_dict key for the pmod_status slave, or None."""
    for key in sorted(ip_dict or {}):
        if "pmod_status" in key or "pmod_i2s2_status" in key:
            return key
    return None


def find_status_mmio(overlay=None, require_loaded=True):
    """Return ``(mmio, key)`` for the Pmod I2S2 status IP, or ``(None, None)``.

    If ``overlay`` is provided, its ``ip_dict`` is scanned directly (the
    caller already attached the overlay). Otherwise the PL is inspected
    via ``pynq.PL.bitfile_name`` and a non-downloading
    ``Overlay(bitfile, download=False)`` is used purely for its
    ``ip_dict`` -- this is the no-overlay path used by
    ``scripts/pmod_i2s2_mode.py`` while another process owns the bit.

    When the lookup yields no phys_addr the documented
    ``PMOD_PHYS_ADDR_FALLBACK`` is used. ``pynq`` is imported lazily so a
    host without PYNQ returns ``(None, None)`` instead of raising.
    """
    try:
        from pynq import MMIO  # type: ignore
    except Exception:  # pragma: no cover -- off-board / no pynq
        return None, None

    phys_addr = None
    found_key = None

    if overlay is not None:
        ip_dict = getattr(overlay, "ip_dict", {}) or {}
        key = _status_key(ip_dict)
        if key is not None:
            entry = ip_dict[key]
            addr = entry.get("phys_addr")
            if addr is not None:
                phys_addr = int(addr)
                found_key = key
    else:
        try:
            from pynq import PL  # type: ignore
        except Exception:  # pragma: no cover
            return None, None
        bitfile = (PL.bitfile_name or "")
        if require_loaded and "audio_lab" not in os.path.basename(bitfile):
            print("ERROR: audio_lab.bit not loaded on PL (PL.bitfile_name=%r). "
                  "Start the encoder runner first." % bitfile, file=sys.stderr)
            return None, None
        try:
            from pynq import Overlay  # type: ignore
            ovl = Overlay(bitfile, download=False)
            ip_dict = getattr(ovl, "ip_dict", {}) or {}
            key = _status_key(ip_dict)
            if key is not None:
                addr = ip_dict[key].get("phys_addr")
                if addr is not None:
                    phys_addr = int(addr)
                    found_key = key
        except Exception as exc:
            print("WARN: Overlay(download=False) failed (%r); falling back to "
                  "hardcoded address 0x%08X."
                  % (exc, PMOD_PHYS_ADDR_FALLBACK), file=sys.stderr)

    if phys_addr is None:
        phys_addr = PMOD_PHYS_ADDR_FALLBACK
        found_key = "fallback:0x%08X" % phys_addr

    try:
        return MMIO(phys_addr, PMOD_ADDR_RANGE), found_key
    except Exception as exc:
        print("ERROR: pynq.MMIO failed at 0x%08X: %r"
              % (phys_addr, exc), file=sys.stderr)
        return None, None
