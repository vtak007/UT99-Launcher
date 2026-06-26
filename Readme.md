# UT99 Launcher

An AutoHotkey script that optimizes Windows for low-latency gaming and automates the launch of Unreal Tournament 99.

---

## What it does

Before launching UT, the script applies a series of system optimizations to minimize latency and free up resources. After UT exits, all changes are automatically restored to their original values.

### Optimizations applied at launch

1. **Disable Nagle's Algorithm** — reduces network latency by disabling `TcpAckFrequency` and `TCPNoDelay` on all TCP interfaces.
2. **Close all application windows** — stops the Dropbox service (`DbxSvc`) first, then force-kills PhraseExpress and all Dropbox processes via `taskkill`, then gracefully closes all visible app windows (with a safelist of protected system processes), then force-kills anything still open.
3. **Ethernet adapter optimization** — enables optimal properties for the ethernet adapter for gaming.
4. **Enable Windows Game Mode** — enables `AutoGameModeEnabled` via registry, disabling background services to free up resources.
5. **Switch to Ultimate Performance power plan** — eliminates micro-latencies and frame-time stutters.
6. **Launch One-Click Dodge script** — starts `UT99_OneClickDodge.ahk` alongside UT; inherits the elevated token so no second UAC prompt is needed.
7. **Launch Walk-and-Move-Forward script** — starts `UT99_WalkAndMoveForward.ahk` alongside UT (tap-to-autorun); inherits the elevated token so no second UAC prompt is needed.

### At exit (automatic restore)

- One-Click Dodge script closed
- Walk-and-Move-Forward script closed
- Nagle's Algorithm re-enabled
- Game Mode disabled
- Power plan reverted to High Performance
- Dropbox service (`DbxSvc`) restarted, then PhraseExpress and Dropbox relaunched
- All temp files cleaned up

---

## Features

| # | Feature | Description |
|---|---|---|
| 1 | UAC Self-Elevation | Relaunches itself with admin privileges via `*RunAs` if not already running as administrator |
| 2 | Nagle's Algorithm Toggle | Disables `TcpAckFrequency` and `TCPNoDelay` before launch; restores after UT exits |
| 3 | Close All Application Windows | Stops DbxSvc, then force-kills PhraseExpress and all Dropbox.exe instances via `taskkill`; then gracefully closes visible apps with a protected safelist; force-kills stragglers |
| 4 | PowerShell Profile Script Execution | Runs an external `.ps1` script with stdin redirected from a temp file to pass menu choices without keyboard simulation |
| 5 | Windows Game Mode Toggle | Enables `AutoGameModeEnabled` via registry before launch; disables after exit |
| 6 | Ultimate Performance Power Plan | Switches to the Ultimate Performance power plan (by GUID) before launch; shows success/fail popup |
| 7 | Unreal Tournament Launch | Runs the UT executable, captures its PID for tracking; shows an error dialog if launch fails |
| 8 | One-Click Dodge Integration | Launches `UT99_OneClickDodge.ahk` immediately after UT starts; inherits elevated token (no second UAC prompt); closed automatically when UT exits |
| 8b | Walk-and-Move-Forward Integration | Launches `UT99_WalkAndMoveForward.ahk` immediately after UT starts (tap-to-autorun); inherits elevated token (no second UAC prompt); closed automatically when UT exits |
| 9 | Game Navigation Automation | After a 5-second load wait, sends keystrokes (Escape, Alt+M, F) to skip the intro and navigate to Multiplayer → Find Internet Games |
| 10 | Process-Based Exit Detection | Uses `Process, WaitClose` instead of `WinWaitClose` to reliably detect UT exit in fullscreen DirectX mode |
| 11 | High Performance Power Plan Restore | Reverts to the High Performance power plan (by GUID) after UT exits; shows success/fail popup |
| 12 | Restore Closed Apps | After all cleanup steps, restarts DbxSvc via `net start`, then relaunches PhraseExpress and Dropbox (`/home`) |
| 13 | Temp File Cleanup | All intermediate temp files (PowerShell scripts, input files, saved state) are created and deleted within their respective functions |
