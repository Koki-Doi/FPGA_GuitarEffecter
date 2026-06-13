#!/usr/bin/env bash
# Build the offline DSP sim harness (tools/dsp_sim/dsp_sim).
# Run after any DSP-source edit (hw/ip/clash/src/**.hs or Sim.hs).
set -e
cd "$(dirname "$0")/../.."   # repo root
PKGID="${CLASH_PRELUDE_PACKAGE_ID:-clash-prelude-1.8.1-043657e64d575898396c414bafaea7f08fdd2ba6b4085ce0bd624cd91d00144c}"
clash -O1 -ihw/ip/clash/src -itools/dsp_sim -package-id "$PKGID" \
  tools/dsp_sim/Sim.hs -o tools/dsp_sim/dsp_sim -outputdir /tmp/dsp_sim_build
echo "built tools/dsp_sim/dsp_sim"
