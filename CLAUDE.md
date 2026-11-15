# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

AweGapps is a small, systemless Google Apps package for Android, flashed as a
Magisk/Kopi module. It is a renamed fork of LiteGapps; see README.md for credits.
**This repo is the build tool** that packages gapps files
into flashable zips. The build itself is entirely POSIX shell (`sh`/`bash`)
with no compiler and no test suite. There is no web panel and no service
component: builds run from a terminal (`build.sh`) or a GitHub workflow that
also publishes the release.

## Who builds this, and on what

The build runs on GitHub Actions and on local machines, and the devices
differ a lot:

- GitHub Actions runners (4 cores, 16 GB);
- a maintainer machine (8 cores, 24 GB RAM);
- ordinary Linux PCs and laptops of any size;
- **Android phones in Termux, without root** - often 4-8 slow cores that
  throttle when hot, 1-8 GB RAM, and an Android that kills processes which
  use too much memory.

So never tune the build for one machine. Anything that depends on the
hardware must adapt to the machine it runs on and fail safe on a small one:

- read the real core count (`nproc`) and **available** memory
  (`MemAvailable` in `/proc/meminfo`) at run time instead of assuming them,
  and fall back to one thread / one job when they cannot be read;
- keep the default the safe, sequential behaviour; extra parallelism is
  opt-in or capped by what the machine can afford (`xz_threads()` is the
  example: 8 threads on the VPS, 1 on a 1-3 GB phone);
- no root, no `sudo`, no system packages beyond what a normal Termux or
  Linux install has; `build.sh` runs under plain `sh`, so no bash-only
  syntax there (`PIPESTATUS`, arrays, `wait -n` belong in bash scripts only);
- never change the output to make a small machine cope (e.g. lowering the
  xz level behind the user's back) - warn in the log and let the builder
  decide; the official releases stay at `xz -9e` / zip 9.

Installing is a different matter: a finished zip only needs ~65 MiB to
decompress on the phone, whatever machine built it.

For the full working guide, see the `build-litegapps` skill
(`.claude/skills/build-litegapps/SKILL.md`). `AGENTS.md` is the short version
of the rules in this file, for agents that do not read this one.

## Build commands

Run from the repo root:

```bash
sh build.sh restore   # download bin.zip + gapps files (needs internet); run ONCE first
sh build.sh make      # build zips per config
sh build.sh clean     # reset tree (removes downloads, output, logs)

# build a single target, ignoring config:
bash build.sh make litegapps <variant> <arch> <sdk>   # e.g. lite arm64 36

# restore a single target, ignoring config (variants comma separated):
sh build.sh restore bin                               # bin.zip only
sh build.sh restore litegapps <variant,...> <arch> <sdk>
bash packages/make restore <arch> <sdk>
```

With no arguments both `restore` commands behave as before and read their
config (`litegapps.restore` + each variant's `restore.arch`/`restore.sdk`, and
`packages/config`); the arguments only override it.

Output: `output/litegapps/<arch>/<sdk>/<variant>/<date>/LiteGapps-*.zip`
Logs: `log/make.log` and `log/make_live.log` — **read these first when a build fails.**

## Layout

- `build.sh` — thin CLI/dispatcher + shared helpers (`get_config`, `make_zip`,
  `make_archive`, `make_tar_arch`, `get_android_version`, `printlog`, `del`, `cdir`,
  `clean_variant_dirs`). Subcommands `restore`/`make`/`clean` dispatch to the
  product functions in `lib/`. It has no upload step: releases are published by
  the GitHub workflows only.
- `installer/27-litegapps.sh` — addon.d script that keeps a Kopi (system) install
  across ROM updates. It is run by the ROM's backuptool in recovery
  (`backuptool.sh`, or `backuptool_ab.sh` at postinstall on A/B), once per stage
  and as a separate process. Follow that contract, never guess mount points:
  address files through `$S` (`$S/product/...`, `$S/system_ext/...`, which the
  V3 backuptool mounts), keep state in `$C` (A/B has no `/tmp`), and write only
  through `backup_file`/`restore_file`/`get_output_path` so A/B lands in the new
  slot under `/postinstall`. Keep the `. /tmp/backuptool.functions` line verbatim
  (backuptool_ab rewrites it) and use `exit`, not `return`, at top level. The
  install lists it replays (`list_install_<partition>`) are written by the Kopi
  `update-binary`, relative to each partition root. The previous version guessed
  `/mnt/product`, so GmsCore (product) and GSF (system_ext) were lost on every
  ROM update, and on A/B it restored nothing into the new slot.
- `lib/litegapps.sh` / `lib/litegappsx.sh` — per-product build logic, each exposing
  `<product>_restore`, `<product>_make`, `<product>_clean`. Sourced by `build.sh`.
  (This replaced the old `core/*/make.sh`, `core/litegapps/restore.sh`, and the
  per-variant `clean.sh` files — none of those exist any more.)
- `installer/` — flashable-zip installer payload copied into every zip (Kopi installer,
  `customize.sh`, `action.sh`, `module.prop`, `LICENSE`, post-fs scripts). Referenced as
  `$utils` in the build code. (Was `core/utils/`.) The build writes the zip's target
  into `module.prop` as `litegapps_arch=` / `litegapps_sdk=`, and `customize.sh`
  checks them against the device **before** touching `bin/<arch>`, so a wrong zip
  fails with "this zip is for arm, but this device is arm64" instead of a chmod
  error. On any failure `report_bug` writes the reason into the log before
  `make_log` packs it. The log is `[LOG]litegapps_<version>.tar.gz`, packed with
  the environment's own `tar`/`gzip` (toybox has `tar` since Android 7 and `gzip`
  since Android 9; Magisk/KernelSU/APatch busybox has both, and TWRP builds carry
  busybox or toybox) — never with a binary from the zip, which is absent on
  exactly that failure. `log_tool` finds them as linked applets on PATH, or
  through `busybox <applet>` / `toybox <applet>` for recoveries that ship the
  multi-call binary without applet symlinks. Without gzip it
  is a plain `.tar`; without tar the `log/` folder is kept. No `zip` binary is
  shipped in flashable zips any more.
- `config` — top-level build config (version, compression, which products/variants).
- `core/litegapps/<variant>/` — one dir per variant
  (`lite awe`), each with its own `config`,
  `restore/`, `gapps/`, `modules/`, `utils/README.md`. They do not all restore the
  same gapps zip - see "Variants and where their gapps come from" below, which
  is the rule lite hangs off.
- `core/litegappsx/` — second product, `microg` only, enabled by
  `litegappsx.build=true` in `config` (was off by default before 2026-11-14).
  Its components come from `micro5k/microg-unofficial-installer`: only the
  Apache-2.0 APKs and CC0-1.0 permission XMLs are downloaded, never its
  GPL-3.0 shell code, so this repo stays MIT. The restored tree keeps the
  `cross_system/` + `cross_sdk/<api>/` shape the installer expects.
- `packages/` — addon/apk packaging tool (a vendored standalone sub-project; called as a
  black box via `bash packages/make make $ARCH $SDK`, has its own `packages/utils` installer).
- `bin/`, `output/`, `files/`, gapps dirs, `*.zip/*.tar/*.apk`, logs — all gitignored.
  Careful with `.gitignore`: the artifact names there (`log`, `bin`, `output`,
  `tmp`) have no leading slash, so they match at **any** depth. Check
  `git check-ignore -v <path>` before assuming a new file is tracked.

## Conventions

- Match the existing shell style: tab indentation, config via `getp`/`get_config`/`read_config`,
  logging via `printlog`/`sedlog`, and `del`/`cdir` instead of raw `rm -rf`/`mkdir -p`.
- **Write everything inside files in English** — `#` comments, `print`/`ui_print` strings,
  log messages, commit messages. This is an English-language project. Some legacy
  Indonesian comments exist in the tree; do not add more, and do not mirror the
  language of the chat into the code (replying to the user in Indonesian is fine).
- `restore` hits the network (SourceForge, GitHub). The gapps sources are
  downloaded, never uploaded; publishing happens in the workflows.
- Do not commit generated/gitignored artifacts.
- Only commit or push when the user asks.

## Variants and where their gapps come from

The variants are **not** the same files with different app lists: two
different gapps bases feed them, which is why several rules elsewhere in this
file key on the variant.

| Variant | gapps zip restored | Set by |
|---|---|---|
| awe | `<sdk>.zip` | (default) |
| lite | `<sdk>-lite.zip`, falling back to `<sdk>.zip` when the server has none | `restore.suffix=-lite` |

This fork keeps only `lite` and `awe`. core, go, micro, nano, user,
superlite, pixel and basic were removed; do not add them back.

## Reading a failed build

Failures are almost always the **sources**, not the build code, so read the
reason in `log/make_live.log` before touching anything:

- `restore gagal` with `! <path> is not on SourceForge either` - that source
  zip exists nowhere. Downloads use `curl -f`, so SourceForge's 404 page
  (~48 KB of HTML) is no longer saved as the zip and misreported as
  `Extract status : Failed`.
- `- <...>-lite.zip is not on SourceForge` / `is not on SourceForge either`
  followed by `<N-lite.zip> unavailable, falling back to N.zip` is normal for
  lite on arm64 24-28 and 34: their `-lite.zip` sources were deleted on
  purpose, so lite restores `<sdk>.zip` instead.
- `! file <packages/zip-server/<arch>/<sdk>.zip> is not found` - no addon
  source for that target; only the addon step fails, the zips still build.
- `source tidak ada` - the gapps were missing and auto-restore was off.

Re-run one target with `sh build.sh restore litegapps <variant> <arch> <sdk>`
followed by `bash build.sh make litegapps <variant> <arch> <sdk>`.

## Compression: smallest output first

`files.tar` is compressed with **`xz -T<n> -9e`** (`make_archive` in
`build.sh`), and the zip around it with `zip -9`. The thread count is the
`corecompressing` key in `config`: `multi` (default) or `single` (`-T1`); the
output is the same size either way. `multi` does **not** pass `-T0`:
`xz_threads()` in `build.sh` counts the machine's cores (`nproc`) and
`MemAvailable`, allows ~1250 MiB per `-9e` thread within 80 % of that, and
passes the number explicitly (`LG_XZ_THREADS` overrides). Builds run on very
different hardware, and `-T0` behaves differently per xz version: xz 5.4.1
caps itself at 25 % of RAM ("Reduced the number of threads from 8 to 4" on a
24 GB box), 5.4.5 takes every core however little memory is free. Examples:
24 GB -> 8, 6 GB free -> 3, 1-3 GB -> 1.
More threads only help a `files.tar` with more blocks than threads (see
below), so on typical gapps sizes the real gain comes from building several
targets at once, not from xz alone. The repo `config`
carries the key too. **xz is used because it is
designed to make the output as small as possible**, and that is the goal for
every release: the maintainer chose `-9e` and zip level 9 on purpose, so do
not lower them or trade size for speed.

`-T0` only adds threads. xz splits its input into blocks and compresses one
block per thread; at `-9` the default block is 3 x the 64 MiB dictionary =
192 MiB, so a `files.tar` smaller than that is still one block on one core,
and a 260 MiB one is two blocks. That default is kept deliberately - do **not**
add `--block-size`. Measured 2026-09-23 on a real 260 MiB arm64/36 tar with
8 cores:

| xz options | time | output |
|---|---|---|
| `-9e` (before) | 262 s | 94.01 MiB |
| `-9e -T0` (used) | 190-199 s | 94.14 MiB |
| `-9e -T0 --block-size=32MiB` | 36 s | 94.98 MiB (+1 %) |

The smaller blocks were rejected: faster, but every release would grow ~1 %.
A multi-block `.xz` is plain standard xz: the `xz` in `bin.zip` (XZ Utils
5.2.4, what devices decompress with) and busybox `unxz` (XZ Embedded) both
read it byte-identical. `BIN_TEST` prefers the host's own `xz` and only falls
back to `bin/<arch>/xz`, which is an Android binary and hangs on the VPS - so
the host must have xz installed (the GitHub runners do). `zip -9` on an
already-xz'd file costs ~3 s and is not worth parallelising.

## Shared files.tar (litegapps.tar=multi)

`litegapps.tar=multi` in `config` makes
one arch/SDK build its `files.tar.<compression>` once and reuse it for the
other variants, instead of running xz again per variant. It is a **per
arch/SDK** cache, not one archive for several architectures.

The cache lives in `tmp_files/litegapps/<arch>/<sdk>/<key>/`, and the key is
**the zip the gapps were really extracted from**: the restore writes it to
`gapps/<arch>/<sdk>/.gapps-source` (a dot file, so the `*` copy into the build
never packs it) and `_litegapps_build_variant` (`lib/litegapps.sh`) reads it
as `src-<zip>`. Variants that ended up on the same zip share one archive -
identical files, identical output - and anything with a zip of its own gets
its own key:

- awe restores `<sdk>.zip`;
- lite falls back to `<sdk>.zip` when the server has no `<sdk>-lite.zip`
  (arm64 24-28 and 34) and then shares that same archive; a real
  `<sdk>-lite.zip` gets a key of its own;
- sources restored before the marker existed use the old key from the
  variant config (`sdk`, `sdk-lite`).

## Supported targets

Android 7.0 (SDK 24) is the **oldest** target; Android 5.0, 5.1
and 6.0 (SDK 21-23) were dropped. The floor is `MIN_SDK` in `build.sh`
(checked by `target_supported()`, copied into `packages/make`).
Both GitHub workflows start at 24 too. On 2026-09-27
everything for 21-23 was deleted from the download server
(`litegapps/`, `addon/`, `files-server/litegapps/`; `files-server/package`
never had them). The device-side
`get_android_version()` copies in `installer/` and `packages/utils/` keep the
21-23 names on purpose, so an old zip still prints its Android version when it
is flashed.

Only arm64 is built any more. Every other target was dropped at every SDK:
arm (armeabi-v7a), x86 (32-bit) and x86_64. No source is restored and no zip
is made for them. The rule lives in `arch_supported()` / `target_supported()`
in `build.sh` (copied into the standalone `packages/make`, and applied in both
GitHub workflows). Do not add builds or sources back for any of them. Their
published releases still install.

Both remaining variants build for every supported arm64 SDK.
`variant_supported()` in `build.sh` is the hook a future variant would use to
restrict itself; it is checked by both the make and the restore loop in
`lib/litegapps.sh`. The workflows build awe (which needs the addon) only from
SDK 26 up, where the addon source exists; lite needs no addon at all.

## Adding Android/SDK support

Add the SDK→version mapping in `get_android_version()` in `build.sh` (the `case`
around line 296), add the SDK to the relevant variant `config` (`sdk=`/`restore.sdk=`),
and ensure `restore/<arch>/<sdk>/` gapps exist. Commit `98396d6` (A17 = SDK 36) is
the reference example.

## Open items (updated 2026-11-14)

**Drive restore** still works from the shell: with `LG_SOURCE=drive`, an
rclone remote (`LG_GDRIVE_REMOTE`, default `gdrive`) and a folder
(`LG_GDRIVE_DIR`, default `litegapps-mirror`), `fetch_source()` and
`fetch_package()` try `files-server/<path>` there before SourceForge and fall
back on any failure. The panel scripts that used to keep that mirror in sync
are gone; sync it with rclone by hand.

- Unproven: the per-gapps-base `files.tar` cache key - build lite and awe for
  one target with `litegapps.tar=multi` and marker files, then compare the
  two zips' `files.tar.xz`, on a free tree.
- **Bug (reported 2026-10-27, open): Setup Wizard stops after a ROM update.**
  The user updated the ROM over a Kopi (system) install; `27-litegapps.sh`
  restored LiteGapps, and on first boot Setup Wizard crashes ("has stopped").
  Not reproduced or diagnosed yet. Needed first: the device, ROM (before and
  after), arch/SDK and variant, the recovery log of the addon.d run (does
  every stage print, is anything skipped), and `adb logcat -b crash` /
  `adb logcat | grep -iE 'setupwizard|AndroidRuntime'` from the crash.
  Suspects to check, none confirmed:
  - a file the wizard needs was not restored: backup only saves entries of
    `list_install_<part>` that are regular files under `$S`, so anything the
    ROM's backuptool did not mount, or a list path that does not resolve
    under `$S`, is silently dropped (GmsCore, GSF, SetupWizard, the
    `etc/permissions` / `privapp-permissions` xml, `etc/sysconfig`);
  - SELinux labels / permissions of the restored files (`restore_file` copies
    with `cp -dp`);
  - the debloat replay removing a ROM app the new ROM's setup flow relies on
    (e.g. `Provision`) while LiteGapps' own wizard was not restored;
  - the Setup Wizard props patched into `build.prop` (`set_prop`, non-lite
    variants) clashing with what the new ROM ships;
  - old restored GMS apps against the new ROM's framework (fresh flash of the
    same LiteGapps zip after the update would rule this in or out).
