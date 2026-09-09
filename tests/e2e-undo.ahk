#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
SetKeyDelay 15, 15
SendLevel 1        ; level 0 input never triggers another script's hotkeys

; Needs LangFix running.
;
; Ctrl+Z is everyone's undo key, so the interesting half of this test is not
; that LangFix undoes a fix - it is that it GIVES THE KEY BACK. Four things
; are checked, and the middle two matter most:
;   1. after a fix, Ctrl+Z puts the original characters back
;   2. a second Ctrl+Z is the application's own undo, not a redo
;   3. with no fix pending, Ctrl+Z was never ours at all
;   4. a selection fix is undone too - by the application, deliberately
;
; TELLING THOSE TWO APART IS THE WHOLE PROBLEM. On screen they are identical:
; a Win32 Edit has a single-level undo that toggles, so "the text went back"
; looks the same whoever did it. The evidence used here is that LANGFIX PUTS
; ITS RESULT ON THE CLIPBOARD whenever it changes text, and the application
; does not. So each Ctrl+Z is preceded by a sentinel on the clipboard: still
; there afterwards means LangFix stood aside, gone means LangFix acted.
;
; (An earlier version looked for LangFix's tooltip instead. WinExist never
; found it - AHK's own tooltip windows do not answer a normal window search -
; so every reading came back "did not act", including for fixes that had
; visibly worked. A detector that can never say YES is not a detector.)

global SENTINEL := "LANGFIX-TEST-SENTINEL"

Rec := ""
g := Gui("+AlwaysOnTop", "LangFix e2e - undo on Ctrl+Z")
ed := g.Add("Edit", "w600 h60")
SaveMouse()
Rec .= ScreenNote(ShowOffPrimary(g)) "`n"
Loop 5 {
    WinActivate "ahk_id " g.Hwnd
    if WinWaitActive("ahk_id " g.Hwnd, , 2)
        break
    Sleep 400
}
Sleep 700
ControlFocus ed

; --- 1. fix, then undo -----------------------------------------------
SendEvent "{Text}nv to tbh"
Sleep 700
Rec .= "typed        : [" ed.Value "]`n"

SendEvent "^!{sc026}"          ; Ctrl+Alt+L
Sleep 1600
Rec .= "after ^!L    : [" ed.Value "]   (want: מה אם אני)`n"

Arm()
SendEvent "^{sc02C}"           ; Ctrl+Z
Sleep 1200
Rec .= "after ^Z     : [" ed.Value "]  LangFix acted: " Acted()
     . "   (want: nv to tbh, acted YES)`n"

; --- 2. the second Ctrl+Z belongs to the app, and must not redo -------
Arm()
SendEvent "^{sc02C}"           ; Ctrl+Z again
Sleep 1200
Rec .= "after ^Z #2  : [" ed.Value "]  LangFix acted: " Acted()
     . "   (want: acted no - the key was the Edit's, and its single-level"
     . " undo simply toggled back)`n"

; --- 3. no fix pending: Ctrl+Z was never ours ------------------------
ed.Value := ""
Sleep 300
ControlFocus ed
SendEvent "{Text}plain typing"
Sleep 700
Rec .= "`ntyped        : [" ed.Value "]  (no fix made - Ctrl+Z is the app's)`n"
Arm()
SendEvent "^{sc02C}"           ; Ctrl+Z
Sleep 1200
Rec .= "after ^Z     : [" ed.Value "]  LangFix acted: " Acted()
     . "   (want: acted no, and the EDIT's own undo ran - the text gone or"
     . " changed, not still 'plain typing')`n"

; --- 4. the SELECTION path: Ctrl+Z must undo that fix too ------------
; We deliberately do not claim Ctrl+Z here - a selection fix is a single
; paste, and the application's own undo restores it, and the selection with
; it, better than we could. What Yair sees must be the same either way.
ed.Value := ""
Sleep 300
ControlFocus ed
SendEvent "{Text}kunr"
Sleep 500
ed.GetPos(&cx, &cy, &cw, &ch)
Click cx + 40, cy + 12          ; a click clears the typed buffer, so the
Sleep 500                       ; next fix has to go the selection route
SendEvent "^{sc01E}"            ; Ctrl+A - select all
Sleep 600
Rec .= "`nselected     : [" ed.Value "]  (clicked, so the buffer is empty)`n"
SendEvent "^!{sc026}"           ; Ctrl+Alt+L
Sleep 2000
Rec .= "after ^!L    : [" ed.Value "]   (want: לומר)`n"
Arm()
SendEvent "^{sc02C}"            ; Ctrl+Z
Sleep 1200
Rec .= "after ^Z     : [" ed.Value "]  LangFix acted: " Acted()
     . "   (want: kunr, acted no - the APPLICATION undid the paste)`n"

FileAppend Rec, A_ScriptDir "\_undo.txt", "UTF-8"
RestoreMouse()
ExitApp

; Put the sentinel on the clipboard, so the next keypress can be judged by
; whether it is still sitting there afterwards.
Arm() {
    global SENTINEL
    A_Clipboard := SENTINEL
    ClipWait(1, 0)
    Sleep 250
}

; "YES" when LangFix acted on the last keypress: it writes its result to the
; clipboard every time it changes text, and nothing else here does.
Acted() {
    global SENTINEL
    return (A_Clipboard == SENTINEL) ? "no" : "YES"
}

#Include screen.ahk
