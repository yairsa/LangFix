<#
.SYNOPSIS
  Health check and on/off switch for LangFix.

.DESCRIPTION
  Reports whether LangFix is running now and whether it is set to start at logon --
  two separate things that look identical from the outside, which is exactly how the
  01/09/2026 outage hid: the Startup shortcut was intact and pointed at a real
  AutoHotkey, but Windows had switched the entry off, so nothing launched at boot.

  Run it with no arguments for the interactive menu, which only offers the action
  that makes sense: Stop when it is up, Launch when it is down.

.PARAMETER Status
  Print the health report and exit. No prompt. Exit code 0 = running, 1 = not running.

.PARAMETER Start
  Launch it (or reload it if already up) and exit.

.PARAMETER Stop
  Shut it down and exit.

.PARAMETER Restart
  Reload it from disk -- use after editing LangFix.ahk.

.PARAMETER Autostart
  'on' or 'off' -- set whether it launches at logon, then exit.
#>
[CmdletBinding(DefaultParameterSetName = 'Menu')]
param(
    [Parameter(ParameterSetName = 'Status')]  [switch] $Status,
    [Parameter(ParameterSetName = 'Start')]   [switch] $Start,
    [Parameter(ParameterSetName = 'Stop')]    [switch] $Stop,
    [Parameter(ParameterSetName = 'Restart')] [switch] $Restart,
    [Parameter(ParameterSetName = 'Auto')]    [ValidateSet('on', 'off')] [string] $Autostart
)

$ErrorActionPreference = 'Stop'

$ScriptPath   = Join-Path $PSScriptRoot 'LangFix.ahk'
$ShortcutPath = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\LangFix.lnk'
$ApprovedKey  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
$ApprovedName = 'LangFix.lnk'

# --- win32 --------------------------------------------------------------------
# The script's window is hidden, so Get-Process reports MainWindowHandle 0 and
# CloseMainWindow cannot reach it. Find the window by class + title instead.
if (-not ('LangFixWin' -as [type])) {
    Add-Type @'
using System; using System.Text; using System.Runtime.InteropServices;
public class LangFixWin {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
  public delegate bool EnumProc(IntPtr h, IntPtr p);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
}
'@
}

function Get-LangFixWindow {
    # AHK's main window: class 'AutoHotkey', title '<script path> - AutoHotkey v2.x'.
    $script:hits = @()
    $cb = [LangFixWin+EnumProc] {
        param($h, $p)
        $c = New-Object Text.StringBuilder 256
        [void][LangFixWin]::GetClassName($h, $c, 256)
        if ($c.ToString() -eq 'AutoHotkey') {
            $t = New-Object Text.StringBuilder 512
            [void][LangFixWin]::GetWindowText($h, $t, 512)
            if ($t.ToString() -like '*LangFix.ahk*') {
                $procId = 0
                [void][LangFixWin]::GetWindowThreadProcessId($h, [ref]$procId)
                $script:hits += [PSCustomObject]@{ HWND = $h; ProcessId = $procId }
            }
        }
        return $true
    }
    [void][LangFixWin]::EnumWindows($cb, [IntPtr]::Zero)
    return $script:hits
}

function Get-LangFixProcess {
    @(Get-CimInstance Win32_Process -Filter "Name='AutoHotkey64.exe' OR Name='AutoHotkey32.exe' OR Name='AutoHotkey.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*LangFix.ahk*' })
}

function Resolve-AhkExe {
    # Prefer whatever the Startup shortcut already uses: if that one works at boot,
    # it works here too.
    if (Test-Path $ShortcutPath) {
        try {
            $t = (New-Object -ComObject WScript.Shell).CreateShortcut($ShortcutPath).TargetPath
            if ($t -and (Test-Path $t)) { return $t }
        } catch { }
    }
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey32.exe",
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:ProgramFiles\AutoHotkey\AutoHotkey64.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    $cmd = Get-Command AutoHotkey64.exe, AutoHotkey.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    return $null
}

function Get-AutostartState {
    # Two independent switches. The shortcut is the obvious one; the registry byte
    # is the one that gets flipped silently by Task Manager > Startup apps.
    $state = [PSCustomObject]@{
        ShortcutExists = (Test-Path $ShortcutPath)
        Enabled        = $false
        DisabledOn     = $null
        TargetOk       = $false
    }
    if ($state.ShortcutExists) {
        try {
            $sc = (New-Object -ComObject WScript.Shell).CreateShortcut($ShortcutPath)
            $state.TargetOk = ($sc.TargetPath -and (Test-Path $sc.TargetPath) -and $sc.Arguments -like '*LangFix.ahk*')
        } catch { }
    }
    $bytes = $null
    try { $bytes = (Get-ItemProperty -Path $ApprovedKey -Name $ApprovedName -ErrorAction Stop).$ApprovedName } catch { }
    if ($null -eq $bytes) {
        # No entry at all means it was never disabled.
        $state.Enabled = $state.ShortcutExists
    }
    else {
        # Byte 0: even = enabled, odd = disabled. Bytes 4-11 are a FILETIME of when
        # it was switched off, which usually identifies the culprit.
        $state.Enabled = (($bytes[0] % 2) -eq 0)
        if (-not $state.Enabled -and $bytes.Length -ge 12) {
            try {
                $ft = [BitConverter]::ToInt64($bytes, 4)
                if ($ft -gt 0) { $state.DisabledOn = [datetime]::FromFileTime($ft) }
            } catch { }
        }
        if (-not $state.ShortcutExists) { $state.Enabled = $false }
    }
    return $state
}

function Set-Autostart([bool] $On) {
    if (-not (Test-Path $ShortcutPath)) {
        if (-not $On) {
            Write-Host '  Autostart is already off - there is no Startup shortcut.' -ForegroundColor Yellow
            return
        }
        $exe = Resolve-AhkExe
        if (-not $exe) {
            Write-Host '  Cannot create the shortcut: AutoHotkey v2 not found.' -ForegroundColor Red
            return
        }
        $sc = (New-Object -ComObject WScript.Shell).CreateShortcut($ShortcutPath)
        $sc.TargetPath       = $exe
        $sc.Arguments        = '"' + $ScriptPath + '"'
        $sc.WorkingDirectory = $PSScriptRoot
        $sc.Description      = 'LangFix - Hebrew/English keyboard fixes'
        $sc.Save()
        Write-Host '  Startup shortcut re-created.' -ForegroundColor Green
    }
    if (-not (Test-Path $ApprovedKey)) { New-Item -Path $ApprovedKey -Force | Out-Null }
    $val = if ($On) { [byte[]](0x02, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0) } else { [byte[]](0x03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0) }
    Set-ItemProperty -Path $ApprovedKey -Name $ApprovedName -Value $val -Type Binary
    if ($On) {
        Write-Host '  Autostart ON - LangFix will launch at every logon.' -ForegroundColor Green
    }
    else {
        Write-Host '  Autostart OFF - it will not launch at logon (it keeps running now).' -ForegroundColor Yellow
    }
}

function Start-LangFix {
    if (-not (Test-Path $ScriptPath)) {
        Write-Host "  LangFix.ahk not found at $ScriptPath" -ForegroundColor Red
        return $false
    }
    $exe = Resolve-AhkExe
    if (-not $exe) {
        Write-Host '  AutoHotkey v2 not found. Install it with:  winget install AutoHotkey.AutoHotkey' -ForegroundColor Red
        return $false
    }
    # The script is #SingleInstance Force, so this reloads rather than duplicating.
    Start-Process -FilePath $exe -ArgumentList ('"' + $ScriptPath + '"') -WorkingDirectory $PSScriptRoot
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 250
        if ((Get-LangFixProcess).Count -gt 0) {
            Write-Host '  LangFix is running.' -ForegroundColor Green
            return $true
        }
    }
    Write-Host '  Launched, but no process appeared after 5s - check the script for errors.' -ForegroundColor Red
    return $false
}

function Stop-LangFix {
    if ((Get-LangFixProcess).Count -eq 0) {
        Write-Host '  It is not running.' -ForegroundColor Yellow
        return $true
    }
    # Ask it to close, so it runs its own exit handling. Kill only if it refuses.
    foreach ($w in Get-LangFixWindow) {
        [void][LangFixWin]::PostMessage($w.HWND, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)  # WM_CLOSE
    }
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 250
        if ((Get-LangFixProcess).Count -eq 0) {
            Write-Host '  LangFix stopped.' -ForegroundColor Green
            return $true
        }
    }
    Write-Host '  It did not close on request - forcing it.' -ForegroundColor Yellow
    foreach ($p in Get-LangFixProcess) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 500
    if ((Get-LangFixProcess).Count -eq 0) {
        Write-Host '  LangFix stopped.' -ForegroundColor Green
        return $true
    }
    Write-Host '  Could not stop it.' -ForegroundColor Red
    return $false
}

function Show-Health {
    $procs = Get-LangFixProcess
    $auto = Get-AutostartState

    Write-Host ''
    Write-Host '  LangFix' -ForegroundColor Cyan -NoNewline
    Write-Host "   $ScriptPath" -ForegroundColor DarkGray
    Write-Host '  ------------------------------------------------------------------' -ForegroundColor DarkGray

    if ($procs.Count -gt 0) {
        $p = $procs[0]
        $up = ''
        try {
            $started = (Get-Process -Id $p.ProcessId).StartTime
            $span = (Get-Date) - $started
            $up = '   up since {0:dd/MM/yyyy HH:mm}  ({1:N0}h {2}m)' -f $started, [math]::Floor($span.TotalHours), $span.Minutes
        } catch { }
        Write-Host '  Right now   ' -NoNewline
        Write-Host 'RUNNING' -ForegroundColor Green -NoNewline
        Write-Host "   PID $($p.ProcessId)$up" -ForegroundColor DarkGray
        if ($procs.Count -gt 1) {
            Write-Host "              $($procs.Count) copies are running - stopping closes all of them." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host '  Right now   ' -NoNewline
        Write-Host 'STOPPED' -ForegroundColor Red -NoNewline
        Write-Host '   hotkeys and the console clipboard fix are inactive' -ForegroundColor DarkGray
    }

    if ($auto.Enabled) {
        Write-Host '  At logon    ' -NoNewline
        Write-Host 'ON     ' -ForegroundColor Green -NoNewline
        Write-Host '   starts automatically when you sign in' -ForegroundColor DarkGray
    }
    else {
        Write-Host '  At logon    ' -NoNewline
        Write-Host 'OFF    ' -ForegroundColor Red -NoNewline
        if (-not $auto.ShortcutExists) {
            Write-Host '   the Startup shortcut is missing' -ForegroundColor DarkGray
        }
        elseif ($auto.DisabledOn) {
            Write-Host ('   switched off on {0:dd/MM/yyyy HH:mm}' -f $auto.DisabledOn) -ForegroundColor DarkGray
        }
        else {
            Write-Host '   disabled in Windows startup apps' -ForegroundColor DarkGray
        }
    }

    if ($auto.ShortcutExists -and -not $auto.TargetOk) {
        Write-Host '  Warning     the Startup shortcut points somewhere invalid' -ForegroundColor Yellow
    }
    if (-not (Test-Path $ScriptPath)) {
        Write-Host '  Warning     LangFix.ahk is missing' -ForegroundColor Red
    }
    if (-not (Resolve-AhkExe)) {
        Write-Host '  Warning     AutoHotkey v2 not found - winget install AutoHotkey.AutoHotkey' -ForegroundColor Red
    }
    Write-Host ''
    return ($procs.Count -gt 0)
}

# ----------------------------- non-interactive --------------------------------
switch ($PSCmdlet.ParameterSetName) {
    'Status' { $r = Show-Health; if ($r) { exit 0 } else { exit 1 } }
    'Start' { [void](Show-Health); $ok = Start-LangFix; if ($ok) { exit 0 } else { exit 1 } }
    'Stop' { [void](Show-Health); $ok = Stop-LangFix; if ($ok) { exit 0 } else { exit 1 } }
    'Restart' { [void](Show-Health); [void](Stop-LangFix); $ok = Start-LangFix; if ($ok) { exit 0 } else { exit 1 } }
    'Auto' { [void](Show-Health); Set-Autostart ($Autostart -eq 'on'); exit 0 }
}

# ------------------------------- interactive ----------------------------------
while ($true) {
    $running = Show-Health
    $auto = Get-AutostartState

    Write-Host '  What would you like to do?' -ForegroundColor Cyan
    if ($running) {
        Write-Host '    [S]  Stop LangFix       ' -NoNewline -ForegroundColor White
        Write-Host ' turn the hotkeys off now' -ForegroundColor DarkGray
        Write-Host '    [R]  Restart it         ' -NoNewline -ForegroundColor White
        Write-Host ' reload from disk, after editing LangFix.ahk' -ForegroundColor DarkGray
    }
    else {
        Write-Host '    [L]  Launch LangFix     ' -NoNewline -ForegroundColor White
        Write-Host ' turn the hotkeys on now' -ForegroundColor DarkGray
    }
    if ($auto.Enabled) {
        Write-Host '    [A]  Autostart -> OFF   ' -NoNewline -ForegroundColor White
        Write-Host ' stop it launching when you sign in' -ForegroundColor DarkGray
    }
    else {
        Write-Host '    [A]  Autostart -> ON    ' -NoNewline -ForegroundColor White
        Write-Host ' launch it automatically when you sign in' -ForegroundColor DarkGray
    }
    Write-Host '    [Q]  Quit' -ForegroundColor White
    Write-Host ''
    $choice = (Read-Host '  Choice').Trim().ToUpper()
    Write-Host ''

    switch ($choice) {
        'S' { if ($running) { [void](Stop-LangFix) } else { Write-Host '  It is not running.' -ForegroundColor Yellow } }
        'L' { if ($running) { Write-Host '  Already running.' -ForegroundColor Yellow } else { [void](Start-LangFix) } }
        'R' { [void](Stop-LangFix); [void](Start-LangFix) }
        'A' { Set-Autostart (-not $auto.Enabled) }
        'Q' { Write-Host ''; exit 0 }
        '' { Write-Host ''; exit 0 }
        default { Write-Host "  '$choice' is not one of the options." -ForegroundColor Yellow }
    }
    Write-Host ''
    Write-Host '  ==================================================================' -ForegroundColor DarkGray
}
