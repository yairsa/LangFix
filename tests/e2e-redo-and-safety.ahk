#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
SetKeyDelay 15, 15
SendLevel 1        ; level 0 input never triggers another script's hotkeys

; Needs LangFix running.
;
; Two things:
;   A. Ctrl+Z and Ctrl+Y cycle - undo, redo, undo again - each putting back
;      exactly the characters the other took away.
;   B. THE SAFETY PROPERTY, which matters more than any feature here:
;      Ctrl+Alt+L with nothing to work on must leave the text ALONE. Not
;      shorten it, not empty it, not touch it. The worst case is a no-op.
;      (Yair, 09/09/2026: "worst case should do nothing, not delete the
;      text" - after Ctrl+Alt+L following a Ctrl+Y wiped a line with no
;      trace.)
;
; Evidence, as in e2e-undo.ahk: LangFix writes its result to the clipboard
; whenever it changes text, and the application does not. A sentinel on the
; clipboard before each keypress therefore says who acted.

global SENTINEL := "LANGFIX-TEST-SENTINEL"

Rec := ""
g := Gui("+AlwaysOnTop", "LangFix e2e - redo, and doing nothing safely")
ed := g.Add("Edit", "w600 h60")
SaveMouse()
Rec .= ScreenNote(ShowOffPrimary(g)) "`n"
Loop 5 {
    WinActivate "ahk_id " g.Hwnd
    if WinWaitActive("ahk_id " g.Hwnd, , 2)
        break
    Sleep 400
}
Refocus(g, ed)

; --- A. the undo / redo cycle ----------------------------------------
SendEvent "{Text}nv to tbh"
Sleep 700
SendEvent "^!{sc026}"          ; Ctrl+Alt+L
Sleep 1600
Rec .= "after ^!L    : [" ed.Value "]   (want: מה אם אני)`n"

Arm()
SendEvent "^{sc02C}"           ; Ctrl+Z
Sleep 1300
Rec .= "after ^Z     : [" ed.Value "]  LangFix acted: " Acted()
     . "   (want: nv to tbh, YES)`n"

Arm()
SendEvent "^{sc015}"           ; Ctrl+Y
Sleep 1300
Rec .= "after ^Y     : [" ed.Value "]  LangFix acted: " Acted()
     . "   (want: מה אם אני, YES)`n"

Arm()
SendEvent "^{sc02C}"           ; Ctrl+Z again - the cycle continues
Sleep 1300
Rec .= "after ^Z #2  : [" ed.Value "]  LangFix acted: " Acted()
     . "   (want: nv to tbh, YES - undo and redo cycle)`n"

; --- B. Ctrl+Alt+L with nothing to work on must not touch the text ---
; A click clears the typed buffer, and nothing is selected, so Ctrl+Alt+L
; has no source at all. This is the exact state that used to eat the line.
ed.Value := ""
Refocus(g, ed)
SendEvent "{Text}this line must survive"
Sleep 700
ed.GetPos(&cx, &cy, &cw, &ch)
Click cx + 40, cy + 12          ; clears the buffer; selects nothing
Sleep 600
SendEvent "{End}"               ; make sure nothing is selected
Sleep 400
Rec .= "`nbefore       : [" ed.Value "]  (buffer cleared, nothing selected)`n"

Arm()
SendEvent "^!{sc026}"           ; Ctrl+Alt+L with no source
Sleep 2200
Rec .= "after ^!L    : [" ed.Value "]  LangFix acted: " Acted() "`n"
Rec .= "  want       : [this line must survive] - UNCHANGED, acted no`n"

; and again straight after a Ctrl+Y that had nothing to redo
Arm()
SendEvent "^{sc015}"            ; Ctrl+Y - nothing of ours to redo
Sleep 900
SendEvent "^!{sc026}"           ; Ctrl+Alt+L
Sleep 2200
Rec .= "after ^Y+^!L : [" ed.Value "]  LangFix acted: " Acted() "`n"
Rec .= "  want       : [this line must survive] - still UNCHANGED`n"

FileAppend Rec, A_ScriptDir "\_redo.txt", "UTF-8"
RestoreMouse()
ExitApp

Arm() {
    global SENTINEL
    A_Clipboard := SENTINEL
    ClipWait(1, 0)
    Sleep 250
}
Acted() {
    global SENTINEL
    return (A_Clipboard == SENTINEL) ? "no" : "YES"
}

#Include screen.ahk
