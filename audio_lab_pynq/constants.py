"""Project-wide constants -- single source of truth for values that several
modules and scripts would otherwise hardcode.

This module has NO third-party dependencies (no pynq / numpy), so it is safe to
import from anywhere, including standalone scripts.
"""

# Audio sample rate. The Pmod I2S2 codec runs CS4344/CS5343 double-speed at
# 96 kHz as of D98 (was 48000 through D97; BCLK = MCLK/2, MCLK still 12.288 MHz
# = 128 fs). See docs/ai_context/DECISIONS.md D98. Anything that needs "samples
# per second" (frame-count expectations, FS for spectral analysis, ~1 s capture
# defaults) should import this rather than hardcoding the number.
SAMPLE_RATE_HZ = 96000
