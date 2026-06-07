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
3. Close all apps — tray apps first (`Process, Close`), then visible windows, then force-kill stragglers
4. Run `Set-I226VProfile.ps1` with choice `1` (Gaming/ethernet profile)
5. Enable Windows Game Mode (`AutoGameModeEnabled=1`)
6. Launch `UnrealTournament.exe`, capture PID
7. Wait 5 s, send `Escape` → `Alt+M` → `F` to navigate to Multiplayer → Find Internet Games
8. `Process, WaitClose` on UT's PID until UT exits
9. Disable Game Mode
10. Re-enable Nagle's Algorithm
11. Run `Set-I226VProfile.ps1` with choice `3` (restore profile)
12. Show completion dialog

---

## Key Implementation Notes

### Tray apps need `Process, Close`
`CloseAllApps()` filters out `WS_EX_TOOLWINDOW` windows (system tray utilities), so they are never reached by the `WinClose` / `WinKill` loops. Apps like PhraseExpress and Dropbox must be terminated explicitly with `Process, Close, processname.exe` at the top of `CloseAllApps()`.

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

### PowerShell scripts written to temp files
`EnableNaglesAlgorithm()` and `DisableNaglesAlgorithm()` write a `.ps1` to `%TEMP%`, run it with `RunWait ... Hide`, then delete it. This avoids needing a separate file on disk.

---

## Paths

| Variable | Value |
|---|---|
| `PS_SCRIPT` | `D:\Dropbox\Computing1\BatchFiles_Scripts\PowershellScripts\Set-I226VProfile.ps1` |
| `UT_EXE` | `C:\UnrealTournament\System\UnrealTournament.exe` |
