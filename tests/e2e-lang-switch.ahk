#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
SetKeyDelay 15, 15
SendLevel 1

; Needs LangFix running. Types wrong-layout English, presses Ctrl+Alt+L,
; then checks BOTH that the text was converted and that the keyboard
; language followed it to Hebrew - and back again on the second press.

Rec := ""
g := Gui("+AlwaysOnTop", "LangFix language-switch test")
ed := g.Add("Edit", "w520 h60")
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
ed.GetPos(&cx, &cy, &cw, &ch)
Click cx + 40, cy + 15          ; a real click guarantees focus
Sleep 500

; start from English
en := DllCall("LoadKeyboardLayout", "Str", "00000409", "UInt", 1, "Ptr")
DllCall("ActivateKeyboardLayout", "Ptr", en, "UInt", 0, "Ptr")
Sleep 500
Rec .= "start layout : " Lay() "`n"

SendEvent "{Text}akuo' tbh rumv kunr a"
Sleep 800
Rec .= "typed        : [" ed.Value "]  layout=" Lay() "`n"

SendEvent "^!{sc026}"
Sleep 2500
Rec .= "after ^!L    : [" ed.Value "]  layout=" Lay() "   (want Hebrew 040D)`n"

; switching the input language can raise the OS flyout, which steals focus -
; take it back before pressing again, or the hotkey acts on the wrong window
WinActivate "ahk_id " g.Hwnd
WinWaitActive "ahk_id " g.Hwnd, , 3
Sleep 600
SendEvent "^!{sc026}"
Sleep 2500
Rec .= "after ^!L #2 : [" ed.Value "]  layout=" Lay() "   (want English 0409)`n"

FileAppend Rec, A_ScriptDir "\_langswitch.txt", "UTF-8"
RestoreMouse()
ExitApp

Lay() {
    tid := DllCall("GetWindowThreadProcessId", "Ptr", WinExist("A"), "Ptr", 0, "UInt")
    ; An HKL is a POINTER: on 64-bit it sign-extends to FFFFFFFF.... and
    ; printing it whole made a correct Hebrew layout read as a failure.
    ; The language is the LOW WORD, and that is the only part we asked for.
    return Format("{:04X}", DllCall("GetKeyboardLayout", "UInt", tid, "Ptr") & 0xFFFF)
}

#Include screen.ahk
