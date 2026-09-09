# LangFix — Hebrew/English keyboard fixes

Two global Windows shortcuts, always on. AutoHotkey v2 script, runs from the tray,
starts with Windows.

| Shortcut | What it does |
|---|---|
| **Ctrl + Alt + L** | **Fix text written in the wrong language** — covers what you just **typed**, what you just **pasted**, and any **selection**, in that order. Backspaces over it, retypes it in the other layout, **and switches the keyboard to that language**. Direction auto-detected. Only the **current line** and only its **trailing wrong-language run** are touched. Press again to flip both back. |
| *(nothing to press)* | **Hebrew copied from a console is un-reversed automatically**, at the moment you copy it. Plain `Ctrl+V` then pastes it correctly into anything. Copies from Word / Chrome / ReadAll are never touched. |
| **Ctrl + Alt + R** | Manual version of the above — un-reverse whatever is on the clipboard and paste it at the cursor, for copies the automatic rule missed. |
| **Ctrl + Alt + Shift + L** | Force the **selection** path, skipping the typed buffer. Falls back to the clipboard when nothing is selected. *(ReadAll uses this combination for its own inbox — see Notes.)* |
| **Ctrl + Alt + Shift + R** | Reverse fix on the **clipboard only**, no paste. |
| **Ctrl + Z** | **Undo the last fix** — the normal undo key. Puts back exactly what `Ctrl+Alt+L` changed. It is only LangFix's key in the moment it can be; the rest of the time it is your application's own undo, untouched. |
| **Ctrl + Alt + Z** | The same undo, always listening — so when nothing appears to happen, it says *why*. |
| **Ctrl + Alt + D** | Show the typing buffer, and what `Ctrl+Z` would put back (debug). |
| **Win + Shift + L / R** | Alt-free twins of the two main fixes. Same behaviour, no Alt involved. |

A small tooltip confirms each action.

## What a fix is allowed to touch

Two hard limits, both there so a press can never damage text that was already right.

**The current line only.** The buffer holds one line: a line break starts a new one, and a
fix never backspaces past it. Anything above the caret is previous text and is out of
reach — including after a multi-line paste, where only the part after the last line break
counts as fixable. *(This is the bug fixed on 09/09/2026: Enter arrives at the hook twice,
once as a key and once as the character `` `r ``. The key cleared the buffer, the character
then put a lone `` `r `` back into it — so the next fix backspaced through the line break
and ate the end of the line above.)*

**It stops at the last character that was already right.** A wrong-language run sits at the
*end* of what you typed — that is why you are pressing the key at all. So the fix takes the
script of the last letter, walks back over that script and over neutral characters (spaces,
digits, punctuation), and stops dead at the first letter of the other script:

```
in case גולן is at the correct פךשבק   -> Ctrl+Alt+L ->
in case גולן is at the correct place
        ^^^^ a real Hebrew word, before the last English letter — untouched
```

A second press flips back **exactly the same run**, not whatever the rule would pick out of
the now-corrected text.

**A selection is the exception: it is converted whole.** You chose where it starts and ends,
so `Ctrl+Alt+Shift+L` over a mixed line converts all of it. That is the escape hatch when
the run you want fixed is not at the end of the line.

## One key, three sources

`Ctrl+Alt+L` tries these in order:

1. **What you typed or pasted.** The script watches characters going in, so it can
   backspace over them and retype them. Needs no selection — which is the only thing that
   works in a console or TUI.
2. **Whatever is selected.** Copied, converted, pasted back over the selection. This is
   what covers Word, ReadAll, browsers, and any text you didn't type in this sitting.

The buffer wins when it isn't empty, deliberately: a mouse click clears it, so a non-empty
buffer means "I have been typing right here". It also avoids a trap — some editors
(VS Code among them) treat `Ctrl+C` with nothing selected as *copy the whole line*, and
preferring the buffer means we never ask them to.

**Pasted text counts as typed.** `Ctrl+V` used to invalidate the buffer; now the pasted
string is appended to it, so `Ctrl+Alt+L` fixes typed and pasted text together in one go.
A **multi-line** paste leaves only its last line in the buffer — the caret sits at the end
of that line, and everything before the caret on it came from the paste, so that much is
safely reversible while the lines above are not. Pastes over 1000 characters still drop the
buffer entirely.

**A whole-line copy is not a selection.** Some editors (VS Code, Visual Studio) answer
`Ctrl+C` with nothing selected by copying the entire line, trailing line break and all.
When `Ctrl+Alt+L` reaches the selection path on its own and gets back something ending in a
line break, it treats that as "nothing was selected" and stops, rather than pasting a
duplicate line.

## Undo is Ctrl+Z, and the rest of the time Ctrl+Z is not ours

A fix is many backspaces followed by a retype, so an application's own undo unpicks it in
pieces, if at all. So LangFix handles that one case itself: **`Ctrl+Z` puts back exactly the
characters the fix replaced**, and the keyboard language with them.

The delicate part is not undoing — it is **not owning `Ctrl+Z`**. The hotkey sits behind
`#HotIf CanUndoFix()`, so it *exists only* in the moment it can be right: straight after a
fix, in the same window, with the caret still where the fix left it. At every other moment
the hotkey is not there at all and `Ctrl+Z` reaches the application exactly as it always did.
Nothing to learn, nothing taken away.

- **After undoing once it hands the key straight back**, so a second `Ctrl+Z` is your
  application's own undo again. It is deliberately *not* a redo — that is not what that key
  means. To redo, fix it again with `Ctrl+Alt+L`.
- **A fix through the selection path is a single paste**, and your application's own `Ctrl+Z`
  undoes a paste in one press — restoring the selection too, which we could not. So LangFix
  does not claim the key after one. The result you see is the same either way: `Ctrl+Z` puts
  your text back.
- **In a console there is no application undo at all**, which is exactly where LangFix's own
  matters most.
- **`Ctrl+Alt+Z` is the same undo, always listening.** When `Ctrl+Z` does nothing because the
  key was not ours, `Ctrl+Alt+Z` says which reason it was: wrong window, caret moved, nothing
  fixed yet, or *that one was a paste — plain `Ctrl+Z` undoes it*.

One trap this had to close on the way in: the buffer must **not** treat `Ctrl+Z` as one of
ours when we are not holding the key. Otherwise an application-level undo would change the
text while our buffer survived unchanged — and a later fix would backspace over characters
that had already gone.

### Why not snapshot the whole field first

The obvious design is `Ctrl+A` + copy before every fix, and restore that on undo. It was
rejected: **`Ctrl+A` moves the caret**, and the fix's backspaces would then land wherever it
ended up. In a one-line field that is recoverable; in a multi-line field or a Word document
there is no way to put the caret back where you were, so the snapshot meant to protect the
text would be the thing that damaged it. It also has to borrow the clipboard, and restoring
in Word would paste plain text over the document and strip its formatting.

The undo above takes its snapshot **in memory** instead — it already knows the exact
characters it replaced — which costs no keystrokes, no clipboard and no caret movement.

## Why an Alt hotkey nudged ReadAll's menu bar

A hotkey containing Alt swallows its own letter, so the application only sees **Alt pressed,
then Alt released, with nothing in between** — which Windows, and Electron apps like ReadAll,
read as "activate the menu bar". That is why File lit up as though something inside it were
selected.

The fix is to make it a real combination: while Alt is still held, LangFix sends `vkE8`, an
**unassigned** virtual key. No application acts on it, but Windows no longer sees a bare Alt
tap, so the menu stays put.

**Win+Shift+L and Win+Shift+R** are Alt-free twins that avoid the question entirely.

### Win+L cannot be taken

`Win+L` is the Windows lock shortcut, and Windows handles it *below* the keyboard-hook layer —
no hook, AutoHotkey's included, ever sees it. The only way to claim it is a registry policy
that disables locking the workstation altogether, which also removes **Lock** from the
Ctrl+Alt+Del screen and the Start menu. `Win+Shift+L` is free and behaves identically.

## The keyboard language follows the text

Needing `Ctrl+Alt+L` means the keyboard was on the wrong language — and it still is, so the
very next keystroke would be wrong too. So after fixing the text, LangFix switches the
keyboard to whatever language the text ended up in.

```
akuo' tbh rumv kunr a   ->  Ctrl+Alt+L  ->  שלום, אני רוצה לומר ש
                                            + keyboard now on Hebrew
```

It asks the window politely first (`WM_INPUTLANGCHANGEREQUEST`); apps that ignore that get
the OS switcher (`Win+Space`) instead, tried at most once per installed layout so it can
never spin. If the target language isn't installed, the text is still fixed and the
keyboard is left alone.

Turn it off from the tray menu (**Also switch the keyboard language on Ctrl+Alt+L**).

## Word's autocorrect used to survive the conversion

Two characters classes came through a conversion untouched, which is what made the result
look *almost* right:

- **Capital letters.** `Cut` stayed `Cut` instead of becoming `בוא`. The map was built with
  `if (up != k)` to add the shifted letters — but in AutoHotkey `!=` is a **case-insensitive**
  comparison, so `"Q" != "q"` is false and not one capital was ever added to the map. The
  case-sensitive operator is `!==`. Word auto-capitalises the first letter of every sentence,
  so this showed up constantly.
- **Smart quotes and dashes.** Word silently rewrites `'` as `’`, `"` as `”`, `-` as `–`.
  Those characters are on no keyboard, so the map has no entry for them and they passed
  straight through — `trul’` became `ארוך’` instead of `ארוך,`. They are now normalised back
  to what the key actually produced before conversion.

## Why the copy is fixed, not the paste

At **copy** time we know where the text came from — the active window is the console.
At **paste** time that information is gone; the clipboard doesn't say who filled it. So
LangFix watches for clipboard changes and, when one happens while a console window is
focused *and* the text contains Hebrew *and* un-reversing it actually changes something,
it rewrites the clipboard right there. Everything downstream is then a normal `Ctrl+V`.

Consoles recognised: Windows Terminal, conhost/cmd, PowerShell, pwsh, Git Bash (mintty),
alacritty, WezTerm. Anything else — Word, Chrome, ReadAll, the CRM — is left alone.

Turn it off from the tray menu (**Auto un-reverse Hebrew copied from consoles**). If it
ever fires on text that was already in the right order, `Ctrl+Alt+R` flips it back — the
operation is its own inverse.

## The hotkeys are bound to the physical keys

They use **scan codes**, not letters, so they fire identically whether the keyboard is on
English or Hebrew — the L key is also `ך`, the R key is also `ר`, the D key is also `ג`.
Verified end-to-end with the Hebrew layout active. (`sc026` = L, `sc013` = R, `sc020` = D.)

## Why Ctrl+Alt+L works off what you typed, not off a selection

In a console or TUI — Windows Terminal, **Claude Code**, cmd, PowerShell — a mouse drag
is not a text selection the app knows about. Claude Code turns on mouse tracking, so the
drag goes to the application and no terminal selection exists at all: `Ctrl+C` and
`Ctrl+Shift+C` both copy **nothing**. Anything selection-based silently does nothing there.

So the main fix reads from a rolling buffer of the characters you actually typed. That
works identically in a terminal, a browser and Word.

### Selecting is fine now — but you rarely need to

Earlier versions worked *only* off the typed buffer, so selecting first broke them. Since
the cascade above, a selection is simply the second thing tried, and both work.

The buffer path is still the better one where it applies, because it needs nothing from the
application. It covers **the tail of what you typed or pasted**, and is cleared by Enter,
Esc, Tab, an arrow key, or a mouse click — deliberately, so it can never backspace over
characters the script did not watch go in. After any of those, a selection is what's left,
and `Ctrl+Alt+L` reaches for it automatically.

In a console there is no selection to reach for (see above), so there the buffer is the only
route: fix it before you press Enter.

### The buffer

In memory only, never written to disk, capped at 1000 characters, and **never holding a
line break**. Cleared on Enter, Esc, Tab, any arrow/Home/End/Delete, any Ctrl or Alt
combination **except Ctrl+V**, any mouse click, and whenever the active window changes. The keyboard hook's own transcript is wiped
every 20 seconds.

## Examples

```
nv to tbh rumv kf,uc  -> Ctrl+Alt+L ->  מה אם אני רוצה לכתוב
ן מקקג ש /וןבל כןס    -> Ctrl+Alt+L ->  i need a quick fix
!(םלוע) םולש          -> Ctrl+Alt+R ->  שלום (עולם)!

in case גולן is at the correct פךשבק
                      -> Ctrl+Alt+L ->  in case גולן is at the correct place
```

Brackets and parentheses are mirrored when reversing. Latin words and numbers inside a
Hebrew line keep their own order (`2026 Yair בוט רקוב` stays readable). A line with no
Hebrew in it is never touched by the reverse fix.

## Files

- `LangFix.ahk` — the script. Hotkeys are the five lines under `; HOTKEYS`.
  `^` = Ctrl, `!` = Alt, `+` = Shift, `#` = Win.
- `tests\e2e-typed-fix.ahk` — types wrong-layout text into its own box, presses the real
  hotkey, checks the result and that a second press flips it back.
- `tests\e2e-hebrew-layout.ahk` — the same with the Hebrew layout forced on, pressing the
  physical L key (`ך`).
- `tests\e2e-console-copy.ahk` — puts reversed Hebrew on the clipboard with a console
  focused (must be corrected), with a normal window focused (must not be), and English
  from a console (must not be).
- `tests\e2e-lang-switch.ahk` — types wrong-layout English, presses the hotkey, and checks
  both the text and the active keyboard layout, in both directions.
- `tests\e2e-paste-and-select.ahk` — typed-plus-pasted text fixed in one press, and the
  fall-through to the selection path after a click.
- `tests\e2e-undo.ahk` — `Ctrl+Z` after a fix, and the two things that matter more: that a
  second `Ctrl+Z` is the application's own undo rather than a redo, and that with no fix
  pending the key was never ours at all. Plus the same through the selection path.
- `tests\e2e-partial-and-lines.ahk` — the two limits above: a mixed English/Hebrew line
  where only the trailing run may change (and a second press flips back only that run),
  and a fix on a second line that must leave the first alone.
- `tests\unit-swaplayout.ahk` — pure conversion checks, including the capitals and curly
  quotes from a real Word paragraph, plus `TailStart` (where a fix may begin) and
  `LastLine`. No focus needed.
- `tests\e2e-alt-menu.ahk` — presses the hotkey over a window with a menu bar and asks
  Windows (`GetGUIThreadInfo`) whether a menu became active.
- `tests\screen.ahk` — shared by every e2e test: puts the test window on the **secondary**
  monitor, and saves and restores the mouse pointer.
- `tests\run-all.ps1` — restarts LangFix from disk (which is also the syntax check) and runs
  the tests:
  - `pwsh -File tests\run-all.ps1` — **unit tests only.** Silent, takes nothing, safe to run
    at any moment. This is the default deliberately.
  - `pwsh -File tests\run-all.ps1 -E2E` — **also the end-to-end tests, which take over the
    keyboard and mouse for about a minute.** Start them only when you are away from the
    machine; anything you type meanwhile lands in the wrong window. They open on the
    secondary monitor and put the pointer back, but focus is theirs while they run — the fix
    under test reads a low-level keyboard hook, and a hook only ever sees real input.

  All the e2e tests need LangFix running, and they send at `SendLevel 1` — level-0 synthetic
  input never triggers another script's hotkeys, which is why a naive test appears to do
  nothing.
- Startup shortcut: `%AppData%\Microsoft\Windows\Start Menu\Programs\Startup\LangFix.lnk`
- `LangFix-Control.ps1` — health check and on/off switch; see **Control** below.
- `LangFix.bat` — double-clickable wrapper around it. Desktop copy: **LangFix Control**.

## Control

- Tray icon → **Reload** after editing the script, **Exit** to stop it.
- Start it manually: double-click `LangFix.ahk`.
- Debugging: set `DEBUG := true` near the top and every keystroke is logged to `_dbg.txt`.
  **It records everything you type — turn it back off and delete the file when done.**
- **`LangFix.bat` — the control panel.** Double-click it (or the **LangFix Control**
  shortcut on the desktop) for a health check: whether it is running *right now*, and
  whether it is set to start *at logon*. Those are two separate switches, and the menu
  then offers only the move that makes sense — **Stop** when it is up, **Launch** when
  it is down, plus **Restart** and an autostart toggle.
  Scriptable too: `LangFix.bat -Status` (exit 0 = running, 1 = not), `-Start`, `-Stop`,
  `-Restart`, `-Autostart on|off`.
- **Stopping is a request, not a kill.** The control panel posts `WM_CLOSE` to the script's
  hidden main window so it exits the same way the tray's **Exit** does, and only forces the
  process if it has not gone after 5 seconds. `Get-Process` alone cannot do this — a tray
  script's `MainWindowHandle` is `0`, so the window has to be found by class + title.
- **Autostart can be switched off behind your back.** Task Manager → *Startup apps* (and
  "speed up boot" tools) disable the entry without touching the shortcut, so the `.lnk`
  still looks perfectly fine while nothing launches at boot. The real switch is a registry
  byte under `StartupApproved\StartupFolder`: byte 0 even = enabled, odd = disabled, and
  bytes 4-11 are a FILETIME of *when* it was turned off, which usually names the culprit.
  The control panel reads and sets it — that is the `At logon` line, and `[A]` flips it.
  Re-enabling only takes effect at the next logon, so launch it by hand for today.
  (Hit on 01/09/2026: disabled 30/08 16:33, so the 31/08 boot came up without it — which
  is why this script exists.)

## Notes

- If some app already uses Ctrl+Alt+L or Ctrl+Alt+R, LangFix wins while it is running —
  change the hotkey in the script and Reload from the tray.
- **ReadAll** binds `Ctrl+Shift+Alt+L` to its own "הרשימה שלי" inbox. LangFix's keyboard hook
  intercepts it first, so the inbox no longer opens on that combination — use plain
  `Ctrl+Alt+L` there, which now handles selections too.
- LangFix never pastes over a selection unless the clipboard is confirmed to hold the
  replacement. If another app is holding the clipboard open the write can fail silently, and
  pasting then would have wiped the selected text; instead you get "clipboard is busy".
- The file must keep its UTF-8 BOM, otherwise AutoHotkey may misread the Hebrew map.

## License

MIT, plus the [Commons Clause](LICENSE.md). In plain terms: **use it however you like,
including at work and inside a company** — install it, change it, share it, build on it.
The single thing you may not do is sell it: charge for LangFix itself, or for a product or
service whose value comes substantially from what it does.

Keep the copyright notice and the Commons Clause notice with any copy you pass on.

**Want to sell it?** That is the one right the Commons Clause holds back, and it can be
licensed separately. Write to `mail [at] yairsahar [dot] co [dot] il` — spelled out that way
deliberately, to keep address harvesters off it — or just open an issue and ask.

(The Commons Clause makes this technically not OSI open source, and GitHub will not show a
licence badge for it — `LICENSE.md` is the authoritative text.)
