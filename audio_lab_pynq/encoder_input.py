"""Low-level driver for the Phase 7F ``axi_encoder_input`` IP.

The PL IP exposes three rotary encoders (CLK / DT / SW) behind a small
AXI4-Lite slave at base ``0x43D10000`` (see ``DECISIONS.md`` D32). The PS
side only needs to read accumulated signed deltas and event flags; the
PL fabric handles synchronisation, debounce, quadrature decode and
short/long-press timing.

This module is import-safe on workstations without ``pynq`` installed.
``EncoderInput`` will raise a clear ``RuntimeError`` if you try to
construct it without a real overlay / MMIO.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Iterable, List, Literal, Optional, Sequence, Tuple


# ---- Register map -----------------------------------------------------------

REG_STATUS       = 0x00
REG_DELTA_PACKED = 0x04
REG_COUNT0       = 0x08
REG_COUNT1       = 0x0C
REG_COUNT2       = 0x10
REG_BUTTON_STATE = 0x14
REG_CONFIG       = 0x18
REG_CLEAR_EVENTS = 0x1C
REG_VERSION      = 0x20

# CONFIG bit positions (mirrors hw/ip/encoder_input/src/axi_encoder_input.v)
CONFIG_DEBOUNCE_MS_SHIFT   = 0
CONFIG_DEBOUNCE_MS_MASK    = 0x000000FF
CONFIG_CLEAR_ON_READ_BIT   = 1 << 8
CONFIG_ACCELERATION_BIT    = 1 << 9
CONFIG_REVERSE_DIR_SHIFT   = 10  # 3 bits
CONFIG_CLK_DT_SWAP_SHIFT   = 13  # 3 bits
CONFIG_SW_ACTIVE_LOW_BIT   = 1 << 16

CONFIG_DEFAULT = 0x00010105  # debounce=5, clear-on-read=1, sw_active_low=1

EXPECTED_VERSION = 0x00070001

# Default IP names to try in pynq.Overlay.ip_dict
DEFAULT_IP_NAMES: Tuple[str, ...] = (
    "axi_encoder_input_0",
    "enc_in_0",
    "axi_encoder_input",
)

# Each detent on a typical rotary encoder produces 4 quadrature edges,
# which is what the IP accumulates raw. The Python layer down-converts
# raw edges to detents.
EDGES_PER_DETENT = 4


# ---- Event dataclass --------------------------------------------------------

EventKind = Literal["rotate", "short_press", "long_press", "release"]


@dataclass
class EncoderEvent:
    kind: EventKind
    encoder_id: int          # 0, 1, or 2
    delta: int = 0           # signed detents (already divided by EDGES_PER_DETENT) for rotate
    raw_delta: int = 0       # signed raw quadrature edges for rotate (unscaled)
    timestamp: float = 0.0   # seconds (host clock); zero if caller didn't fill it in


# ---- Helpers ----------------------------------------------------------------


def _s8(x: int) -> int:
    """Sign-extend the low 8 bits of x as a signed int."""
    x &= 0xFF
    return x - 0x100 if x & 0x80 else x


def _s32(x: int) -> int:
    x &= 0xFFFFFFFF
    return x - 0x100000000 if x & 0x80000000 else x


def unpack_delta(packed: int) -> Tuple[int, int, int]:
    """Unpack DELTA_PACKED into three signed int8s (enc0, enc1, enc2)."""
    return (_s8(packed), _s8(packed >> 8), _s8(packed >> 16))


def decode_status(status: int) -> dict:
    """Decode STATUS into a dict with rotate/short/long/sw_level flags."""
    return {
        "rotate_event": [(status >> i) & 1 for i in range(3)],
        "short_press":  [(status >> (8 + i)) & 1 for i in range(3)],
        "long_press":   [(status >> (16 + i)) & 1 for i in range(3)],
        "sw_level":     [(status >> (24 + i)) & 1 for i in range(3)],
    }


# ---- Driver -----------------------------------------------------------------


class EncoderInput:
    """Thin AXI-Lite wrapper around the ``axi_encoder_input`` IP.

    Accepts either:
      * a ``pynq.Overlay``-like object exposing the IP under one of
        ``DEFAULT_IP_NAMES`` (preferred), or
      * a raw MMIO-like object exposing ``read(offset)`` and
        ``write(offset, value)``.

    Use ``EncoderInput.from_overlay(overlay)`` for the common case.
    """

    def __init__(self, mmio, *, edges_per_detent: int = EDGES_PER_DETENT):
        if mmio is None:
            raise RuntimeError("EncoderInput requires an MMIO-like object")
        if not (hasattr(mmio, "read") and hasattr(mmio, "write")):
            raise RuntimeError(
                "EncoderInput's mmio argument must expose read(offset) and "
                "write(offset, value); got %r" % (type(mmio),)
            )
        self._mmio = mmio
        self._edges_per_detent = int(edges_per_detent)
        # Track the "released" edge of SW so we can emit synthetic release
        # events without the PL needing a release latch.
        self._sw_level_prev = [0, 0, 0]
        # Carry leftover raw-edges between polls so 1-detent rotations
        # accumulated across two polls still emit a rotate event eventually.
        self._raw_carry = [0, 0, 0]

    # -- construction helpers --------------------------------------------------

    @classmethod
    def from_overlay(
        cls,
        overlay,
        *,
        ip_name: Optional[str] = None,
        edges_per_detent: int = EDGES_PER_DETENT,
    ) -> "EncoderInput":
        """Locate the encoder IP on a pynq.Overlay and bind to it.

        ``ip_name`` overrides the default search list (useful if the BD
        cell is renamed).
        """
        candidates: Sequence[str]
        if ip_name is not None:
            candidates = (ip_name,)
        else:
            candidates = DEFAULT_IP_NAMES

        ip_obj = None
        for name in candidates:
            ip_obj = getattr(overlay, name, None)
            if ip_obj is not None:
                break
            # PYNQ Overlay also exposes IPs in .ip_dict
            try:
                ip_dict = overlay.ip_dict  # type: ignore[attr-defined]
            except AttributeError:
                ip_dict = None
            if ip_dict and name in ip_dict:
                # Use the AXI helper to instantiate a default driver
                try:
                    from pynq import DefaultIP  # type: ignore
                    ip_obj = DefaultIP(description=ip_dict[name])
                    break
                except Exception:
                    pass

        if ip_obj is None:
            raise RuntimeError(
                "axi_encoder_input IP not found on overlay; tried %s"
                % (list(candidates),)
            )

        mmio = getattr(ip_obj, "mmio", ip_obj)
        return cls(mmio, edges_per_detent=edges_per_detent)

    # -- raw register access ---------------------------------------------------

    def read_version(self) -> int:
        return int(self._mmio.read(REG_VERSION))

    def read_status(self) -> int:
        return int(self._mmio.read(REG_STATUS))

    def read_delta_packed(self) -> int:
        return int(self._mmio.read(REG_DELTA_PACKED))

    def read_counts(self) -> Tuple[int, int, int]:
        return (
            _s32(self._mmio.read(REG_COUNT0)),
            _s32(self._mmio.read(REG_COUNT1)),
            _s32(self._mmio.read(REG_COUNT2)),
        )

    def read_button_state(self) -> int:
        return int(self._mmio.read(REG_BUTTON_STATE)) & 0x7

    def read_config(self) -> int:
        return int(self._mmio.read(REG_CONFIG))

    def write_config(self, value: int) -> None:
        self._mmio.write(REG_CONFIG, int(value) & 0xFFFFFFFF)

    def clear_events(
        self,
        *,
        rotate: Iterable[int] = (0, 1, 2),
        short_press: Iterable[int] = (0, 1, 2),
        long_press: Iterable[int] = (0, 1, 2),
    ) -> None:
        """Explicit CLEAR_EVENTS write. Default clears every latch."""
        word = 0
        for i in rotate:
            word |= 1 << i
        for i in short_press:
            word |= 1 << (8 + i)
        for i in long_press:
            word |= 1 << (16 + i)
        self._mmio.write(REG_CLEAR_EVENTS, word & 0xFFFFFFFF)

    # -- convenience config helpers --------------------------------------------

    def configure(
        self,
        *,
        debounce_ms: Optional[int] = None,
        clear_on_read: Optional[bool] = None,
        sw_active_low: Optional[bool] = None,
        reverse_direction: Optional[Sequence[bool]] = None,
        clk_dt_swap: Optional[Sequence[bool]] = None,
    ) -> int:
        """Read CONFIG, modify the requested fields, write back, return new word."""
        cfg = self.read_config()
        if debounce_ms is not None:
            cfg = (cfg & ~CONFIG_DEBOUNCE_MS_MASK) | (int(debounce_ms) & CONFIG_DEBOUNCE_MS_MASK)
        if clear_on_read is not None:
            cfg = (cfg | CONFIG_CLEAR_ON_READ_BIT) if clear_on_read else (cfg & ~CONFIG_CLEAR_ON_READ_BIT)
        if sw_active_low is not None:
            cfg = (cfg | CONFIG_SW_ACTIVE_LOW_BIT) if sw_active_low else (cfg & ~CONFIG_SW_ACTIVE_LOW_BIT)
        if reverse_direction is not None:
            mask = 0
            for i, v in enumerate(reverse_direction):
                if v:
                    mask |= 1 << i
            cfg = (cfg & ~(0x7 << CONFIG_REVERSE_DIR_SHIFT)) | (mask << CONFIG_REVERSE_DIR_SHIFT)
        if clk_dt_swap is not None:
            mask = 0
            for i, v in enumerate(clk_dt_swap):
                if v:
                    mask |= 1 << i
            cfg = (cfg & ~(0x7 << CONFIG_CLK_DT_SWAP_SHIFT)) | (mask << CONFIG_CLK_DT_SWAP_SHIFT)
        self.write_config(cfg)
        return cfg

    # -- event polling ---------------------------------------------------------

    def poll(self, *, timestamp: float = 0.0) -> List[EncoderEvent]:
        """Read STATUS + DELTA_PACKED once and return the resulting events.

        When ``clear_on_read`` is enabled in CONFIG (the default), reading
        the registers also clears the latches inside the IP, so callers
        don't need to clear them by hand.
        """
        events: List[EncoderEvent] = []

        # NOTE: read DELTA first, then STATUS. With clear_on_read=1 the
        # STATUS read also clears all rotate latches; reading DELTA first
        # captures the accumulated raw delta from the latched window.
        packed = self.read_delta_packed()
        status = self.read_status()
        decoded = decode_status(status)
        deltas = unpack_delta(packed)

        for i in range(3):
            # rotate
            raw = deltas[i] + self._raw_carry[i]
            if self._edges_per_detent > 1 and raw != 0:
                # Quantise to detents; carry any remainder so several
                # partial polls still emit a rotate event eventually.
                if raw >= 0:
                    detents = raw // self._edges_per_detent
                    remainder = raw - detents * self._edges_per_detent
                else:
                    # Symmetric quantisation around zero (round toward zero)
                    abs_detents = (-raw) // self._edges_per_detent
                    detents = -abs_detents
                    remainder = raw - detents * self._edges_per_detent
                self._raw_carry[i] = remainder
                if detents != 0:
                    events.append(EncoderEvent(
                        kind="rotate", encoder_id=i,
                        delta=detents, raw_delta=raw - remainder,
                        timestamp=timestamp,
                    ))
            elif raw != 0:
                self._raw_carry[i] = 0
                events.append(EncoderEvent(
                    kind="rotate", encoder_id=i,
                    delta=raw, raw_delta=raw,
                    timestamp=timestamp,
                ))

            # short / long press
            if decoded["short_press"][i]:
                events.append(EncoderEvent(
                    kind="short_press", encoder_id=i, timestamp=timestamp,
                ))
            if decoded["long_press"][i]:
                events.append(EncoderEvent(
                    kind="long_press", encoder_id=i, timestamp=timestamp,
                ))

            # release edge (synthetic; the IP doesn't latch release)
            sw_level = decoded["sw_level"][i]
            if self._sw_level_prev[i] == 1 and sw_level == 0:
                events.append(EncoderEvent(
                    kind="release", encoder_id=i, timestamp=timestamp,
                ))
            self._sw_level_prev[i] = sw_level

        return events
