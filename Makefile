DIR := ${CURDIR}
SRC_DIR := src
FMT_DIRS := src

LUALS_VERSION := 3.17.1
LUALS_DIR := bin/lua-language-server
LUALS := $(LUALS_DIR)/bin/lua-language-server
LUALS_URL := https://github.com/LuaLS/lua-language-server/releases/download/$(LUALS_VERSION)/lua-language-server-$(LUALS_VERSION)-linux-x64.tar.gz

.PHONY: help all files clean release manifest manifest-check \
	install-tools install-stylua install-luals \
	format format-check typecheck check sync push

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
