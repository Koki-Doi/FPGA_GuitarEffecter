ip := ./vhdl/component.xml

CLASH ?= clash
CLASH_PRELUDE_PACKAGE_ID ?= clash-prelude-1.8.1-043657e64d575898396c414bafaea7f08fdd2ba6b4085ce0bd624cd91d00144c
CLASH_PACKAGE_FLAGS := $(if $(strip $(CLASH_PRELUDE_PACKAGE_ID)),-package-id $(CLASH_PRELUDE_PACKAGE_ID),)
CLASH_FLAGS ?= -isrc $(CLASH_PACKAGE_FLAGS) --vhdl

LIBS := LowPassFir

SRCS := $(foreach LIB, $(LIBS), ./src/$(LIB).hs)
AUDIO_LAB_SRCS := $(shell find ./src/AudioLab -name '*.hs' -type f | sort)
VHDLS := $(foreach LIB, $(LIBS), ./vhdl/$(LIB))
IPS := $(foreach VHDL, $(VHDLS), $(VHDL)/component.xml)

.PHONY: all clean regen

all: $(IPS)

vhdl/%/component.xml : vhdl/%
	vivado -mode batch -notrace -nojournal -nolog -source create_ip.tcl -tclargs "$<"

vhdl/%: src/%.hs $(AUDIO_LAB_SRCS)
	set -e; \
	tmp_dir=$$(mktemp -d); \
	$(CLASH) $(CLASH_FLAGS) -outputdir "$$tmp_dir" "$<"; \
	rm -rf "$@/$*.topEntity"; \
	mkdir -p "$@/$*.topEntity"; \
	cp "$$tmp_dir/$*.topEntity/"* "$@/$*.topEntity/"; \
	rm -rf "$$tmp_dir"
	find $@ -name '*.vhdl' -type f -print0 | xargs -0 sed -i 's/in [^[:space:]]*\.\(clk\|rst\).*;/in std_logic;/'
	touch "$@"

regen:
	rm -rf $(VHDLS)
	$(MAKE) all

clean:
	rm -rf vhdl *.jou *.log NA
	find src \( -name '*.hi' -o -name '*.o' \) -delete
