# packages

Standalone addon/APK packaging tool, vendored into this repo. It builds the
per-app "addon" packages (Google Play Store, Play Services, GSF, etc.) that
`build.sh` later pulls into an AweGapps flashable zip.

This is a **separate sub-project** from the rest of the repo — it has its own
`config`, its own installer payload (`utils/`), and is invoked as a black box
via `bash packages/make <command> [arch] [sdk]`. Nothing here should be merged
into root `installer/` or `lib/`.

## Layout

- `make` — the script, self-contained (`RESTORE`/`MAKE`/`CLEAN`/`CHECK`/`UPLOAD`
  and `zip-make`/`zip-upload` functions), same shell style as the rest of the
  repo (`getp`, `print`, tab indentation).
- `config` — `arch=`/`sdk=` defaults (used when not passed as args), `by=`
  (builder name), `zipsigner=` (whether to sign output zips with
  `bin/zipsigner.jar`).
- `utils/` — installer payload for the addon zips themselves (`module.prop`,
  `customize.sh`, `META-INF/...`, `litegapps-prop`, `LICENSE`) — the addon
  equivalent of root `installer/`.
- `files/` — gitignored. Per-arch/per-sdk source tree restored from
  `zip-server/`, one dir per app, each with a `build.info` (name/id) driving
  `MAKE`.
- `zip-server/` — gitignored. Downloaded source zips.
- `output/`, `tmp/` — gitignored. Build output / scratch dirs (same pattern as
  root `output/`/`tmp/`).

## Commands

```bash
bash packages/make restore [arch] [sdk]    # download+extract source zips
bash packages/make make [arch] [sdk]       # build addon packages
bash packages/make clean [arch] [sdk]      # reset files/output/tmp
bash packages/make check [arch] [sdk]      # check for conflicts
bash packages/make zip-make                # package zip-server/ into zips
```

`arch`/`sdk` default to `config`'s `arch=`/`sdk=` when omitted.

## How the rest of the repo uses this

- `lib/litegapps.sh`'s `_litegapps_build_addon()` calls
  `bash packages/make restore`/`make` for the target arch/sdk before the
  variant is built — addon packages must exist under `files/` before an
  AweGapps zip can bundle them.
- Nothing uploads from here: the GitHub workflows publish the finished zips.
