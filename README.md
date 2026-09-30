# UT99 Launcher

An AutoHotkey script that optimizes Windows for low-latency gaming and automates the launch of Unreal Tournament 99.

---

## What it does

Before launching UT, the script applies a series of system optimizations to minimize latency and free up resources. After UT exits, all changes are automatically restored to their original values.

### Optimizations applied at launch

1. **Disable Nagle's Algorithm** — reduces network latency by disabling `TcpAckFrequency` and `TCPNoDelay` on all TCP interfaces.
2. **Close all application windows** — stops the Dropbox service (`DbxSvc`) first, then force-kills PhraseExpress and all Dropbox processes via `taskkill`, then gracefully closes all visible app windows (with a safelist of protected system processes), then force-kills anything still open.
3. **Ethernet adapter optimization** — enables optimal properties for the ethernet adapter for gaming.
4. **Switch to Ultimate Performance power plan** — eliminates micro-latencies and frame-time stutters.
5. **Enable Windows Game Mode** — sets `AutoGameModeEnabled=1` in the registry so Windows prioritizes UT over background workloads (see [Why Game Mode](#why-game-mode)).
6. **Launch One-Click Dodge script** — starts `UT99_OneClickDodge.ahk` alongside UT; inherits the elevated token so no second UAC prompt is needed.
7. **Launch Walk-and-Move-Forward script** — starts `UT99_WalkAndMoveForward.ahk` alongside UT (tap-to-autorun); inherits the elevated token so no second UAC prompt is needed.
8. **Switch playback device to Headphones** — sets the default audio output to the headset via [`SoundVolumeView.exe`](https://www.nirsoft.net/utils/sound_volume_view.html) (NirSoft; not included in this repo — see [Dependencies](#dependencies)) (all roles: Console/Multimedia/Communications).

### When UT exits

A prompt asks whether to **Restart** or **Shutdown**:

- **Restart** — relaunches UT immediately (re-runs the menu navigation) and skips
  straight back into the wait-for-exit loop. No cleanup/restore runs. The One-Click
  Dodge and Walk-and-Move-Forward scripts stay running throughout — they don't
  depend on UT's process, so they aren't relaunched.
- **Shutdown** — runs the full cleanup/restore sequence below.

### At exit (automatic restore, Shutdown only)

- One-Click Dodge script closed
- Walk-and-Move-Forward script closed
- Game Mode disabled
- Playback device switched back to Speakers
- Nagle's Algorithm re-enabled
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
| 5 | Windows Game Mode Toggle | Sets `AutoGameModeEnabled=1` via registry before launch; sets it back to `0` after exit (Shutdown only) |
| 6 | Ultimate Performance Power Plan | Switches to the Ultimate Performance power plan (by GUID) before launch; shows success/fail popup |
| 7 | Unreal Tournament Launch | Runs the UT executable, captures its PID for tracking; shows an error dialog if launch fails |
| 8 | One-Click Dodge Integration | Launches `UT99_OneClickDodge.ahk` immediately after UT starts; inherits elevated token (no second UAC prompt); closed automatically when UT exits |
| 8b | Walk-and-Move-Forward Integration | Launches `UT99_WalkAndMoveForward.ahk` immediately after UT starts (tap-to-autorun); inherits elevated token (no second UAC prompt); closed automatically when UT exits |
| 8c | Audio Device Switch | Switches the default playback device to Headphones before launch and back to Speakers after exit, via `SoundVolumeView.exe` (downloaded separately — see [Dependencies](#dependencies)) targeting Command-Line Friendly IDs (all roles) |
| 9 | Game Navigation Automation | After a 5-second load wait, sends keystrokes (Escape, Alt+M, F) to skip the intro and navigate to Multiplayer → Find Internet Games |
| 10 | Process-Based Exit Detection | Uses `Process, WaitClose` instead of `WinWaitClose` to reliably detect UT exit in fullscreen DirectX mode |
| 11 | High Performance Power Plan Restore | Reverts to the High Performance power plan (by GUID) after UT exits; shows success/fail popup |
| 12 | Restore Closed Apps | After all cleanup steps, restarts DbxSvc via `net start`, then relaunches PhraseExpress and Dropbox (`/home`) |
| 13 | Temp File Cleanup | All intermediate temp files (PowerShell scripts, input files, saved state) are created and deleted within their respective functions |
| 14 | Restart / Shutdown Prompt | After UT exits, a MsgBox offers Restart (relaunch UT, skip cleanup) or Shutdown (run full cleanup/restore); implemented as a loop around the launch/wait steps |

---

## Why Game Mode

Windows 11 Game Mode prioritizes the active game over background workloads. Its main benefits are improved CPU/GPU scheduling priority, reduced interference from background apps and some Windows activity, and potentially better frame-time consistency, 1% lows, and responsiveness under load. It usually does **not** produce large average-FPS gains on high-end systems like your i7-14700K/RTX 4070 Ti Super. Its real value is maintaining smoother, more consistent performance when other processes are competing for system resources.

---

## Dependencies

| Tool | Source | Setup |
|---|---|---|
| `SoundVolumeView.exe` | [NirSoft](https://www.nirsoft.net/utils/sound_volume_view.html) | Download and place `SoundVolumeView.exe` in the same folder as `UT_Launcher.ahk`. Not included in this repo. |
