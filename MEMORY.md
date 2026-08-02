# UT Launcher — Project Memory

Persistent notes for the UT Launcher project. Read at the start of every session.
See `CLAUDE.md` for the full launch sequence and implementation notes.

## CONFIRMED ROOT CAUSES

- **Tray apps survive `WinClose`/`WinKill`.** PhraseExpress and Dropbox are
  `WS_EX_TOOLWINDOW` windows, which `CloseAllApps()` filters out. They must be
  killed explicitly via `cmd.exe /c` (`net stop DbxSvc`, then `taskkill /F /IM`).
  DbxSvc must be stopped first or it respawns `Dropbox.exe`.
- **`WinWaitClose` returns immediately for fullscreen DirectX UT.** AHK cannot
  find a trackable window; use `Process, WaitClose, %ut_pid%` instead.
- **AHK v1 misparses `<` as less-than.** The PowerShell stdin redirect in
  `RunProfileScript()` must be built with `.=` string concatenation, not a
  single expression.

## RULED-OUT THEORIES

- (none recorded yet)

## PROJECT CONVENTIONS

- **AHK v1 only** — no v2 syntax (fat-arrow, `{}` function bodies, object clipboard).
- **Correct paths / GUIDs** live in the `Paths & GUIDs` table in `CLAUDE.md`
  (`UT_EXE`, `PS_SCRIPT`, `SVV_EXE`, power-plan GUIDs).
- **`SoundVolumeView.exe` is committed** despite the `*.exe` gitignore rule via a
  `!SoundVolumeView.exe` exception. Audio targets are Command-Line Friendly IDs,
  not plain names (duplicate Headphones/Speakers entries exist).
- **Pre-commit doc-update rule** (from global + project `CLAUDE.md`): update
  `Readme.md` and `CLAUDE.md` only *after* the user has tested and approved a
  change; never commit before that doc step is confirmed. Code is branched first,
  merged with `--no-ff`.

## CHANGE LOG

- 2026-08-02 — Removed the Windows Game Mode toggle feature
  (`EnableGameMode()`/`DisableGameMode()` and their calls). Merged to `main`.
