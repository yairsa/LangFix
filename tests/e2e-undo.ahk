#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
SetKeyDelay 15, 15
SendLevel 1        ; level 0 input never triggers another script's hotkeys

; Needs LangFix running.
;
; Ctrl+Z is everyone's undo key, so the interesting half of this test is not
; that LangFix undoes a fix - it is that it GIVES THE KEY BACK. Three things
; are checked, and the last two matter more than the first:
;   1. after a fix, Ctrl+Z puts the original characters back
;   2. a second Ctrl+Z is the application's own undo, not a redo
;   3. with no fix pending, Ctrl+Z was never ours at all

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
Sleep 1500
Rec .= "after ^!L    : [" ed.Value "]   (want: מה אם אני)`n"

SendEvent "^{sc02C}"           ; Ctrl+Z
Sleep 1200
Rec .= "after ^Z     : [" ed.Value "]   (want: nv to tbh)`n"

; --- 2. the second Ctrl+Z belongs to the app, and must not redo -------
SendEvent "^{sc02C}"           ; Ctrl+Z again
Sleep 1200
Rec .= "after ^Z #2  : [" ed.Value "]   (want: NOT מה אם אני - no redo)`n"

; --- 3. no fix pending: Ctrl+Z was never ours ------------------------
ed.Value := ""
Sleep 300
ControlFocus ed
SendEvent "{Text}plain typing"
Sleep 700
Rec .= "`ntyped        : [" ed.Value "]  (no fix made - Ctrl+Z is the app's)`n"
SendEvent "^{sc02C}"           ; Ctrl+Z
Sleep 1200
Rec .= "after ^Z     : [" ed.Value "]   (want: the EDIT's own undo ran,"
     . " i.e. the text is gone or changed - not still 'plain typing')`n"

; --- 4. the SELECTION path: Ctrl+Z must undo that fix too ------------
; We deliberately do not claim Ctrl+Z here - a fix through the selection
; path is a single paste, and the application's own undo restores it (and
; the selection) better than we could. This checks that the result Yair
; sees is the same either way: Ctrl+Z puts his text back.
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
SendEvent "^{sc02C}"            ; Ctrl+Z
Sleep 1200
Rec .= "after ^Z     : [" ed.Value "]   (want: kunr - the paste undone)`n"

FileAppend Rec, A_ScriptDir "\_undo.txt", "UTF-8"
RestoreMouse()
ExitApp

#Include screen.ahk
