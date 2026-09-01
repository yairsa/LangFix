# LangFix installer.
#   Right-click this file -> Run with PowerShell
# or:
#   powershell -ExecutionPolicy Bypass -File Install.ps1

$ErrorActionPreference = 'Stop'
$here   = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$script = Join-Path $here 'LangFix.ahk'

function Say($msg, $colour = 'Gray') { Write-Host $msg -ForegroundColor $colour }

Say "`n  LangFix installer" Cyan
Say "  =================`n"

if (-not (Test-Path $script)) {
    Say "  LangFix.ahk is not next to this installer. Unzip the whole folder and try again." Red
    Read-Host "`n  Press Enter to close"; exit 1
}

# --- 1. AutoHotkey v2 ------------------------------------------------------
function Find-Ahk {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey32.exe",
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
        "${env:ProgramFiles(x86)}\AutoHotkey\v2\AutoHotkey32.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    return $null
}

$ahk = Find-Ahk
if ($ahk) {
    Say "  [1/3] AutoHotkey v2 found." Green
} else {
    Say "  [1/3] AutoHotkey v2 not found - installing it (needs internet)..."
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Say "`n  winget is not available on this PC." Red
        Say "  Install AutoHotkey v2 by hand from https://www.autohotkey.com/ and run this again."
        Read-Host "`n  Press Enter to close"; exit 1
    }
    winget install --id AutoHotkey.AutoHotkey --source winget `
                   --accept-package-agreements --accept-source-agreements --silent
    Start-Sleep -Seconds 2
    $ahk = Find-Ahk
    if (-not $ahk) {
        Say "`n  AutoHotkey still not found after installing." Red
        Say "  Install it from https://www.autohotkey.com/ and run this again."
        Read-Host "`n  Press Enter to close"; exit 1
    }
    Say "        installed." Green
}

# --- 2. start with Windows -------------------------------------------------
$startup = [Environment]::GetFolderPath('Startup')
$lnk     = Join-Path $startup 'LangFix.lnk'
$w  = New-Object -ComObject WScript.Shell
$sc = $w.CreateShortcut($lnk)
$sc.TargetPath       = $ahk
$sc.Arguments        = "`"$script`""
$sc.WorkingDirectory = $here
$sc.Description      = 'LangFix - Hebrew/English keyboard fixes'
$sc.Save()
Say "  [2/3] Added to Startup, so it comes back after a reboot." Green

# --- 3. run it now ---------------------------------------------------------
Get-Process AutoHotkey64, AutoHotkey32 -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -eq $ahk } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 400
Start-Process $ahk -ArgumentList "`"$script`""
Start-Sleep -Seconds 2

if (Get-Process AutoHotkey64, AutoHotkey32 -ErrorAction SilentlyContinue) {
    Say "  [3/3] LangFix is running - look for the keyboard icon in the tray.`n" Green
    Say "  Try it now: type  akuo  into any text box and press Ctrl+Alt+L." Cyan
    Say "  Read README.md for the rest.`n"
} else {
    Say "  [3/3] LangFix did not start. Double-click LangFix.ahk to see the error.`n" Red
}

Read-Host "  Press Enter to close"
