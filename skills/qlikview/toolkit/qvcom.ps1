# Shared QlikView COM helpers (skill: ~/.claude/skills/qlikview). Lives in <project>\_build\tools\ (copied there by qv-init.sh).
# Usage (inside a .ps1):   . "$PSScriptRoot\..\tools\qvcom.ps1"
# Run from WSL:            _build/tools/qvrun.sh <script.ps1> [args]     (timeout + powershell.exe + wslpath)
# .ps1 files containing non-ASCII characters (e.g. the euro sign) must be saved as UTF-8 *with BOM* for PowerShell 5.1.
# PowerShell + QlikView COM: properties that take parameters are called like methods: $doc.GetSheet(0).GetProperties().Name

$ErrorActionPreference = 'Stop'
# _build root = parent of this tools folder. Target document: $env:QV_DOC, else _build\qv.config (one line: full .qvw path),
# else whatever document is active in QlikView.
$Global:QvBuildRoot = Split-Path $PSScriptRoot -Parent
$Global:QvDocPath = $env:QV_DOC
$cfg = Join-Path $QvBuildRoot 'qv.config'
if (-not $QvDocPath -and (Test-Path $cfg)) { $Global:QvDocPath = (Get-Content $cfg -TotalCount 1).Trim() }
$Global:QvLockDir   = Join-Path $QvBuildRoot '.locks\com'
$Global:QvExe       = 'C:\Program Files\QlikView\Qv.exe'

function Get-QvApp {
    [System.Runtime.InteropServices.Marshal]::GetActiveObject('QlikTech.QlikView')
}

# Starts QlikView with the target document if it is not running / not open (does NOT close anything).
function Start-QvDoc {
    param([string]$Path = $QvDocPath, [int]$WaitSec = 90)
    if (-not $Path) { throw 'No document path: set _build\qv.config or $env:QV_DOC.' }
    $running = Get-Process qv -ErrorAction SilentlyContinue
    if ($running) {
        try { $d = (Get-QvApp).ActiveDocument(); if ($d -and $d.GetPathName() -eq $Path) { return 'already open' } } catch {}
        throw "QlikView is running but '$Path' is not the active document. Ask the user to open it (never close their docs)."
    }
    Start-Process $QvExe -ArgumentList "`"$Path`""
    $deadline = (Get-Date).AddSeconds($WaitSec)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep 3
        try { $d = (Get-QvApp).ActiveDocument(); if ($d) { [void](Get-QvApp).WaitForIdle(); return 'started' } } catch {}
    }
    throw "QlikView did not open '$Path' within $WaitSec s."
}

# Returns the target document (must be the active one). With no configured path: the active document.
function Get-QvDoc {
    $doc = (Get-QvApp).ActiveDocument()
    if (-not $doc) { throw 'No active QlikView document.' }
    if ($QvDocPath -and $doc.GetPathName() -ne $QvDocPath) { throw "Active document is '$($doc.GetPathName())', expected '$QvDocPath'." }
    return $doc
}

# ---------- COM write lock (one writer at a time: script changes, reloads, object create/modify, saves) ----------
function Enter-QvLock {
    param([Parameter(Mandatory)][string]$Owner, [int]$TimeoutSec = 1800, [int]$StaleMinutes = 30)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    $ownerFile = Join-Path $QvLockDir 'owner.txt'
    while ($true) {
        try {
            New-Item -ItemType Directory -Path $QvLockDir -ErrorAction Stop | Out-Null
            Set-Content -Path $ownerFile -Value "$Owner $(Get-Date -Format o) pid=$PID"
            return
        } catch {
            if (Test-Path $ownerFile) {
                # Holder process gone (killed by a timeout, crashed)? Then the lock is stale right away.
                $holder = Get-Content $ownerFile -Raw -ErrorAction SilentlyContinue
                if ($holder -match 'pid=(\d+)' -and -not (Get-Process -Id ([int]$Matches[1]) -ErrorAction SilentlyContinue)) {
                    Write-Warning "Breaking COM lock of dead process: $holder"
                    Remove-Item -Recurse -Force $QvLockDir -ErrorAction SilentlyContinue
                    continue
                }
                # Holder may release between Test-Path and here: just retry.
                $it = Get-Item $ownerFile -ErrorAction SilentlyContinue
                if (-not $it) { continue }
                $age = (Get-Date) - $it.LastWriteTime
                if ($age.TotalMinutes -gt $StaleMinutes) {
                    Write-Warning "Breaking stale COM lock: $(Get-Content $ownerFile)"
                    Remove-Item -Recurse -Force $QvLockDir -ErrorAction SilentlyContinue
                    continue
                }
            }
            if ((Get-Date) -gt $deadline) {
                throw "Timeout waiting for COM lock (held by: $(Get-Content $ownerFile -ErrorAction SilentlyContinue))"
            }
            Start-Sleep -Seconds 3
        }
    }
}

function Exit-QvLock {
    param([Parameter(Mandatory)][string]$Owner)
    $ownerFile = Join-Path $QvLockDir 'owner.txt'
    if ((Test-Path $ownerFile) -and ((Get-Content $ownerFile -Raw) -like "$Owner *")) {
        Remove-Item -Recurse -Force $QvLockDir
    }
}

# Keeps a long-running lock fresh (call between steps of a long batch so it is not treated as stale).
function Update-QvLock {
    param([Parameter(Mandatory)][string]$Owner)
    $ownerFile = Join-Path $QvLockDir 'owner.txt'
    if ((Test-Path $ownerFile) -and ((Get-Content $ownerFile -Raw) -like "$Owner *")) {
        Set-Content -Path $ownerFile -Value "$Owner $(Get-Date -Format o) pid=$PID"
    }
}

# Runs a scriptblock while holding the lock:  Invoke-QvLocked -Owner designer { param($doc) ... }
function Invoke-QvLocked {
    param([Parameter(Mandatory)][string]$Owner, [Parameter(Mandatory)][scriptblock]$Body, [switch]$Save)
    Enter-QvLock -Owner $Owner
    try {
        $doc = Get-QvDoc
        & $Body $doc
        if ($Save) { $doc.Save() }
    } finally {
        Exit-QvLock -Owner $Owner
    }
}

# Retries a COM call while QlikView is busy (RPC_E_CALL_REJECTED / RPC_E_SERVERCALL_RETRYLATER).
function Invoke-QvRetry {
    param([Parameter(Mandatory)][scriptblock]$Call, [int]$Tries = 20, [int]$DelayMs = 1500)
    for ($i = 1; $i -le $Tries; $i++) {
        try { return & $Call } catch {
            if ($i -eq $Tries -or $_.Exception.Message -notmatch '0x80010001|0x8001010A|busy|rejected') { throw }
            Start-Sleep -Milliseconds $DelayMs
        }
    }
}

# Checkpoint: save the document and copy it to _build\backup with a label.
function Save-QvCheckpoint {
    param([Parameter(Mandatory)]$Doc, [Parameter(Mandatory)][string]$Label)
    $Doc.Save()
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $src = $Doc.GetPathName()
    $bk = Join-Path $QvBuildRoot 'backup'
    if (-not (Test-Path $bk)) { New-Item -ItemType Directory -Path $bk | Out-Null }
    Copy-Item $src (Join-Path $bk ("{0}_{1}_{2}.qvw" -f [IO.Path]::GetFileNameWithoutExtension($src), $stamp, $Label))
}

# ---------- Screenshots (for visual design review and QA) ----------
Add-Type -AssemblyName System.Drawing
if (-not ('QvWin32' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class QvWin32 {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
'@
}

# Captures the whole QlikView main window to a PNG (works even if the window is covered; not if minimized).
# Activate the sheet first, e.g.  $doc.ActivateSheetById('Document\SH_DASH'); [void](Get-QvApp).WaitForIdle()
function Save-QvScreenshot {
    param([Parameter(Mandatory)][string]$Path)
    [void][QvWin32]::SetProcessDPIAware()
    $app = Get-QvApp
    $app.WaitForIdle()
    $hwnd = (Get-Process -Id $app.GetProcessId()).MainWindowHandle
    $r = New-Object QvWin32+RECT
    [void][QvWin32]::GetWindowRect($hwnd, [ref]$r)
    $w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    [void][QvWin32]::PrintWindow($hwnd, $hdc, 2)   # PW_RENDERFULLCONTENT
    $g.ReleaseHdc($hdc); $g.Dispose()
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    return $Path
}
