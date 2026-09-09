#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
SetKeyDelay 15, 15
SendLevel 1

; Needs LangFix running. Checks that plain Ctrl+Alt+L now covers all three
; sources: typed text, PASTED text, and a SELECTION.

Rec := ""
g := Gui("+AlwaysOnTop", "LangFix paste/select test")
ed := g.Add("Edit", "w520 h80")
SaveMouse()
Rec .= ScreenNote(ShowOffPrimary(g)) "`n"
Loop 5 {
    WinActivate "ahk_id " g.Hwnd
    if WinWaitActive("ahk_id " g.Hwnd, , 2)
        break
    Sleep 500
}
Sleep 800
ControlFocus ed
Rec .= "window active  : " (WinActive("ahk_id " g.Hwnd) ? "yes" : "NO") "`n"

en := DllCall("LoadKeyboardLayout", "Str", "00000409", "UInt", 1, "Ptr")
DllCall("ActivateKeyboardLayout", "Ptr", en, "UInt", 0, "Ptr")
Sleep 400

; ---------- 1. typed, then pasted, fixed together ----------
SendEvent "{Text}akuo "
Sleep 500
A_Clipboard := "tbh rumv"
ClipWait(1)
Sleep 400
SendEvent "^{sc02F}"                      ; Ctrl+V
Sleep 900
Rec .= "1 typed+pasted : [" ed.Value "]`n"
SendEvent "^!{sc026}"
Sleep 2500
Rec .= "  after ^!L    : [" ed.Value "]   (want: שלום אני רוצה)`n"

; ---------- 2. a selection, via PLAIN Ctrl+Alt+L ----------
; re-take focus: switching the keyboard language can raise an OS flyout
WinActivate "ahk_id " g.Hwnd
WinWaitActive "ahk_id " g.Hwnd, , 3
Sleep 800
DllCall("ActivateKeyboardLayout", "Ptr", en, "UInt", 0, "Ptr")
ed.Value := ""
ControlFocus ed
Sleep 300
SendEvent "{Text}kunr"
Sleep 500
; a real click is what clears the typed buffer in real use - and it is the
; only thing that makes Ctrl+Alt+L fall through to the selection path
ed.GetPos(&cx, &cy, &cw, &ch)
Click cx + 40, cy + 12
Sleep 500
SendEvent "^{sc01E}"                      ; Ctrl+A - select all
Sleep 600
Rec .= "2 selected     : [" ed.Value "]  (clicked, so buffer is empty)`n"
SendEvent "^!{sc026}"
Sleep 2500
Rec .= "  after ^!L    : [" ed.Value "]   (want: לומר)`n"

FileAppend Rec, A_ScriptDir "\_pastesel.txt", "UTF-8"
RestoreMouse()
ExitApp

#Include screen.ahk
