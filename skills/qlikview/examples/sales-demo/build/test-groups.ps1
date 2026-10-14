# Zero-defect check for SH_DASH / SH_SALES / SH_CUST: cycles cyclic groups, drills drill groups, checks captions/cells for errors.
. "$PSScriptRoot\..\tools\lib-qv.ps1"; . "$PSScriptRoot\app-settings.ps1"
$app = Get-QvApp
$bad = 0
function Chk($doc, [string]$id, [string]$step) {
    $app.WaitForIdle()
    $o = $doc.GetSheetObject("Document\$id")
    $cap = $o.GetCaption().Name.v
    $c0 = try { $o.GetCell(0,0).Text } catch { 'ERR' }
    $c1 = try { $o.GetCell(1,0).Text + ' | ' + $o.GetCell(1,1).Text } catch { 'NO ROWS' }
    $flag = if (($cap + '|' + $c0 + '|' + $c1) -cmatch 'Error|ERR|Allocated|NaN' -or ($c1 -eq 'NO ROWS' -and $id -notmatch '_GA_')) { $script:bad++; 'FAIL' } else { 'ok  ' }
    "{0} {1,-16} {2,-28} cap=[{3}] hdr=[{4}] row1=[{5}]" -f $flag, $id, $step, $cap, $c0, $c1
}
Enter-QvLock -Owner designer-a -TimeoutSec 1200
try {
    $doc = Get-QvDoc
    $doc.ClearAll($true)
    # --- SALES: cyclic dimension groups
    $doc.ActivateSheetById('Document\SH_SALES') | Out-Null
    foreach ($pair in @(@('cyc_Time','SALES_CH_TREND'), @('cyc_Dimension','SALES_CH_TOPN'))) {
        $g = $doc.GetGroup($pair[0]); $n = try { $g.GetProperties().FieldDefs.Count } catch { if ($pair[0] -eq "cyc_Time") { 5 } else { 6 } }
        for ($i = 0; $i -lt $n; $i++) { Chk $doc $pair[1] ("$($pair[0])=" + $g.GetActiveField().Name); $g.Cycle(1) }   # n steps -> back to start
    }
    foreach ($id in 'SALES_CH_SEASON','SALES_CH_MEKKO','SALES_CH_SCATTER','SALES_CH_CHGROW') { Chk $doc $id 'static' }
    # trend measure buttons (vUI_TrendMeasure 1..6) and TOPN cyclic expressions
    for ($m = 1; $m -le 6; $m++) { $doc.Variables('vUI_TrendMeasure').SetContent("$m", $true); Chk $doc 'SALES_CH_TREND' "measure=$m" }
    $doc.Variables('vUI_TrendMeasure').SetContent('1', $true)
    $p = $doc.GetSheetObject('Document\SALES_CH_TOPN').GetProperties(); $grp = $p.Expressions.Item(0)
    for ($i = 0; $i -lt $grp.Count; $i++) { $d = $grp.Item($i).Data.ExpressionData.Definition.v -replace 'If\(Rank\(TOTAL [^)]*\)\)<=vTopN, ', '(' ; $r = $doc.Evaluate($d); $f = if ($r -eq $null -or "$r" -eq '') { $bad++; 'FAIL' } else { 'ok  ' }; "$f topn cyc-expr $i [$($grp.Item($i).Data.ExpressionVisual.Label.v)] = $r" }
    foreach ($sid in 'SALES','CUST') { $f = if ($doc.GetSheetObject("Document\${sid}_FLT_CS")) { 'ok  ' } else { $bad++; 'FAIL' }; "$f ${sid}_FLT_CS exists" }
    $doc.Variables('vTopN').SetContent('3', $true); Chk $doc 'SALES_CH_TOPN' 'vTopN=3'
    $doc.Variables('vTopN').SetContent('10', $true)
    # --- CUST: drill groups
    $doc.ActivateSheetById('Document\SH_CUST') | Out-Null
    Chk $doc 'CUST_CH_GEO' 'level 1'
    $doc.Fields('CustomerRegion').Select('DACH') | Out-Null; Chk $doc 'CUST_CH_GEO' 'Region=DACH'
    $doc.Fields('CustomerCountry').Select('Germany') | Out-Null; Chk $doc 'CUST_CH_GEO' 'Country=Germany'
    $city = $doc.Evaluate('MinString(CustomerCity)'); $doc.Fields('CustomerCity').Select($city) | Out-Null; Chk $doc 'CUST_CH_GEO' "City=$city"
    foreach ($id in 'CUST_CH_RADAR','CUST_TB_TOPN','CUST_CH_FUNNEL') { Chk $doc $id 'with geo selection' }
    $doc.ClearAll($true)
    Chk $doc 'CUST_CH_PROD' 'level 1'
    $doc.Fields('ProductCategory').Select('Networking') | Out-Null; Chk $doc 'CUST_CH_PROD' 'Category=Networking'
    $pg = $doc.Evaluate('MinString(ProductGroup)'); $doc.Fields('ProductGroup').Select($pg) | Out-Null; Chk $doc 'CUST_CH_PROD' "Group=$pg"
    $doc.ClearAll($true)
    foreach ($id in 'CUST_CH_RADAR','CUST_TB_TOPN','CUST_CH_FUNNEL') { Chk $doc $id 'no selection' }
    $doc.Fields('Year').Select('2025') | Out-Null; Chk $doc 'CUST_CH_FUNNEL' 'Year=2025 (calendar sel)'
    $doc.ClearAll($true)
    # --- DASH
    $doc.ActivateSheetById('Document\SH_DASH') | Out-Null
    foreach ($id in 'DASH_CH_TREND','DASH_GA_BUDGET','DASH_CH_CHANNEL','DASH_TB_REGION','DASH_GA_CREDIT','DASH_CH_CATCR') { Chk $doc $id 'static' }
    foreach ($id in 'DASH_KPI1_VAL','DASH_KPI2_VAL','DASH_KPI3_VAL','DASH_KPI4_VAL','DASH_KPI5_VAL','DASH_KPI6_VAL','DASH_GA_CREDIT_VAL') {
        $t = $doc.GetSheetObject("Document\$id").GetText(); $f = if ($t -match '^\s*-?\s*$|Error|NaN') { $bad++; 'FAIL' } else { 'ok  ' }; "$f $id = $t" }
} finally {
    try { $doc.ClearAll($true) } catch {}
    Exit-QvLock -Owner designer-a
}
"FAILURES: $bad"
