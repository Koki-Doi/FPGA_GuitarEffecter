PYTHON ?= python3

# C++ DSP prototypes (src/effects/*.cpp) were removed. The live DSP
# path is hw/ip/clash/src/LowPassFir.hs; CPU-side tests now cover only
# the Python control layer.

all: python

python:
	$(PYTHON) test_overlay_controls.py

run:
	@echo "C++ DSP prototypes were removed; nothing to run for tests/run."

check: python

clean:
	@true

.PHONY: all run python check clean
