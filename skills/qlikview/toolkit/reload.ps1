# Loads a .qvs file into the open document, reloads under the COM lock, then prints log errors and table row counts.
#   qvrun.sh reload.ps1 [-Script _build\script\app.qvs] [-Set @{vCfgRows='50000'}] [-Owner engineer]
# -Set overrides  SET/LET <name> = <value>;  lines (e.g. a small row count for a fast test reload).
param([string]$Script, [hashtable]$Set = @{}, [string]$Owner = 'engineer', [switch]$NoSave)
. "$PSScriptRoot\qvcom.ps1"
if (-not $Script) { $Script = (Get-ChildItem (Join-Path $QvBuildRoot 'script') -Filter *.qvs | Select-Object -First 1).FullName }
if (-not $Script -or -not (Test-Path $Script)) { throw "No .qvs script found (pass -Script)." }
$text = [IO.File]::ReadAllText($Script, [Text.Encoding]::UTF8)
if ($text.Length -gt 0 -and [int]$text[0] -eq 0xFEFF) { $text = $text.Substring(1) }
foreach ($k in $Set.Keys) { $text = [regex]::Replace($text, "((?:SET|LET)\s+$k\s*=\s*)[^;]+", "`${1}$($Set[$k])") }

Enter-QvLock -Owner $Owner
try {
    $doc = Get-QvDoc
    $p = $doc.GetProperties(); $p.Script = $text; $p.GenerateLogfile = $true; $doc.SetProperties($p)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $ok = $doc.DoReload(2, $false, $false)      # 2 = fail on error, no partial reload, no keep-data
    [void](Get-QvApp).WaitForIdle(); $sw.Stop()
    "DoReload returned: $ok   elapsed: {0:N1} s" -f $sw.Elapsed.TotalSeconds
    if (-not $NoSave -and $ok) { $doc.Save() }
} finally { Exit-QvLock -Owner $Owner }

$logPath = "$($doc.GetPathName()).log"
if (Test-Path $logPath) {
    $log = Get-Content $logPath -Encoding UTF8
    "--- log errors ($logPath)"
    $log | Where-Object { $_ -match 'error|failed|Syntax|not found|Unknown statement' } | Select-Object -First 30
    "--- last lines"; $log | Select-Object -Last 6
}
"--- tables (synthetic keys show up as `$Syn tables)"
for ($i = 0; $i -lt $doc.GetTableCount(); $i++) {
    $t = $doc.GetTableName($i)
    $rows = Invoke-QvRetry { $doc.Evaluate("Only({1<`$Table={'$t'}>} `$Rows)") }
    $fields = Invoke-QvRetry { $doc.Evaluate("Only({1<`$Table={'$t'}>} `$Fields)") }
    "{0,-22} rows={1,-10} fields={2}" -f $t, $rows, $fields
}
