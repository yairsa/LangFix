#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
SetKeyDelay 15, 15
SendLevel 1        ; level 0 input never triggers another script's hotkeys

; End-to-end test: types wrong-layout text into our own edit box, then
; presses the real LangFix hotkey and reads back what ended up there.

Rec := ""
g := Gui("+AlwaysOnTop", "LangFix e2e test")
ed := g.Add("Edit", "w500 h60")
SaveMouse()
Rec .= ScreenNote(ShowOffPrimary(g)) "`n"
WinActivate "ahk_id " g.Hwnd
Sleep 800
ControlFocus ed

SendEvent "{Text}nv to tbh"
Sleep 800
Rec .= "typed      : [" ed.Value "]`n"

SendEvent "^!{sc026}"          ; Ctrl+Alt+L
Sleep 1500
Rec .= "after ^!L  : [" ed.Value "]`n"

SendEvent "^!{sc026}"          ; again - should flip back
Sleep 1500
Rec .= "after ^!L#2: [" ed.Value "]`n"

FileAppend Rec, A_ScriptDir "\_e2e.txt", "UTF-8"
RestoreMouse()
ExitApp

#Include screen.ahk
