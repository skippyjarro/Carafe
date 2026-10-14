#!/bin/bash
# Installs Carafe's Wine engines into Carafe's Engines folder from Carafe's own GitHub release:
#   CrossOver 26.3.0  Wine 11, the default; runs Battle.net and Diablo IV.
#   CrossOver 24.0.7  Wine 9, for anything that misbehaves on 26.
# Each engine bundles its libraries and graphics layers (Apple D3DMetal, DXMT, DXVK, MoltenVK); see
# CREDITS.md. Pass engine versions (e.g. `install-wine.sh 26.3.0`) to install only those.
set -euo pipefail

ENGINES="$HOME/Library/Application Support/Carafe/Engines"
RELEASE="https://github.com/skippyjarro/Carafe/releases/download/engines-1"
CHECKSUMS=(  # version sha256 of carafe-engine-cx<version>.tar.xz
  "26.3.0 1db6b747a35a6f16592fff4145a99ae4fd4fdee0cc605176e0285e6dbdb9ab42"
  "24.0.7 b3bf4b1ed6418c656597908d5027ffc64b3b4f7c9c6ec72ab81f235ae4e18948"
)
WANTED=("$@")

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

for entry in "${CHECKSUMS[@]}"; do
  read -r version sha <<<"$entry"
  if [ ${#WANTED[@]} -gt 0 ] && [[ ! " ${WANTED[*]} " =~ " $version " ]]; then continue; fi
  DEST="$ENGINES/CrossOver $version"
  ARCHIVE="$TMP/engine-$version.tar.xz"

  # Replacing an engine while its programs are running would pull it out from under them.
  if pgrep -f "$DEST/wine/" >/dev/null; then
    echo "Error: Windows programs are still running on CrossOver $version." >&2
    echo "Use Quit All Programs in each bottle (or quit the programs), then install again." >&2
    exit 1
  fi

  echo "Downloading CrossOver $version..."
  curl -fsSL -o "$ARCHIVE" "$RELEASE/carafe-engine-cx$version.tar.xz"
  if [ "$(shasum -a 256 "$ARCHIVE" | cut -d' ' -f1)" != "$sha" ]; then
    echo "Checksum mismatch for CrossOver $version; the download is damaged or was tampered with." >&2
    exit 1
  fi

  echo "Installing CrossOver $version..."
  mkdir "$TMP/$version"
  tar -xJf "$ARCHIVE" -C "$TMP/$version"
  rm "$ARCHIVE"
  if [ ! -x "$TMP/$version/wine/bin/wine" ] || [ ! -d "$TMP/$version/Frameworks" ]; then
    echo "The CrossOver $version download did not contain the expected files." >&2
    exit 1
  fi
  mkdir -p "$ENGINES"
  rm -rf "$DEST"
  mv "$TMP/$version" "$DEST"
  xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
  echo "Installed $(DYLD_FALLBACK_LIBRARY_PATH="$DEST/Frameworks:/usr/lib" "$DEST/wine/bin/wine" --version) to $DEST"
done
