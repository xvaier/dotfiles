#!/bin/sh
# Run the extension tests against the Pi package used by the managed install.
# Set PI_NODE_MODULES to point at another node_modules directory.
set -eu
cd "$(dirname "$0")/.."
exec node --import ./tests/pi-modules.mjs --test tests/*.test.ts tests/*.test.mts
