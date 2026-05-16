all: Pynq-Z2 wheel

wheel:
	python3 setup.py bdist_wheel

Pynq-Z2: ip
	make -C hw/Pynq-Z2

clean_Pynq-Z2:
	make -C hw/Pynq-Z2 clean

ip:
	make -C hw/ip

clean_ip:
	make -C hw/ip clean

python_tests:
	make -C tests python

# Note: the C++ DSP prototypes were removed (`docs/ai_context/DECISIONS.md`
# D13); the source of truth for the live DSP path is
# `hw/ip/clash/src/LowPassFir.hs` and its split modules under
# `hw/ip/clash/src/AudioLab/`. The earlier `cpp_tests` / `test_cpp`
# stub targets are gone too.

tests: python_tests

test: tests

clean: clean_Pynq-Z2 clean_ip

.PHONY: all wheel Pynq-Z2 clean_Pynq-Z2 ip clean_ip python_tests tests test clean
