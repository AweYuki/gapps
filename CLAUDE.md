# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

AweGapps is a small, systemless Google Apps package for Android, flashed as a
Magisk/Kopi module. It is a renamed fork of LiteGapps; see README.md for credits.
**This repo is the build tool** that packages gapps files
into flashable zips. The build itself is entirely POSIX shell (`sh`/`bash`)
with no compiler and no test suite. There is no web panel and no service
component: everything runs from a terminal, `vps-build.sh`, `sf-build.sh` or
a GitHub workflow.

## Who builds this, and on what

The build is **not** only run on the maintainer's VPS. Anyone may clone the
repo and build LiteGapps on their own hardware, and the devices differ a lot:

- the maintainer's VPS (8 cores, 24 GB RAM);
- GitHub Actions runners (4 cores, 16 GB);
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
  `clean_variant_dirs`). Subcommands `restore`/`make`/`clean`/`upload`/`update-gapps-server`
  dispatch to the product functions in `lib/`.
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
  (`lite pixel basic awe`), each with its own `config`,
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
- `sf-build.sh` — legacy maintainer auto-build, runs on the **SourceForge build VPS**
  (`$HOMEE=/home/frs/project/litegapps`) which has a **4-hour job time limit**;
  builds must fit that window. Interactive. Not for casual local builds.
  Menu option 6 ("Build All") batches through every arm64 ×
  SDK 24-37 (Android 7.0-17) combination, `$BUILD_ALL_BATCH` (4) targets per
  run, tracked in `sf-build-progress.log` (gitignored) — stop, reboot the
  VPS job, and re-pick option 6 to resume where it left off.
  The checkout it runs from lives at `$HOMEE/build/litegapps`. Two different
  SourceForge hosts serve it, and they are not interchangeable:
  `ssh -t <user>@shell.sourceforge.net create` gives a real shell (this is the
  only way to *run* anything there), while `<user>@web.sourceforge.net` is a
  restricted account that can copy files but never execute a command.
  To push repo changes up, rsync a `git archive HEAD` export (no `--delete`,
  or you wipe the downloaded gapps under `bin/`, `core/**/gapps`, `output/`).
  Two things that trip this up: rsync cannot create or update dot-entries
  there — `.github/` and `.claude/` fail to mkdir, and the `.gitignore` already
  sitting there cannot be overwritten — so treat those as unsyncable; and the
  server keeps its own `config` tuned for releases (xz, compression 9, zip 9,
  `litegapps.tar=multi`) — leave it alone rather than overwriting it with the
  local one. `$HOMEE` is the public File Release System: everything placed
  there is downloadable by anyone, so never copy `.env` or keys into it.
- `vps-build.sh` — **unattended full build for a self-hosted VPS** (no time limit).
  Loops all ARCH × SDK, per target: download package source → build+upload addon →
  download gapps → build+upload every litegapps variant → **delete sources/output
  before the next target** (low-memory friendly). Config in `.env` (gitignored;
  `SF_USER` etc.). On failure it logs to `vps-build-logs/vps-build-failed.log` and
  continues. Its consolidated log lives in `vps-build-logs/`, separate from
  `build.sh`'s own `log/` (which appends across runs).
  Run detached so it survives SSH logout — via Docker (`Dockerfile` /
  `docker-compose.yml`) or `tmux`/`nohup`.
- `sf-prune.sh` — release retention on the FRS (`bash sf-prune.sh <arch> <sdk>
  [--dry-run]`), called by `vps-build.sh` after a successful upload.
  `sf-common.sh` holds the shared `.env`/ssh setup both scripts use.
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
- `restore` and `upload`/`update-gapps-server` hit the network (Sourceforge, GitHub).
  **Do not run `upload`/`update-gapps-server` unless explicitly asked** — they push to
  the release server and prompt for a Sourceforge username.
- Do not commit generated/gitignored artifacts.
- Only commit or push when the user asks.

## Variants and where their gapps come from

The variants are **not** the same files with different app lists: two
different gapps bases feed them, which is why several rules elsewhere in this
file key on the variant.

| Variant | gapps zip restored | Set by |
|---|---|---|
| pixel, basic, awe | `<sdk>.zip` | (default) |
| lite | `<sdk>-lite.zip`, falling back to `<sdk>.zip` when the server has none | `restore.suffix=-lite` |

This fork keeps only those four variants. core, go, micro, nano, user and
superlite were removed; do not add them back.

## Releasing to SourceForge

`vps-build.sh` uploads **per variant**, right after each one is built, with
`scp_tree`: every file under the variant's output tree is copied to
`<FRS>/litegapps/<arch>/<sdk>/<variant>/`, preserving the relative path (the
`web.sourceforge.net` account cannot run `mkdir`; scp creates the parent
directories). After a successful upload it runs `sf-prune.sh <arch> <sdk>` to
apply release retention. Consequences worth knowing:

- Zips appear on the FRS one variant at a time; a run stopped mid-variant
  uploads nothing for that variant.
- A failed `scp` marks that variant's upload failed and skips the prune, so no
  old release is lost over a broken upload; the file is named in the log.
- `sf-build.sh` writes to the FRS directly on the build VPS and applies the
  same retention locally (`PRUNE_RELEASES`), since it never calls
  `sf-prune.sh`.

## Reading a failed run

A `vps-build.sh` run continues past a failure and ends non-zero; every failure
is listed in `vps-build-logs/vps-build-failed.log` with its target. In
practice they are almost always the **sources**, not the build code, so read
the reason before touching anything:

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

After fixing the source, re-run only that target: `ARCH_LIST` and `SDK_LIST`
are environment overrides, so `SDK_LIST=36 bash vps-build.sh` redoes that one
column; nothing in the run needs to be repeated wholesale.

## Release retention on SourceForge

Each variant folder on the FRS (`litegapps/<arch>/<sdk>/<variant>/`) keeps only
its **newest 15 dated releases** (`YYYY-MM-DD` folders, `SF_KEEP_RELEASES`
overrides the number); after a release is published the older ones are deleted.
Both publishing paths apply it: `vps-build.sh` calls
`sf-prune.sh <arch> <sdk>` after a successful upload (remote, via
`rsync --list-only` + an sftp `rm`/`rmdir` batch, verified by relisting, and it
refuses to prune on a failed or empty listing), and `sf-build.sh` runs
`PRUNE_RELEASES` locally since it writes to the FRS directly. Folders that are
not ISO dates (old `v3.0` or `20-02-2024` releases) are neither counted nor
deleted. `bash sf-prune.sh <arch> <sdk> --dry-run` shows what would go.
`SF_PRUNE` and `SF_KEEP_RELEASES` come from `.env`.

## Compression: smallest output first

`files.tar` is compressed with **`xz -T<n> -9e`** (`make_archive` in
`build.sh`), and the zip around it with `zip -9`. The thread count is the
`corecompressing` key in `config`: `multi` (default) or `single` (`-T1`); the
output is the same size either way. `multi` does **not** pass `-T0`:
`xz_threads()` in `build.sh` counts the machine's cores (`nproc`) and
`MemAvailable`, allows ~1250 MiB per `-9e` thread within 80 % of that, and
passes the number explicitly (`LG_XZ_THREADS` overrides). Builds run on very
different hardware, and `-T0` behaves differently per xz version: the Docker
image's xz 5.4.1 caps itself at 25 % of RAM ("Reduced the number of threads
from 8 to 4" on the 24 GB VPS), the host's 5.4.5 takes every core however
little memory is free. Examples: 24 GB VPS -> 8, 6 GB free -> 3, 1-3 GB -> 1.
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
the host must have xz installed (the Docker image does). `zip -9` on an
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

- pixel, basic and awe all restore `<sdk>.zip`, so they share one archive and
  xz runs once per target for all three;
- lite falls back to `<sdk>.zip` when the server has no `<sdk>-lite.zip`
  (arm64 24-28 and 34) and then shares that same archive; a real
  `<sdk>-lite.zip` gets a key of its own;
- sources restored before the marker existed use the old key from the
  variant config (`sdk`, `sdk-lite`).

`vps-build.sh` logs a timestamp on every step, so further speed-ups can be
measured from `vps-build-logs/vps-build.log`.

## Supported targets

Android 7.0 (SDK 24) is the **oldest** target; Android 5.0, 5.1
and 6.0 (SDK 21-23) were dropped. The floor is `MIN_SDK` in `build.sh`
(checked by `target_supported()`, copied into `packages/make`).
`vps-build.sh` and the full GitHub workflow start at 24 too. On 2026-09-27
everything for 21-23 was deleted from the FRS
(`litegapps/`, `addon/`, `files-server/litegapps/`; `files-server/package`
never had them). The device-side
`get_android_version()` copies in `installer/` and `packages/utils/` keep the
21-23 names on purpose, so an old zip still prints its Android version when it
is flashed.

Only arm64 is built any more. Every other target was dropped at every SDK:
arm (armeabi-v7a), x86 (32-bit) and x86_64. No source is restored and no zip
is made for them. The rule lives in `arch_supported()` / `target_supported()`
in `build.sh` (copied into the standalone `packages/make`, and applied in
`sf-build.sh`, `vps-build.sh` and both GitHub workflows). Do not add
builds or sources back for any of them. Their published releases stay on the
FRS, and still install.

All four remaining variants build for every supported arm64 SDK.
`variant_supported()` in `build.sh` is the hook a future variant would use to
restrict itself; it is checked by both the make and the restore loop in
`lib/litegapps.sh`. Variant selection for unattended builds lives in
`variants_for()` (`vps-build.sh`) and `MAKE_LITEGAPPS()` (`sf-build.sh`):
everything above SDK 25, lite alone below that (the addon source starts at 26).

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

- Offered, not done: `sf.mirror=phoenixnap` in `config` (measured 18 MB/s vs
  9 MB/s default) - the user decides.
- Unproven: the per-gapps-base `files.tar` cache key - build lite and basic for
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
