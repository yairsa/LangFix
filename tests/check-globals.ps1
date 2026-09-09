# Finds the bug that has now bitten this script twice.
#
# In AutoHotkey v2, a variable ASSIGNED inside a function is local unless the
# function declares it global - silently, with no error and no warning at
# load time. So `LastFixOut := out` inside a function that forgot to declare
# LastFixOut writes to a local and leaves the real global empty. Everything
# still runs; the feature simply never works, and the symptom appears
# somewhere else entirely.
#
# It cost an afternoon on 09/09/2026 (the undo), then repeated the same hour
# (the redo). This checks it mechanically instead.
#
#   pwsh -File tests\check-globals.ps1
#
# Exit 0 = clean, 1 = at least one undeclared assignment to a global.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src  = [IO.File]::ReadAllLines("$root\LangFix.ahk", [Text.Encoding]::UTF8)

function Strip($line) { return ($line -replace '(?<!`);.*$', '') }

# --- script-level globals -------------------------------------------------
$globals = [Collections.Generic.HashSet[string]]::new()
foreach ($line in $src) {
    if ($line -match '^global\s+(.+)$') {
        foreach ($part in (Strip $matches[1]) -split ',') {
            if ($part -match '\s*([A-Za-z_]\w*)') { [void]$globals.Add($matches[1]) }
        }
    }
}

# --- walk each function ---------------------------------------------------
$bad = @()
$fn = $null; $decl = $null; $start = 0; $depth = 0
for ($i = 0; $i -lt $src.Count; $i++) {
    $line = Strip $src[$i]

    if (-not $fn -and $line -match '^([A-Za-z_]\w*)\s*\(.*\)\s*\{\s*$') {
        $fn = $matches[1]; $start = $i + 1; $depth = 1
        $decl = [Collections.Generic.HashSet[string]]::new()
        continue
    }
    if (-not $fn) { continue }

    $depth += ([regex]::Matches($line, '\{')).Count - ([regex]::Matches($line, '\}')).Count

    if ($line -match '^\s*global\s+(.+)$') {
        foreach ($part in $matches[1] -split ',') {
            if ($part -match '\s*([A-Za-z_]\w*)') { [void]$decl.Add($matches[1]) }
        }
    }
    foreach ($m in [regex]::Matches($line, '(?<![.\w])([A-Za-z_]\w*)\s*:=')) {
        $name = $m.Groups[1].Value
        if ($globals.Contains($name) -and -not $decl.Contains($name)) {
            $bad += [pscustomobject]@{ Line = $i + 1; Func = $fn; Var = $name }
        }
    }

    if ($depth -le 0) { $fn = $null }
}

if ($bad.Count -eq 0) {
    Write-Host "globals: clean - every assignment to a global is declared" -ForegroundColor Green
    exit 0
}

Write-Host "GLOBALS: $($bad.Count) assignment(s) to a global that the function never declared." -ForegroundColor Red
Write-Host "Each one silently writes to a LOCAL and leaves the global untouched.`n" -ForegroundColor Red
$bad | Sort-Object Line | ForEach-Object {
    "  LangFix.ahk:{0}  {1}()  assigns {2}" -f $_.Line, $_.Func, $_.Var
}
exit 1
