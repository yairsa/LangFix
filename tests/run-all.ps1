# Runs the LangFix test suite.
#
#   pwsh -File tests\run-all.ps1          unit tests only - silent, safe to
#                                         run at any time, takes nothing
#   pwsh -File tests\run-all.ps1 -E2E     ALSO the end-to-end tests
#
# -E2E DRIVES THE REAL KEYBOARD AND MOUSE for about a minute: it presses the
# actual hotkeys, types into its own window, and clicks. Whatever you type
# while it runs lands in the wrong place. It is deliberately not the default,
# and it should only be started when you are away from the keyboard.
#
# What -E2E does to be as unobtrusive as it can:
#   - every test window opens on the SECONDARY monitor (tests\screen.ahk)
#   - the mouse pointer is put back where it was afterwards
# It still takes focus. There is no way around that: the fix under test reads
# a low-level keyboard hook, which by definition only sees real input.

[CmdletBinding()]
param(
    [switch]$E2E
)

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
# Also the syntax check: a script that does not parse never starts.
Get-Process AutoHotkey64 -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 600
Start-Process $ahk -ArgumentList "`"$root\LangFix.ahk`""
Start-Sleep -Seconds 2
if (-not (Get-Process AutoHotkey64 -ErrorAction SilentlyContinue)) {
    throw "LangFix did not start - syntax error?"
}
Write-Host "LangFix running." -ForegroundColor Green

# --- unit tests: pure logic, no window, no input -------------------------
# The logic block is lifted straight out of LangFix.ahk, so the tests always
# run against the shipping code rather than a copy of it.
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
Write-Host "`n=== unit: SwapLayout / TailStart / LastLine ===" -ForegroundColor Cyan
$unit = if ([IO.File]::Exists("$root\_unit.txt")) { [IO.File]::ReadAllText("$root\_unit.txt") } else { "NO OUTPUT" }
$unit
Clear-File "$root\_unitrun.ahk"
Clear-File "$root\_unit.txt"

$failed = ([regex]::Matches($unit, '(?m)^FAIL')).Count
if ($failed) { Write-Host "$failed unit test(s) FAILED" -ForegroundColor Red }
else         { Write-Host "unit tests all passed"       -ForegroundColor Green }

if (-not $E2E) {
    Write-Host "`nEnd-to-end tests skipped. They take over the keyboard and mouse for" -ForegroundColor Yellow
    Write-Host "about a minute - re-run with -E2E when you are away from the machine." -ForegroundColor Yellow
    exit ($failed ? 1 : 0)
}

# --- end-to-end tests: THESE TAKE THE KEYBOARD ---------------------------
$e2eTests = @(
    @{ name = 'typed fix';        script = 'e2e-typed-fix.ahk';        out = '_e2e.txt' }
    @{ name = 'hebrew layout';    script = 'e2e-hebrew-layout.ahk';    out = '_e2e_heb.txt' }
    @{ name = 'language switch';  script = 'e2e-lang-switch.ahk';      out = '_langswitch.txt' }
    @{ name = 'paste + select';   script = 'e2e-paste-and-select.ahk'; out = '_pastesel.txt' }
    @{ name = 'console copy';     script = 'e2e-console-copy.ahk';     out = '_consolecopy.txt' }
    @{ name = 'partial + lines';  script = 'e2e-partial-and-lines.ahk'; out = '_partial.txt' }
)
Write-Host "`nStarting the end-to-end tests - the keyboard and mouse are theirs" -ForegroundColor Yellow
Write-Host "for about a minute. Windows open on the secondary monitor." -ForegroundColor Yellow
foreach ($t in $e2eTests) {
    Clear-File "$root\tests\$($t.out)"
    $ok = Invoke-Ahk "$root\tests\$($t.script)" 60000
    Write-Host "`n=== e2e: $($t.name) ===" -ForegroundColor Cyan
    if (-not $ok) { Write-Host "TIMED OUT" -ForegroundColor Red; continue }
    if ([IO.File]::Exists("$root\tests\$($t.out)")) {
        [IO.File]::ReadAllText("$root\tests\$($t.out)")
        Clear-File "$root\tests\$($t.out)"
    } else { Write-Host "NO OUTPUT" -ForegroundColor Red }
}

Write-Host "`nDone - keyboard and mouse are yours again." -ForegroundColor Green
Write-Host "Check each e2e block against its (want: ...) note." -ForegroundColor Green
exit ($failed ? 1 : 0)
