# build-SH_SALES.ps1 - Sales Analysis (A of D-A-R): stories 2 (seasonality, growth) and 4 (E-Commerce discounts). Idempotent.
# Run: powershell.exe -NoProfile -ExecutionPolicy Bypass -File build-SH_SALES.ps1 [-Phase all|top|charts] [-NoShot]
param([string]$SheetId = 'SH_SALES', [string]$Tag = 'SALES', [ValidateSet('all','top','charts')][string]$Phase = 'all', [switch]$NoShot, [string]$Owner = 'designer-a')
. "$PSScriptRoot\..\tools\lib-qv.ps1"; . "$PSScriptRoot\app-settings.ps1"
. "$PSScriptRoot\..\tools\lib-ext.ps1"
$G = $QS.Glyph; $C = $QS.C; $T = $Tag
$good = Get-QvRgbExpr $C.Good; $bad = Get-QvRgbExpr $C.Bad; $prim = Get-QvRgbExpr $C.Primary
$eurM = "(" + $G.Eur + " M)"

function Build-Top($doc) {
    $sh = Reset-QvSheet $doc $SheetId 'Sales Analysis'
    try { [void]$doc.Variables('vUI_TrendMeasure').GetContent() } catch { [void]$doc.CreateVariable('vUI_TrendMeasure') }
    if (-not ($doc.Variables('vUI_TrendMeasure').GetContent().String)) { $doc.Variables('vUI_TrendMeasure').SetContent('1', $true) }
    if (-not $sh) { throw "Reset-QvSheet did not return $SheetId" }
    New-QvHeader $doc $sh $T -Active 'SALES' -Title 'Sales Analysis' `
        -Subtitle ("All values respect your selections   " + $G.Mid + "   click the cycle icon in a chart to switch dimension or measure") `
        -Help ("What am I looking at?  Trend over time (switch Year / Quarter / Month / Week / Weekday and the measure), seasonality per year, the Top N of any dimension, and the channel economics: discount vs margin. Set Top N with the slider in the left panel.")
    New-QvbFilterPanel $doc $sh $T 'Top N' | Out-Null
    Repair-QvCurSelWidths $doc $sh "${T}_FLT_CS" @(14,118,202,84)
    New-QvSlider $doc $sh "${T}_FLT_SL_TOPN" @(14,606,202,44) 'vTopN' 3 25 1 -Caption "='Top N = ' & vTopN & '  (3 - 25)'" -HelpText 'Number of bars in the Top N chart (variable vTopN, shared with the Customers sheet).' | Out-Null
    New-QvHelp $doc $sh "${T}_HELP_PANEL" @(14,656,202,86) ("Cyclic groups switch the dimension: click the cycle icon next to the axis. Click a bar to select it; Clear selections resets all sheets.") | Out-Null
}

function Build-Charts($doc) {
    $sh = Get-QvSheetById $doc $SheetId
    if (-not $sh) { throw "sheet $SheetId missing - run -Phase top first" }
    foreach ($id in 'CH_TREND','CH_SEASON','CH_TOPN','CH_MEKKO','CT_CHAN','CH_SCATTER','CH_CHGROW') { Remove-QvObj $doc "${T}_$id" }

    # 1 Trend by cyc_Time; the measure is chosen with 6 buttons (variable vUI_TrendMeasure) so the title and axis unit can name it
    $mLbl = "Pick(vUI_TrendMeasure,'Net Sales (" + $G.Eur + " M)','Net Revenue (" + $G.Eur + " M)','Gross Margin (" + $G.Eur + " M)','Gross Margin %','Discount Rate %','Invoices (count)')"
    $tLbl = "Pick(Match(GetCurrentField(cyc_Time),'Year','YearQuarter','YearMonth','Week','Weekday'),'Year','Quarter','Month','Week','Weekday')"
    New-QvChart $doc $sh "${T}_CH_TREND" bar @(230,96,950,280) -Maximize `
        -Caption ("='Trend by ' & $tLbl & ' " + $G.Dash + " ' & $mLbl & '   " + $G.Mid + "   2026 = Jan" + $G.Dash + "Sep (YTD)'") `
        -YUnit ("=Pick(vUI_TrendMeasure,'" + $G.Eur + " M','" + $G.Eur + " M','" + $G.Eur + " M','%','%','count')") -YUnitTop 2 `
        -HelpText 'Trend of the chosen measure over the chosen time level. Switch the time level with the cycle icon (cyc_Time) and the measure with the buttons below the chart.' `
        -Dims @(@{ F='cyc_Time' }) `
        -Exprs @(@{ D="Pick(vUI_TrendMeasure, Num(`$(vNetSales)/1000000,'#,##0.0'), Num(`$(vNetRevenue)/1000000,'#,##0.0'), Num(`$(vGrossMargin)/1000000,'#,##0.0'), Num(`$(vGrossMarginPct)*100,'0.0'), Num(`$(vDiscountRate)*100,'0.0'), Num(`$(vInvoices),'#,##0'))"; L='=' + $mLbl; Fmt='raw'; Color=$C.Primary }) | Out-Null
    New-QvText $doc $sh "${T}_TRD_BAR" @(230,376,950,30) -Text 'Measure:' -Bg $C.Card -Fg $C.Muted -Size 8.5 -Bold -Margin 10 | Out-Null
    $ms = @('Net Sales','Net Revenue','Gross Margin','Gross Margin %','Discount Rate %','Invoices')
    for ($i = 0; $i -lt $ms.Count; $i++) {
        $n = $i + 1
        New-QvButton $doc $sh "${T}_TRD_M$n" @((310 + $i * 124),380,118,22) -Text $ms[$i] -Size 8 `
            -Actions @(@{ Type='setvar'; P=@('vUI_TrendMeasure', "$n") }) `
            -BgExpr ("If(vUI_TrendMeasure=$n," + (Get-QvRgbExpr $C.Primary) + "," + (Get-QvRgbExpr $C.Panel) + ")") `
            -FgExpr ("If(vUI_TrendMeasure=$n," + (Get-QvRgbExpr $C.White) + "," + (Get-QvRgbExpr $C.Text) + ")") | Out-Null
    }

    # 2 Seasonality: one line per year
    New-QvChart $doc $sh "${T}_CH_SEASON" line @(1190,96,490,310) -Caption ("Seasonality " + $G.Dash + " Net Sales by Month per Year " + $eurM) -Legend -LegendPos 0 `
        -HelpText 'One line per year: the Q4 peak and the August dip repeat every year; 2026 runs to September.' `
        -Colors @($C.PY, $C.PrimaryLt, $C.Primary) `
        -YUnit ($G.Eur + ' M') -YUnitTop 52 -Dims @(@{ F='Month' }, @{ F='Year' }) `
        -Exprs @(@{ D='$(vNetSales)/1000000'; L=("Net Sales " + $eurM); Fmt='moneyM' }) | Out-Null

    $dimLbl = "Pick(Match(GetCurrentField(cyc_Dimension),'CustomerRegion','ProductCategory','Channel','SalesTeam','CustomerSegment','Brand'),'Region','Category','Channel','Sales Team','Segment','Brand')"
    # 3 Top N by cyc_Dimension with a cyclic expression group (bar labels carry the unit); limit through Rank
    New-QvChart $doc $sh "${T}_CH_TOPN" bar @(230,416,560,330) -Horizontal `
        -Caption ("='Top ' & vTopN & ' by ' & $dimLbl & ' " + $G.Dash + " ranked by the selected measure'") -Configure { param($p) $p.SortByYValue = -1 } `
        -HelpText 'Ranking of the chosen dimension. Cycle icon at the axis: dimension; cycle icon at the bottom: measure (Net Sales, Gross Margin, Invoices). The Top N slider in the left panel sets the number of bars.' `
        -Dims @(@{ F='cyc_Dimension' }) `
        -Exprs @(@{ D='If(Rank(TOTAL Sum(NetSales))<=vTopN, Sum(NetSales)/1000000)'; L=("Net Sales " + $eurM); Fmt='moneyM1'; Color=$C.Primary; Values=$true; Cycle=@(
                @{ D='If(Rank(TOTAL Sum(GrossMargin))<=vTopN, Sum(GrossMargin)/1000000)'; L=("Gross Margin " + $eurM); Fmt='moneyM1' },
                @{ D='If(Rank(TOTAL Count(DISTINCT InvoiceNo))<=vTopN, Count(DISTINCT InvoiceNo))'; L='Invoices (count)'; Fmt='int' }) }) | Out-Null

    # 4 Mekko Region x Channel
    New-QvChart $doc $sh "${T}_CH_MEKKO" mekko @(800,416,440,330) -Caption ("Channel Share of Net Sales by Region (column width = region size)") -Legend -LegendPos 0 `
        -HelpText 'Bar thickness = region size, segment length = channel share within the region. Compare the E-Commerce share across regions.' `
        -Dims @(@{ F="=If(CustomerRegion='Southern Europe','S. Europe',If(CustomerRegion='UK & Ireland','UK & IE',CustomerRegion))"; L='Region' }, @{ F='=Channel'; L='Channel' }) `
        -Exprs @(@{ D='$(vNetSales)/1000000'; L=("Net Sales " + $eurM); Fmt='moneyM'; NoAxis=$true; ColorExpr=$QS.ChannelColorExpr }) -Configure { param($p) $p.SortByYValue = -1; Set-QvFontDef $p.ChartProperties.XAxis.Font 7 } | Out-Null

    # 5 Container: scatter + growth by channel
    $crect = @(1250,416,430,330)
    New-QvChart $doc $sh "${T}_CH_SCATTER" scatter $crect -Caption 'Discount Rate vs Gross Margin % (bubble = Net Sales)' -Legend -LegendPos 0 `
        -HelpText 'Each bubble is a sales channel (size = net sales). E-Commerce sits bottom-right: highest discount, lowest margin.' `
        -Dims @(@{ F='Channel'; L='Channel' }) `
        -Exprs @(
            @{ D='$(vDiscountRate)'; L='Discount rate'; Fmt='pct'; NoForce0=$true },
            @{ D='$(vGrossMarginPct)'; L='Gross margin %'; Fmt='pct'; NoForce0=$true; ColorExpr=$QS.ChannelColorExpr },
            @{ D='$(vNetSales)/1000000'; L=("Net sales " + $eurM); Fmt='moneyM' }
        ) | Out-Null
    New-QvChart $doc $sh "${T}_CH_CHGROW" bar $crect -Caption ("Net Sales Growth by Channel " + $G.Dash + " CYTD vs PYTD (%)") `
        -HelpText 'Year-to-date growth per channel (Jan-Sep 2026 vs Jan-Sep 2025). E-Commerce grows fastest.' `
        -Dims @(@{ F='Channel'; SortExpr='$(vNetSales_YoY)'; SortDesc=$true }) `
        -Exprs @(@{ D='$(vNetSales_YoY)'; L='Growth vs PY'; Fmt='growth'; ColorExpr="If(`$(vNetSales_YoY)>=0,$good,$bad)"; Values=$true }) | Out-Null
    New-QvContainer $doc $sh "${T}_CT_CHAN" $crect -Caption 'Channel Economics' -HelpText 'Two views on the channels: click a tab.' `
        -Items @(@{ Id="${T}_CH_SCATTER"; Text='Discount vs margin' }, @{ Id="${T}_CH_CHGROW"; Text='Growth by channel' }) | Out-Null
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
