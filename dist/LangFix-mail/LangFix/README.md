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
2. **Rename `Install.ps1.txt` to `Install.ps1`** — drop the `.txt` off the end.
   *(It arrived with `.txt` on purpose: Gmail refuses to deliver `.ps1` files, even
   inside a zip. Same for `Uninstall.ps1.txt`, whenever you need it.)*
   If Windows hides file extensions and you only see `Install.ps1`, turn them on first:
   in File Explorer → **View** → tick **File name extensions**. Otherwise you'll rename
   the file to `Install.ps1.ps1` without seeing it.
3. Right-click **`Install.ps1`** → **Run with PowerShell**.

That's it. The installer:

- installs **AutoHotkey v2** if it isn't already there (via `winget`, Microsoft's package
  manager — built into Windows 10/11),
- adds a shortcut to your Startup folder so LangFix comes back after a reboot,
- starts it now.

If PowerShell refuses to run the script, open PowerShell and run:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Tools\LangFix\Install.ps1"
```

### Or install it by hand — three steps, no scripts

If any of the above is a nuisance, skip the installer entirely:

1. Install AutoHotkey **v2** from <https://www.autohotkey.com/> (or run
   `winget install AutoHotkey.AutoHotkey` in PowerShell).
2. Double-click **`LangFix.ahk`**. It's running — look for the tray icon.
3. To have it start with Windows: press **Win+R**, type **`shell:startup`**, Enter, and
   drop a *shortcut* to `LangFix.ahk` into the folder that opens.

**You need the Hebrew keyboard layout installed** in Windows (Settings → Time & language →
Language & region). You almost certainly do already.

---

## Using it

| Shortcut | What it does |
|---|---|
| **Ctrl+Alt+L** | Fix text written in the wrong language, and switch the keyboard to match. Press again to flip back. |
| **Win+Shift+L** | Exactly the same, without Alt — use it if any app reacts badly to Alt. |
| *(nothing to press)* | Hebrew copied from a terminal is un-reversed automatically. |
| **Ctrl+Alt+R** | Manual version of that: un-reverse the clipboard and paste it here. |
| **Ctrl+Alt+Shift+L** | Fix a selection, ignoring what you typed. |
| **Ctrl+Alt+Shift+R** | Un-reverse the clipboard without pasting. |

A small tooltip confirms each action.

### The one thing worth knowing

**Ctrl+Alt+L works on what you just typed or pasted** — it remembers the characters going
in, backspaces over them, and retypes them. So the natural flow is: type, notice the
language was wrong, press it. No selecting needed.

That memory is cleared by **Enter, Esc, Tab, an arrow key, or a mouse click** — on purpose,
so it can never delete characters it didn't watch you type. After any of those, it falls
back to **whatever you have selected**, so you can still select the text and press the same
key. Both work.

The one place selections don't exist is inside a terminal, so there: fix it before you
press Enter.

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

Rename `Uninstall.ps1.txt` to `Uninstall.ps1`, then right-click it → **Run with PowerShell**.
It stops LangFix and removes the startup shortcut. (By hand: delete the shortcut from
`shell:startup`, and right-click the tray icon → Exit.) Delete the folder afterwards. AutoHotkey stays installed; remove it with
`winget uninstall AutoHotkey.AutoHotkey` if you don't want it.

---

## A note on privacy

To fix what you typed, LangFix has to see what you type. Those characters live **in memory
only** — never written to disk, never sent anywhere, capped at the last 1000 characters, and
cleared on Enter, Esc, Tab, an arrow key, a mouse click, or when you switch windows. There
is no network code in it at all. The whole thing is one readable text file: open
`LangFix.ahk` in Notepad and check.

Built by Yair Sahar. Free to pass on.
