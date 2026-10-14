# Activates a sheet and saves a screenshot of the QlikView window (look at it with an image viewer / the Read tool).
#   qvrun.sh shot.ps1 -Sheet SH_DASH [-Out _build\shots\SH_DASH.png] [-WaitSec 6]
param([Parameter(Mandatory)][string]$Sheet, [string]$Out, [int]$WaitSec = 6)
. "$PSScriptRoot\qvcom.ps1"
$doc = Invoke-QvRetry { Get-QvDoc }
if (-not $Out) { $Out = Join-Path $QvBuildRoot "shots\$Sheet.png" }
[void]$doc.ActivateSheetById("Document\$Sheet"); [void](Get-QvApp).WaitForIdle(); Start-Sleep $WaitSec
Save-QvScreenshot -Path $Out
