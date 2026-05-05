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

# C++ DSP prototypes were removed; the source of truth for the live
# DSP path is hw/ip/clash/src/LowPassFir.hs. cpp_tests / test_cpp
# stay as deprecated targets so older invocations do not error out.
cpp_tests:
	@echo "C++ DSP prototypes were removed; FPGA DSP source of truth is hw/ip/clash/src/LowPassFir.hs"

test_cpp: cpp_tests

tests: python_tests

test: tests

clean: clean_Pynq-Z2 clean_ip

.PHONY: all wheel Pynq-Z2 clean_Pynq-Z2 ip clean_ip cpp_tests python_tests tests test test_cpp clean
