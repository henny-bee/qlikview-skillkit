# build-SH_INSIGHTS.ps1 - template for the INSIGHT PAGE layout (reference/layouts.md): one page that answers
# "what are the most important things to know?". KPI strip on top, then 6 ranked insight cards, each a headline
# sentence with the number + a small chart that proves it. Idempotent.
# Workflow: analyse the data FIRST, agree the insight list with the user, then fill the cards below (most important = 1).
# Field and measure names (Sales, Region, Product, YearMonth, Year) are placeholders: use your data contract names.
param([string]$SheetId = 'SH_INSIGHTS', [string]$Tag = 'INS', [string]$Title = 'Key Insights', [switch]$NoShot, [string]$Owner = 'designer')
. "$PSScriptRoot\..\tools\lib-qv.ps1"
. "$PSScriptRoot\app-settings.ps1"
# Single-page app? Show just one nav button:
# $Global:QvNav = @(@{ Key='INS'; Sheet='SH_INSIGHTS'; Text='Insights'; W=110 }); $Global:QvSheetOrder = @('SH_INSIGHTS')
$G = $QS.Glyph; $C = $QS.C; $T = $Tag

# ---- expression building blocks (single quotes: $(...) must reach QlikView unexpanded) ----
$CY  = 'Sum({$<Year={$(=Max(Year))}>} Sales)'
$PY  = 'Sum({$<Year={$(=Max(Year)-1)}>} Sales)'
$GRW = "($CY/$PY-1)"                                               # growth vs last year
$growByRegion = "Aggr($GRW, Region)"
$redGreen = "If($GRW<0," + (Get-QvRgbExpr $C.Bad) + "," + (Get-QvRgbExpr $C.Good) + ")"

# card grid: KPI strip y 96..160, two rows of three cards below (canvas 1690 x 755)
$cx = 10, 570, 1130; $cw = 550; $ry = 170, 463; $chh = 283

Enter-QvLock -Owner $Owner
try {
    $doc = Get-QvDoc
    Enter-QvParking $doc
    $sh = Reset-QvSheet $doc $SheetId $Title
    New-QvHeader $doc $sh $T -Title $Title -Subtitle 'The most important things to know, ranked. Each card: what happened, how big, and the proof.' `
        -Help 'What am I looking at?  The top findings in the data, most important first. Click a bar to filter; the headlines update with your selections.'

    # ---- KPI strip: context for the insights ----
    New-QvMiniKpi $doc $sh "${T}_K1" 10 96 -W 410 -Label 'SALES (CURRENT YEAR)' -Value ('=' + (Get-QvMoneyM $CY)) -Delta ('=' + (Get-QvGrowthText $GRW)) -StatusExpr "If($GRW>=0,1,-1)" | Out-Null
    New-QvMiniKpi $doc $sh "${T}_K2" 430 96 -W 410 -Label 'TODO KPI 2' -Value "=Num(Count(DISTINCT Region),'#,##0')" | Out-Null
    New-QvMiniKpi $doc $sh "${T}_K3" 850 96 -W 410 -Label 'TODO KPI 3' -Value "=Num(Count(DISTINCT Product),'#,##0')" | Out-Null
    New-QvMiniKpi $doc $sh "${T}_K4" 1270 96 -W 410 -Label 'TODO KPI 4' -Value "=Num(Sum(Sales),'#,##0')" | Out-Null

    # ---- Insight 1: biggest problem (weakest region vs last year) ----
    New-QvInsightCard $doc $sh "${T}_I1" @($cx[0],$ry[0],$cw,$chh) -Rank 1 `
        -Headline ("='Weakest region: ' & FirstSortedValue(Region, $growByRegion) & ' ' & Num(Min($growByRegion),'+0.0%;-0.0%') & ' vs last year'") `
        -Detail 'Sales growth by region, current year vs last year (red = shrinking).' `
        -StatusExpr "If(Min($growByRegion)<0,-1,0)" `
        -Chart @{ Type='bar'; Horizontal=$true; Dims=@(@{ F='Region'; L='Region'; SortExpr=$GRW }); Exprs=@(@{ D=$GRW; L='Growth'; Fmt='growth'; ColorExpr=$redGreen; Values=$true }) } | Out-Null

    # ---- Insight 2: concentration (Pareto: share of the top 10 products) ----
    New-QvInsightCard $doc $sh "${T}_I2" @($cx[1],$ry[0],$cw,$chh) -Rank 2 `
        -Headline "='Top 10 products = ' & Num(Sum(Aggr(If(Rank(Sum(Sales))<=10, Sum(Sales)), Product)) / Sum(Sales),'0%') & ' of all sales'" `
        -Detail 'Sales of the 10 biggest products. A high share means high dependency on a few products.' `
        -StatusExpr '0' `
        -Chart @{ Type='bar'; Horizontal=$true; Dims=@(@{ F='Product'; L='Product'; Limit='10'; SortExpr='Sum(Sales)'; SortDesc=$true }); Exprs=@(@{ D='Sum(Sales)'; L='Sales'; Fmt='money'; Color=$C.Primary }) } | Out-Null

    # ---- Insight 3: timing (best month) ----
    New-QvInsightCard $doc $sh "${T}_I3" @($cx[2],$ry[0],$cw,$chh) -Rank 3 `
        -Headline "='Best month: ' & FirstSortedValue(YearMonth, -Aggr(Sum(Sales), YearMonth)) & ' (' & Num(Max(Aggr(Sum(Sales), YearMonth)),'#,##0') & ')'" `
        -Detail 'Monthly sales. Look for peaks, dips and a change of trend.' `
        -StatusExpr '1' `
        -Chart @{ Type='line'; Dims=@(@{ F='YearMonth'; L='Month' }); Exprs=@(@{ D='Sum(Sales)'; L='Sales'; Fmt='money'; Color=$C.Primary }) } | Out-Null

    # ---- Insights 4-6: fill from your analysis (see the checklist in reference/layouts.md) ----
    foreach ($k in 4..6) {
        $i = $k - 4
        New-QvInsightCard $doc $sh "${T}_I$k" @($cx[$i],$ry[1],$cw,$chh) -Rank $k `
            -Headline "TODO insight ${k}: one sentence with the number" -Detail 'TODO: what the chart shows' -StatusExpr '0' `
            -Chart @{ Type='bar'; Dims=@('Region'); Exprs=@(@{ D='Sum(Sales)'; L='Sales'; Fmt='money'; Color=$C.Primary }) } | Out-Null
    }
    Set-QvSheetOrder $doc
} finally {
    try { Exit-QvParking $doc $SheetId } catch { Write-Warning "parking cleanup: $_" }
    try { $doc.ClearAll($true) } catch {}
    Exit-QvLock -Owner $Owner
}
if (-not $NoShot) {
    [void]$doc.ActivateSheetById("Document\$SheetId"); [void](Get-QvApp).WaitForIdle(); Start-Sleep 5
    Save-QvScreenshot -Path "$QvBuildRoot\shots\$SheetId.png"     # LOOK at it: headlines must fit on one line, charts must prove them
}
