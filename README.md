![](https://github.com/litegapps/litegapps.github.io/raw/master/pages/images/new_i.png)
# AweGapps

**AweGapps** is a custom Google Apps package for Android — a systemless,
open-source gapps focused on being small, efficient, and comprehensive.
It's flashed as a Magisk/Kopi module.

This repo is the **build tool**: shell scripts that package gapps files into
flashable zips. It is not the gapps files themselves — those are restored
from SourceForge (see [Building](#building) below).

Project website: [litegapps.github.io](https://litegapps.github.io) (upstream LiteGapps project; update this link after setting up AweGapps hosting).

## Requirements

``zip`` ``tar`` ``xz-utils`` ``unzip`` ``bash`` ``brotli`` ``curl``

### Termux
```bash
apt update && pkg upgrade && pkg install zip tar xz unzip bash brotli curl
```

### Ubuntu / Debian
```bash
sudo apt update && sudo apt upgrade -y && sudo apt install -y zip tar xz-utils unzip bash brotli curl
```

## Cloning

```bash
# https
git clone https://github.com/AweYuki/gapps.git
# ssh
git clone git@github.com:AweYuki/gapps.git
```

## Repo layout

| Path | What it is |
|---|---|
| `build.sh` | CLI + dispatcher (`restore`/`make`/`clean`). |
| `lib/litegapps.sh`, `lib/litegappsx.sh` | Per-product build logic (restore/make/clean). Builds `packages/` addons and stages modules automatically for variants with `modules=true`. |
| `installer/` | Flashable-zip installer payload (Kopi installer, `customize.sh`, `action.sh`, `module.prop`, ...). |
| `config` | Top-level build config — see [Configure](#configure). |
| `core/litegapps/<variant>/` | One dir per variant: `lite awe`. Each has its own `config`, and (after restore) `gapps/`, `files/`, `modules/`. `awe` is this fork's own package; its app list is the `awe` case of `_litegapps_module_whitelist()` in `lib/litegapps.sh` (override with `LG_PKGS_AWE`). |
| `core/litegappsx/microg/` | The `litegappsx` product — a microG-based build, enabled with `litegappsx.build=true` in `config`. |
| `packages/` | Addon/apk packaging tool used by variants with `modules=true` (awe). See `packages/README.md`. |
| `.github/workflows/` | Build & publish AweGapps to **your fork's** GitHub Releases via Actions — no VPS needed. See [Building via GitHub Actions](#building-via-github-actions). |

## Configure

Top-level `config`:

```
version=4.9                # version.code=49
codename=stable
name.builder=<your name>
build.status=official       # or unofficial / your name
set.time.stamp=true
date.time=202007122239

compression=br               # xz or br (brotli)
compression.level=1          # 1-9
zip.level=1                  # 1-9
zip.signer=false             # true/false

litegapps.build=true
litegapps.restore=lite       # comma-separated: lite,awe
litegapps.type=lite          # comma-separated, same list
litegapps.tar=single         # single or multi - reuse one files.tar across variants sharing gapps

litegappsx.build=true
litegappsx.restore=microg
litegappsx.type=microg
```

Per-variant `core/litegapps/<variant>/config`:

```
sdk=36                  # Android SDK / API level this zip is labelled as
arch=arm64               # arm64 only
restore.sdk=35            # actual gapps SDK to download - can differ from sdk=
restore.arch=arm64
modules=false             # true if this variant needs packages/ addons
name=AweGapps
dir_name=lite
desc=...

# optional gapps-source overrides:
restore.suffix=-lite       # fetch <sdk><suffix>.zip instead of <sdk>.zip
restore.filename=variant   # fetch a fixed name, e.g. variant.zip, ignoring sdk
```

## Building

Restore the binaries and gapps files first (needs internet):
```bash
sh build.sh restore
```

Build every variant/arch/sdk configured in `config`:
```bash
sh build.sh make
```

Build a single target, ignoring `config`:
```bash
bash build.sh make litegapps <variant> <arch> <sdk>
# example:
bash build.sh make litegapps lite arm64 35
```

Output: `output/litegapps/<arch>/<sdk>/<variant>/<date>/AweGapps-*.zip`

Reset the tree (removes downloads, output, logs):
```bash
sh build.sh clean
```

Variants with `modules=true` (awe) also
need addon packages — `build.sh make` builds and stages those automatically
via `packages/make`, no extra step required.

## Supported targets

| Architecture | Android versions |
|---|---|
| arm64 | Android 7.0 (SDK 24) and up |

Android 5.0, 5.1 and 6.0 (SDK 21-23) are no longer built on any architecture
(`MIN_SDK` in `build.sh`). Zips already released for them stay on the
download server and still install.

Only arm64 is built: arm (armeabi-v7a), x86 and x86_64 are no longer built at
all, so no source is restored and no zip is made for them. The rule lives in
`arch_supported()` / `target_supported()` in `build.sh` (copied into the
standalone `packages/make`) and is applied in both GitHub workflows.
Releases already published for those architectures still install.

## Building via GitHub Actions

Fork this repo and use the workflows under `.github/workflows/` to build and
publish straight to **your fork's** GitHub Releases — no SourceForge account,
SSH key, or VPS required:

- **`build-release-full.yml`** — builds every variant (`awe`, `lite` by
  default) for one arch/sdk target, including the `packages/`
  addon build. Restores/builds/cleans one variant at a time so the runner's
  disk never has to hold all of them at once. Configure `variants`/`arch`/`sdk`
  as workflow inputs, or push a tag like `full-v1`.
- **`build-release-lite.yml`** — builds `lite` only, across every SDK 29-36
  for arm64 as a GitHub Actions matrix (8 parallel jobs), publishing every
  zip produced to one release. Run manually,
  or push a tag like `lite-v1`.

Both use the built-in `GITHUB_TOKEN`, so no secrets need to be configured.

## Compression benchmark

![Benchmark](https://github.com/wahyu6070/Cloud/raw/main/project/litegapps/images/compres_lvl.jpg)

## Watch: building video

[<img src="https://img.youtube.com/vi/5ddkNReE2RE/maxresdefault.jpg" width="50%">](https://youtu.be/NiT2qBaYFdg?si=5VyyntICvjp5iseD)

## Download

[Click here](https://litegapps.github.io/)

## Social media

[Telegram](https://t.me/litegapps) · [XDA](https://forum.xda-developers.com/t/litegapps-systemless.4146013/)

## Credits and upstream notices

AweGapps is a renamed fork of [LiteGapps](https://github.com/litegapps/litegapps), originally developed by The LiteGapps Project. The existing MIT license files and upstream copyright notices are retained. The installer also includes components with their own licenses; see `installer/LICENSE` and `packages/utils/LICENSE` for notices covering Google APKs, GNU Tar, Info-ZIP, and XZdec.

Credits: [The LiteGapps Project](https://github.com/litegapps) · [wahyu6070](https://github.com/wahyu6070) (controller and installer components) · [microG Project](https://microg.org/) · [ale5000 / microg-unofficial-installer](https://github.com/micro5k/microg-unofficial-installer) (microG APKs and permission XMLs) · [OpenGApps](https://opengapps.org/) · [APKPure](https://apkpure.com/) · [Kopi Installer](https://github.com/wahyu6070/Kopi-installer). The LiteGapps website and social links above remain upstream links.

The `litegappsx` (microG) build downloads only the Apache-2.0 microG APKs and
CC0-1.0 permission XMLs from microg-unofficial-installer; none of its GPL-3.0
installer code is used, so this repo stays MIT. Attribution is in
`installer/LICENSE`.
