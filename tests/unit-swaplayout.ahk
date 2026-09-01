#Requires AutoHotkey v2.0
#SingleInstance Force

; Pure-logic check of SwapLayout, using Yair's real Word paragraph:
; capital letters (Word auto-capitalises) and curly quotes (Word smart
; quotes) both used to survive the conversion untouched.

Rec := ""

cases := [
    ["Cut", "בוא"],
    ["T,v", "אתה"],
    ["akuo' tbh rumv kunr a", "שלום, אני רוצה לומר ש"],
    ["trul" Chr(0x2019) " tck", "ארוך, אבל"],          ; Word's curly apostrophe
    ["Cut bbhj af,c, j,hf, nxnl trul" Chr(0x2019),
     "בוא נניח שכתבת חתיכת מסמך ארוך,"],
    ["שלום", "akuo"],
    ["hello world", "יקךךם 'םרךג"] ]

for c in cases {
    got := SwapLayout(c[1])
    Rec .= (got == c[2] ? "PASS  " : "FAIL  ")
        . "[" c[1] "]`n         got  [" got "]`n         want [" c[2] "]`n"
}

FileAppend Rec, A_ScriptDir "\_unit.txt", "UTF-8"
ExitApp

#Include ..\LangFix-logic.ahk
