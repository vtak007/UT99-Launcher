; ============================================================
; UT_Launcher.ahk  –  AutoHotkey v1
;
; Sequence:
;   1.  Close all open application windows
;   2.  Run Set-I226VProfile.ps1  →  choose 1  →  wait  →  Enter
;   3.  Launch Unreal Tournament
;   4.  Wait 5 s, Alt+Enter (fullscreen), ESC
;   5.  Wait for UT to close
;   6.  Run Set-I226VProfile.ps1  →  choose 3  →  wait  →  Enter
;
; IMPORTANT: The script self-elevates on startup. Windows will show
; ONE UAC prompt when you launch this script.  Click "Yes" and the
; rest of the automation runs unattended – no further UAC dialogs.
; ============================================================

#NoEnv
#SingleInstance Force
SetTitleMatchMode, 2
SetWorkingDir, %A_ScriptDir%

; Self-elevate via UAC if not already running as administrator (AHK v1 method)
if not A_IsAdmin {
    Run *RunAs "%A_AhkPath%" "%A_ScriptFullPath%"
    ExitApp
}

PS_SCRIPT := A_ScriptDir . "\Set-I226VProfile.ps1"
UT_EXE    := "C:\UnrealTournament\System\UnrealTournament.exe"

; SoundVolumeView.exe (NirSoft) lives in the script folder; used to switch the
; default playback device.  Targets use Command-Line Friendly IDs (not plain
; names) so duplicate "Headphones"/"Speakers" entries can't be mis-matched.
SVV_EXE       := A_ScriptDir . "\SoundVolumeView.exe"
AUDIO_GAME    := "Arctis Nova Pro\Device\Headphones\Render"
AUDIO_RESTORE := "Realtek USB Audio\Device\Speakers\Render"

GUID_HIGH_PERF := "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
GUID_ULTIMATE  := "209bbce3-d696-4b47-b0cd-a7280a509878"

; ── STEP 1: Disable Nagle's Algorithm ──────────────────────────────────────
DisableNaglesAlgorithm()

; ── STEP 2: Close all visible application windows ──────────────────────────
CloseAllApps()

; ── STEP 3: Switch to Ultimate Performance power plan ──────────────────────
SwitchPowerPlanWithPopup("Ultimate Performance", GUID_ULTIMATE)

; ── STEPS 2-6: Profile script, choice 1 (Gaming) ───────────────────────────
RunProfileScript(PS_SCRIPT, 1)

; ── STEP 7b: Switch default playback device to Headphones ──────────────────
SwitchAudioDevice(SVV_EXE, AUDIO_GAME)

; ── STEP 8: Launch Unreal Tournament ───────────────────────────────────────
Run, %UT_EXE%,,, ut_pid
if (ErrorLevel || !ut_pid) {
    MsgBox, 16, Error, Failed to launch Unreal Tournament.`nPath: %UT_EXE%
    ExitApp
}

; ── STEP 8b: Launch One-Click Dodge script (inherits elevated token) ───────
; The "Online" argument makes the dodge script skip its forward-mode dialog
; and use the smooth IG+ single-button forward dodge automatically.
Run, "D:\Dropbox\Computing1\BatchFiles_Scripts\Claude Projects\UT99\UT99 One-Click Dodge\UT99_OneClickDodge.ahk" Online
Sleep, 1000   ; give it a moment to register hotkeys

; ── STEP 8c: Launch Walk-and-Move-Forward autorun script (inherits elevated token) ──
Run, "D:\Dropbox\Computing1\BatchFiles_Scripts\Claude Projects\UT99\UT99 Walk and Move Forward\UT99_WalkAndMoveForward.ahk"
Sleep, 1000   ; give it a moment to register hotkeys

; ── STEP 9: Wait 5 seconds for UT to finish loading ───────────────────────
Sleep, 5000

; ── STEP 10: Skip intro video, open Multiplayer → Find Internet Games ───────
WinActivate, ahk_pid %ut_pid%
WinWaitActive, ahk_pid %ut_pid%,, 10
Send, {Escape}
Sleep, 1000
Send, !m
Sleep, 500
Send, f

; ── STEP 11: Wait for Unreal Tournament to close ───────────────────────────
; WinWaitClose is unreliable for fullscreen DirectX games — AHK cannot find
; a trackable window and returns immediately.  Process, WaitClose monitors
; the process directly and waits until the EXE exits, regardless of window state.
Process, WaitClose, %ut_pid%
Sleep, 2000

; ── Close One-Click Dodge script ───────────────────────────────────────────
WinClose, UT99_OneClickDodge.ahk ahk_class AutoHotkey

; ── Close Walk-and-Move-Forward autorun script ─────────────────────────────
WinClose, UT99_WalkAndMoveForward.ahk ahk_class AutoHotkey

; ── Restore default playback device to Speakers ────────────────────────────
SwitchAudioDevice(SVV_EXE, AUDIO_RESTORE)

; ── Enable Nagle's Algorithm ────────────────────────────────────────────────
EnableNaglesAlgorithm()

; ── Switch back to High Performance power plan ──────────────────────────────
SwitchPowerPlanWithPopup("High Performance", GUID_HIGH_PERF)

; ── STEPS 12-14: Profile script, choice 3 ──────────────────────────────────
RunProfileScript(PS_SCRIPT, 3)

; ── Restore closed apps ─────────────────────────────────────────────────────
RestoreApps()

MsgBox, 64, Done, All steps completed successfully.
ExitApp


; ============================================================
; FUNCTIONS
; ============================================================

CloseAllApps() {
    ; Processes that must never be closed
    SafeList := "explorer.exe|SearchHost.exe|ShellExperienceHost.exe|StartMenuExperienceHost.exe"
    SafeList .= "|TextInputHost.exe|SystemSettings.exe|RuntimeBroker.exe|sihost.exe|taskhostw.exe"
    SafeList .= "|ctfmon.exe|dwm.exe|winlogon.exe|csrss.exe|lsass.exe|services.exe|svchost.exe"
    SafeList .= "|SecurityHealthSystray.exe|SecurityHealthService.exe"
    SafeList .= "|WindowsTerminal.exe"  ; TEMP: keep Claude Code terminal open during testing
    SafeList .= "|obs64.exe"            ; OBS Studio

    ; --- Close system tray apps ---
    RunWait, cmd.exe /c net stop DbxSvc,,Hide
    RunWait, cmd.exe /c taskkill /F /IM phraseexpress.exe,,Hide
    RunWait, cmd.exe /c taskkill /F /IM Dropbox.exe,,Hide
    Sleep, 1500

    ; --- Close File Explorer windows individually ---
    ; explorer.exe must stay in SafeList to protect the shell (taskbar/desktop),
    ; but that also blocks WinClose on File Explorer windows.  Target them
    ; directly by window class (CabinetWClass) instead.
    WinGet, explorerList, List, ahk_class CabinetWClass
    Loop, %explorerList% {
        ewid := explorerList%A_Index%
        WinClose, ahk_id %ewid%
    }
    Sleep, 1000

    ; --- Politely close all visible app windows ---
    WinGet, winList, List
    Loop, %winList% {
        wid := winList%A_Index%
        WinGet,  pname,  ProcessName, ahk_id %wid%
        WinGetTitle, wtitle, ahk_id %wid%
        WinGet,  wstyle, Style,       ahk_id %wid%
        WinGet,  exstyle,ExStyle,     ahk_id %wid%

        ; Skip invisible, untitled, or system windows
        if (wtitle = "" || pname = "")
            Continue
        if !(wstyle & 0x10000000)         ; WS_VISIBLE
            Continue
        if (exstyle & 0x00000080)          ; WS_EX_TOOLWINDOW (tray utilities, no taskbar btn)
            Continue
        if _InList(pname, SafeList)
            Continue
        ; Skip this AHK script itself
        if (pname = "AutoHotkey.exe" || pname = "AutoHotkey64.exe" || pname = "AutoHotkey32.exe")
            Continue

        WinClose, ahk_id %wid%
    }
    Sleep, 3000   ; Give apps time to close gracefully

    ; --- Force-kill anything still open ---
    WinGet, winList2, List
    Loop, %winList2% {
        wid := winList2%A_Index%
        WinGet,  pname,  ProcessName, ahk_id %wid%
        WinGetTitle, wtitle, ahk_id %wid%
        WinGet,  wstyle, Style,       ahk_id %wid%
        WinGet,  exstyle,ExStyle,     ahk_id %wid%

        if (wtitle = "" || pname = "")
            Continue
        if !(wstyle & 0x10000000)
            Continue
        if (exstyle & 0x00000080)
            Continue
        if _InList(pname, SafeList)
            Continue
        if (pname = "AutoHotkey.exe" || pname = "AutoHotkey64.exe" || pname = "AutoHotkey32.exe")
            Continue

        WinKill, ahk_id %wid%
    }
    Sleep, 1500
}


RunProfileScript(scriptPath, choice) {
    ; Write the menu choice and a blank "Press ENTER" line to a temp file,
    ; then redirect PowerShell's stdin from it via cmd.exe.
    ; Input travels through the file system, not the keyboard/window stack,
    ; so it works reliably even immediately after a fullscreen game exits.
    ;
    ; IMPORTANT: the cmd string MUST be built with .= so that the < redirect
    ; character stays inside a string literal.  Writing it as a single AHK
    ; expression causes AHK v1 to misparse < as its less-than operator,
    ; setting cmd to 0 or 1 instead of the actual command string.
    inputFile := A_Temp . "\ut_launcher_input.txt"
    FileDelete, %inputFile%
    FileAppend, %choice%`r`n`r`n, %inputFile%

    cmd  := "cmd.exe /c powershell.exe -ExecutionPolicy Bypass -File "
    cmd .= """" . scriptPath . """"
    cmd .= " < "
    cmd .= """" . inputFile . """"
    cmd .= " & ping -n 6 127.0.0.1 > nul"

    Run, %cmd%,,, ps_pid
    if (!ps_pid) {
        MsgBox, 16, Error, Failed to launch PowerShell script:`n%scriptPath%
        FileDelete, %inputFile%
        return
    }

    ; Wait up to 30 s for the console window to appear
    WinWait, ahk_pid %ps_pid%,, 30
    if ErrorLevel {
        MsgBox, 16, Error, PowerShell window did not appear within 30 s.
        FileDelete, %inputFile%
        return
    }

    ; Maximise the console so output is visible
    WinMaximize, ahk_pid %ps_pid%

    ; No keystrokes needed — just wait for the window to close on its own.
    ; Allow up to 120 s for the script's work to complete.
    WinWaitClose, ahk_pid %ps_pid%,, 120
    FileDelete, %inputFile%
    Sleep, 1000
}


EnableNaglesAlgorithm() {
    ; Removes TcpAckFrequency and TCPNoDelay from all TCP interfaces,
    ; restoring Windows default Nagle's Algorithm behaviour.
    psFile := A_Temp . "\nagle_enable.ps1"
    FileDelete, %psFile%
    FileAppend, Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' | ForEach-Object {`n    Remove-ItemProperty -Path $_.PSPath -Name TcpAckFrequency -ErrorAction SilentlyContinue`n    Remove-ItemProperty -Path $_.PSPath -Name TCPNoDelay -ErrorAction SilentlyContinue`n}, %psFile%
    RunWait, powershell.exe -ExecutionPolicy Bypass -File "%psFile%",,Hide
    FileDelete, %psFile%
}

DisableNaglesAlgorithm() {
    ; Sets TcpAckFrequency=1 and TCPNoDelay=1 on all TCP interfaces,
    ; disabling Nagle's Algorithm for lower latency.
    psFile := A_Temp . "\nagle_disable.ps1"
    FileDelete, %psFile%
    FileAppend, Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' | ForEach-Object {`n    Set-ItemProperty -Path $_.PSPath -Name TcpAckFrequency -Value 1 -Type DWord -Force`n    Set-ItemProperty -Path $_.PSPath -Name TCPNoDelay -Value 1 -Type DWord -Force`n}, %psFile%
    RunWait, powershell.exe -ExecutionPolicy Bypass -File "%psFile%",,Hide
    FileDelete, %psFile%
}


SwitchAudioDevice(svvExe, deviceId) {
    ; Sets the default playback device using SoundVolumeView (NirSoft).
    ; "all" sets every role (Console, Multimedia, Communications) in one call.
    ; deviceId is a Command-Line Friendly ID, e.g. "Arctis Nova Pro\Device\Headphones\Render".
    if !FileExist(svvExe) {
        MsgBox, 48, Audio Switch Skipped, SoundVolumeView.exe not found:`n%svvExe%`n`nDefault playback device was not changed.
        return
    }
    RunWait, "%svvExe%" /SetDefault "%deviceId%" all,, Hide
}



SwitchPowerPlanWithPopup(planName, planGuid) {
    if (planGuid = "209bbce3-d696-4b47-b0cd-a7280a509878")
        EnsureUltimatePerformanceExists()

    success := SetActivePowerPlan(planGuid)
    activeGuid := GetActivePowerPlanGuid()

    if (success && StrLowerEx(activeGuid) = StrLowerEx(planGuid)) {
        MsgBox, 64, Power Plan Switched, Power plan successfully switched to:`n`n%planName%
    } else {
        msg := "Failed to switch power plan to:`n`n" . planName
        if (activeGuid != "")
            msg .= "`n`nCurrent active GUID:`n" . activeGuid
        else
            msg .= "`n`nUnable to determine the currently active power plan."
        MsgBox, 16, Power Plan Switch Failed, %msg%
    }
}

EnsureUltimatePerformanceExists() {
    plansText := GetPowerPlansText()
    if InStr(StrLowerEx(plansText), "209bbce3-d696-4b47-b0cd-a7280a509878")
        return true

    RunWait, %ComSpec% /c powercfg -duplicatescheme 209bbce3-d696-4b47-b0cd-a7280a509878,, Hide
    Sleep, 1000

    plansText := GetPowerPlansText()
    if InStr(StrLowerEx(plansText), "209bbce3-d696-4b47-b0cd-a7280a509878")
        return true

    return false
}

SetActivePowerPlan(planGuid) {
    RunWait, %ComSpec% /c powercfg /S %planGuid%,, Hide
    Sleep, 500
    activeGuid := GetActivePowerPlanGuid()
    return (StrLowerEx(activeGuid) = StrLowerEx(planGuid))
}

GetActivePowerPlanGuid() {
    tempFile := A_Temp . "\active_power_plan.txt"
    FileDelete, %tempFile%
    RunWait, %ComSpec% /c powercfg /GETACTIVESCHEME > "%tempFile%",, Hide
    FileRead, output, %tempFile%
    FileDelete, %tempFile%
    RegExMatch(output, "i)Power Scheme GUID:\s*([a-f0-9\-]+)", m)
    return m1
}

GetPowerPlansText() {
    tempFile := A_Temp . "\power_plans_list.txt"
    FileDelete, %tempFile%
    RunWait, %ComSpec% /c powercfg /L > "%tempFile%",, Hide
    FileRead, output, %tempFile%
    FileDelete, %tempFile%
    return output
}

StrLowerEx(str) {
    StringLower, out, str
    return out
}


RestoreApps() {
    RunWait, cmd.exe /c net start DbxSvc,,Hide
    Run, "C:\Program Files (x86)\PhraseExpress\phraseexpress.exe"
    Run, "C:\Program Files (x86)\Dropbox\Client\Dropbox.exe" /home
}


; Helper: case-insensitive search in a pipe-delimited list
_InList(needle, haystack) {
    Loop, Parse, haystack, |
    {
        if (A_LoopField = needle)
            return true
    }
    return false
}
