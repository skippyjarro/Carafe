# Credits

Carafe is a front end. The software that actually runs Windows programs is the work of the projects
below, redistributed in Carafe's engine downloads under their own licences. Each component's licence
file ships next to it inside the engine.

## Wine engines

| Component | Author | Licence | Source |
|---|---|---|---|
| Wine | The Wine project | LGPL 2.1+ | https://gitlab.winehq.org/wine/wine |
| CrossOver's Wine (both engines) | CodeWeavers | LGPL 2.1+ | https://www.codeweavers.com/crossover/source (mirrored in this repo's `engines-1` release) |
| CrossOver 24.0.7 engine build and its library bundle | Sikarugir (Gcenx) | LGPL 2.1 | https://github.com/Sikarugir-App/Engines, https://github.com/Sikarugir-App/Template, https://github.com/Sikarugir-App/Sikarugir-foss-sources |
| CrossOver 26.3.0 engine build | Carafe | LGPL 2.1+ | `Scripts/engine/` (patches, plugin and build scripts) |
| Wine Mono | The Wine project | MIT and others | https://gitlab.winehq.org/mono/wine-mono |
| Wine Gecko | The Wine project / Mozilla | MPL 2.0 | https://dl.winehq.org/wine/wine-gecko/ |

## Graphics layers

| Component | Author | Licence |
|---|---|---|
| D3DMetal (Game Porting Toolkit) | Apple Inc. | Apple Game Porting Toolkit licence, `Frameworks/renderer/d3dmetal/License.rtf`. Redistributed in its entirety, free of charge, for use on Apple-branded hardware only. |
| DXMT | Feifan He for CodeWeavers | LGPL 2.1+ |
| DXVK, D9VK | Philip Rebohle, Joshua Ashton and contributors | zlib |
| cnc-ddraw | FunkyFr3sh | MIT |
| MoltenVK | The Khronos Group | Apache 2.0 |
| KosmicKrisp Vulkan driver (Mesa) | The Mesa project | MIT |
| Vulkan loader | The Khronos Group | Apache 2.0 |

## Libraries

GStreamer (LGPL 2.1+), FreeType (FreeType licence), GnuTLS (LGPL 2.1+), Nettle (LGPL 3 / GPL 2),
GMP (LGPL 3 / GPL 2), libtasn1 (LGPL 2.1+), p11-kit (BSD), libunistring and libidn2 (LGPL 3 / GPL 2),
GNU libiconv and gettext's libintl (LGPL 2.1+), ICU (Unicode licence), libxml2 and libxslt (MIT),
SDL 2 and 3 (zlib), zlib (zlib), Zstandard and LZ4 (BSD), Brotli (MIT), bzip2 (bzip2 licence),
libffi (MIT), libpng (libpng licence), libpcap (BSD), libinotify-kqueue (MIT).

## Build tools (not redistributed)

The CrossOver 26.3.0 engine's Windows libraries are compiled with GCC 13.4, binutils 2.41 and
mingw-w64 11.0.1 (`Scripts/engine/build-toolchain.sh`).
