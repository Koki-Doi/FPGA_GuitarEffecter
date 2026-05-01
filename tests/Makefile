CXX ?= g++
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra -pedantic -I..
PYTHON ?= python3

TARGETS := test_rat_style_distortion test_amp_cab_simulators

RAT_SOURCES := test_rat_style_distortion.cpp ../src/effects/RatStyleDistortion.cpp
AMP_CAB_SOURCES := test_amp_cab_simulators.cpp ../src/effects/SimpleAmpSimulator.cpp ../src/effects/CabIRSimulator.cpp

all: $(TARGETS)

test_rat_style_distortion: $(RAT_SOURCES) ../src/effects/RatStyleDistortion.h
	$(CXX) $(CXXFLAGS) $(RAT_SOURCES) -o $@

test_amp_cab_simulators: $(AMP_CAB_SOURCES) ../src/effects/SimpleAmpSimulator.h ../src/effects/CabIRSimulator.h
	$(CXX) $(CXXFLAGS) $(AMP_CAB_SOURCES) -o $@

run: $(TARGETS)
	./test_rat_style_distortion
	./test_amp_cab_simulators

python:
	$(PYTHON) test_overlay_controls.py

check: run python

clean:
	rm -f $(TARGETS)

.PHONY: all run python check clean
