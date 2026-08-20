#!/usr/bin/env bash
#
# Generate src/SCRIPTS/BF/COMPILE/scripts.lua -- the list of every Lua file we
# ship. COMPILE/compile.lua walks it to pre-compile the tree on the radio, one
# file per run() frame, which is what keeps a cold 128x64 radio from running its
# ~40 KB Lua heap dry while parsing sources on demand.
#
# The list is committed rather than produced at build time because edgetx-cli
# installs straight from src/ and never runs bin/build.sh. Generating it into
# obj/ left every package-manager install with a manifest the tool could not
# find, and the tool died on its first frame.
#
# Usage:
#   bin/manifest.sh           rewrite the manifest in place
#   bin/manifest.sh --check   fail if the committed manifest is out of date

set -euo pipefail

cd "$(dirname "$0")/.."

MANIFEST=src/SCRIPTS/BF/COMPILE/scripts.lua

# Anything edgetx.yml marks `dev: true` is not installed on a radio, so
# compile.lua's assert(loadScript(script, 'c')) would kill the tool on its
# first frame if the manifest listed it.
DEV_ONLY='src/SCRIPTS/BFSimulator/*'

generate() {
    echo 'local scripts = {'
    # Sorted, so the committed file is reproducible -- find alone yields
    # directory order, which differs between machines and filesystems.
    # The manifest never lists itself; compile.lua has no reason to compile it.
    find src -name '*.lua' -type f ! -path "$MANIFEST" ! -path "$DEV_ONLY" -print |
        LC_ALL=C sort |
        sed 's|^src|    "|; s|$|",|'
    echo '}'
    echo 'return scripts[...]'
}

if [ "${1:-}" = "--check" ]; then
    if ! generate | diff -u "$MANIFEST" - >/dev/null 2>&1; then
        echo "bin/manifest.sh: $MANIFEST is out of date -- run 'make manifest'" >&2
        generate | diff -u "$MANIFEST" - || true
        exit 1
    fi
    exit 0
fi

generate >"$MANIFEST"
echo "wrote $MANIFEST ($(grep -c '^    "' "$MANIFEST") entries)"
