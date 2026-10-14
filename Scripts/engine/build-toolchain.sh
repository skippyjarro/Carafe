#!/bin/bash
# Builds the MinGW cross compiler Carafe's engines must be built with: GCC 13 and binutils 2.41,
# the toolchain CodeWeavers uses for CrossOver 26.
#
# Why not Homebrew's mingw-w64: Wine's core DLLs (ntdll, kernelbase, kernel32) built with GCC 16
# make Diablo IV's anti-tamper loader crash at startup, while the same source built with GCC 13
# runs. GCC 13.4 rather than 13.2 because 13.2's host tools don't build against current Xcode.
#
# Needs: Xcode and `brew install gmp mpfr libmpc isl`. Takes about 15 minutes on an M1 Pro.
# Installs into ~/Library/Caches/CarafeMingw13/prefix; build-engine.sh looks for it there.
set -euo pipefail

M="${CARAFE_MINGW:-$HOME/Library/Caches/CarafeMingw13}"; P=$M/prefix; SRC=$M/src; J=$(sysctl -n hw.ncpu)
B="$(brew --prefix)/opt"
mkdir -p "$SRC"

fetch() { # url sha256
  local file="$SRC/$(basename "${1%/download}")"
  [ -f "$file" ] || curl -fsSL -L -o "$file" "$1"
  [ "$(shasum -a 256 "$file" | cut -d' ' -f1)" = "$2" ] || { echo "Checksum mismatch for $file" >&2; exit 1; }
  tar -xf "$file" -C "$SRC"
}
fetch https://ftp.gnu.org/gnu/binutils/binutils-2.41.tar.xz ae9a5789e23459e59606e6714723f2d3ffc31c03174191ef0d015bdf06007450
fetch https://ftp.gnu.org/gnu/gcc/gcc-13.4.0/gcc-13.4.0.tar.xz 9c4ce6dbb040568fdc545588ac03c5cbc95a8dbf0c7aa490170843afb59ca8f5
fetch https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/mingw-w64-v11.0.1.tar.bz2/download \
  3f66bce069ee8bed7439a1a13da7cb91a5e67ea6170f21317ac7f5794625ee10

export PATH="$P/bin:$PATH"
for T in x86_64-w64-mingw32 i686-w64-mingw32; do
  echo "=== $T binutils"
  rm -rf "$M/b-binutils-$T"; mkdir -p "$M/b-binutils-$T"; cd "$M/b-binutils-$T"
  # binutils' bundled zlib doesn't compile against the current macOS SDK.
  "$SRC/binutils-2.41/configure" --target=$T --prefix="$P" --with-sysroot="$P" --disable-multilib \
    --disable-nls --disable-werror --with-system-zlib >log 2>&1
  make -j$J MAKEINFO=true >>log 2>&1; make MAKEINFO=true install >>log 2>&1

  echo "=== $T headers"
  rm -rf "$M/b-hdr-$T"; mkdir -p "$M/b-hdr-$T"; cd "$M/b-hdr-$T"
  "$SRC/mingw-w64-v11.0.1/mingw-w64-headers/configure" --host=$T --prefix="$P/$T" >log 2>&1
  make install >>log 2>&1
  ln -sfn "$P/$T" "$P/mingw"

  echo "=== $T gcc"
  rm -rf "$M/b-gcc-$T"; mkdir -p "$M/b-gcc-$T"; cd "$M/b-gcc-$T"
  "$SRC/gcc-13.4.0/configure" --target=$T --prefix="$P" --with-sysroot="$P" --disable-multilib \
    --enable-languages=c --disable-nls --disable-shared --enable-threads=win32 --disable-libssp \
    --disable-libquadmath --disable-libgomp --disable-libatomic --disable-lto \
    --with-gmp="$B/gmp" --with-mpfr="$B/mpfr" --with-mpc="$B/libmpc" --with-isl="$B/isl" --with-system-zlib >log 2>&1
  make -j$J MAKEINFO=true all-gcc >>log 2>&1; make MAKEINFO=true install-gcc >>log 2>&1

  echo "=== $T runtime"
  rm -rf "$M/b-crt-$T"; mkdir -p "$M/b-crt-$T"; cd "$M/b-crt-$T"
  if [ $T = i686-w64-mingw32 ]; then L="--enable-lib32 --disable-lib64"; else L="--enable-lib64 --disable-lib32"; fi
  "$SRC/mingw-w64-v11.0.1/mingw-w64-crt/configure" --host=$T --prefix="$P/$T" $L >log 2>&1
  make -j$J >>log 2>&1; make install >>log 2>&1

  echo "=== $T libgcc"
  cd "$M/b-gcc-$T"; make -j$J all-target-libgcc >>log 2>&1; make install-target-libgcc >>log 2>&1
  echo "=== $($P/bin/$T-gcc --version | head -1)"
done
