# AGENTS.md

Notes for any coding agent working in this repository. The full working guide
is **[CLAUDE.md](CLAUDE.md)** — read that first; this file is the short list of
rules that are easy to get wrong.

## What this repo is

The LiteGapps build tool: POSIX shell (`build.sh`, `lib/`, `packages/`) that
packages Google Apps into flashable zips. There is no web panel and no service
component - everything is run from a terminal, `vps-build.sh`, `sf-build.sh`
or a GitHub workflow.

## Hard rules

- Builds run on very different hardware (VPS, GitHub runners, Linux PCs, Android phones in Termux without root): adapt to the machine at run time (`nproc`, `MemAvailable`), default to safe/sequential, no root, POSIX `sh` in `build.sh`.
- **Everything inside files is English** — `#` comments, `print`/`ui_print`
  strings, log messages, commit messages. Replies to the user can be
  Indonesian; the code stays English.
- **Never commit secrets**: `.env`, ssh keys, passwords, database dumps.
  `git check-ignore -v <path>` before assuming a new file is tracked.
- **Commit and push only when the user asks.**
- **Do not run `upload` / `update-gapps-server`** unless explicitly asked; they
  publish to the release server.
- The repo `config` is a neutral default (`name.builder=yourname`,
  `build.status=unofficial`). A maintainer's identity is set for a release run
  through the environment (`LG_CFG_*`); never commit it back into `config`.
- Android 7.0 (SDK 24) is the oldest target (`MIN_SDK`); Android 5.0-6.0
  (SDK 21-23) were dropped. Do not add them back.
- The variants restore three different gapps bases: `<sdk>.zip` (most),
  `<sdk>-lite.zip` (lite), `superlite.zip` (superlite, the release the Android
  version originally shipped with). superlite must always build from its own
  gapps - never reuse another variant's `files.tar` for it.
- `vps-build.sh` uploads per variant, right after each one is built. Retention
  is applied by `sf-prune.sh <arch> <sdk>` after a successful upload.
- Only arm64 is built. arm (armeabi-v7a), x86 and x86_64 were dropped; do not
  add builds or sources for them back (`arch_supported()` in `build.sh` and
  `packages/make`). Releases already published for them stay on the FRS.
- Anything uploaded to `$HOMEE` (`/home/frs/project/litegapps`) is public.

## Testing

There is no test suite. Check shell syntax with `sh -n build.sh packages/make`
and `bash -n *.sh installer/kopi/META-INF/com/google/android/update-binary`,
then do a real single-target build (`bash build.sh make litegapps lite arm64 36`)
against restored sources. Never run `upload` / `update-gapps-server` as a test.
