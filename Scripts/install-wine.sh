#!/bin/bash
# Installs Carafe's gaming engine: a CrossOver-source Wine build plus the libraries and
# graphics layers (Apple D3DMetal, DXMT, MoltenVK) it needs, into Carafe's Engines folder.
set -euo pipefail

ENGINES="$HOME/Library/Application Support/Carafe/Engines"
DEST="$ENGINES/CrossOver 24.0.7"
WINE_URL="https://github.com/Sikarugir-App/Engines/releases/download/v1.0/WS12WineCX24.0.7_7.tar.xz"
WINE_SHA="203f9e9fd6c2cc77e6525d798a434ced326145db34a356355e05659d3445fd1c"
SUPPORT_URL="https://github.com/Sikarugir-App/Template/releases/download/v1.0/Template-1.0.21.tar.xz"
SUPPORT_SHA="bbe996e4e4375318485953d0c7818b7b4b0a4dc1f13303bcc584f99f7602f78d"

# Replacing the engine while its programs are running would pull it out from under them.
if pgrep -f "$DEST/wine/" >/dev/null; then
  echo "Error: Windows programs are still running on this engine." >&2
  echo "Use Quit All Programs in each bottle (or quit the programs), then install again." >&2
  exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fetch() { # url sha256 name
  echo "Downloading $3..."
  curl -fsSL -o "$TMP/$3.tar.xz" "$1"
  local actual
  actual=$(shasum -a 256 "$TMP/$3.tar.xz" | cut -d' ' -f1)
  if [ "$actual" != "$2" ]; then
    echo "Checksum mismatch for $3: got $actual" >&2
    exit 1
  fi
  mkdir "$TMP/$3"
  tar -xJf "$TMP/$3.tar.xz" -C "$TMP/$3"
}

fetch "$WINE_URL" "$WINE_SHA" wine
fetch "$SUPPORT_URL" "$SUPPORT_SHA" support

FRAMEWORKS=$(find "$TMP/support" -maxdepth 3 -type d -name Frameworks | head -1)
if [ ! -x "$TMP/wine/wswine.bundle/bin/wine" ] || [ -z "$FRAMEWORKS" ]; then
  echo "The downloads did not contain the expected files." >&2
  exit 1
fi

echo "Installing..."
mkdir -p "$ENGINES"
rm -rf "$DEST"
mkdir "$DEST"
mv "$TMP/wine/wswine.bundle" "$DEST/wine"
mv "$FRAMEWORKS" "$DEST/Frameworks"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

# Install the small fix library Carafe injects into Wine (see sysctl-shim.c). The app bundle ships it
# prebuilt; run from a source checkout, it is built here instead, which needs Xcode's clang.
HERE="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$HERE/carafe-shim.dylib" ]; then
  cp "$HERE/carafe-shim.dylib" "$DEST/carafe-shim.dylib"
else
  "$HERE/build-shim.sh" "$DEST/carafe-shim.dylib" || true
fi

echo "Installed $(DYLD_FALLBACK_LIBRARY_PATH="$DEST/Frameworks:/usr/lib" "$DEST/wine/bin/wine" --version) to $DEST"

if [ ! -f "$DEST/carafe-shim.dylib" ]; then
  echo "Error: the network fix library is missing, so Battle.net will not be able to load games." >&2
  echo "Install Xcode's command line tools (xcode-select --install) and run the install again." >&2
  exit 1
fi
