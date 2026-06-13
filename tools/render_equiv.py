"""Render-equivalence harness for the compact_v2 renderer refactor.

Renders a matrix of (AppState x variant x theme) frames and prints a single
combined sha256 over every frame's raw RGB bytes. Run before and after the
refactor; the hash must be identical (deterministic render given a state).
"""
import sys, os, hashlib
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) if False else "/home/doi20/Desktop/Audio-Lab-PYNQ"
sys.path.insert(0, os.path.join(REPO, "GUI"))

import compact_v2
from compact_v2 import (
    render_frame_800x480, render_frame_800x480_compact_v2, AppState,
)
from compact_v2.layout import THEMES

EFFECTS = compact_v2.EFFECTS

def make_states():
    states = []
    # 1) default
    s = AppState(); s.t = 0.0
    states.append(s)
    # 2) all effects on, various selected effect/knob, model indices set
    for sel in range(len(EFFECTS)):
        s = AppState(); s.t = 0.0
        s.effect_on = [True] * len(s.effect_on)
        s.selected_effect = sel
        s.selected_knob = sel % 3
        s.dist_model_idx = (sel * 2) % 7
        s.amp_model_idx = sel % 6
        s.cab_model_idx = sel % 3
        s.overdrive_model_idx = sel % 6
        # nudge some knob values
        for nm in EFFECTS:
            s.all_knob_values.setdefault(nm, [])
        states.append(s)
    # 3) WAH source = pedal (exercises source_label path)
    s = AppState(); s.t = 0.0
    s.selected_effect = EFFECTS.index("Wah") if "Wah" in EFFECTS else 2
    if hasattr(s, "wah_source"): s.wah_source = "pedal"
    if hasattr(s, "wah_pedal_available"): s.wah_pedal_available = False
    states.append(s)
    # 4) bypass-all (active_n == 0) + encoder status flags
    s = AppState(); s.t = 0.0
    s.effect_on = [False] * len(s.effect_on)
    for f in ("edit_mode", "model_select_mode", "value_dirty", "apply_pending"):
        if hasattr(s, f): setattr(s, f, True)
    if hasattr(s, "last_control_source"): s.last_control_source = "encoder"
    if hasattr(s, "live_apply"): s.live_apply = True
    states.append(s)
    return states

def main():
    h = hashlib.sha256()
    n = 0
    states = make_states()
    theme_names = [t for t in THEMES]
    for s in states:
        # compact-v1 (logical) -- ignores theme
        arr = render_frame_800x480(s, variant="compact-v1")
        h.update(arr.tobytes()); n += 1
        # compact-v2 across all themes, both entry points + placement label
        for th in theme_names:
            arr = render_frame_800x480(s, variant="compact-v2", theme=th,
                                       placement_label="X1")
            h.update(arr.tobytes()); n += 1
            arr = render_frame_800x480_compact_v2(s, theme=th)
            h.update(arr.tobytes()); n += 1
    print("frames={} combined_sha256={}".format(n, h.hexdigest()))

if __name__ == "__main__":
    main()
