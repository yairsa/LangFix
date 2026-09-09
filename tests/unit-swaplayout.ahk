#Requires AutoHotkey v2.0
#SingleInstance Force

; Pure-logic checks, no focus needed:
;   SwapLayout  - using Yair's real Word paragraph: capital letters (Word
;                 auto-capitalises) and curly quotes (Word smart quotes)
;                 both used to survive the conversion untouched.
;   TailStart   - where a fix is allowed to start, so a Hebrew name in an
;                 English line is not swept up with the wrong-layout tail.
;   LastLine    - a fix never crosses a line break.

Rec := ""

Check(label, got, want) {
    global Rec
    Rec .= (got == want ? "PASS  " : "FAIL  ") . label "`n"
        . "         got  [" got "]`n         want [" want "]`n"
}

; --------------------------- SwapLayout ------------------------------
cases := [
    ["Cut", "בוא"],
    ["T,v", "אתה"],
    ["akuo' tbh rumv kunr a", "שלום, אני רוצה לומר ש"],
    ["trul" Chr(0x2019) " tck", "ארוך, אבל"],          ; Word's curly apostrophe
    ["Cut bbhj af,c, j,hf, nxnl trul" Chr(0x2019),
     "בוא נניח שכתבת חתיכת מסמך ארוך,"],
    ["שלום", "akuo"],
    ["hello world", "יקךךם 'םרךג"] ]

for c in cases
    Check("[" c[1] "]", SwapLayout(c[1]), c[2])

; ---------------------------- TailStart ------------------------------
; Expressed as the substring a fix would touch - everything before it must
; be left exactly as it was.
tails := [
    ; all one script -> the whole thing, as before
    ["akuo' tbh rumv",                        "akuo' tbh rumv"],
    ["שלום",                                   "שלום"],
    ["",                                      ""],
    ["12:45 (7)",                             "12:45 (7)"],     ; no letters
    ; Yair's case: English line that slipped into Hebrew at the end
    ["in case גולן is at the correct פךשבק",  "פךשבק"],
    ["hello שלום",                             "שלום"],
    ["שלום akuo",                              "akuo"],
    ; digits and punctuation are neutral: the run walks straight past them
    ["send 3 files, ארהך",                     "ארהך"],
    ; and the flip-back is NOT computed this way - see LastFixStart in
    ; ReplaceTyped(); this is what TailStart alone would say afterwards
    ["in case גולן is at the correct place",  "is at the correct place"] ]

for c in tails
    Check("TailStart [" c[1] "]", SubStr(c[1], TailStart(c[1])), c[2])

; ----------------------------- LastLine ------------------------------
lines := [
    ["one line",                    "one line"],
    ["prev text`nakuo",             "akuo"],
    ["prev text`r`nakuo",           "akuo"],
    ["prev text`n",                 ""],
    ["a`nb`nc",                     "c"] ]

for c in lines
    Check("LastLine", LastLine(c[1]), c[2])

FileAppend Rec, A_ScriptDir "\_unit.txt", "UTF-8"
ExitApp

#Include ..\LangFix-logic.ahk
