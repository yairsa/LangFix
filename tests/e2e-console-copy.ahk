#Requires AutoHotkey v2.0
#SingleInstance Force

; Auto un-reverse test. Needs LangFix running.
; Puts reversed Hebrew on the clipboard twice: once with a console focused
; (should be corrected) and once with a normal window focused (must not be).

Rec := ""

; ---- 1. console focused ----
; conhost forces the LEGACY console host, so the window class is reliably
; ConsoleWindowClass. Plain "cmd.exe" opens inside Windows Terminal on this
; machine and the wait below would never match.
Run "conhost.exe cmd.exe", , , &pid
if (!WinWait("ahk_class ConsoleWindowClass", , 8)) {
    FileAppend "SKIPPED - no console window appeared`n", A_ScriptDir "\_consolecopy.txt", "UTF-8"
    RestoreMouse()
ExitApp
}
WinActivate "ahk_class ConsoleWindowClass"
Sleep 1000
Rec .= "active class    : " WinGetClass("A") "`n"
A_Clipboard := "(םלוע) םולש"          ; the true visual form of: שלום (עולם)
Sleep 1500
Rec .= "console  copy   : [" A_Clipboard "]   (want: שלום (עולם))`n"

; ---- 2. ordinary window focused ----
g := Gui("+AlwaysOnTop", "not a terminal")
g.Add("Edit", "w400 h50")
SaveMouse()
Rec .= ScreenNote(ShowOffPrimary(g)) "`n"
WinActivate "ahk_id " g.Hwnd
Sleep 1000
Rec .= "active class    : " WinGetClass("A") "`n"
A_Clipboard := "(םלוע) םולש"
Sleep 1500
Rec .= "non-console copy: [" A_Clipboard "]   (want it UNCHANGED)`n"

; ---- 3. English copied from a console must be untouched ----
WinActivate "ahk_class ConsoleWindowClass"
Sleep 800
A_Clipboard := "hello world"
Sleep 1200
Rec .= "console english : [" A_Clipboard "]   (want: hello world)`n"

try WinClose "ahk_class ConsoleWindowClass"
try ProcessClose pid
FileAppend Rec, A_ScriptDir "\_consolecopy.txt", "UTF-8"
ExitApp

#Include screen.ahk
