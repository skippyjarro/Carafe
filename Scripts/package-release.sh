#!/bin/bash
# Packages the installed engines and the source code behind them into build/release/, ready to upload
# to the GitHub release that install-wine.sh downloads from. Prints the checksums to paste into it.
#
# Needs: `brew install xz` (multithreaded compression).
set -euo pipefail
cd "$(dirname "$0")/.."

ENGINES="$HOME/Library/Application Support/Carafe/Engines"
OUT="build/release"
CX_SOURCES=(  # version sha256 (CodeWeavers' source releases for the engines' Wine)
  "26.3.0 ac99c8ca4b3848f3e81784135f023df266b61c2345726ea55a50b3e030dd6872"
  "24.0.7 56749e926df9f0437dbcea259cf0bff6657a43871af50182887fe15a84fc2e4e"
)
mkdir -p "$OUT"

# Engines: each folder as installed (wine/, Frameworks/, carafe-shim.dylib) plus the credits.
for version in 26.3.0 24.0.7; do
  dir="$ENGINES/CrossOver $version"
  [ -x "$dir/wine/bin/wine" ] || { echo "Missing engine: $dir" >&2; exit 1; }
  echo "Packing CrossOver $version..."
  # macOS metadata (._ files, quarantine) stays out of the archive; symlinks inside stay links.
  COPYFILE_DISABLE=1 tar -cf - --no-mac-metadata -C "$dir" wine Frameworks carafe-shim.dylib -C "$PWD" CREDITS.md \
    | xz -T0 -6 > "$OUT/carafe-engine-cx$version.tar.xz"
done

# Sources: CodeWeavers' Wine source for both engines, Carafe's own changes to it, and where everything
# else comes from. Mirrored here so the engines stay buildable (and LGPL-compliant) if upstream moves.
SRC=$(mktemp -d)
for entry in "${CX_SOURCES[@]}"; do
  read -r version sha <<<"$entry"
  file="crossover-sources-$version.tar.gz"
  curl -fsSL -A "Mozilla/5.0 (Macintosh)" -o "$OUT/$file" "https://media.codeweavers.com/pub/crossover/source/$file"
  actual=$(shasum -a 256 "$OUT/$file" | cut -d' ' -f1)
  [ "$actual" = "$sha" ] || { echo "Checksum mismatch for $file" >&2; exit 1; }
done
mkdir "$SRC/carafe-engine-sources"
cp -R Scripts/engine Scripts/sysctl-shim.c Scripts/build-shim.sh CREDITS.md "$SRC/carafe-engine-sources/"
COPYFILE_DISABLE=1 tar -czf "$OUT/carafe-engine-sources.tar.gz" --no-mac-metadata -C "$SRC" carafe-engine-sources
rm -rf "$SRC"

(cd "$OUT" && shasum -a 256 *.tar.*)
