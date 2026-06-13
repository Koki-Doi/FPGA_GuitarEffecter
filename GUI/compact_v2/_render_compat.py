"""NumPy RandomState compatibility shim for the compact_v2 renderer.

Side-effect-free leaf extracted verbatim from ``renderer.py`` so the
independent helpers live in their own module; ``renderer.py`` re-imports
these names so ``from compact_v2.renderer import _rng`` keeps working.
"""
import numpy as np


class _RandomStateCompat:
    """Small adapter for NumPy 1.16, which has RandomState but no default_rng."""
    def __init__(self, seed=None):
        self._rng = np.random.RandomState(seed)

    def integers(self, low, high=None, size=None, dtype=None, endpoint=False):
        if high is None:
            low, high = 0, low
        if endpoint:
            high = high + 1
        values = self._rng.randint(low, high=high, size=size)
        if dtype is not None:
            if hasattr(values, "astype"):
                values = values.astype(dtype)
            else:
                values = np.asarray(values, dtype=dtype).item()
        return values

    def uniform(self, low=0.0, high=1.0, size=None):
        return self._rng.uniform(low, high, size)


def _rng(seed=None):
    if hasattr(np.random, "default_rng"):
        return np.random.default_rng(seed)
    return _RandomStateCompat(seed)
