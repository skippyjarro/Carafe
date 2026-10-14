# Carafe

Run Windows apps and games on Apple silicon Macs. Carafe manages bottles (isolated Windows
environments) on CrossOver-based Wine engines with Apple's D3DMetal, DXMT and DXVK for graphics.
Diablo IV runs through Battle.net on its CrossOver 26.3.0 engine.

## Install

1. Download `Carafe-<version>.dmg` from [Releases](https://github.com/skippyjarro/Carafe/releases),
   open it and drag Carafe to Applications.
2. Carafe isn't notarized, so the first launch is blocked: open System Settings → Privacy & Security
   and choose **Open Anyway**.
3. Install Rosetta if you haven't: `softwareupdate --install-rosetta --agree-to-license`.
4. In Carafe, click **Install Wine**. It downloads the engines from this repo's `engines-1` release.

Needs macOS 14 or later on an Apple silicon Mac.

## Build

```bash
swift test
Scripts/make-dmg.sh          # build/Carafe-<version>.dmg
```

`Scripts/engine/` rebuilds the CrossOver 26.3.0 engine from CodeWeavers' source
(`build-toolchain.sh`, then `build-engine.sh`), and `Scripts/package-release.sh` packages the
installed engines and their sources for the release.

## Credits

The engines are the work of Wine, CodeWeavers, Sikarugir, Apple and others. See [CREDITS.md](CREDITS.md).
