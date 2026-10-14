#!/bin/bash
# Builds and ad-hoc signs the fix library Carafe injects into Wine (see sysctl-shim.c).
# Usage: build-shim.sh <output.dylib>
set -euo pipefail

xcrun clang -arch x86_64 -dynamiclib -O2 -mmacosx-version-min=11.0 -o "$1" "$(dirname "$0")/sysctl-shim.c"
codesign -f -s - "$1"
