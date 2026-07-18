# UT Launcher — Project Instructions

## Key Files

| File | Purpose |
|---|---|
| `UT_Launcher.ahk` | Main AutoHotkey script — launches and configures Unreal Tournament |
| `Readme.md` | Project readme — describes all optimizations and features |

---

## Project Overview

Single-file AutoHotkey v1 script that prepares Windows for low-latency gaming, launches Unreal Tournament 99, and fully restores all settings after UT exits. Runs unattended after one UAC prompt.

---

## AutoHotkey Version

**AHK v1 only.** Do not use v2 syntax (fat-arrow functions, `{` blocks for function bodies, `A_Clipboard` as object, etc.). All functions use the AHK v1 style with `()` body braces and `%var%` variable dereference.

---

## Launch Sequence

1. Self-elevate via UAC (`*RunAs`) if not already admin
2. Disable Nagle's Algorithm (registry: `TcpAckFrequency=1`, `TCPNoDelay=1`)
3. Close all apps — stop DbxSvc, then kill tray apps via `taskkill /F` (wrapped in `cmd.exe /c`), then visible windows, then force-kill stragglers
4. Switch to Ultimate Performance power plan (`GUID_ULTIMATE`) — shows success/fail popup
5. Run `Set-I226VProfile.ps1` with choice `1` (Gaming/ethernet profile)
6. Enable Windows Game Mode (`AutoGameModeEnabled=1`)
7. Launch `UnrealTournament.exe`, capture PID
8. Launch `UT99_OneClickDodge.ahk` (step 8b) — `Sleep, 1000` to let it register hotkeys
9. Launch `UT99_WalkAndMoveForward.ahk` (step 8c) — `Sleep, 1000` to let it register hotkeys
10. Wait 5 s, send `Escape` → `Alt+M` → `F` to navigate to Multiplayer → Find Internet Games
11. `Process, WaitClose` on UT's PID until UT exits
12. Close One-Click Dodge and Walk-and-Move-Forward scripts via `WinClose` on their AHK window titles
12. Disable Game Mode
13. Re-enable Nagle's Algorithm
14. Switch back to High Performance power plan (`GUID_HIGH_PERF`) — shows success/fail popup
15. Run `Set-I226VProfile.ps1` with choice `3` (restore profile)
16. `RestoreApps()` — start DbxSvc, launch PhraseExpress, launch Dropbox `/home`
17. Show completion dialog

---

## Key Implementation Notes

### Tray apps need `net stop` + `taskkill /F` via `cmd.exe /c`
`CloseAllApps()` filters out `WS_EX_TOOLWINDOW` windows (system tray utilities), so they are never reached by the `WinClose` / `WinKill` loops. PhraseExpress and Dropbox must be killed explicitly at the top of `CloseAllApps()` using three `RunWait, cmd.exe /c ...,,Hide` calls:

1. `net stop DbxSvc` — stops the Dropbox service first; without this, DbxSvc respawns `Dropbox.exe` immediately after `taskkill` kills it.
2. `taskkill /F /IM phraseexpress.exe` — force-kills PhraseExpress (no watchdog service).
3. `taskkill /F /IM Dropbox.exe` — kills all 9 Dropbox.exe instances now that the service is stopped.

The `cmd.exe /c` wrapper is required — AHK's `RunWait` without it does not parse `/F` and `/IM` correctly. `net stop` does **not** accept a `/y` flag; omit it.

### `Process, WaitClose` instead of `WinWaitClose`
AHK cannot find a trackable window for fullscreen DirectX games. `WinWaitClose` returns immediately. `Process, WaitClose, %ut_pid%` blocks until the EXE exits regardless of window state.

### stdin redirect via temp file — use `.=` concatenation
The `RunProfileScript()` function redirects PowerShell's stdin from a temp file using `<`. The redirect character **must** be placed inside a string built with `.=` concatenation. Writing the full command as a single AHK expression causes AHK v1 to misparse `<` as its less-than operator, setting `cmd` to `0` or `1`.

### CloseAllApps SafeList
Pipe-delimited list of process names that must never be closed:

| Process | Reason |
|---|---|
| `explorer.exe` | Shell host — closing kills taskbar/desktop |
| `SearchHost.exe`, `ShellExperienceHost.exe`, `StartMenuExperienceHost.exe` | Shell UI |
| `TextInputHost.exe`, `SystemSettings.exe`, `RuntimeBroker.exe` | System UI |
| `sihost.exe`, `taskhostw.exe`, `ctfmon.exe` | System services |
| `dwm.exe`, `winlogon.exe`, `csrss.exe`, `lsass.exe`, `services.exe`, `svchost.exe` | Core OS |
| `SecurityHealthSystray.exe`, `SecurityHealthService.exe` | Windows Security |
| `WindowsTerminal.exe` | Keep Claude Code terminal open during testing |
| `obs64.exe` | OBS Studio (intentionally kept running) |

File Explorer windows (class `CabinetWClass`) are closed separately via `WinGet, List, ahk_class CabinetWClass` because `explorer.exe` must stay in the SafeList to protect the shell.

### One-Click Dodge script — launch after UT, close after UT exits
`UT99_OneClickDodge.ahk` is launched via `Run` immediately after UT starts (step 8b). Because the launcher already holds an elevated token, the dodge script inherits elevation automatically — no second UAC prompt. A `Sleep, 1000` follows to let it finish loading and register its hotkeys before UT takes focus.

On exit, the script is closed with `WinClose, UT99_OneClickDodge_TapHold.ahk ahk_class AutoHotkey`. The window title must match the AHK script's title exactly; `ahk_class AutoHotkey` scopes the match to AHK windows only to avoid false positives.

Path: `D:\Dropbox\Computing1\BatchFiles_Scripts\Claude Projects\UT99\UT99 One-Click Dodge\UT99_OneClickDodge.ahk`

### Walk-and-Move-Forward script — launch after UT, close after UT exits
`UT99_WalkAndMoveForward.ahk` is launched via `Run` immediately after the One-Click Dodge script (step 8c), inheriting the same elevated token (no second UAC prompt). It provides tap-to-autorun: tapping Mouse4 holds the `Backspace` key (bound to the `Walking` alias in `User.ini`) so the player keeps walking forward until any movement/action key — or a second Mouse4 tap — releases it.

On exit it is closed with `WinClose, UT99_WalkAndMoveForward.ahk ahk_class AutoHotkey`.

Path: `D:\Dropbox\Computing1\BatchFiles_Scripts\Claude Projects\UT99\UT99 Walk and Move Forward\UT99_WalkAndMoveForward.ahk`

### RestoreApps() — relaunch PhraseExpress and Dropbox after UT exits
`RestoreApps()` is called after all cleanup steps complete. It runs `net start DbxSvc` (wrapped in `cmd.exe /c`) to restart the Dropbox service, then uses `Run` to launch PhraseExpress (`C:\Program Files (x86)\PhraseExpress\phraseexpress.exe`) and Dropbox (`C:\Program Files (x86)\Dropbox\Client\Dropbox.exe /home`). DbxSvc must be started before Dropbox.exe or the service will respawn its own instance and conflict.

### PowerShell scripts written to temp files
`EnableNaglesAlgorithm()` and `DisableNaglesAlgorithm()` write a `.ps1` to `%TEMP%`, run it with `RunWait ... Hide`, then delete it. This avoids needing a separate file on disk.

---

## Paths & GUIDs

| Variable | Value |
|---|---|
| `PS_SCRIPT` | `A_ScriptDir . "\Set-I226VProfile.ps1"` (local copy in script folder) |
| `UT_EXE` | `C:\UnrealTournament\System\UnrealTournament.exe` |
| `GUID_ULTIMATE` | `209bbce3-d696-4b47-b0cd-a7280a509878` (Ultimate Performance) |
| `GUID_HIGH_PERF` | `8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c` (High Performance) |
