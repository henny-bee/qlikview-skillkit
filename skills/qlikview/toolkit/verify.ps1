# Read-only: evaluates a TSV file of  <label><TAB><expression>  lines (# = comment) and prints label = value.
# Keep one TSV per project with the numbers that must reconcile (totals, row counts, KPIs, story checks).
#   qvrun.sh verify.ps1 -Tsv _build\spec\metrics.tsv
param([Parameter(Mandatory)][string]$Tsv)
. "$PSScriptRoot\qvcom.ps1"
$doc = Invoke-QvRetry { Get-QvDoc }
foreach ($line in [IO.File]::ReadAllLines($Tsv, [Text.Encoding]::UTF8)) {
    if ($line -match '^\s*#' -or $line.Trim() -eq '') { continue }
    $label, $expr = $line -split "`t", 2
    try { $v = Invoke-QvRetry { $doc.Evaluate($expr) } } catch { $v = "EVAL-FAIL: $($_.Exception.Message)" }
    "{0,-28} {1}" -f $label, $v
}
