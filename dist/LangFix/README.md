# LangFix — Hebrew/English keyboard fixes for Windows

Two everyday annoyances, fixed:

1. **You typed in the wrong language.** `שלום` came out as `akuo`. Press **Ctrl+Alt+L** and
   the text is rewritten in the right language — *and* the keyboard switches to that
   language, so the next word is right too.
2. **Hebrew copied from a terminal comes out backwards.** `שלום` pastes as `םולש`.
   Nothing to press: it's corrected the moment you copy it, so a plain **Ctrl+V** pastes
   correctly into Word, Chrome, anywhere.

It runs quietly from the system tray and starts with Windows.

---

## Install

1. Unzip this folder somewhere permanent — `C:\Tools\LangFix` is a good choice.
   (Don't run it from the Downloads folder; the shortcut will break when you clean up.)
2. Right-click **`Install.ps1`** → **Run with PowerShell**.

That's it. The installer:

- installs **AutoHotkey v2** if it isn't already there (via `winget`, Microsoft's package
  manager — built into Windows 10/11),
- adds a shortcut to your Startup folder so LangFix comes back after a reboot,
- starts it now.

If PowerShell refuses to run the script, open PowerShell and run:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Tools\LangFix\Install.ps1"
```

**You need the Hebrew keyboard layout installed** in Windows (Settings → Time & language →
Language & region). You almost certainly do already.

---

## Using it

| Shortcut | What it does |
|---|---|
| **Ctrl+Alt+L** | Fix text written in the wrong language, and switch the keyboard to match. |
| **Ctrl+Z** | **Undo that fix** — the normal undo key. *(New)* |
| **Ctrl+Y** | **Redo it.** *(New)* |
| **Win+Shift+L** | Exactly the same as Ctrl+Alt+L, without Alt — use it if any app reacts badly to Alt. |
| *(nothing to press)* | Hebrew copied from a terminal is un-reversed automatically. |
| **Ctrl+Alt+R** | Manual version of that: un-reverse the clipboard and paste it here. |
| **Ctrl+Alt+Shift+L** | Fix a selection, ignoring what you typed. |
| **Ctrl+Alt+Shift+R** | Un-reverse the clipboard without pasting. |
| **Ctrl+Alt+Z / Y** | The same undo and redo, but they always answer — so when nothing seems to happen, they say why. |

A small tooltip confirms each action.

### New in this version

**Ctrl+Z undoes a fix.** The normal undo key — it puts back exactly the characters the fix
replaced, and the keyboard language with them. **Ctrl+Y** redoes it, and the two cycle.

The care went into *not* stealing Ctrl+Z: it is only LangFix's key in the one moment it can
be — straight after a fix, same window, cursor unmoved. Every other Ctrl+Z in your life
reaches your application untouched, because at that moment the shortcut does not exist.
After undoing once it hands the key straight back.

**It only fixes the current line.** A fix can no longer reach past a line break into text
above it. (It could before, and occasionally did.)

**It stops at the last character that was already right.** A wrong-language run sits at the
*end* of what you typed — that is why you are pressing the key. So a Hebrew word inside an
English line now survives:

```
in case גולן is at the correct פךשבק   →   in case גולן is at the correct place
```

A *selection*, by contrast, is still converted whole — you chose where it starts and ends.

### The one thing worth knowing

**Ctrl+Alt+L works on what you just typed or pasted** — it remembers the characters going
in, backspaces over them, and retypes them. So the natural flow is: type, notice the
language was wrong, press it. No selecting needed.

That memory is cleared by **Enter, Esc, Tab, an arrow key, or a mouse click** — on purpose,
so it can never delete characters it didn't watch you type. After any of those, it falls
back to **whatever you have selected**, so you can still select the text and press the same
key. Both work.

Inside a **terminal** there are no selections, so there the typed memory is the only route:
fix it before you press Enter. If that memory is empty in a terminal, Ctrl+Alt+L now does
nothing at all and says so, rather than reaching for a selection that cannot exist.

### Right-to-left details it gets right

- Direction is detected automatically — it converts Hebrew→English just as happily.
- Capital letters and Word's curly quotes (`’` `”` `–`) are handled; Word auto-capitalises
  and auto-curls as you type, and both used to survive the conversion.
- When un-reversing, brackets and parentheses are mirrored, and Latin words and numbers
  inside a Hebrew line keep their own order — `2026 Yair בוט רקוב` stays readable.
- A line with no Hebrew in it is never touched.

---

## Controlling it

Right-click the tray icon (a small keyboard) for:

- **Auto un-reverse Hebrew copied from consoles** — on by default.
- **Also switch the keyboard language on Ctrl+Alt+L** — on by default.
- **Reload** — after editing the script. **Exit** — stop it for this session.

To change a shortcut, open `LangFix.ahk` in Notepad and edit the `HOTKEYS` block near the
top (`^` = Ctrl, `!` = Alt, `+` = Shift, `#` = Win), then Reload from the tray.

**Why not Win+L?** That's the Windows lock shortcut. Windows handles it below the level any
hook can see, so no program can take it over. `Win+Shift+L` is the free equivalent.

---

## Uninstall

Right-click **`Uninstall.ps1`** → **Run with PowerShell**. It stops LangFix and removes the
startup shortcut. Delete the folder afterwards. AutoHotkey stays installed; remove it with
`winget uninstall AutoHotkey.AutoHotkey` if you don't want it.

---

## A note on privacy

To fix what you typed, LangFix has to see what you type. Those characters live **in memory
only** — never written to disk, never sent anywhere, capped at the last 1000 characters, and
cleared on Enter, Esc, Tab, an arrow key, a mouse click, or when you switch windows. There
is no network code in it at all. The whole thing is one readable text file: open
`LangFix.ahk` in Notepad and check.

Built by Yair Sahar. Free to pass on.
