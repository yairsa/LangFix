#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
SetKeyDelay 20, 20
SendLevel 1

; Same test, but with the Hebrew layout active in the target window and
; using PHYSICAL key presses. Proves Ctrl+Alt+L still fires when the L key
; types ך, and that Hebrew -> English conversion works.

Rec := ""
g := Gui("+AlwaysOnTop", "LangFix hebrew e2e")
ed := g.Add("Edit", "w500 h60")
SaveMouse()
Rec .= ScreenNote(ShowOffPrimary(g)) "`n"
WinActivate "ahk_id " g.Hwnd
Sleep 600

; switch THIS thread (which owns the foreground window) to he-IL
hkl := DllCall("LoadKeyboardLayout", "Str", "0000040D", "UInt", 1, "Ptr")   ; KLF_ACTIVATE
DllCall("ActivateKeyboardLayout", "Ptr", hkl, "UInt", 0, "Ptr")
Sleep 800
ControlFocus ed
Rec .= "layout now : " Format("{:08X}", DllCall("GetKeyboardLayout", "UInt", DllCall("GetWindowThreadProcessId", "Ptr", g.Hwnd, "Ptr", 0, "UInt"), "Ptr")) "`n"

; physical N and V keys -> should type מ and ה on the Hebrew layout
SendEvent "{sc031}{sc02F}"
Sleep 800
Rec .= "typed      : [" ed.Value "]`n"

SendEvent "^!{sc026}"          ; Ctrl+Alt + physical L key (= ך in Hebrew)
Sleep 1500
Rec .= "after ^!L  : [" ed.Value "]`n"

FileAppend Rec, A_ScriptDir "\_e2e_heb.txt", "UTF-8"
RestoreMouse()
ExitApp

#Include screen.ahk
