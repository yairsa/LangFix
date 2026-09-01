#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
#UseHook true
SetKeyDelay 8, 8

; =====================================================================
;  LangFix - Hebrew/English fixes for Windows
;
;  Ctrl+Alt+L   Fix text written in the wrong language. It works on,
;               in this order:
;                 1. what you just TYPED or PASTED - the script watches
;                    the characters going in, backspaces over them and
;                    retypes them in the other layout. No selecting, no
;                    copying, so it works in consoles and TUIs (Claude
;                    Code, cmd, PowerShell) where a mouse drag is not a
;                    real text selection at all.
;                 2. otherwise, whatever is SELECTED - pasted back over
;                    the selection. For Word, ReadAll, browsers.
;               It then SWITCHES THE KEYBOARD to the language the text
;               ended up in - needing this hotkey means the keyboard was
;               wrong, and it still is, so the next keystroke would be
;               wrong too. Press it again to flip both back.
;
;  Ctrl+C       Nothing to press. Hebrew copied out of a CONSOLE is
;               un-reversed automatically, the moment it is copied, so a
;               plain Ctrl+V pastes it correctly anywhere. Text copied
;               from Word / Chrome / ReadAll is never touched - the fix
;               happens at copy time, where we still know the origin.
;               Toggle it from the tray menu.
;
;  Ctrl+Alt+R   Manual version of the same thing: un-reverse whatever is
;               on the clipboard and paste it at the cursor. For copies
;               the automatic rule did not catch.
;
;  Ctrl+Alt+Shift+L   Force the SELECTION path, skipping the typed
;                     buffer. Falls back to fixing the clipboard when
;                     nothing is selected.
;                     NOTE: ReadAll uses Ctrl+Shift+Alt+L for its own
;                     inbox - LangFix intercepts it first, so use plain
;                     Ctrl+Alt+L there.
;  Ctrl+Alt+Shift+R   Reverse fix on the clipboard only, no paste.
;
;  Ctrl+Alt+D   Show what is currently in the typing buffer.
;
;  The typed-characters buffer lives in memory only, never touches disk,
;  holds at most 1000 characters and is cleared on Enter, Esc, Tab, any
;  arrow/Home/End/Delete, any Ctrl or Alt combo except Ctrl+V, any mouse
;  click, and whenever the active window changes.
;
;  To change a hotkey, edit the HOTKEYS block below.
;    ^ = Ctrl   ! = Alt   + = Shift   # = Win
; =====================================================================

; ----------------------------- HOTKEYS -------------------------------
; Bound to SCAN CODES, i.e. to the physical keys, so they fire the same
; whether the keyboard is on English or Hebrew - the L key is also ך and
; the R key is also ר.   sc026 = L,  sc013 = R,  sc020 = D
^!sc026::  FixTyped()          ; Ctrl+Alt+L        fix what I just typed
^!sc013::  FixClipboard(true)  ; Ctrl+Alt+R        unreverse clipboard + paste
^!+sc026:: FixSelection()      ; Ctrl+Alt+Shift+L  fix the selection
^!+sc013:: FixClipboard(false) ; Ctrl+Alt+Shift+R  unreverse clipboard only
^!sc020::  ShowBuffer()        ; Ctrl+Alt+D        what's in the buffer

; Alt-free twins. Any hotkey containing Alt can nudge an app's menu bar
; (see SwallowAlt below); these avoid the question entirely. Win+L itself
; belongs to Windows and cannot be taken by any hook - it is handled below
; the hook layer - so Win+Shift+L is the closest free equivalent.
#+sc026::  FixTyped()          ; Win+Shift+L
#+sc013::  FixClipboard(true)  ; Win+Shift+R
; ---------------------------------------------------------------------

; reset the buffer on any mouse click (~ = let the click through)
~LButton::  ResetBuf()
~RButton::  ResetBuf()
~MButton::  ResetBuf()

; a paste inserts text we did not watch being typed - record it too, so
; Ctrl+Alt+L can fix pasted text exactly like typed text
~^sc02F::  TrackPaste()      ; Ctrl+V
~^+sc02F:: TrackPaste()      ; Ctrl+Shift+V (paste as plain text)


; ============================ layout map =============================
; English (US) key  ->  character the same key types on the Hebrew layout
global E2H := Map(
    "q","/",  "w","'",  "e","ק", "r","ר", "t","א", "y","ט", "u","ו",
    "i","ן",  "o","ם",  "p","פ", "[","]", "]","[",
    "a","ש",  "s","ד",  "d","ג", "f","כ", "g","ע", "h","י", "j","ח",
    "k","ל",  "l","ך",  ";","ף", "'",",",
    "z","ז",  "x","ס",  "c","ב", "v","ה", "b","נ", "n","מ", "m","צ",
    ",","ת",  ".","ץ",  "/","." )

global H2E := Map()
for k, v in E2H.Clone() {
    H2E[v] := k                           ; Hebrew -> English
    up := StrUpper(k)
    ; !== is the CASE-SENSITIVE comparison. With plain != , "Q" != "q" is
    ; false, so no capital was ever added to the map - which is why Word's
    ; auto-capitalised letters came through the conversion untouched.
    if (up !== k)
        E2H[up] := v                      ; SHIFTed English -> same Hebrew letter
}

; ======================== typed-text buffer ==========================
global Buf    := ""        ; characters typed since the last reset
global BufWin := 0         ; window they were typed into
global Busy   := false     ; true while WE are sending keys

; ===================== auto-fix console copies =======================
; Hebrew copied out of a console arrives visually ordered. We fix it at
; COPY time, not paste time, because only at copy time do we know where
; the text came from. After this, a plain Ctrl+V pastes correctly into
; anything, and text copied from Word/Chrome/ReadAll is never touched.
global AutoFix := true
global ClipGuardUntil := 0     ; ignore clipboard changes we caused ourselves

OnClipboardChange ClipChanged

ClipChanged(dataType) {
    global AutoFix, ClipGuardUntil
    if (dataType != 1 || !AutoFix)             ; 1 = the clipboard holds text
        return
    if (A_TickCount < ClipGuardUntil)          ; that change was ours
        return
    if (!IsTerminal())                         ; only consoles produce this
        return
    txt := A_Clipboard
    if (txt = "" || !HasHebrew(txt))
        return
    fixed := UnreverseText(txt)
    if (fixed = txt)
        return
    SetClip(fixed)
    Toast("console copy un-reversed")
}

; Every clipboard write of ours goes through here, so ClipChanged can tell
; our own writes from a real copy and never loops.
SetClip(text) {
    global ClipGuardUntil
    ClipGuardUntil := A_TickCount + 800
    A_Clipboard := text
    ClipWait(1)
}

Guard(ms := 800) {
    global ClipGuardUntil
    ClipGuardUntil := A_TickCount + ms
}

; ====================== keyboard language switch =====================
; Needing Ctrl+Alt+L means the keyboard was on the wrong language, and it
; still is - so after fixing the text, switch to the language the text
; actually ended up in. Otherwise the next keystroke is wrong too.
global SwitchLang := true

; Pick a loaded layout: the Hebrew one, or the first non-Hebrew one.
FindLayout(wantHebrew) {
    n := DllCall("GetKeyboardLayoutList", "Int", 0, "Ptr", 0, "Int")
    if (n < 1)
        return 0
    buf := Buffer(n * A_PtrSize, 0)
    DllCall("GetKeyboardLayoutList", "Int", n, "Ptr", buf, "Int")
    other := 0
    Loop n {
        hkl  := NumGet(buf, (A_Index - 1) * A_PtrSize, "Ptr")
        lang := hkl & 0xFFFF
        if (wantHebrew && lang = 0x040D)
            return hkl
        if (!wantHebrew && lang != 0x040D && !other)
            other := hkl
    }
    return wantHebrew ? 0 : other
}

LayoutCount() {
    return DllCall("GetKeyboardLayoutList", "Int", 0, "Ptr", 0, "Int")
}

CurrentLayout(hwnd) {
    tid := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    return DllCall("GetKeyboardLayout", "UInt", tid, "Ptr")
}

SwitchLayout(wantHebrew) {
    global SwitchLang
    if (!SwitchLang)
        return false
    target := FindLayout(wantHebrew)
    if (!target)                                   ; that language isn't installed
        return false
    hwnd := WinExist("A")
    if (CurrentLayout(hwnd) = target)
        return true

    ; The polite way: ask the window to change its input language.
    PostMessage 0x0050, 0, target, , "ahk_id " hwnd      ; WM_INPUTLANGCHANGEREQUEST
    Sleep 150
    if (CurrentLayout(hwnd) = target)
        return true

    ; Some apps ignore that message - fall back to the OS switcher, at most
    ; once per installed layout so we can never spin.
    Loop Max(LayoutCount() - 1, 1) {
        Send "#{Space}"
        Sleep 250
        if (CurrentLayout(hwnd) = target)
            return true
    }
    return false
}

IsTerminal() {
    try {
        cls  := WinGetClass("A")
        proc := WinGetProcessName("A")
    } catch
        return false
    if (cls = "CASCADIA_HOSTING_WINDOW_CLASS"     ; Windows Terminal
        || cls = "ConsoleWindowClass"             ; cmd / conhost
        || cls = "PseudoConsoleWindow"
        || cls = "mintty")                        ; Git Bash
        return true
    for p in ["WindowsTerminal.exe", "wt.exe", "conhost.exe", "cmd.exe",
              "powershell.exe", "pwsh.exe", "mintty.exe", "alacritty.exe",
              "WezTerm-gui.exe"]
        if (proc = p)
            return true
    return false
}

global DEBUG := false      ; set true to log every keystroke to _dbg.txt
Dbg(s) {
    global DEBUG
    if (DEBUG)
        FileAppend s "`n", A_ScriptDir "\_dbg.txt", "UTF-8"
}
Dbg("=== script started ===")   ; only writes when DEBUG is true

global IH := InputHook("V")          ; V = visible: keys still reach the app
IH.KeyOpt("{All}", "N")              ; notify on key-down for every key
IH.OnChar    := BufChar
IH.OnKeyDown := BufKey
IH.Start()

; The hook keeps its own transcript of everything typed. We never use it,
; so wipe it regularly - only our own 300-char buffer should exist.
SetTimer TrimHook, 20000
TrimHook() {
    global IH
    if (StrLen(IH.Input) > 200) {
        IH.Stop()
        IH.Start()
    }
}

ResetBuf() {
    global Buf
    Buf := ""
}

BufChar(ih, char) {
    global Buf, BufWin, Busy
    if (Busy)
        return
    ; A Ctrl/Alt combo produces a control character here. Ignore it -
    ; never clear the buffer from this callback, or our own Ctrl+Alt+L
    ; would wipe the buffer a moment before FixTyped() reads it.
    if (GetKeyState("Control", "P") || GetKeyState("Alt", "P"))
        return
    hwnd := WinExist("A")
    if (hwnd != BufWin) {                 ; moved to another window
        Dbg("char '" char "' : window changed " BufWin " -> " hwnd " (buffer cleared)")
        Buf := ""
        BufWin := hwnd
    }
    Buf .= char
    Dbg("char '" char "' -> Buf=[" Buf "] hwnd=" hwnd)
    if (StrLen(Buf) > 1000)
        Buf := SubStr(Buf, -1000)
}

BufKey(ih, vk, sc) {
    global Buf, Busy
    if (Busy)
        return
    Dbg("key vk=" Format("{:02X}", vk) " sc=" Format("{:03X}", sc)
        . " ctrl=" (GetKeyState("Control","P") ? 1 : 0)
        . " alt=" (GetKeyState("Alt","P") ? 1 : 0) " Buf=[" Buf "]")
    if (vk = 0x08) {                      ; BackSpace
        Buf := SubStr(Buf, 1, -1)
        return
    }
    ; Enter, Esc, Tab, PgUp/PgDn, End/Home, arrows, Insert, Delete
    if (vk = 0x0D || vk = 0x1B || vk = 0x09 || (vk >= 0x21 && vk <= 0x2E)) {
        Buf := ""
        return
    }
    ; Any other Ctrl/Alt combo (Ctrl+V, Ctrl+A, Alt+Tab...) invalidates the
    ; buffer, because text may have arrived that we never saw typed.
    if (GetKeyState("Control", "P") || GetKeyState("Alt", "P")) {
        if (IsModifierVK(vk) || IsOurHotkey(sc))
            return                        ; a modifier, or one of our own keys
        Buf := ""
    }
}

IsModifierVK(vk) {
    return vk = 0x10 || vk = 0x11 || vk = 0x12      ; Shift, Control, Alt
        || (vk >= 0xA0 && vk <= 0xA5)               ; L/R Shift, Ctrl, Alt
        || vk = 0x5B || vk = 0x5C                   ; L/R Win
        || vk = 0x14                                ; CapsLock
}

; Our own hotkeys must not disturb the buffer they are about to act on,
; and neither must Ctrl+V - a paste EXTENDS the buffer via TrackPaste()
; instead of invalidating it.
IsOurHotkey(sc) {
    return sc = 0x026 || sc = 0x013 || sc = 0x020   ; L, R, D
        || sc = 0x02F                               ; V
}

; Called the moment Ctrl+V is pressed. The paste itself happens a beat
; later, so read the clipboard now and append it just after.
TrackPaste() {
    global Busy
    if (Busy)
        return
    txt := A_Clipboard
    SetTimer () => AppendPaste(txt), -150
}

AppendPaste(txt) {
    global Buf, BufWin
    ; Multi-line or very large pastes are not safely reversible by
    ; backspacing, so drop the buffer rather than guess at it.
    if (txt = "" || StrLen(txt) > 1000 || InStr(txt, "`n") || InStr(txt, "`r")) {
        Buf := ""
        return
    }
    hwnd := WinExist("A")
    if (hwnd != BufWin) {
        Buf := ""
        BufWin := hwnd
    }
    Buf .= txt
    Dbg("paste appended -> Buf=[" Buf "]")
}

ShowBuffer() {
    global Buf
    SwallowAlt()
    Toast(Buf = "" ? "buffer empty" : "[" Buf "]", 2500)
}

; ============================== actions ==============================
; Ctrl+Alt+L, in order of preference:
;   1. text we watched being TYPED or PASTED  -> backspace over it, retype
;   2. otherwise whatever is SELECTED         -> paste over the selection
; The buffer is preferred because a mouse click clears it, so a non-empty
; buffer means "I have been typing here" - and asking some apps to copy
; with nothing selected (VS Code, for one) grabs the whole line instead.
FixTyped() {
    global Buf, BufWin
    SwallowAlt()
    Dbg("HOTKEY FixTyped: Buf=[" Buf "] BufWin=" BufWin " active=" WinExist("A"))
    if (Buf != "" && WinExist("A") = BufWin) {
        ReplaceTyped()
        return
    }
    if (FixSelection(true))
        return
    Toast("nothing to fix - type it, paste it, or select it", 2200)
}

; Replace the tail of the input we have been watching.
ReplaceTyped() {
    global Buf, Busy
    src := Buf
    out := SwapLayout(src)
    ReleaseModifiers()
    Busy := true
    TypeOut(StrLen(src), out)
    Sleep 30
    Busy := false
    Buf := out                            ; press again to flip back
    SetClip(out)
    AnnounceFixed(out)
}

; Backspace over n characters and type the replacement. Terminals need the
; slower event-based send; everywhere else SendInput keeps long replacements
; from crawling.
TypeOut(n, text) {
    if (IsTerminal()) {
        SetKeyDelay 8, 8
        SendEvent "{BackSpace " n "}"
        SendEvent "{Text}" text
    } else {
        SendInput "{BackSpace " n "}"
        SendInput "{Text}" text
    }
}

; Fix a real selection - browsers, Word, ReadAll, chat boxes.
; Returns true if it found a selection and acted on it.
FixSelection(quiet := false) {
    global Busy
    ; FIRST - the hotkey's own Ctrl+Alt are still physically down, and a
    ; copy sent while Alt is held is Ctrl+Alt+C, which copies nothing.
    ReleaseModifiers()
    before := A_Clipboard
    Guard(3000)                                   ; this whole exchange is ours
    A_Clipboard := ""
    Send IsTerminal() ? "^+c" : "^c"              ; ^c would interrupt a console
    if (!ClipWait(0.7, 0) || A_Clipboard = "") {  ; nothing was selected
        A_Clipboard := before
        if (quiet)
            return false
        if (before = "") {
            Toast("nothing selected, clipboard empty")
            return false
        }
        SetClip(SwapLayout(before))               ; fall back to the clipboard
        Toast("clipboard fixed")
        return true
    }
    sel := A_Clipboard
    out := SwapLayout(sel)                        ; no trimming: the paste has
    if (out = "") {                               ; to match the selection
        A_Clipboard := before
        Toast("nothing to fix")
        return false
    }
    SetClip(out)
    ; NEVER paste over a selection unless the clipboard really holds the
    ; replacement. If another app is holding the clipboard open, the write
    ; can silently fail - and pasting then would wipe the selected text.
    if (A_Clipboard !== out) {
        A_Clipboard := before
        Toast("clipboard is busy - try again", 1800)
        return false
    }
    Busy := true
    Send "^v"
    Sleep 150
    Busy := false
    AnnounceFixed(out)
    return true
}

; Fix the clipboard's reversed Hebrew, optionally pasting it.
FixClipboard(paste) {
    global Busy
    SwallowAlt()
    txt := A_Clipboard
    if (txt = "") {
        Toast("clipboard is empty")
        return
    }
    SetClip(UnreverseText(txt))
    if (!paste) {
        Toast("clipboard fixed")
        return
    }
    ReleaseModifiers()
    Busy := true
    Send "^v"
    Sleep 120
    Busy := false
    Toast("pasted")
}

AnnounceFixed(out) {
    switched := SwitchLayout(HasHebrew(out))
    Toast(switched ? (HasHebrew(out) ? "fixed - keyboard now Hebrew"
                                     : "fixed - keyboard now English")
                   : "fixed")
}

; A hotkey containing Alt swallows its own letter, so the application only
; sees Alt pressed and then released with nothing in between - which Windows
; (and Electron apps like ReadAll) read as "activate the menu bar", leaving
; File highlighted as though something were selected. Sending an unassigned
; virtual key while Alt is still down makes it a real combination, and the
; menu stays put. vkE8 is unassigned, so no application acts on it.
SwallowAlt() {
    if (GetKeyState("Alt", "P"))
        Send "{Blind}{vkE8}"
}

; The hotkey's own Ctrl/Alt/Shift are still physically down - typing
; while they are held would produce control chars instead of characters.
ReleaseModifiers() {
    SwallowAlt()
    KeyWait "Control", "T1"
    KeyWait "Alt",     "T1"
    KeyWait "Shift",   "T1"
    Sleep 30
}

Toast(msg, ms := 900) {
    ToolTip msg
    SetTimer () => ToolTip(), -ms
}

; =========================== layout swap =============================
; Auto-detects direction: any Hebrew letter present -> Hebrew->English,
; otherwise English->Hebrew.
; Word (and Outlook, and Google Docs) silently replace straight quotes and
; dashes with typographic ones as you type. Those characters are not on any
; keyboard, so the map has no entry for them and they used to survive the
; conversion. Put them back to what the key actually produced first.
NormalizeTypography(s) {
    s := StrReplace(s, Chr(0x2019), "'")      ; ’ right single quote
    s := StrReplace(s, Chr(0x2018), "'")      ; ‘ left single quote
    s := StrReplace(s, Chr(0x201D), '"')      ; ” right double quote
    s := StrReplace(s, Chr(0x201C), '"')      ; “ left double quote
    s := StrReplace(s, Chr(0x2013), "-")      ; – en dash
    s := StrReplace(s, Chr(0x2014), "-")      ; — em dash
    s := StrReplace(s, Chr(0x05F3), "'")      ; ׳ geresh
    s := StrReplace(s, Chr(0x05F4), '"')      ; ״ gershayim
    return s
}

SwapLayout(s) {
    s := NormalizeTypography(s)
    tbl := HasHebrew(s) ? H2E : E2H
    out := ""
    Loop Parse s {
        c := A_LoopField
        out .= tbl.Has(c) ? tbl[c] : c
    }
    return out
}

HasHebrew(s) {
    Loop Parse s
        if (IsHebrewChar(A_LoopField))
            return true
    return false
}

IsHebrewChar(c) {
    o := Ord(c)
    return (o >= 0x05D0 && o <= 0x05EA)   ; alef..tav
}

; ========================= reversed-Hebrew fix =======================
; Console copies of RTL text come out visually ordered. Reverse each line
; that actually contains Hebrew, keeping Latin/digit runs readable and
; mirroring paired punctuation. Lines with no Hebrew are left untouched.
UnreverseText(s) {
    s := StrReplace(s, "`r`n", "`n")
    out := ""
    for i, line in StrSplit(s, "`n")
        out .= (i > 1 ? "`n" : "") . UnreverseLine(line)
    return out
}

UnreverseLine(line) {
    if (!HasHebrew(line))
        return line

    runs := [], cur := "", curT := ""
    Loop Parse line {
        c := A_LoopField
        t := IsLatinish(c) ? "L" : "O"
        if (cur != "" && t != curT) {
            runs.Push({t: curT, v: cur})
            cur := ""
        }
        curT := t
        cur .= c
    }
    if (cur != "")
        runs.Push({t: curT, v: cur})

    out := ""
    Loop runs.Length {
        r := runs[runs.Length - A_Index + 1]
        out .= (r.t = "L") ? r.v : RevStr(r.v)
    }
    return out
}

IsLatinish(c) {
    o := Ord(c)
    return (o >= 0x30 && o <= 0x39)       ; 0-9
        || (o >= 0x41 && o <= 0x5A)       ; A-Z
        || (o >= 0x61 && o <= 0x7A)       ; a-z
}

global MIRROR := Map("(",")", ")","(", "[","]", "]","[", "{","}", "}","{",
                     "<",">", ">","<")

RevStr(s) {
    out := ""
    Loop Parse s {
        c := A_LoopField
        out := (MIRROR.Has(c) ? MIRROR[c] : c) . out
    }
    return out
}

; ============================ tray menu ==============================
A_TrayMenu.Delete()
A_TrayMenu.Add("LangFix - Ctrl+Alt+L (typed) / Ctrl+Alt+R (reversed)", (*) => 0)
A_TrayMenu.Disable("LangFix - Ctrl+Alt+L (typed) / Ctrl+Alt+R (reversed)")
A_TrayMenu.Add()
A_TrayMenu.Add("Auto un-reverse Hebrew copied from consoles", ToggleAutoFix)
A_TrayMenu.Check("Auto un-reverse Hebrew copied from consoles")
A_TrayMenu.Add("Also switch the keyboard language on Ctrl+Alt+L", ToggleSwitchLang)
A_TrayMenu.Check("Also switch the keyboard language on Ctrl+Alt+L")

ToggleSwitchLang(name, *) {
    global SwitchLang
    SwitchLang := !SwitchLang
    if (SwitchLang)
        A_TrayMenu.Check(name)
    else
        A_TrayMenu.Uncheck(name)
    Toast(SwitchLang ? "language switching ON" : "language switching OFF", 1400)
}

ToggleAutoFix(name, *) {
    global AutoFix
    AutoFix := !AutoFix
    if (AutoFix)
        A_TrayMenu.Check(name)
    else
        A_TrayMenu.Uncheck(name)
    Toast(AutoFix ? "auto un-reverse ON" : "auto un-reverse OFF", 1400)
}
A_TrayMenu.Add()
A_TrayMenu.Add("Reload", (*) => Reload())
A_TrayMenu.Add("Exit", (*) => ExitApp())
TraySetIcon("shell32.dll", 174)
