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

cpp_tests:
	make -C tests run

test_cpp: cpp_tests

clean: clean_Pynq-Z2 clean_ip

.PHONY: all wheel Pynq-Z2 clean_Pynq-Z2 ip clean_ip cpp_tests test_cpp clean
