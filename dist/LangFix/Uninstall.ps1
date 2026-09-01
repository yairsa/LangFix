# Removes LangFix: stops it and takes it out of Startup.
# AutoHotkey itself is left installed - remove it with
#   winget uninstall AutoHotkey.AutoHotkey
# if you don't want it. Delete this folder afterwards.

$ErrorActionPreference = 'Continue'
function Say($msg, $colour = 'Gray') { Write-Host $msg -ForegroundColor $colour }

Say "`n  Removing LangFix...`n" Cyan

$lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'LangFix.lnk'
if (Test-Path $lnk) {
    Remove-Item $lnk -Force
    Say "  Startup shortcut removed." Green
} else {
    Say "  No startup shortcut found (already removed)."
}

$stopped = $false
Get-Process AutoHotkey64, AutoHotkey32 -ErrorAction SilentlyContinue | ForEach-Object {
    $_ | Stop-Process -Force -ErrorAction SilentlyContinue
    $stopped = $true
}
if ($stopped) { Say "  LangFix stopped." Green } else { Say "  LangFix was not running." }

Say "`n  Done. You can delete this folder now.`n"
Read-Host "  Press Enter to close"
