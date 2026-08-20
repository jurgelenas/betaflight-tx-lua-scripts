DIR := ${CURDIR}
SRC_DIR := src
# bin holds the layout harness and its fixtures -- Lua we maintain, so it is
# formatted alongside src even though it never ships.
FMT_DIRS := src bin

LUALS_VERSION := 3.17.1
LUALS_DIR := bin/lua-language-server
LUALS := $(LUALS_DIR)/bin/lua-language-server
LUALS_URL := https://github.com/LuaLS/lua-language-server/releases/download/$(LUALS_VERSION)/lua-language-server-$(LUALS_VERSION)-linux-x64.tar.gz

LAYOUT_GOLDEN := bin/layout.golden.csv
LAYOUT_SD := obj/layout-sd
# bin/layout_dump.lua runs host-side in the simulator process, not on the radio;
# --script is just the only Lua interpreter available. gx12 boots fastest and
# the choice does not reach the output. Kept out of `check` because it wants a
# simulator image, which a lint job should not have to download.
LAYOUT_ENV := BF_SRC=src BF_OUT=obj/layout.csv
LAYOUT_SIM := edgetx-cli dev simulator --radio gx12 --headless \
	--sdcard $(LAYOUT_SD) --script bin/layout_dump.lua --timeout 300s

.PHONY: help all files clean release manifest manifest-check \
	install-tools install-stylua install-luals \
	format format-check typecheck check layout-check layout-golden sim-bw sim-color sync push

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "  files           Build obj/ and parse-check every script with luac"
	@echo "  release         Build and zip obj/ into release/"
	@echo "  clean           Empty obj/"
	@echo "  manifest        Regenerate the COMPILE script manifest"
	@echo "  manifest-check  Fail if the committed manifest is out of date"
	@echo "  install-tools   Install stylua and lua-language-server"
	@echo "  install-stylua  Install stylua (via cargo)"
	@echo "  install-luals   Install lua-language-server"
	@echo "  format          Format Lua files with stylua"
	@echo "  format-check    Check formatting without modifying files"
	@echo "  typecheck       Run lua-language-server type checking"
	@echo "  check           Run manifest-check, format-check and typecheck"
	@echo "  layout-check    Diff page geometry against bin/layout.golden.csv (needs the simulator)"
	@echo "  layout-golden   Recapture bin/layout.golden.csv"
	@echo "  sim-bw          Screenshot the B&W tool into obj/sim/ (needs the simulator)"
	@echo "  sim-color       Screenshot the colour tool into obj/sim-color/ (needs the simulator)"
	@echo "  sync            Sync source files to EdgeTX simulator SD card"
	@echo "  push            Install package to EdgeTX radio and eject"

all:	files

files:
	@bin/build.sh

clean:
	@rm -rf obj/*

manifest:
	@bin/manifest.sh

manifest-check:
	@bin/manifest.sh --check

install-stylua:
	@command -v cargo >/dev/null 2>&1 || { echo "cargo is required (install Rust: https://rustup.rs)"; exit 1; }
	cargo install stylua --features lua53

install-luals:
	mkdir -p $(LUALS_DIR)
	curl -fSL $(LUALS_URL) | tar xz -C $(LUALS_DIR)

install-tools: install-stylua install-luals

format:
	stylua $(FMT_DIRS)

format-check:
	stylua --check $(FMT_DIRS)

typecheck:
	$(LUALS) --check .

check: manifest-check format-check typecheck

layout-check:
	@mkdir -p obj $(LAYOUT_SD)
	@$(LAYOUT_ENV) BF_SUM=obj/layout.sum.csv BF_CMP=$(LAYOUT_GOLDEN) $(LAYOUT_SIM) >obj/layout.log 2>&1 \
		|| { grep -a layout_dump obj/layout.log; exit 1; }
	@grep -a layout_dump obj/layout.log

sim-bw:
	@rm -rf obj/sim obj/sim-sd
	@mkdir -p obj/sim obj/sim-sd
	@edgetx-cli dev simulator --radio gx12 --headless --sdcard obj/sim-sd \
		--script bin/sim/bw.lua --timeout 120s >obj/sim.log 2>&1 \
		|| { tail -20 obj/sim.log; exit 1; }
	@md5sum obj/sim/*.png

sim-color:
	@rm -rf obj/sim-color obj/sim-color-sd
	@mkdir -p obj/sim-color obj/sim-color-sd
	@edgetx-cli dev simulator --radio "RadioMaster TX16S" --headless --sdcard obj/sim-color-sd \
		--script bin/sim/color.lua --timeout 120s >obj/sim-color.log 2>&1 \
		|| { tail -20 obj/sim-color.log; exit 1; }
	@md5sum obj/sim-color/*.png

layout-golden:
	@mkdir -p obj $(LAYOUT_SD)
	@$(LAYOUT_ENV) BF_SUM=$(LAYOUT_GOLDEN) $(LAYOUT_SIM) >obj/layout.log 2>&1 \
		|| { grep -a layout_dump obj/layout.log; exit 1; }
	@grep -a layout_dump obj/layout.log

sync:
	edgetx-cli dev sync ../edgetx-sdcard

push:
	edgetx-cli pkg install . --eject

release: clean files
	@RELEASE_DIR=release; \
	FILE_NAME="betaflight-tx-lua-scripts_$$(git describe --abbrev=0 --tags).zip"; \
	mkdir -p $${RELEASE_DIR}; \
	rm -f $${RELEASE_DIR}/$${FILE_NAME}; \
	zip -q -r $${RELEASE_DIR}/$${FILE_NAME} obj/
