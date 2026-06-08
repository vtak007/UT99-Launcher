# UT Launcher

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
6. **Disable core parking** — forces all CPU cores active (100%), eliminating latency spikes caused by the OS waking idle cores.
7. **Set minimum processor state to 100%** — prevents the CPU from reducing speed during moments of lower activity.

### At exit (automatic restore)

- Nagle's Algorithm re-enabled
- Game Mode disabled
- Power plan reverted to High Performance
- Core parking values restored to their saved originals
- Minimum processor state restored to its prior value
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
| 6 | Ultimate Performance Power Plan | Switches to a custom Ultimate Performance power plan (by GUID) before launch |
| 7 | Core Parking Disable | Saves current `CPMINCORES`/`CPMAXCORES` values, forces all cores active, restores on exit |
| 8 | Minimum Processor State Override | Saves and sets `PROCTHROTTLEMIN` to 100% so the CPU never throttles; restores on exit |
| 9 | Unreal Tournament Launch | Runs the UT executable, captures its PID for tracking; shows an error dialog if launch fails |
| 10 | Game Navigation Automation | After a 5-second load wait, sends keystrokes (Escape, Alt+M, F) to skip the intro and navigate to Multiplayer → Find Internet Games |
| 11 | Process-Based Exit Detection | Uses `Process, WaitClose` instead of `WinWaitClose` to reliably detect UT exit in fullscreen DirectX mode |
| 12 | High Performance Power Plan Restore | Reverts to the High Performance power plan (by GUID) after UT exits |
| 13 | Temp File Cleanup | All intermediate temp files (PowerShell scripts, input files, saved state) are created and deleted within their respective functions |
