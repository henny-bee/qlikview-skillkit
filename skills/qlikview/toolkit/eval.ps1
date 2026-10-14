# Read-only: evaluates QlikView expressions against the open document, one expression per argument.
#   qvrun.sh eval.ps1 'Sum(Sales)' '$(vMargin)' 'Count(DISTINCT CustomerID)'
# (Expressions contain commas, so pass each one as its own quoted argument; do not join them with commas.)
param([Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)][string[]]$Expr)
. "$PSScriptRoot\qvcom.ps1"
$doc = Invoke-QvRetry { Get-QvDoc }
foreach ($e in $Expr) { "{0} = {1}" -f $e, (Invoke-QvRetry { $doc.Evaluate($e) }) }
