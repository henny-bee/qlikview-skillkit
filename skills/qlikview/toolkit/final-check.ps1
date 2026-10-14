# Zero-defect gate: for every sheet, scans text objects, chart captions and first table cells for QlikView error
# texts, saves a screenshot per sheet, then activates the first sheet, clears selections and saves the document.
#   qvrun.sh final-check.ps1 [-OutDir _build\final-shots] [-NoSave] [-Owner lead]
# Exit code 1 if any error text was found. ALWAYS look at the screenshots too: this scan cannot see overlaps, 'EUR 0', truncation.
param([string]$OutDir, [switch]$NoSave, [string]$Owner = 'lead', [int]$WaitSec = 7)
. "$PSScriptRoot\qvcom.ps1"
if (-not $OutDir) { $OutDir = Join-Path $QvBuildRoot 'final-shots' }
$pattern = 'Error in expression|Allocated memory exceeded|Garbage after|Bad field name|Unknown function|Out of object memory'
$total = 0
Enter-QvLock -Owner $Owner -TimeoutSec 600
try {
    $doc = Get-QvDoc
    $doc.ClearAll($true) | Out-Null
    for ($i = 0; $i -lt $doc.NoOfSheets(); $i++) {
        $sh = $doc.GetSheet($i); $sp = $sh.GetProperties(); $short = $sp.SheetId -replace '^Document\\', ''
        [void]$doc.ActivateSheetById($sp.SheetId); [void](Get-QvApp).WaitForIdle(); Start-Sleep $WaitSec
        $bad = @()
        foreach ($o in $sh.GetSheetObjects()) {
            try {
                $t = $o.GetObjectType(); $txt = ''
                if ($t -eq 6) { $txt = $o.GetText() } elseif ($t -ge 10) { try { $txt = $o.GetCaption().Name.v } catch {} }
                if ($txt -match $pattern) { $bad += "$($o.GetObjectId()): $txt" }
                if ($t -ge 10) { try { $c = $o.GetCell(1, 1).Text; if ($c -match $pattern) { $bad += "$($o.GetObjectId()) cell: $c" } } catch {} }
            } catch {}
            Update-QvLock -Owner $Owner
        }
        $total += $bad.Count
        Save-QvScreenshot -Path (Join-Path $OutDir "$short.png") | Out-Null
        "{0,-14} {1,-28} objects={2,-4} errors={3} {4}" -f $short, $sp.Name, $sh.NoOfSheetObjects(), $bad.Count, ($bad -join ' | ')
    }
    if ($doc.NoOfSheets() -gt 0) { [void]$doc.GetSheet(0).Activate() }
    $doc.ClearAll($true) | Out-Null
    if (-not $NoSave) { $doc.Save(); "Saved: $($doc.GetPathName())" }
} finally { Exit-QvLock -Owner $Owner }
"Screenshots: $OutDir"
if ($total -gt 0) { exit 1 }
