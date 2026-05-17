"""Offline HDMI frame analysis helpers.

These helpers are intentionally pure NumPy. They are used by local tests and
diagnostic scripts to verify that the compact-v2 renderer paints the real UI
panels near the framebuffer origin without importing PYNQ or touching HDMI
hardware.
"""
from __future__ import print_function

import numpy as np


def non_background_bbox(frame, background=(3, 8, 4), tol=12):
    """Return ``(min_x, max_x, min_y, max_y)`` for pixels above background.

    ``None`` means the frame is effectively all background. This is useful as
    a broad smoke check, but it is not enough to prove the actual UI panel
    body is left-aligned because corner markers and scanlines can populate
    x=0 while the panel body is shifted.
    """
    arr = np.asarray(frame)
    bg = np.array(background, dtype=np.int32)
    diff = np.abs(arr.astype(np.int32) - bg[None, None, :]).sum(axis=2)
    mask = diff > int(tol)
    cols = mask.any(axis=0)
    rows = mask.any(axis=1)
    if not cols.any() or not rows.any():
        return None
    xs = np.where(cols)[0]
    ys = np.where(rows)[0]
    return int(xs[0]), int(xs[-1]), int(ys[0]), int(ys[-1])


def _strong_ui_mask(frame):
    """Detect bright UI strokes while ignoring most background texture."""
    arr = np.asarray(frame).astype(np.int16)
    if arr.ndim != 3 or arr.shape[2] < 3:
        raise ValueError("frame must be an HxWx3 RGB array")
    r = arr[:, :, 0]
    g = arr[:, :, 1]
    b = arr[:, :, 2]

    # Pip-Boy green theme: panel borders / active strokes have a strong green
    # channel. Cyan theme: active strokes have high G+B. Amber bypass chips
    # must also count as real UI.
    green = (g >= 90) & (g >= r + 18) & (g >= b + 18)
    cyan = (g >= 120) & (b >= 120) & (r <= 170)
    amber = (r >= 145) & (g >= 85) & (b <= 120)
    bright = (r + g + b) >= 330
    return green | cyan | amber | bright


def _candidate_columns(mask, y0, y1, min_count=36):
    h = mask.shape[0]
    y0 = max(0, min(h, int(y0)))
    y1 = max(y0, min(h, int(y1)))
    counts = mask[y0:y1, :].sum(axis=0)
    return [int(x) for x in np.where(counts >= int(min_count))[0]]


def _candidate_rows(mask, x0, x1, min_count=120):
    w = mask.shape[1]
    x0 = max(0, min(w, int(x0)))
    x1 = max(x0, min(w, int(x1)))
    counts = mask[:, x0:x1].sum(axis=1)
    return [int(y) for y in np.where(counts >= int(min_count))[0]]


def _first_or_none(values):
    return values[0] if values else None


def _last_or_none(values):
    return values[-1] if values else None


def analyze_frame(frame, background=(3, 8, 4)):
    """Return origin diagnostics for an 800x480 compact-v2 RGB frame.

    The returned dict keeps the Phase 6G field names used by tests and board
    diagnostics. The detector is based on continuous bright UI strokes, so it
    ignores small corner markers that only prove the canvas origin, not the
    main panel origin.
    """
    arr = np.asarray(frame)
    if arr.ndim != 3 or arr.shape[2] < 3:
        raise ValueError("frame must be an HxWx3 RGB array")
    height, width = int(arr.shape[0]), int(arr.shape[1])
    mask = _strong_ui_mask(arr[:, :, :3])

    # Exclude the first/last few pixels from continuity checks so TL/TR/BL/BR
    # markers do not masquerade as panel borders.
    edge = 18
    inner_x0 = min(width, edge)
    inner_x1 = max(inner_x0, width - edge)
    inner_y0 = min(height, edge)
    inner_y1 = max(inner_y0, height - edge)

    vertical = _candidate_columns(mask, inner_y0, inner_y1, min_count=48)
    horizontal = _candidate_rows(mask, inner_x0, inner_x1, min_count=160)
    panel_left_hint = _first_or_none(vertical)
    min_panel_x = inner_x0 if panel_left_hint is None else panel_left_hint

    header_cols = _candidate_columns(mask, 20, 100, min_count=34)
    chain_cols = _candidate_columns(mask, 110, 250, min_count=50)
    selected_cols = _candidate_columns(mask, 260, 454, min_count=58)
    header_cols = [x for x in header_cols if min_panel_x <= x < inner_x1]
    chain_cols = [x for x in chain_cols if min_panel_x <= x < inner_x1]
    selected_cols = [x for x in selected_cols if min_panel_x <= x < inner_x1]

    left_estimates = [
        _first_or_none(header_cols),
        _first_or_none(chain_cols),
        _first_or_none(selected_cols),
    ]
    left_estimates = [v for v in left_estimates if v is not None]
    main_left = min(left_estimates) if left_estimates else None

    strong_bbox = None
    if vertical and horizontal:
        strong_bbox = [
            _first_or_none(vertical),
            _last_or_none(vertical),
            _first_or_none(horizontal),
            _last_or_none(horizontal),
        ]

    return {
        "shape": list(arr.shape),
        "non_background_bbox": non_background_bbox(
            arr[:, :, :3], background=background),
        "strong_ui_bbox": strong_bbox,
        "vertical_border_candidates": vertical,
        "horizontal_border_candidates": horizontal,
        "estimated_outer_frame_left_x": _first_or_none(vertical),
        "estimated_header_left_x": _first_or_none(header_cols),
        "estimated_chain_left_x": _first_or_none(chain_cols),
        "estimated_selected_panel_left_x": _first_or_none(selected_cols),
        "estimated_main_panel_left_x": main_left,
    }


__all__ = [
    "analyze_frame",
    "non_background_bbox",
]
