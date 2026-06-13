#!/usr/bin/env bash
#
# Local CI gate (Tier 3). This repo is local-only -- git push/pull/fetch are
# forbidden, so there is no remote CI; run this before committing instead.
#
#   scripts/check.sh          # fast: py_compile + Python test suite
#   scripts/check.sh --dsp    # also run the offline DSP regression (needs clash, ~1 min)
#
# Exit 0 = all green, non-zero = something failed.
set -u
cd "$(dirname "$0")/.."

fail=0
section() {
  local name="$1"; shift
  echo ""
  echo "=== ${name} ==="
  if "$@"; then echo "  -> OK"; else echo "  -> FAIL"; fail=1; fi
}

# 1. byte-compile every tracked Python file (catches syntax errors repo-wide)
section "py_compile (all tracked .py)" \
  bash -c 'git ls-files "*.py" | xargs -r python3 -m py_compile'

# 2. Python test suite (control layer / GUI / encoder / footswitch / HDMI state)
section "pytest tests/" \
  python3 -m pytest tests/ -q -p no:cacheprovider

# 3. optional: offline DSP regression (safe-bypass invariant + golden vectors).
#    Opt-in because it needs `clash` + a ~1 min harness (re)build.
if [ "${1:-}" = "--dsp" ]; then
  section "DSP sim regression (bypass + goldens)" \
    env DSP_SIM_TESTS=1 python3 -m pytest tests/test_dsp_sim_regression.py -q -p no:cacheprovider
fi

echo ""
if [ "$fail" -eq 0 ]; then
  echo "================  ALL CHECKS PASSED  ================"
else
  echo "================  CHECKS FAILED  ===================="
fi
exit "$fail"
