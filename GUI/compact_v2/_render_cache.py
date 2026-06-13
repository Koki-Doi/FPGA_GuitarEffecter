"""RenderCache + change-driven render signatures for the compact_v2 renderer.

Side-effect-free leaf extracted verbatim from ``renderer.py``. ``RenderCache``
holds the per-frame PIL/NumPy caches; the two ``state_*_signature`` helpers
quantise ``AppState`` into the keys that drive the frame cache. ``renderer.py``
re-imports these names so the existing import surface is unchanged.
"""
from .knobs import EFFECTS
from .state import AppState


# =============================================================================
# RENDER CACHE / FAST RENDER PATH
# =============================================================================
class RenderCache:
    """Small, PYNQ-friendly cache for PIL/NumPy rendering.

    This is intentionally conservative: it avoids external dependencies and
    keeps only a handful of full-frame entries. The largest win is avoiding
    full redraws when the GUI state has not changed or when visual meters are
    throttled to lower FPS.
    """
    def __init__(self, visualizer_fps: float = 5.0, meter_fps: float = 10.0,
                 max_frame_entries: int = 8, pynq_static_mode: bool = False):
        self.visualizer_fps = float(visualizer_fps)
        self.meter_fps = float(meter_fps)
        self.max_frame_entries = int(max_frame_entries)
        self.pynq_static_mode = bool(pynq_static_mode)
        self.static_layers = {}
        self.semi_static_layers = {}
        self.text_cache = {}
        self.gradient_cache = {}
        self.mask_cache = {}
        self.glow_cache = {}
        self.knob_body_cache = {}
        self.chain_block_cache = {}
        self.meter_segment_cache = {}
        self.frame_cache = {}
        self.frame_cache_order = []
        self.last_static_key = None
        self.last_semistatic_key = None
        self.last_visualizer_time = 0.0
        self.last_meter_time = 0.0
        self.cached_visualizer_layer = None
        self.cached_meter_layer = None
        self.stats = {
            "frame_hits": 0,
            "frame_misses": 0,
            "static_hits": 0,
            "static_misses": 0,
            "semistatic_hits": 0,
            "semistatic_misses": 0,
            "text_hits": 0,
            "text_misses": 0,
            "gradient_hits": 0,
            "gradient_misses": 0,
            "visualizer_updates": 0,
            "meter_updates": 0,
        }

    def clear_frame_cache(self):
        self.frame_cache.clear()
        self.frame_cache_order.clear()

    def put_frame(self, key, arr):
        self.frame_cache[key] = arr
        self.frame_cache_order.append(key)
        while len(self.frame_cache_order) > self.max_frame_entries:
            old = self.frame_cache_order.pop(0)
            self.frame_cache.pop(old, None)




def make_pynq_static_render_cache(max_frame_entries: int = 8) -> RenderCache:
    """Cache profile for PYNQ HDMI static/change-driven display."""
    return RenderCache(visualizer_fps=0.0, meter_fps=0.0,
                       max_frame_entries=max_frame_entries,
                       pynq_static_mode=True)


def state_semistatic_signature(state: AppState):
    """State components that require the non-background UI to be redrawn.

    Do not include state.t directly; otherwise animation time invalidates the
    cache every frame and defeats throttling.
    """
    return (
        state.preset_id,
        state.preset_name,
        getattr(state, "preset_idx", None),
        tuple(state.chain),
        tuple(bool(v) for v in state.effect_on),
        int(state.selected_effect),
        int(state.selected_knob),
        tuple(int(round(v))
              for nm in EFFECTS
              for v in state.all_knob_values.get(nm, [])),
        getattr(state, "dist_model_idx", None),
        getattr(state, "amp_model_idx", None),
        getattr(state, "cab_model_idx", None),
        getattr(state, "overdrive_model_idx", None),
        bool(state.save_flash > 0),
        # Phase 7G+ live-apply status: include so the status strip refreshes
        # when the encoder runtime updates these fields.
        bool(getattr(state, "live_apply", True)),
        bool(getattr(state, "last_apply_ok", True)),
        str(getattr(state, "last_apply_message", "")),
        str(getattr(state, "last_unsupported_label", "")),
        bool(getattr(state, "edit_mode", False)),
        bool(getattr(state, "model_select_mode", False)),
        bool(getattr(state, "value_dirty", False)),
        bool(getattr(state, "apply_pending", False)),
        str(getattr(state, "last_control_source", "")),
    )


def state_dynamic_signature(state: AppState, cache: RenderCache):
    """Quantized dynamic state.

    Meters and visualizer are intentionally bucketed to lower update rates.
    This is the practical part that makes Tk/PYNQ display usable: frames between
    buckets can reuse the previous RGB array.
    """
    if getattr(cache, "pynq_static_mode", False):
        return ("static",)
    vf = float(cache.visualizer_fps)
    mf = float(cache.meter_fps)
    viz_bucket = 0 if vf <= 0 else int(float(state.t) * max(0.5, vf))
    meter_bucket = 0 if mf <= 0 else int(float(state.t) * max(1.0, mf))
    # Level values are intentionally not part of the key; they are sampled at
    # the beginning of each meter bucket. Including raw/quantized levels here
    # would invalidate the frame cache almost every tick and undo throttling.
    return (viz_bucket, meter_bucket)
