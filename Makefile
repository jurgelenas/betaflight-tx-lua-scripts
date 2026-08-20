DIR := ${CURDIR}

.PHONY: help all files clean release manifest manifest-check sync push

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "  files           Build obj/ and parse-check every script with luac"
	@echo "  release         Build and zip obj/ into release/"
	@echo "  clean           Empty obj/"
	@echo "  manifest        Regenerate the COMPILE script manifest"
	@echo "  manifest-check  Fail if the committed manifest is out of date"
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
