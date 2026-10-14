# build-SH_CUST.ps1 - Customers & Products (A of D-A-R): drill-down. Idempotent.
# Run: powershell.exe -NoProfile -ExecutionPolicy Bypass -File build-SH_CUST.ps1 [-Phase all|top|charts] [-NoShot]
param([string]$SheetId = 'SH_CUST', [string]$Tag = 'CUST', [ValidateSet('all','top','charts')][string]$Phase = 'all', [switch]$NoShot, [string]$Owner = 'designer-a')
. "$PSScriptRoot\..\tools\lib-qv.ps1"; . "$PSScriptRoot\app-settings.ps1"
. "$PSScriptRoot\..\tools\lib-ext.ps1"
$G = $QS.Glyph; $C = $QS.C; $T = $Tag
$good = Get-QvRgbExpr $C.Good; $bad = Get-QvRgbExpr $C.Bad; $warn = Get-QvRgbExpr $C.Warn
$eurM = "(" + $G.Eur + " M)"
function Px2Cw([int]$px) { [int][Math]::Round($px * 300 / 96) }

function Build-Top($doc) {
    $sh = Reset-QvSheet $doc $SheetId 'Customers & Products'
    if (-not $sh) { throw "Reset-QvSheet did not return $SheetId" }
    New-QvHeader $doc $sh $T -Active 'CUST' -Title 'Customers & Products' `
        -Subtitle ("Drill down: Region " + $G.Arrow + " Country " + $G.Arrow + " City " + $G.Arrow + " Customer   and   Category " + $G.Arrow + " Group " + $G.Arrow + " Product") `
        -Help ("What am I looking at?  Click a bar to drill down one level (the drill-up arrow appears next to the axis). The Top N customers table follows the Top N input in the left panel. The funnel shows how many customers are active.")
    New-QvbFilterPanel $doc $sh $T 'Top N customers' | Out-Null
    Repair-QvCurSelWidths $doc $sh "${T}_FLT_CS" @(14,118,202,84)
    New-QvInputBox $doc $sh "${T}_FLT_IB_TOPN" @(14,606,202,40) -Variables @('vTopN') -Labels @('Top N customers') -LabelPx 104 `
        -HelpText 'Type a number (e.g. 10 or 25). Shared with the Top N slider on the Sales sheet.' | Out-Null
    New-QvSectionHead $doc $sh "${T}_FLT_H6" @(10,652,210,20) 'Segment' | Out-Null
    New-QvbListBox $doc $sh "${T}_FLT_LB_SEG" @(14,674,202,68) 'CustomerSegment' | Out-Null
}

function Build-Charts($doc) {
    $sh = Get-QvSheetById $doc $SheetId
    if (-not $sh) { throw "sheet $SheetId missing - run -Phase top first" }
    foreach ($id in 'CH_GEO','CH_PROD','CH_RADAR','TB_TOPN','CH_FUNNEL') { Remove-QvObj $doc "${T}_$id" }

    # 1 Geography drill: CYTD vs PYTD, top 15 by CYTD (Rank limit works on every drill level)
    $lim = 'Rank(TOTAL $(vNetRevenue_CYTD))<=15'
    $geoLbl = "Pick(Match(GetCurrentField(drl_Geography),'CustomerRegion','CustomerCountry','CustomerCity','CustomerName'),'Region','Country','City','Customer')"
    $prdLbl = "Pick(Match(GetCurrentField(drl_Product),'ProductCategory','ProductGroup','ProductName'),'Category','Product Group','Product')"
    New-QvChart $doc $sh "${T}_CH_GEO" bar @(230,96,720,320) -Legend -LegendPos 0 -YUnit ($G.Eur + ' M') `
        -Configure { param($p) $p.SortByYValue = -1 } `
        -Caption ("='Net Revenue by ' & $geoLbl & ' " + $eurM + " " + $G.Dash + " CYTD vs PYTD (top 15)'") `
        -HelpText 'Click a bar to drill down Region > Country > City > Customer. CEE grows fastest, UK & Ireland is flat.' `
        -Dims @(@{ F='drl_Geography'; SortExpr='$(vNetRevenue_CYTD)'; SortDesc=$true }) `
        -Exprs @(
            @{ D=("If($lim, " + '$(vNetRevenue_CYTD)/1000000)'); L='CYTD'; Fmt='moneyM1'; Color=$C.Primary },
            @{ D=("If($lim, " + '$(vNetRevenue_PYTD)/1000000)'); L='PYTD'; Fmt='moneyM1'; Color=$C.PY }
        ) | Out-Null

    # 2 Product drill: Net Sales bars + GM% line on the right axis
    New-QvChart $doc $sh "${T}_CH_PROD" combo @(960,96,720,320) -Legend -LegendPos 0 -YUnit ($G.Eur + ' M') `
        -Configure { param($p) $p.SortByYValue = -1 } `
        -Caption ("='Net Sales " + $eurM + " and Gross Margin % by ' & " + $prdLbl) `
        -HelpText 'Click a bar to drill down Category > Group > Product. Bars: net sales; line: gross margin % (right axis).' `
        -Dims @(@{ F='drl_Product'; SortExpr='Sum(NetSales)'; SortDesc=$true }) `
        -Exprs @(
            @{ D='$(vNetSales)/1000000'; L=("Net Sales " + $eurM); Fmt='moneyM'; Mode='bar'; Color=$C.Primary },
            @{ D='$(vGrossMarginPct)'; L='Gross Margin %'; Fmt='pct'; Mode='linesymbol'; Right=$true; Color=$C.Budget }
        ) | Out-Null

    # 3 Radar: category mix per segment
    New-QvChart $doc $sh "${T}_CH_RADAR" radar @(230,426,400,320) -Legend -LegendPos 0 `
        -Caption 'Category Mix by Customer Segment (% of segment sales)' `
        -HelpText 'Each line is a customer segment; each spoke a product category. Share of the segment''s net sales.' `
        -Dims @(@{ F='ProductCategory'; L='Category' }, @{ F='CustomerSegment'; L='Segment' }) `
        -Exprs @(@{ D='Sum(NetSales)/Sum(TOTAL <CustomerSegment> NetSales)'; L='Share of segment sales'; Fmt='pct'; NoAxis=$true }) | Out-Null

    # 4 Top N customers table
    $crCol = "If(`$(vCreditRate_CYTD)>0.07,$bad,If(`$(vCreditRate_CYTD)>0.05,$warn,$good))"
    New-QvChart $doc $sh "${T}_TB_TOPN" straight @(640,426,640,320) -XL `
        -Caption ("='Top ' & vTopN & ' Customers by Net Revenue " + $G.Dash + " CYTD'") `
        -HelpText 'Key accounts by net revenue Jan-Sep 2026. The bar shows the size relative to the largest customer; credit rate light: green <= 5 %, amber 5-7 %, red > 7 %.' `
        -Dims @(@{ F='=Aggr(If(Rank(Sum($(vSetCYTD) NetSales)-Sum($(vSetCYTD) CreditAmount))<=vTopN,CustomerName),CustomerName)'; L='Customer'; SortExpr='$(vNetRevenue_CYTD)'; SortDesc=$true; ColWidth=(Px2Cw 165) }) `
        -Exprs @(
            @{ D='Only(CustomerCountry)'; L='Country'; ColWidth=(Px2Cw 88); NoTotal=$true },
            @{ D='Only(CustomerSegment)'; L='Segment'; ColWidth=(Px2Cw 68); NoTotal=$true },
            @{ D='$(vNetRevenue_CYTD)'; L=("Net Rev. (" + $G.Eur + ")"); Fmt='money'; ColWidth=(Px2Cw 86) },
            @{ D='$(vNetRevenue_CYTD)/Max(TOTAL Aggr($(vNetRevenue_CYTD),CustomerName))'; L='vs #1'; Repr='lineargauge'; NoTotal=$true; ColWidth=(Px2Cw 30);
               Gauge=@{ Min='0'; Max='1'; Seg=@(,@('0',$C.Primary)); Fill=$true } },
            @{ D='$(vNetRevenue_YoY)'; L='YoY %'; Fmt='growth'; TextColorExpr="If(`$(vNetRevenue_YoY)>=0,$good,$bad)"; ColWidth=(Px2Cw 48) },
            @{ D='$(vNetMarginPct_CYTD)'; L='NM %'; Fmt='pct'; ColWidth=(Px2Cw 46) },
            @{ D='$(vCreditRate_CYTD)'; L='Credit'; Repr='traffic'; ColWidth=(Px2Cw 38); Gauge=@{ Min='0'; Max='0.1'; SingleLed=$true; Seg=@(@('0',$C.Good),@('0.05',$C.Warn),@('0.07',$C.Bad)) } },
            @{ D='$(vInvoices_CYTD)'; L='Invoices'; Fmt='int'; ColWidth=(Px2Cw 46) }
        ) -Configure { param($p) try { $p.TableProperties.NullSymbol = ' ' } catch {} } | Out-Null

    # 5 Funnel: activity stages. Dimension is a data field (Quarter, 4 values) relabelled as stages; values use TOTAL so they
    #   do not depend on the quarter and {1}/period sets keep all 4 stages visible. (No field-less ValueList dimension.)
    $inv = 'LinkSource={"*Invoice*"}'
    $cal = 'Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date='
    $stage = "=Pick(Match(Quarter,'Q1','Q2','Q3','Q4'),'All customers','Active R12','Active CYTD','Active Sep 2026')"
    $val = "Pick(Match(Only({1} Quarter),'Q1','Q2','Q3','Q4'), Count(TOTAL {1} DISTINCT CustomerID), " +
           "Count(TOTAL {<$cal,Flag_R12={1},$inv>} DISTINCT CustomerID), Count(TOTAL {<$cal,Flag_CYTD={1},$inv>} DISTINCT CustomerID), " +
           "Count(TOTAL {<$cal,Flag_CM={1},$inv>} DISTINCT CustomerID))"
    New-QvChart $doc $sh "${T}_CH_FUNNEL" funnel @(1290,426,390,320) -Caption 'Customer Activity Funnel (count)' -Legend -LegendPos 0 `
        -HelpText 'All customers in the master data, then those with at least one invoice in the last 12 months, this year, and in September 2026. Respects non-calendar selections.' `
        -Colors @($C.PY, $C.PrimaryLt, '#5AA3D8', $C.Primary) `
        -Dims @(@{ F=$stage; L='Stage'; SortExpr="Match(Quarter,'Q1','Q2','Q3','Q4')"; SortDesc=$false }) `
        -Exprs @(@{ D=$val; L='Customers'; Fmt='int'; Values=$true }) | Out-Null
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
