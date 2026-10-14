# build-SH_DASH.ps1 - Dashboard (D of D-A-R). Idempotent. Round 2 (designer-a): built in two lock sessions so no lock is held > 6 min.
# Run:  powershell.exe -NoProfile -ExecutionPolicy Bypass -File build-SH_DASH.ps1 [-Phase all|top|charts] [-NoShot]
#   top    = reset sheet (adopts SH01 'Main'), header/nav, title, help, 6 KPI tiles
#   charts = (re)builds the 6 charts/gauges/table + gauge text
param([string]$SheetId = 'SH_DASH', [string]$Tag = 'DASH', [ValidateSet('all','top','charts')][string]$Phase = 'all', [switch]$NoShot, [string]$Owner = 'designer-a')
. "$PSScriptRoot\..\tools\lib-qv.ps1"; . "$PSScriptRoot\app-settings.ps1"
$G = $QS.Glyph; $C = $QS.C
$T = $Tag

# ---- expression building blocks (single quotes: $(...) must reach QlikView unexpanded) ----
$cal = 'Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date='
$SetCY = '$(vSetCY)'   # full calendar year 2026 (engineer, round 2)
$SetPY = '$(vSetPY)'   # full calendar year 2025
$good = Get-QvRgbExpr $C.Good; $bad = Get-QvRgbExpr $C.Bad; $warn = Get-QvRgbExpr $C.Warn; $prim = Get-QvRgbExpr $C.Primary
$crCol = "If(`$(vCreditRate_CYTD)>0.07,$bad,If(`$(vCreditRate_CYTD)>0.05,$warn,$good))"
function Px2Cw([int]$px) { [int][Math]::Round($px * 300 / 96) }   # table ColWidth unit = 1/300 inch

function Build-Top($doc) {
    $adopt = if ($SheetId -eq 'SH_DASH') { 'SH01' } else { $null }
    $sh = Reset-QvSheet $doc $SheetId 'Dashboard' -AdoptId $adopt
    if (-not $sh) { throw "Reset-QvSheet did not return $SheetId" }
    New-QvHeader $doc $sh $T -Active 'DASH' -Title 'Dashboard' `
        -Subtitle ("Year to date Jan" + $G.Dash + "Sep 2026 (CYTD) vs same period 2025 (PYTD)   " + $G.Mid + "   budget 2026") `
        -Help ("What am I looking at?  Six headline KPIs for the current year to date, each compared with last year (" + $G.Up + $G.Down + " and colour). The gauges show budget achievement and the credit-rate status. Click a chart to filter; open an Analysis sheet to find out why.")

    $xs = 10, 290, 570, 850, 1130, 1410; $y = 96
    $mM = { param($e) Get-QvMoneyM $e }
    New-QvKpiTile $doc $sh "${T}_KPI1" $xs[0] $y -Label ("NET SALES  " + $G.Mid + "  CYTD") `
        -Value ('=' + (& $mM '$(vNetSales_CYTD)')) `
        -Delta ('=' + (Get-QvGrowthText '$(vNetSales_YoY)')) `
        -Context ("='PY ' & " + (& $mM '$(vNetSales_PYTD)') + " & '   " + $G.Mid + "   R12 ' & " + (& $mM '$(vNetSales_R12)')) `
        -StatusExpr 'If($(vNetSales_YoY)>=0,1,-1)' -HelpText 'Invoiced net sales (gross sales minus line discounts), 1 Jan - 30 Sep 2026, compared with 1 Jan - 30 Sep 2025.' | Out-Null
    New-QvKpiTile $doc $sh "${T}_KPI2" $xs[1] $y -Label ("NET REVENUE  " + $G.Mid + "  CYTD") `
        -Value ('=' + (& $mM '$(vNetRevenue_CYTD)')) `
        -Delta ('=' + (Get-QvGrowthText '$(vNetRevenue_YoY)')) `
        -Context ("='after credit notes   " + $G.Mid + "   PY ' & " + (& $mM '$(vNetRevenue_PYTD)')) `
        -StatusExpr 'If($(vNetRevenue_YoY)>=0,1,-1)' -HelpText 'Net sales minus credit notes.' | Out-Null
    New-QvKpiTile $doc $sh "${T}_KPI3" $xs[2] $y -Label ("BUDGET ACHIEVEMENT  " + $G.Mid + "  CYTD") `
        -Value "=Num(`$(vBudgetAch_CYTD),'0.0%')" `
        -Delta ("=If(`$(vNetRevenue_CYTD)>=`$(vBudget_CYTD),Chr(9650),Chr(9660)) & ' ' & Num((`$(vNetRevenue_CYTD)-`$(vBudget_CYTD))/1000000,'+" + $G.Eur + " #,##0.0;-" + $G.Eur + " #,##0.0') & ' M vs budget'") `
        -Context ("='Budget ' & " + (& $mM '$(vBudget_CYTD)') + " & '   " + $G.Mid + "   target 100%'") `
        -StatusExpr 'If($(vBudgetAch_CYTD)>=1,1,If($(vBudgetAch_CYTD)>=0.95,0,-1))' -HelpText 'Net revenue divided by budget (Jan-Sep 2026). Green >= 100 %, amber 95-100 %, red < 95 %.' | Out-Null
    New-QvKpiTile $doc $sh "${T}_KPI4" $xs[3] $y -Label ("NET MARGIN %  " + $G.Mid + "  CYTD") `
        -Value "=Num(`$(vNetMarginPct_CYTD),'0.0%')" `
        -Delta ('=' + (Get-QvPpText '$(vNetMarginPct_YoYpp)')) `
        -Context ("='Net margin ' & " + (& $mM '$(vNetMargin_CYTD)') + " & '   " + $G.Mid + "   PY ' & Num(`$(vNetMarginPct_PYTD),'0.0%')") `
        -StatusExpr 'If($(vNetMarginPct_YoYpp)>=0,1,-1)' -HelpText 'Gross margin minus credit notes plus cost reversals, as % of net revenue.' | Out-Null
    New-QvKpiTile $doc $sh "${T}_KPI5" $xs[4] $y -Label ("CREDIT RATE  " + $G.Mid + "  CYTD") `
        -Value "=Num(`$(vCreditRate_CYTD),'0.0%')" `
        -Delta ('=' + (Get-QvPpText '$(vCreditRate_YoYpp)')) `
        -Context ("='Credit notes ' & " + (& $mM '$(vCreditAmount_CYTD)') + " & '   " + $G.Mid + "   lower is better'") `
        -StatusExpr 'If($(vCreditRate_YoYpp)<=0,1,-1)' -HelpText 'Credit amount / net sales. A rising rate (red) means more returns and credits.' | Out-Null
    New-QvKpiTile $doc $sh "${T}_KPI6" $xs[5] $y -Label ("INVOICES  " + $G.Mid + "  CYTD") `
        -Value "=Num(`$(vInvoices_CYTD),'#,##0')" `
        -Delta ('=' + (Get-QvGrowthText '$(vInvoices_YoY)')) `
        -Context ("='Avg " + $G.Eur + " ' & Num(`$(vAvgInvoiceValue_CYTD),'#,##0') & '   " + $G.Mid + "   ' & Num(`$(vActiveCustomers_CYTD),'#,##0') & ' active customers'") `
        -StatusExpr 'If($(vInvoices_YoY)>=0,1,-1)' -HelpText 'Number of distinct invoices, average net sales per invoice and customers with at least one invoice.' | Out-Null
}

function Build-Charts($doc) {
    $sh = Get-QvSheetById $doc $SheetId
    if (-not $sh) { throw "sheet $SheetId missing - run -Phase top first" }
    foreach ($id in 'CH_TREND','GA_BUDGET','CH_CHANNEL','TB_REGION','GA_CREDIT','GA_CREDIT_VAL','GA_CREDIT_CTX','CH_CATCR') { Remove-QvObj $doc "${T}_$id" }

    # Trend: values in EUR millions (axis + bar labels short), labels only on the bars
    New-QvChart $doc $sh "${T}_CH_TREND" combo @(10,224,830,256) -Caption ("Net Revenue by Month (" + $G.Eur + " M) " + $G.Dash + " 2026 vs 2025 vs Budget") `
        -Dims @(@{ F='Month'; L='Month' }) -Legend -LegendPos 0 -Maximize -YUnit ($G.Eur + ' M') `
        -HelpText 'Bars: net revenue 2026 (Jan-Sep) in EUR million. Grey line: full year 2025. Amber line: budget 2026. Calendar selections are ignored so the whole year stays visible.' `
        -Exprs @(
            @{ D='($(vNetRevenue_CYTD))/1000000'; L='2026 actual'; Fmt='moneyM'; Mode='bar'; Color=$C.Primary },
            @{ D=('(Sum(' + $SetPY + ' NetSales) - Sum(' + $SetPY + ' CreditAmount))/1000000'); L='2025 actual'; Fmt='moneyM'; Mode='line'; Color=$C.PY },
            @{ D=('Sum(' + $SetCY + ' BudgetNetSales)/1000000'); L='2026 budget'; Fmt='moneyM'; Mode='line'; Color=$C.Budget }
        ) | Out-Null

    $budSeg = @(@('0.8', $C.Bad, 'below 95%'), @('0.95', $C.Warn, '95-100%'), @('1', $C.Good, 'on target'))
    New-QvChart $doc $sh "${T}_GA_BUDGET" gauge @(850,224,270,256) -Caption 'Budget Achievement CYTD (%)' `
        -HelpText 'Net revenue / budget, Jan-Sep 2026. Red < 95 %, amber 95-100 %, green >= 100 %.' `
        -Exprs @(@{ D='$(vBudgetAch_CYTD)'; L='Budget achievement'; Fmt='pct' }) -GaugeMode 4 `
        -Gauge @{ Min='0.8'; Max='1.2'; Seg=$budSeg; Indicator=$C.Text; Ticks=5 } `
        -Texts @(@{ T="=Num(`$(vBudgetAch_CYTD),'0.0%')"; R=@(0,560,840,90); Size=16; Bold=$true }) | Out-Null

    # Pie: relative (share) -> percent format, labels on slices show the share
    New-QvChart $doc $sh "${T}_CH_CHANNEL" pie @(1130,224,550,256) -Caption ("Net Revenue Share by Channel " + $G.Dash + " CYTD (%)") `
        -Dims @(@{ F='Channel'; L='Channel' }) -Legend -LegendPos 3 `
        -HelpText 'Share of net revenue (Jan-Sep 2026) per sales channel. Click a slice to filter all sheets.' `
        -Exprs @(@{ D='$(vNetRevenue_CYTD)'; L='Share of net revenue'; Fmt='pct'; Relative=$true; Values=$true; ColorExpr=$QS.ChannelColorExpr }) | Out-Null

    # Region table: short headers, explicit column widths, no total on the sparkline
    New-QvChart $doc $sh "${T}_TB_REGION" straight @(10,490,830,256) -Caption ("Regions at a Glance " + $G.Dash + " CYTD") -XL -FontSize 10.5 `
        -HelpText 'One row per customer region: net revenue, growth vs PY, a 12-month trend line, net margin and credit rate (green <= 5 %, amber 5-7 %, red > 7 %). Growth light: green >= +3 %, amber 0 to +3 %, red < 0 %.' `
        -Dims @(@{ F='CustomerRegion'; L='Region'; SortExpr='$(vNetRevenue_CYTD)'; SortDesc=$true; ColWidth=(Px2Cw 130) }) `
        -Exprs @(
            @{ D='$(vNetRevenue_CYTD)'; L=("Net Rev. (" + $G.Eur + ")"); Fmt='money'; ColWidth=(Px2Cw 120) },
            @{ D='$(vNetRevenue_YoY)'; L='YoY %'; Fmt='growth'; TextColorExpr="If(`$(vNetRevenue_YoY)>=0,$good,$bad)"; ColWidth=(Px2Cw 80) },
            @{ D='If(Sum($(vSetR12) NetSales)<>0, $(vNetRevenue_R12))'; L='Trend R12'; Repr='minichart'; Mini=@{ Dim='YearMonth'; Mode='line' }; NoTotal=$true; ColWidth=(Px2Cw 170) },
            @{ D='$(vNetMarginPct_CYTD)'; L='Net Margin %'; Fmt='pct'; ColWidth=(Px2Cw 100) },
            @{ D='$(vCreditRate_CYTD)'; L='Credit Rate'; Fmt='pct'; TextColorExpr=$crCol; ColWidth=(Px2Cw 90) },
            @{ D='$(vNetRevenue_YoY)'; L='Growth'; Repr='traffic'; ColWidth=(Px2Cw 100); Gauge=@{ Min='-0.2'; Max='0.2'; SingleLed=$true; Seg=@(@('-0.2',$C.Bad),@('0',$C.Warn),@('0.03',$C.Good)) } }
        ) -Configure { param($p) try { $p.TableProperties.NullSymbol = ' ' } catch {} } | Out-Null

    # Credit-rate traffic light: gauge on top, value + context as text objects below (nothing cut off)
    New-QvChart $doc $sh "${T}_GA_CREDIT" gauge @(850,490,270,196) -Caption ("Credit Rate CYTD (%) " + $G.Dash + " Status") `
        -HelpText 'Traffic light for the credit rate (credit amount / net sales): green <= 5 %, amber 5-7 %, red > 7 %.' `
        -Exprs @(@{ D='$(vCreditRate_CYTD)'; L='Credit rate'; Fmt='pct' }) -GaugeMode 2 `
        -Gauge @{ Min='0'; Max='0.1'; Seg=@(@('0',$C.Good,'<= 5%'),@('0.05',$C.Warn,'5-7%'),@('0.07',$C.Bad,'> 7%')) } | Out-Null
    New-QvText $doc $sh "${T}_GA_CREDIT_VAL" @(850,686,270,30) -Text "=Num(`$(vCreditRate_CYTD),'0.0%')" -FgExpr $crCol -Size 15 -Bold -HAlign 1 -Margin 0 | Out-Null
    New-QvText $doc $sh "${T}_GA_CREDIT_CTX" @(850,716,270,30) -Text ("=" + (Get-QvPpText '$(vCreditRate_YoYpp)') + " & '   " + $G.Mid + "   green ' & Chr(8804) & ' 5%, red > 7%'") -Fg $C.Muted -Size 8 -HAlign 1 -VAlign 0 -Margin 0 | Out-Null

    New-QvChart $doc $sh "${T}_CH_CATCR" bar @(1130,490,550,256) -Caption ("Credit Rate by Product Category (%) " + $G.Dash + " CYTD vs PYTD") `
        -Horizontal -Legend -LegendPos 0 `
        -HelpText 'Credit rate per product category this year vs last year. Red bars are above 7 % - see the Credit Notes sheet.' `
        -Dims @(@{ F='ProductCategory'; L='Category'; SortExpr='$(vCreditRate_CYTD)'; SortDesc=$true }) `
        -Exprs @(
            @{ D='$(vCreditRate_CYTD)'; L='CYTD'; Fmt='pct'; ColorExpr="If(`$(vCreditRate_CYTD)>0.07,$bad,$prim)"; Values=$true },
            @{ D='$(vCreditRate_PYTD)'; L='PYTD'; Fmt='pct'; Color=$C.PY }
        ) | Out-Null    # the round-1 prototype sheet is obsolete once SH_DASH exists
    if ($SheetId -eq 'SH_DASH') { Remove-QvSheet $doc 'ZZ_designer_Sandbox' }
}

$phases = if ($Phase -eq 'all') { @('top','charts') } else { @($Phase) }
foreach ($ph in $phases) {
    Enter-QvLock -Owner $Owner -TimeoutSec 1200
    Write-QvTrace "=== $SheetId phase $ph start (owner $Owner)"
    try {
        $doc = Get-QvDoc
        Enter-QvParking $doc
        if ($ph -eq 'top') { Build-Top $doc } else { Build-Charts $doc }
        Set-QvSheetOrder $doc
    } finally {
        try { Exit-QvParking $doc $SheetId } catch { Write-Warning "parking cleanup: $_" }
        Write-QvTrace "=== $SheetId phase $ph end"
        Exit-QvLock -Owner $Owner
    }
}

if (-not $NoShot) {
    $doc = Get-QvDoc
    Invoke-QvRetry { $doc.ActivateSheetById("Document\$SheetId") } | Out-Null
    Save-QvScreenshot -Path "$QvBuildRoot\shots\$SheetId.png" | Out-Null
    "shot: $QvBuildRoot\shots\$SheetId.png"
}
