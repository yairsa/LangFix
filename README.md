# LangFix — Hebrew/English keyboard fixes

Two global Windows shortcuts, always on. AutoHotkey v2 script, runs from the tray,
starts with Windows.

| Shortcut | What it does |
|---|---|
| **Ctrl + Alt + L** | **Fix text written in the wrong language** — covers what you just **typed**, what you just **pasted**, and any **selection**, in that order. Backspaces over it, retypes it in the other layout, **and switches the keyboard to that language**. Direction auto-detected. Press again to flip both back. |
| *(nothing to press)* | **Hebrew copied from a console is un-reversed automatically**, at the moment you copy it. Plain `Ctrl+V` then pastes it correctly into anything. Copies from Word / Chrome / ReadAll are never touched. |
| **Ctrl + Alt + R** | Manual version of the above — un-reverse whatever is on the clipboard and paste it at the cursor, for copies the automatic rule missed. |
| **Ctrl + Alt + Shift + L** | Force the **selection** path, skipping the typed buffer. Falls back to the clipboard when nothing is selected. *(ReadAll uses this combination for its own inbox — see Notes.)* |
| **Ctrl + Alt + Shift + R** | Reverse fix on the **clipboard only**, no paste. |
| **Ctrl + Alt + D** | Show what is currently in the typing buffer (debug). |
| **Win + Shift + L / R** | Alt-free twins of the two main fixes. Same behaviour, no Alt involved. |

A small tooltip confirms each action.

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
Pastes over 1000 characters, or containing line breaks, still drop the buffer — those
can't be safely undone by backspacing.

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

In memory only, never written to disk, capped at 1000 characters. Cleared on Enter, Esc,
Tab, any arrow/Home/End/Delete, any Ctrl or Alt combination **except Ctrl+V**, any mouse
click, and whenever the active window changes. The keyboard hook's own transcript is wiped
every 20 seconds.

## Examples

```
nv to tbh rumv kf,uc  -> Ctrl+Alt+L ->  מה אם אני רוצה לכתוב
ן מקקג ש /וןבל כןס    -> Ctrl+Alt+L ->  i need a quick fix
!(םלוע) םולש          -> Ctrl+Alt+R ->  שלום (עולם)!
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
- `tests\unit-swaplayout.ahk` — pure conversion checks, including the capitals and curly
  quotes from a real Word paragraph. No focus needed.
- `tests\e2e-alt-menu.ahk` — presses the hotkey over a window with a menu bar and asks
  Windows (`GetGUIThreadInfo`) whether a menu became active.
- `tests\run-all.ps1` — restarts LangFix from disk and runs the whole suite:
  `pwsh -File tests\run-all.ps1`. The e2e tests drive the real hotkeys, so they take over
  the keyboard and mouse for about a minute — don't type while they run.
  They all need LangFix running, and they send at `SendLevel 1` — level-0 synthetic input
  never triggers another script's hotkeys, which is why a naive test appears to do nothing.
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
licensed separately — email Yair Sahar at <mail [at] yairsahar [dot] co [dot] il>.

(The Commons Clause makes this technically not OSI open source, and GitHub will not show a
licence badge for it — `LICENSE.md` is the authoritative text.)
