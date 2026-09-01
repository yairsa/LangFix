# Runs the LangFix test suite. Restarts LangFix first so the end-to-end
# tests exercise the script currently on disk.
#
#   pwsh -File tests\run-all.ps1
#
# The e2e tests drive the real hotkeys, so they steal focus and the mouse
# for about a minute. Don't type while they run.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$ahk  = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
if (-not (Test-Path $ahk)) { throw "AutoHotkey v2 not found at $ahk" }

function Clear-File($p) { if ([IO.File]::Exists($p)) { [IO.File]::Delete($p) } }

function Invoke-Ahk($script, $timeoutMs = 60000) {
    $p = Start-Process $ahk -ArgumentList "`"$script`"" -PassThru
    if (-not $p.WaitForExit($timeoutMs)) { $p.Kill(); return $false }
    return $true
}

# --- restart LangFix from disk -------------------------------------------
Get-Process AutoHotkey64 -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 600
Start-Process $ahk -ArgumentList "`"$root\LangFix.ahk`""
Start-Sleep -Seconds 2
if (-not (Get-Process AutoHotkey64 -ErrorAction SilentlyContinue)) {
    throw "LangFix did not start - syntax error?"
}
Write-Host "LangFix running." -ForegroundColor Green

# --- unit tests: pure logic, no focus needed -----------------------------
$src   = [IO.File]::ReadAllText("$root\LangFix.ahk", [Text.Encoding]::UTF8)
$logic = $src.Substring($src.IndexOf("; ============================ layout map"))
$logic = $logic.Substring(0, $logic.IndexOf("; ============================ tray menu"))
$body  = [IO.File]::ReadAllText("$root\tests\unit-swaplayout.ahk", [Text.Encoding]::UTF8)
$body  = $body -replace '#Requires AutoHotkey v2.0','' -replace '#SingleInstance Force','' `
               -replace '#Include \.\.\\LangFix-logic\.ahk',''
$asm   = "#Requires AutoHotkey v2.0`r`n#SingleInstance Off`r`n" + $logic + "`r`n" + $body
[IO.File]::WriteAllText("$root\_unitrun.ahk", $asm, (New-Object Text.UTF8Encoding $true))
Clear-File "$root\_unit.txt"
Invoke-Ahk "$root\_unitrun.ahk" 20000 | Out-Null
Write-Host "`n=== unit: SwapLayout ===" -ForegroundColor Cyan
if ([IO.File]::Exists("$root\_unit.txt")) { [IO.File]::ReadAllText("$root\_unit.txt") } else { "NO OUTPUT" }
Clear-File "$root\_unitrun.ahk"

# --- end-to-end tests ----------------------------------------------------
$e2e = @(
    @{ name = 'typed fix';        script = 'e2e-typed-fix.ahk';        out = '_e2e.txt' }
    @{ name = 'hebrew layout';    script = 'e2e-hebrew-layout.ahk';    out = '_e2e_heb.txt' }
    @{ name = 'language switch';  script = 'e2e-lang-switch.ahk';      out = '_langswitch.txt' }
    @{ name = 'paste + select';   script = 'e2e-paste-and-select.ahk'; out = '_pastesel.txt' }
    @{ name = 'console copy';     script = 'e2e-console-copy.ahk';     out = '_consolecopy.txt' }
)
foreach ($t in $e2e) {
    Clear-File "$root\tests\$($t.out)"
    $ok = Invoke-Ahk "$root\tests\$($t.script)" 60000
    Write-Host "`n=== e2e: $($t.name) ===" -ForegroundColor Cyan
    if (-not $ok) { Write-Host "TIMED OUT" -ForegroundColor Red; continue }
    if ([IO.File]::Exists("$root\tests\$($t.out)")) {
        [IO.File]::ReadAllText("$root\tests\$($t.out)")
        Clear-File "$root\tests\$($t.out)"
    } else { Write-Host "NO OUTPUT" -ForegroundColor Red }
}

Write-Host "`nDone. Check each block against its (want: ...) note." -ForegroundColor Green
