# QA common helpers (owner: QA). Dot-source from the qa/*.ps1 check scripts.
# Read-only against the app except where a caller explicitly holds the COM lock (selections / sheet activation).
. "$PSScriptRoot\..\..\tools\qvcom.ps1"

$Global:QaRoot     = Join-Path $QvBuildRoot 'qa'
$Global:QaResDir   = Join-Path $QaRoot 'results'
$Global:QaShotDir  = Join-Path $QaRoot 'screens'
$Global:QaResults  = New-Object System.Collections.ArrayList
$Global:QaStamp    = Get-Date -Format 'yyyyMMdd-HHmmss'
$Global:QaEuro     = [string][char]0x20AC
$Global:QaInv      = [System.Globalization.CultureInfo]::InvariantCulture
foreach ($d in @($QaResDir, $QaShotDir)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null } }

# ---------- date helpers (QlikView serial = OLE automation date) ----------
function DNum([string]$iso) { [int]([datetime]::ParseExact($iso, 'yyyy-MM-dd', $QaInv).ToOADate()) }
function DRange([string]$from, [string]$to) { '%DateKey={">=' + (DNum $from) + '<=' + (DNum $to) + '"}' }

# ---------- evaluation ----------
# Returns @{ Text; Num (double or $null); IsErr }
function QE([string]$Expr) {
    $r = Invoke-QvRetry { $Global:QaDoc.EvaluateEx($Expr) }
    $t = [string]$r.Text
    $isErr = $t -match '^\s*Error'
    $n = $null
    if ($r.IsNumeric -and -not $isErr) { $n = [double]$r.Number }
    [pscustomobject]@{ Text = $t; Num = $n; IsErr = $isErr }
}
function QN([string]$Expr) { (QE $Expr).Num }
function QT([string]$Expr) { (QE $Expr).Text }

# ---------- result collection ----------
function Add-QaResult {
    param([string]$Id, [string]$Test, $Expected, $Actual, [ValidateSet('PASS','FAIL','WARN','INFO','SKIP')][string]$Status, [string]$Note = '')
    [void]$Global:QaResults.Add([pscustomobject]@{
        Id = $Id; Test = $Test; Expected = (Format-QaVal $Expected); Actual = (Format-QaVal $Actual); Status = $Status; Note = $Note })
    $c = @{ PASS = 'Green'; FAIL = 'Red'; WARN = 'Yellow'; INFO = 'Gray'; SKIP = 'Gray' }[$Status]
    Write-Host ("[{0}] {1} {2} | exp={3} act={4} {5}" -f $Status, $Id, $Test, (Format-QaVal $Expected), (Format-QaVal $Actual), $Note) -ForegroundColor $c
}
function Format-QaVal($v) {
    if ($null -eq $v) { return '(null)' }
    if ($v -is [double] -or $v -is [single] -or $v -is [decimal]) {
        if ([math]::Abs($v) -ge 1000) { return $v.ToString('#,##0.##', $QaInv) }
        return $v.ToString('0.######', $QaInv)
    }
    if ($v -is [int] -or $v -is [long]) { return $v.ToString('#,##0', $QaInv) }
    if ($v -is [array]) { return ($v -join ', ') }
    return [string]$v
}
# Pass if $Ok, otherwise FAIL (or WARN with -Soft)
function Test-Qa {
    param([string]$Id, [string]$Test, $Expected, $Actual, [bool]$Ok, [switch]$Soft, [string]$Note = '')
    $st = if ($Ok) { 'PASS' } elseif ($Soft) { 'WARN' } else { 'FAIL' }
    Add-QaResult -Id $Id -Test $Test -Expected $Expected -Actual $Actual -Status $st -Note $Note
}
function Test-QaEq { param([string]$Id, [string]$Test, $Expected, $Actual, [switch]$Soft, [string]$Note = '')
    $ok = if ($null -eq $Actual) { $false } elseif ($Expected -is [string] -or $Actual -is [string]) { [string]$Expected -ceq [string]$Actual } else { $Expected -eq $Actual }
    Test-Qa -Id $Id -Test $Test -Expected $Expected -Actual $Actual -Ok $ok -Soft:$Soft -Note $Note }
# Use inside `catch` of a test section: an exception becomes a FAIL row instead of aborting the whole run.
function Add-QaErr([string]$Name, $Err) {
    Add-QaResult -Id 'ERR' -Test "Section '$Name' crashed" -Expected 'no exception' -Actual $Err.Exception.Message -Status 'FAIL' -Note (($Err.InvocationInfo.PositionMessage) -replace '\s+', ' ')
}
# numeric equality within relative tolerance (default 1e-6) or absolute tolerance
function Test-QaNum {
    param([string]$Id, [string]$Test, $Expected, $Actual, [double]$Rel = 1e-6, [double]$Abs = 1e-9, [switch]$Soft, [string]$Note = '')
    $ok = ($null -ne $Expected -and $null -ne $Actual -and (Test-Close $Expected $Actual $Rel $Abs))
    Test-Qa -Id $Id -Test $Test -Expected $Expected -Actual $Actual -Ok $ok -Soft:$Soft -Note $Note
}
function Test-Close($a, $b, [double]$Rel = 1e-6, [double]$Abs = 1e-9) {
    if ($null -eq $a -or $null -eq $b) { return ($null -eq $a -and $null -eq $b) }
    $d = [math]::Abs([double]$a - [double]$b)
    return ($d -le $Abs -or $d -le $Rel * [math]::Max([math]::Abs([double]$a), [math]::Abs([double]$b)))
}
# range check: hard band -> FAIL outside, soft band -> WARN outside
function Test-QaRange {
    param([string]$Id, [string]$Test, $Actual, [double]$Lo, [double]$Hi, [double]$SoftLo = [double]::NaN, [double]$SoftHi = [double]::NaN, [string]$Fmt = '0.0%', [string]$Note = '')
    $exp = (Format-QaFmt $Lo $Fmt) + ' .. ' + (Format-QaFmt $Hi $Fmt)
    $act = if ($null -eq $Actual) { '(null)' } else { Format-QaFmt $Actual $Fmt }
    if ($null -eq $Actual) { $st = 'FAIL' }
    elseif ($Actual -ge $Lo -and $Actual -le $Hi) { $st = 'PASS' }
    elseif (-not [double]::IsNaN($SoftLo) -and $Actual -ge $SoftLo -and $Actual -le $SoftHi) { $st = 'WARN' }
    else { $st = 'FAIL' }
    Add-QaResult -Id $Id -Test $Test -Expected $exp -Actual $act -Status $st -Note $Note
}
function Format-QaFmt([double]$v, [string]$fmt) { $v.ToString($fmt, $QaInv) }

# ---------- report ----------
function Write-QaReport {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Title, [string[]]$Preamble = @(), [string[]]$Appendix = @())
    $res = $Global:QaResults
    $cnt = @{}; foreach ($s in 'PASS','FAIL','WARN','INFO','SKIP') { $cnt[$s] = @($res | Where-Object Status -eq $s).Count }
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# $Title")
    $lines.Add('')
    $lines.Add("Run: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  |  doc reload: $($Global:QaDoc.GetProperties().LastReloadTimeAsString)")
    $lines.Add('')
    $lines.Add("**Summary:** PASS $($cnt.PASS) / FAIL $($cnt.FAIL) / WARN $($cnt.WARN) / INFO $($cnt.INFO) / SKIP $($cnt.SKIP)")
    $lines.Add('')
    foreach ($p in $Preamble) { $lines.Add($p) }
    if (@($res | Where-Object { $_.Status -in 'FAIL','WARN' }).Count -gt 0) {
        $lines.Add('## Failures and warnings'); $lines.Add('')
        $lines.Add('| ID | Status | Test | Expected | Actual | Note |'); $lines.Add('|---|---|---|---|---|---|')
        foreach ($r in ($res | Where-Object { $_.Status -in 'FAIL','WARN' })) { $lines.Add((Format-QaRow $r)) }
        $lines.Add('')
    }
    $lines.Add('## All results'); $lines.Add('')
    $lines.Add('| ID | Status | Test | Expected | Actual | Note |'); $lines.Add('|---|---|---|---|---|---|')
    foreach ($r in $res) { $lines.Add((Format-QaRow $r)) }
    foreach ($a in $Appendix) { $lines.Add($a) }
    $f1 = Join-Path $QaResDir "$Name-$QaStamp.md"
    $f2 = Join-Path $QaResDir "$Name-latest.md"
    [System.IO.File]::WriteAllLines($f1, $lines, (New-Object System.Text.UTF8Encoding($true)))
    Copy-Item $f1 $f2 -Force
    Write-Host "Report: $f1  (PASS $($cnt.PASS) FAIL $($cnt.FAIL) WARN $($cnt.WARN))"
    return $f1
}
function Format-QaRow($r) {
    $esc = { param($s) ([string]$s).Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ') }
    '| ' + (& $esc $r.Id) + ' | ' + $r.Status + ' | ' + (& $esc $r.Test) + ' | ' + (& $esc $r.Expected) + ' | ' + (& $esc $r.Actual) + ' | ' + (& $esc $r.Note) + ' |'
}

# ---------- doc ----------
# QlikView COM collections (IArrayOf...) do not enumerate with @() / foreach: use Count + Item(i)
function Get-QaComList($c) { $o = New-Object System.Collections.ArrayList; if ($null -ne $c) { for ($i = 0; $i -lt $c.Count; $i++) { [void]$o.Add($c.Item($i)) } }; return ,$o }
function Connect-QaDoc { $Global:QaApp = Get-QvApp; $Global:QaDoc = Get-QvDoc; return $Global:QaDoc }

# Lock helpers for QA: always clear selections before releasing.
# Retries around a race in tools/qvcom.ps1 Enter-QvLock: owner.txt can vanish between Test-Path and Get-Item when the holder releases.
function Enter-QaLock {
    for ($i = 1; $i -le 20; $i++) {
        try { Enter-QvLock -Owner qa -TimeoutSec 900; return }
        catch { if ($i -lt 20 -and $_.Exception.Message -match 'owner\.txt|Cannot find path') { Start-Sleep -Milliseconds 500; continue }; throw }
    }
}
function Exit-QaLock {
    try { Invoke-QvRetry { $Global:QaDoc.ClearAll($true) } | Out-Null } catch { Write-Warning "ClearAll failed: $($_.Exception.Message)" }
    Exit-QvLock -Owner qa
}
