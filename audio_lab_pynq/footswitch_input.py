"""Low-level driver for the ``axi_footswitch_input`` IP.

The PL IP exposes three guitar-pedal 3PDT footswitches behind a small
AXI4-Lite slave at base ``0x43D50000`` (see ``DECISIONS.md`` footswitch
entry). The PL fabric handles 2-FF synchronisation, debounce, and a
per-channel dual-edge "press event" latch; the PS side only reads the
latched events.

The footswitches are *latching* (alternate-action) 3PDT switches, so each
physical stomp flips the debounced level and the IP latches one
``press_event`` per edge -- the absolute level is irrelevant. The channel
mapping is fixed by the wiring / XDC:

  * channel 0 (``fsw0_i``) = FX toggle
  * channel 1 (``fsw1_i``) = preset next
  * channel 2 (``fsw2_i``) = preset prev

This module is import-safe on workstations without ``pynq`` installed.
``FootswitchInput`` raises a clear ``RuntimeError`` if constructed without
a real overlay / MMIO.
"""

from typing import Iterable, List, Optional, Sequence, Tuple


# ---- Register map -----------------------------------------------------------

REG_STATUS       = 0x00
REG_CONFIG       = 0x18
REG_CLEAR_EVENTS = 0x1C
REG_VERSION      = 0x20

# CONFIG bit positions (mirrors hw/ip/footswitch_input/src/axi_footswitch_input.v)
CONFIG_DEBOUNCE_MS_SHIFT = 0
CONFIG_DEBOUNCE_MS_MASK  = 0x000000FF
CONFIG_CLEAR_ON_READ_BIT = 1 << 8

CONFIG_DEFAULT = 0x00000105  # debounce=5, clear-on-read=1

EXPECTED_VERSION = 0x00F50001

# Fixed channel roles (match the XDC wiring fsw0/1/2).
CH_FX_TOGGLE   = 0
CH_PRESET_NEXT = 1
CH_PRESET_PREV = 2

# Default IP names to try in pynq.Overlay.ip_dict. PYNQ exposes a Verilog
# module-reference AXI interface as "<instance>/<bus-interface>".
DEFAULT_IP_NAMES: Tuple[str, ...] = (
    "axi_footswitch_input_0",
    "fsw_in_0",
    "fsw_in_0/s_axi",
    "axi_footswitch_input",
)


def _is_ip_object(obj) -> bool:
    return (
        obj is not None and
        (hasattr(obj, "mmio") or (hasattr(obj, "read") and hasattr(obj, "write")))
    )


# ---- Event class ------------------------------------------------------------

class FootswitchEvent(object):
    """Decoded footswitch event.

    Kept as a plain class rather than a dataclass so the driver runs on the
    PYNQ-Z2 Python 3.6 image without the dataclasses backport.
    """

    __slots__ = ("kind", "channel", "timestamp")

    def __init__(self, kind, channel, timestamp=0.0):
        self.kind = kind            # "press"
        self.channel = int(channel)
        self.timestamp = float(timestamp)

    def __repr__(self):
        return "FootswitchEvent(kind={!r}, channel={!r}, timestamp={!r})".format(
            self.kind, self.channel, self.timestamp)


# ---- Decode helpers ---------------------------------------------------------

def decode_status(status: int) -> dict:
    """Decode STATUS into press_event / level flag lists."""
    return {
        "press_event": [(status >> i) & 1 for i in range(3)],
        "level":       [(status >> (8 + i)) & 1 for i in range(3)],
    }


# ---- Driver -----------------------------------------------------------------

class FootswitchInput:
    """Thin AXI-Lite wrapper around the ``axi_footswitch_input`` IP.

    Accepts either a ``pynq.Overlay``-like object exposing the IP under one
    of ``DEFAULT_IP_NAMES`` (preferred, via ``from_overlay``), or a raw
    MMIO-like object exposing ``read(offset)`` and ``write(offset, value)``.
    """

    def __init__(self, mmio):
        if mmio is None:
            raise RuntimeError("FootswitchInput requires an MMIO-like object")
        if not (hasattr(mmio, "read") and hasattr(mmio, "write")):
            raise RuntimeError(
                "FootswitchInput's mmio argument must expose read(offset) and "
                "write(offset, value); got %r" % (type(mmio),)
            )
        self._mmio = mmio

    # -- construction helpers --------------------------------------------------

    @classmethod
    def from_overlay(
        cls,
        overlay,
        *,
        ip_name: Optional[str] = None,
        clear_on_attach: bool = True,
    ) -> "FootswitchInput":
        """Locate the footswitch IP on a pynq.Overlay and bind to it.

        ``ip_name`` overrides the default search list. ``clear_on_attach``
        flushes any power-up phantom event (a switch that booted in the
        grounded position latches one event before the first clear).
        """
        candidates: Sequence[str]
        if ip_name is not None:
            candidates = (ip_name,)
        else:
            candidates = DEFAULT_IP_NAMES

        ip_obj = None
        for name in candidates:
            candidate_obj = getattr(overlay, name, None)
            if _is_ip_object(candidate_obj):
                ip_obj = candidate_obj
                break
            try:
                ip_dict = overlay.ip_dict  # type: ignore[attr-defined]
            except AttributeError:
                ip_dict = None
            if ip_dict and name in ip_dict:
                try:
                    from pynq import DefaultIP  # type: ignore
                    ip_obj = DefaultIP(description=ip_dict[name])
                    break
                except Exception:
                    pass

        if ip_obj is None and ip_name is None:
            try:
                ip_dict = overlay.ip_dict  # type: ignore[attr-defined]
            except AttributeError:
                ip_dict = None
            if ip_dict:
                for name in ip_dict:
                    lower = name.lower()
                    if "footswitch" in lower or lower.startswith("fsw_in"):
                        try:
                            from pynq import DefaultIP  # type: ignore
                            ip_obj = DefaultIP(description=ip_dict[name])
                            break
                        except Exception:
                            pass

        if ip_obj is None:
            raise RuntimeError(
                "axi_footswitch_input IP not found on overlay; tried %s"
                % (list(candidates),)
            )

        mmio = getattr(ip_obj, "mmio", ip_obj)
        inst = cls(mmio)
        if clear_on_attach:
            inst.clear_events()
        return inst

    # -- raw register access ---------------------------------------------------

    def read_version(self) -> int:
        return int(self._mmio.read(REG_VERSION))

    def read_status(self) -> int:
        return int(self._mmio.read(REG_STATUS))

    def read_config(self) -> int:
        return int(self._mmio.read(REG_CONFIG))

    def write_config(self, value: int) -> None:
        self._mmio.write(REG_CONFIG, int(value) & 0xFFFFFFFF)

    def read_levels(self) -> Tuple[int, int, int]:
        """Debounced raw levels (diagnostics). Does NOT clear events."""
        lv = decode_status(self.read_status())["level"]
        return (lv[0], lv[1], lv[2])

    def clear_events(self, *, channels: Iterable[int] = (0, 1, 2)) -> None:
        """Explicit CLEAR_EVENTS write. Default clears every latch."""
        word = 0
        for i in channels:
            word |= 1 << i
        self._mmio.write(REG_CLEAR_EVENTS, word & 0xFFFFFFFF)

    # -- convenience config helpers --------------------------------------------

    def configure(
        self,
        *,
        debounce_ms: Optional[int] = None,
        clear_on_read: Optional[bool] = None,
    ) -> int:
        """Read CONFIG, modify the requested fields, write back, return new word."""
        cfg = self.read_config()
        if debounce_ms is not None:
            cfg = (cfg & ~CONFIG_DEBOUNCE_MS_MASK) | (int(debounce_ms) & CONFIG_DEBOUNCE_MS_MASK)
        if clear_on_read is not None:
            cfg = (cfg | CONFIG_CLEAR_ON_READ_BIT) if clear_on_read else (cfg & ~CONFIG_CLEAR_ON_READ_BIT)
        self.write_config(cfg)
        return cfg

    # -- event polling ---------------------------------------------------------

    def poll(self, *, timestamp: float = 0.0) -> List[FootswitchEvent]:
        """Read STATUS once and return a ``press`` event per latched channel.

        With ``clear_on_read`` enabled (the default) the STATUS read also
        clears the latches inside the IP, so callers need not clear them by
        hand.
        """
        events: List[FootswitchEvent] = []
        decoded = decode_status(self.read_status())
        for i in range(3):
            if decoded["press_event"][i]:
                events.append(FootswitchEvent(
                    kind="press", channel=i, timestamp=timestamp))
        return events
