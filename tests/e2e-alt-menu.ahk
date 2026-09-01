#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
SetKeyDelay 15, 15
SendLevel 1

; Needs LangFix running.
; A hotkey containing Alt suppresses its own letter, so the app only sees
; Alt press -> Alt release with nothing in between, which Windows reads as
; "activate the menu bar". This checks that pressing Ctrl+Alt+L leaves the
; menu bar alone, by asking Windows whether a menu is active afterwards.

Rec := ""

fileMenu := Menu()
fileMenu.Add("Open", (*) => 0)
fileMenu.Add("Save", (*) => 0)
bar := MenuBar()
bar.Add("&File", fileMenu)
bar.Add("&Edit", fileMenu)

g := Gui("+AlwaysOnTop", "LangFix alt-menu test")
g.MenuBar := bar
ed := g.Add("Edit", "w480 h60")
g.Show()
Loop 5 {
    WinActivate "ahk_id " g.Hwnd
    if WinWaitActive("ahk_id " g.Hwnd, , 2)
        break
    Sleep 400
}
Sleep 700
ControlFocus ed
ed.GetPos(&cx, &cy, &cw, &ch)
Click cx + 40, cy + 15
Sleep 500

Rec .= "window active        : " (WinActive("ahk_id " g.Hwnd) ? "yes" : "NO") "`n"
Rec .= "menu active at start : " MenuState() "`n"

SendEvent "{Text}akuo"
Sleep 600
SendEvent "^!{sc026}"
Sleep 2200

Rec .= "text after ^!L       : [" ed.Value "]`n"
Rec .= "menu active after    : " MenuState() "   (want: no)`n"

FileAppend Rec, A_ScriptDir "\_altmenu.txt", "UTF-8"
ExitApp

; GetGUIThreadInfo: hwndMenuOwner is non-zero, and GUI_INMENUMODE (0x4) is
; set in flags, whenever a menu bar has been activated.
MenuState() {
    static SIZE := 4 + 4 + (A_PtrSize * 6) + 16
    gti := Buffer(SIZE, 0)
    NumPut("UInt", SIZE, gti, 0)
    tid := DllCall("GetWindowThreadProcessId", "Ptr", WinExist("A"), "Ptr", 0, "UInt")
    if (!DllCall("GetGUIThreadInfo", "UInt", tid, "Ptr", gti))
        return "query failed"
    flags     := NumGet(gti, 4, "UInt")
    menuOwner := NumGet(gti, 4 + 4 + (A_PtrSize * 3), "Ptr")
    inMenu    := (flags & 0x4) || menuOwner
    return (inMenu ? "YES" : "no") . "  (flags=" Format("{:X}", flags)
         . " menuOwner=" menuOwner ")"
}
