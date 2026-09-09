#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
SetKeyDelay 15, 15
SendLevel 1        ; level 0 input never triggers another script's hotkeys

; End-to-end test of the two rules that keep a fix from eating text that
; was already right:
;   1. it stops at the last character in the other language
;   2. it never crosses a line break
;
; Both are typed into our own multi-line edit box, then the real LangFix
; hotkey is pressed and the result read straight back off the control.

Flat(v) => StrReplace(StrReplace(v, "`r`n", " / "), "`n", " / ")

Rec := ""
g := Gui("+AlwaysOnTop", "LangFix e2e - partial fix and line breaks")
ed := g.Add("Edit", "w600 h140 Multi")
SaveMouse()
Rec .= ScreenNote(ShowOffPrimary(g)) "`n"
WinActivate "ahk_id " g.Hwnd
Sleep 800
ControlFocus ed

; --- 1. English line that slipped into Hebrew at the end -------------
SendEvent "{Text}in case גולן is at the correct פךשבק"
Sleep 700
Rec .= "typed      : [" ed.Value "]`n"

SendEvent "^!{sc026}"          ; Ctrl+Alt+L
Sleep 1500
Rec .= "after ^!L  : [" ed.Value "]`n"
Rec .= "  want     : [in case גולן is at the correct place]`n"

SendEvent "^!{sc026}"          ; again - flips back the SAME run only
Sleep 1500
Rec .= "after ^!L#2: [" ed.Value "]`n"
Rec .= "  want     : [in case גולן is at the correct פךשבק]`n`n"

; --- 2. a previous line must survive untouched -----------------------
ed.Value := ""
Sleep 300
ControlFocus ed
SendEvent "{Text}keep this line"
Sleep 400
SendEvent "{Enter}"
Sleep 400
SendEvent "{Text}akuo"
Sleep 700
Rec .= "typed      : [" Flat(ed.Value) "]`n"

SendEvent "^!{sc026}"          ; Ctrl+Alt+L
Sleep 1500
Rec .= "after ^!L  : [" Flat(ed.Value) "]`n"
Rec .= "  want     : [keep this line / שלום]`n"

FileAppend Rec, A_ScriptDir "\_partial.txt", "UTF-8"
RestoreMouse()
ExitApp

#Include screen.ahk
