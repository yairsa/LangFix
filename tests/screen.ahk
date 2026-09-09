; Test windows go on a NON-PRIMARY monitor.
;
; An e2e run takes over the keyboard and mouse for the better part of a
; minute; doing that on top of whatever is being read on the main screen is
; the one thing these tests must not do. A window shown with no coordinates
; opens on the primary monitor every time, so every test window is placed
; explicitly through here.
;
; Clicks inside the tests stay correct after the move: AutoHotkey v2's
; CoordMode for the mouse defaults to Client, i.e. relative to the window.
;
; Returns the monitor index used, or 0 when there is only one screen and
; the primary is all we have.

ShowOffPrimary(g, opts := "") {
    primary := MonitorGetPrimary()
    target  := 0
    Loop MonitorGetCount()
        if (A_Index != primary) {
            target := A_Index
            break
        }
    MonitorGetWorkArea(target ? target : primary, &l, &t, &r, &b)
    g.Show(opts " x" (l + 60) " y" (t + 60))
    return target
}

; One line for the test's own log, so a run on a single-screen machine says
; so instead of silently taking over the only screen there is.
ScreenNote(mon) {
    return mon ? ("test window on monitor " mon " (not the primary)")
               : "ONLY ONE MONITOR - this run is on the primary screen"
}

; ---------------------------------------------------------------------
; A test may click, but it must give the pointer back. Whatever the test
; does with the mouse, it ends where Yair left it - a cursor parked in a
; test window has moved his hand for him.
global _mx := 0, _my := 0

SaveMouse() {
    global _mx, _my
    CoordMode "Mouse", "Screen"
    MouseGetPos &_mx, &_my
    CoordMode "Mouse", "Client"      ; back to the default the tests click in
}

RestoreMouse() {
    global _mx, _my
    CoordMode "Mouse", "Screen"
    DllCall("SetCursorPos", "Int", _mx, "Int", _my)
    CoordMode "Mouse", "Client"
}
