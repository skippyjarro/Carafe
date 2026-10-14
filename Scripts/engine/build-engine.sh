#!/bin/bash
# Builds Carafe's "CrossOver 26.3.0" engine: Wine 11 compiled from the source CodeWeavers publishes
# for CrossOver, plus the libraries and graphics layers of an already-installed Carafe engine.
#
# Needs: Xcode, Rosetta, and `brew install mingw-w64 bison` (plus Homebrew's freetype, gnutls and
# sdl2 for their headers). Takes roughly 20 minutes and 6 GB of scratch space on an M1 Pro.
set -euo pipefail

VERSION="26.3.0"
SOURCE_URL="https://media.codeweavers.com/pub/crossover/source/crossover-sources-$VERSION.tar.gz"
SOURCE_SHA="ac99c8ca4b3848f3e81784135f023df266b61c2345726ea55a50b3e030dd6872"
MONO_VERSION="10.4.1"  # must match MONO_VERSION in dlls/appwiz.cpl/addons.c
MONO_URL="https://dl.winehq.org/wine/wine-mono/$MONO_VERSION/wine-mono-$MONO_VERSION-x86.tar.xz"
MONO_SHA="a16606ef0724202e6a6848ece6e0cbba64d11e2f11aefe744af1d93c6d9f99bb"

HERE="$(cd "$(dirname "$0")" && pwd)"
ENGINES="$HOME/Library/Application Support/Carafe/Engines"
DONOR="$ENGINES/CrossOver 24.0.7"   # supplies Frameworks (dylibs, D3DMetal, DXMT, DXVK) and Gecko
DEST="$ENGINES/CrossOver $VERSION"
WORK="${CARAFE_ENGINE_WORK:-$HOME/Library/Caches/CarafeEngineBuild}"
BREW="$(brew --prefix)"

[ -d "$DONOR/Frameworks" ] || { echo "Install the CrossOver 24.0.7 engine first (Scripts/install-wine.sh)." >&2; exit 1; }
[ ! -e "$DEST" ] || { echo "$DEST already exists; remove it to rebuild." >&2; exit 1; }

fetch() { # url sha256 file
  [ -f "$3" ] || curl -fsSL -A "Mozilla/5.0 (Macintosh)" -o "$3" "$1"
  [ "$(shasum -a 256 "$3" | cut -d' ' -f1)" = "$2" ] || { echo "Checksum mismatch for $3" >&2; exit 1; }
}

mkdir -p "$WORK" && cd "$WORK"
fetch "$SOURCE_URL" "$SOURCE_SHA" cx.tar.gz
fetch "$MONO_URL" "$MONO_SHA" mono.tar.xz
if [ ! -d sources/wine ]; then
  tar -xzf cx.tar.gz sources/wine
  # Carafe's changes to Wine itself: per-application launch options (WINE_CMDLINE_APPEND).
  for patch in "$HERE"/patches/*.patch; do patch -d sources/wine -p1 < "$patch"; done
fi

# The donor's libraries are x86_64 and referenced by bare name, so the build links against them
# through a space-free path and is told their names instead of letting configure guess.
ln -sfn "$DONOR/Frameworks" fw
FW="$WORK/fw"
mkdir -p build && cd build
export PATH="$BREW/opt/bison/bin:$PATH"

arch -x86_64 ../sources/wine/configure --prefix=/opt/carafe-wine --enable-archs=i386,x86_64 --disable-tests \
  --without-x --without-gstreamer --without-ffmpeg --without-pulse --without-alsa --without-dbus \
  --without-sane --without-gphoto --without-cups --without-fontconfig --without-capi --without-v4l2 \
  --without-oss --without-usb --without-krb5 --without-inotify --without-pcap --without-pcsclite \
  --without-udev --without-wayland --without-netapi --without-opencl \
  CC="clang -arch x86_64" \
  FREETYPE_CFLAGS="-I$BREW/include/freetype2" FREETYPE_LIBS="-L$FW -lfreetype" \
  GNUTLS_CFLAGS="-I$BREW/include" GNUTLS_LIBS="-L$FW -lgnutls" \
  SDL2_CFLAGS="-I$BREW/include/SDL2" SDL2_LIBS="-L$FW -lSDL2" \
  ac_cv_lib_soname_freetype=libfreetype.6.dylib ac_cv_lib_soname_gnutls=libgnutls.30.dylib \
  ac_cv_lib_soname_SDL2=libSDL2-2.0.0.dylib ac_cv_lib_soname_MoltenVK=libMoltenVK.dylib

# The font tool runs during the build and must find FreeType and its dependencies; macOS strips
# DYLD_* variables from make, so it gets a search path baked in instead.
arch -x86_64 make -j"$(sysctl -n hw.ncpu)" tools/sfnt2fon/sfnt2fon.o
arch -x86_64 clang -arch x86_64 -m64 -o tools/sfnt2fon/sfnt2fon tools/sfnt2fon/sfnt2fon.o \
  -L"$FW" -lfreetype -Wl,-rpath,"$FW"
arch -x86_64 make -j"$(sysctl -n hw.ncpu)"

rm -rf "$WORK/stage"
arch -x86_64 make install DESTDIR="$WORK/stage" >/dev/null
STAGE="$WORK/stage/opt/carafe-wine"

# Drop headers, import libraries and debug data: 1.5 GB down to about 600 MB.
rm -rf "$STAGE/include"
find "$STAGE/lib/wine" -name "*.a" -delete
find "$STAGE/lib/wine/i386-windows" -type f -print0 | xargs -0 i686-w64-mingw32-strip --strip-debug 2>/dev/null || true
find "$STAGE/lib/wine/x86_64-windows" -type f -print0 | xargs -0 x86_64-w64-mingw32-strip --strip-debug 2>/dev/null || true
strip -S "$STAGE"/lib/wine/x86_64-unix/*.so "$STAGE/bin/wine" "$STAGE/bin/wineserver" 2>/dev/null || true

# Without Mono and Gecko on disk, creating a bottle stalls for five minutes on a hidden prompt.
mkdir -p "$STAGE/share/wine/mono"
tar -xJf "$WORK/mono.tar.xz" -C "$STAGE/share/wine/mono"
cp -Rc "$DONOR/wine/share/wine/gecko" "$STAGE/share/wine/gecko"

# DXMT's helper has to sit among Wine's own libraries for its other DLLs to import it.
cp "$FW/renderer/dxmt/wine/x86_64-windows/winemetal.dll" "$STAGE/lib/wine/x86_64-windows/"
cp "$FW/renderer/dxmt/wine/x86_64-unix/winemetal.so" "$STAGE/lib/wine/x86_64-unix/"

# Carafe's graphics-layer plugin (see cxcompatdb.c).
xcrun clang -arch x86_64 -bundle -O2 -mmacosx-version-min=11.0 \
  -o "$STAGE/lib/wine/x86_64-unix/cxcompatdb.so" "$HERE/cxcompatdb.c"
codesign -f -s - "$STAGE/lib/wine/x86_64-unix/cxcompatdb.so"

mkdir "$DEST"
cp -Rc "$STAGE" "$DEST/wine"
cp -Rc "$DONOR/Frameworks" "$DEST/Frameworks"
# The network bug the shim works around is gone in this Wine, but the engine was tested with it in place.
[ ! -f "$DONOR/carafe-shim.dylib" ] || cp "$DONOR/carafe-shim.dylib" "$DEST/"
echo "Installed $(DYLD_FALLBACK_LIBRARY_PATH="$DEST/Frameworks:/usr/lib" "$DEST/wine/bin/wine" --version) to $DEST"
