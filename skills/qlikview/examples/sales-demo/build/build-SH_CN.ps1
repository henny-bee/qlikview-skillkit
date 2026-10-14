# build-SH_CN.ps1 - "Credit Notes & Returns" (Analysis, story 1: Networking quality issue). Owner: designer-b.
# Idempotent: clears SH_CN and rebuilds all objects with fixed IDs (layout-spec section 3).
# Run: timeout 300 powershell.exe -NoProfile -ExecutionPolicy Bypass -File build-SH_CN.ps1 [-NoShot] [-NoSave]
param([string]$SheetId = 'SH_CN', [string]$Tag = 'CN', [switch]$NoShot, [switch]$NoSave)
. "$PSScriptRoot\..\tools\lib-qv.ps1"; . "$PSScriptRoot\app-settings.ps1"
. "$PSScriptRoot\..\tools\lib-ext.ps1"
$G = $QS.Glyph; $C = $QS.C; $T = $Tag; $E = $G.Eur
$good = Get-QvRgbExpr $C.Good; $bad = Get-QvRgbExpr $C.Bad; $warn = Get-QvRgbExpr $C.Warn; $prim = Get-QvRgbExpr $C.Primary
$cal0 = 'Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date='
$qCY = "(Sum({<$cal0,Flag_CYTD={1},ReturnReasonGroup={'Quality'}>} CreditAmount)/" + '$(vCreditAmount_CYTD))'
$qPY = "(Sum({<$cal0,Flag_PYTD={1},ReturnReasonGroup={'Quality'}>} CreditAmount)/" + '$(vCreditAmount_PYTD))'
$cnCY = 'Count($(vSetCYTD) DISTINCT CreditNoteNo)'
$cnPY = 'Count($(vSetPYTD) DISTINCT CreditNoteNo)'
$crCol = "If(`$(vCreditRate)>0.07,$bad,If(`$(vCreditRate)>0.05,$warn,$good))"
$crSeg = @(@('0',$C.Good,'<= 5%'),@('0.05',$C.Warn,'5-7%'),@('0.07',$C.Bad,'> 7%'))

Write-QvbLog "=== build $SheetId start"
Enter-QvLock -Owner designer-b -TimeoutSec 1200
$t0 = Get-Date
try {
    $doc = Get-QvDoc
    Remove-QvbSandbox $doc
    Enter-QvParking $doc
    $sh = Reset-QvSheet $doc $SheetId 'Credit Notes'

    New-QvHeader $doc $sh $T -Active 'CN' -Title 'Credit Notes & Returns' `
        -Subtitle ("Credit rate = Credit amount / Net sales   " + $G.Mid + "   lower is better   " + $G.Mid + "   KPIs: Jan" + $G.Dash + "Sep 2026 (CYTD) vs Jan" + $G.Dash + "Sep 2025") `
        -Help ("What am I looking at?  Which products and reasons drive credit notes? Watch the red Networking line in the credit-rate trend and the 'Quality' reasons. Switch reason / reason group / category with the cycle icon in the bar-chart caption.")

    New-QvbFilterPanel $doc $sh $T -Section5 'Return reason'
    if (Get-Command Repair-QvCurSelWidths -ErrorAction SilentlyContinue) { try { Repair-QvCurSelWidths $doc $sh "${T}_FLT_CS" @(14,118,202,84) | Out-Null } catch { Write-QvbLog "cursel repair: $_" } }
    New-QvbListBox $doc $sh "${T}_FLT_LB_REASON" @(14,606,202,136) 'ReturnReason' -Size 8.5 | Out-Null
    Update-QvLock -Owner designer-b
    Write-QvbLog "chrome+panel done $([int]((Get-Date)-$t0).TotalSeconds)s"

    # ---------------- mini KPIs ----------------
    New-QvMiniKpi $doc $sh "${T}_KPI1" 230 96 -Label ("CREDIT AMOUNT  " + $G.Mid + "  CYTD") `
        -Value ('=' + (Get-QvMoneyM '$(vCreditAmount_CYTD)')) `
        -Delta ('=' + (Get-QvGrowthText '($(vCreditAmount_CYTD)/$(vCreditAmount_PYTD)-1)')) `
        -StatusExpr 'If($(vCreditAmount_CYTD)<=$(vCreditAmount_PYTD),1,-1)'
    New-QvMiniKpi $doc $sh "${T}_KPI2" 595 96 -Label ("CREDIT RATE  " + $G.Mid + "  CYTD") `
        -Value "=Num(`$(vCreditRate_CYTD),'0.0%')" `
        -Delta ('=' + (Get-QvPpText '$(vCreditRate_YoYpp)')) `
        -StatusExpr 'If($(vCreditRate_YoYpp)<=0,1,-1)'
    New-QvMiniKpi $doc $sh "${T}_KPI3" 960 96 -Label ("CREDIT NOTES  " + $G.Mid + "  CYTD") `
        -Value "=Num($cnCY,'#,##0')" `
        -Delta ('=' + (Get-QvGrowthText "($cnCY/$cnPY-1)")) `
        -StatusExpr "If($cnCY<=$cnPY,1,-1)"
    New-QvMiniKpi $doc $sh "${T}_KPI4" 1325 96 -Label ("QUALITY SHARE OF CREDITS  " + $G.Mid + "  CYTD") `
        -Value "=Num($qCY,'0.0%')" `
        -Delta ('=' + (Get-QvPpText "(($qCY-$qPY)*100)")) `
        -StatusExpr "If($qCY<=$qPY,1,-1)"
    Update-QvLock -Owner designer-b

    # ---------------- row 2 ----------------
    $catCol = "If(ProductCategory='Networking',$bad,Pick(Match(ProductCategory,'Notebooks & PCs','Monitors & Displays','Storage','Peripherals','Software & Services'),RGB(127,156,192),RGB(141,182,226),RGB(154,165,177),RGB(180,191,203),RGB(107,119,133)))"
    New-QvbChart @{ Doc=$doc; Sheet=$sh; Id="${T}_CH_RATE"; Type='line'; Rect=@(230,170,720,280)
        Caption='Credit Rate by Quarter per Product Category (%)'; Legend=$true; LegendPos=3; Maximize=$true
        HelpText='Credit amount / net sales per quarter and product category. Red line = Networking: its credit rate climbs from about 3 % (2024) to about 9 % (2026) - a quality problem (see Quality defect in the reason chart).'
        Dims=@(@{ F='YearQuarter'; L='Quarter' }, @{ F='ProductCategory'; L='Category' })
        Exprs=@(@{ D='$(vCreditRate)'; L='Credit rate'; Fmt='pct'; ColorExpr=$catCol; AxisMin='0' }) } -Extra {
        param($p)
        try { $p.Expressions.Item(0).Item(0).Data.AttributeExpressions.LineStyleExp.Definition.v = "If(ProductCategory='Networking','<W4>','<W1.5>')" } catch { Write-QvbLog "linestyle: $_" }
    } | Out-Null

    $retName = "Pick(Match(GetCurrentField(cyc_Returns),'ReturnReason','ReturnReasonGroup','ProductCategory'),'Return Reason','Reason Group','Product Category')"
    New-QvbChart @{ Doc=$doc; Sheet=$sh; Id="${T}_CH_REASON"; Type='bar'; Rect=@(960,170,720,280)
        Caption=("='Credit Amount by ' & $retName & ' per Year (' & Chr(8364) & ' M)'"); Horizontal=$true; Legend=$true; LegendPos=3; Maximize=$true
        HelpText='Credit amount (EUR million) per return reason and year; 2026 = Jan-Sep only. Click the cycle icon to switch between reason, reason group and product category. Quality defect grows fastest.'
        Dims=@(@{ F='cyc_Returns'; L='Reason'; SortExpr='$(vCreditAmount)'; SortDesc=$true }, @{ F='Year'; L='Year' })
        Exprs=@(@{ D='$(vCreditAmount)/1000000'; L=("Credit amount (" + $E + " M)"); Fmt='#,##0.0'
                   ColorExpr="If(Year=2026,$prim,If(Year=2025,RGB(160,172,186),RGB(214,220,227)))" }) } | Out-Null
    Update-QvLock -Owner designer-b
    Write-QvbLog "row2 done $([int]((Get-Date)-$t0).TotalSeconds)s"

    # ---------------- row 3 ----------------
    $heat = 'ColorMix1(RangeMin(1,RangeMax(0,($(vCreditRate)-0.02)/0.075)),RGB(234,242,251),RGB(47,109,181))'
    New-QvbChart @{ Doc=$doc; Sheet=$sh; Id="${T}_PT_HEAT"; Type='pivot'; Rect=@(230,460,520,170)
        Caption='Credit-Rate Heatmap - Category x Year (%)'
        HelpText='Credit rate per product category and year; darker = higher. Click a category or year to filter. Networking rises from 2.8 % (2024) to 9.0 % (2026).'
        Dims=@(@{ F='=ProductCategory'; L='Product category'; ColWidth=(ConvertTo-QvbCw 170) }, @{ F='=Year'; L='Year'; ColWidth=(ConvertTo-QvbCw 40) })
        Exprs=@(@{ D='$(vCreditRate)'; L='Credit rate'; Fmt='pct'; ColorExpr=$heat
                   TextColorExpr='If($(vCreditRate)>0.065,RGB(255,255,255),RGB(31,41,51))'; ColWidth=(ConvertTo-QvbCw 88) }) } -Extra {
        param($p)
        foreach ($o in @($p.TableProperties, $p)) { try { $o.NumberOfLeftDimensions = 1 } catch {} }
        try { Set-QvFontDef $p.GraphLayout.Frame.Font 10 } catch {}
        try { $p.Dimensions.Item(0).ShowPartialSums = $true } catch { Write-QvbLog "partial sums: $_" }
        Set-QvbBlankNull $p
    } | Out-Null

    # ---- story tile under the heatmap (fixed story view: Networking, ignores calendar selections) ----
    $sN = { param($y, $extra) "{<ProductCategory={'Networking'},Year={$y}$extra,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=>}" }
    $rN = { param($y) $st = & $sN $y ''; "(Sum($st CreditAmount)/Sum($st NetSales))" }
    $qN = { param($y) $st = & $sN $y ''; $sq = & $sN $y ",ReturnReasonGroup={'Quality'}"; "(Sum($sq CreditAmount)/Sum($st CreditAmount))" }
    $s26 = & $sN 2026 ''
    $grpRate = "Aggr(Sum($s26 CreditAmount)/Sum($s26 NetSales),ProductGroup)"
    New-QvText $doc $sh "${T}_STORY_BG" @(230,640,520,106) -Bg $C.Card -HelpText 'Story 1 at a glance: Networking credit rate by year, the share of Quality returns and the worst Networking product group in 2026.' | Out-Null
    New-QvText $doc $sh "${T}_STORY_BAR" @(230,640,4,106) -Bg $C.Bad | Out-Null
    New-QvText $doc $sh "${T}_STORY_LBL" @(244,647,496,18) -Text ("STORY  " + $G.Mid + "  NETWORKING QUALITY ISSUE") -BgAlpha 0 -Fg $C.Muted -Size 8.5 -Bold -Margin 0 | Out-Null
    New-QvText $doc $sh "${T}_STORY_VAL" @(244,665,496,32) -Text ("='Networking credit rate  ' & Num(" + (& $rN 2024) + ",'0.0%') & '  ' & Chr(8594) & '  ' & Num(" + (& $rN 2025) + ",'0.0%') & '  ' & Chr(8594) & '  ' & Num(" + (& $rN 2026) + ",'0.0%')") -BgAlpha 0 -Fg $C.Text -Size 15 -Bold -Margin 0 | Out-Null
    New-QvText $doc $sh "${T}_STORY_DLT" @(244,699,496,18) -Text ("=Chr(9650) & ' ' & Num(" + (& $qN 2026) + ",'0%') & ' of Networking credits in 2026 are Quality returns (2024: ' & Num(" + (& $qN 2024) + ",'0%') & ')'") -BgAlpha 0 -Fg $C.Bad -Size 8.5 -Bold -Margin 0 | Out-Null
    New-QvText $doc $sh "${T}_STORY_CTX" @(244,719,496,18) -Text ("='Worst product group 2026: ' & FirstSortedValue($s26 ProductGroup, -$grpRate) & ' ' & Num(Max($grpRate),'0.0%') & '   " + $G.Mid + "   use Year / Category filters to explore'") -BgAlpha 0 -Fg $C.Muted -Size 8 -Margin 0 | Out-Null
    Update-QvLock -Owner designer-b

    $grpCol = "Pick(Match(ReturnReasonGroup,'Quality','Logistics','Commercial'),$bad,RGB(141,182,226),RGB(180,191,203))"
    New-QvbChart @{ Doc=$doc; Sheet=$sh; Id="${T}_CH_MIX"; Type='bar'; Rect=@(760,460,460,286)
        Caption='Credit Mix by Category - Share of Reason Group (%)'; Horizontal=$true; Stacked=$true; Legend=$true; LegendPos=0
        HelpText='Share of each reason group in the credit amount of a product category (each row = 100 %; hover for the exact share). Red = Quality returns: Networking has by far the highest quality share.'
        Dims=@(@{ F='ProductCategory'; L='Category'; SortExpr="Sum({<ReturnReasonGroup={'Quality'}>} CreditAmount)/Sum(CreditAmount)"; SortDesc=$true },
               @{ F='ReturnReasonGroup'; L='Reason group' })
        Exprs=@(@{ D='$(vCreditAmount)/Sum(TOTAL <ProductCategory> CreditAmount)'; L='Share of credits'; Fmt='pct0'; ColorExpr=$grpCol; AxisMin='0'; AxisMax='1' }) } -Extra {
        param($p)
        $ax = $p.Expressions.Item(0).Item(0).Data.AxisData
        Write-QvbLog ("AxisData members: " + (($ax | Get-Member -MemberType Property | ForEach-Object Name) -join ','))
        foreach ($n in 'Show','ShowLabels','HideAxis') { try { if ($n -eq 'HideAxis') { $ax.$n = $true } else { $ax.$n = $false } } catch {} }
        $ax.Grid = $false
    } | Out-Null

    New-QvbChart @{ Doc=$doc; Sheet=$sh; Id="${T}_TB_PROD"; Type='straight'; Rect=@(1230,460,450,286)
        Caption=("Products with the Highest Credit Rate (Net Sales >= " + $E + " 100k)"); XL=$true
        HelpText='Products with at least EUR 100k net sales in the selection, sorted by credit rate. Credits and net sales in EUR thousand. Status: green <= 5 %, amber 5-7 %, red > 7 %.'
        Dims=@(@{ F='=Aggr(If(Sum(NetSales)>=100000,ProductName),ProductName)'; L='Product'; SortExpr='$(vCreditRate)'; SortDesc=$true; ColWidth=(ConvertTo-QvbCw 168) })
        Exprs=@(
            @{ D='$(vCreditRate)'; L='Rate'; Fmt='pct'; TextColorExpr=$crCol; ColWidth=(ConvertTo-QvbCw 50) },
            @{ D='$(vCreditRate)'; L=$G.Dot; Repr='traffic'; Gauge=@{ Min='0'; Max='0.1'; Seg=$crSeg }; ColWidth=(ConvertTo-QvbCw 24) },
            @{ D='$(vCreditAmount)/1000'; L=("Credits " + $E + "k"); Fmt='#,##0'; ColWidth=(ConvertTo-QvbCw 68) },
            @{ D='$(vNetSales)/1000'; L=("Net sales " + $E + "k"); Fmt='#,##0'; ColWidth=(ConvertTo-QvbCw 74) },
            @{ D='$(vCreditNotes)'; L='# CN'; Fmt='int'; ColWidth=(ConvertTo-QvbCw 44) }
        ) } -Extra { param($p) Set-QvbBlankNull $p } | Out-Null
    Update-QvLock -Owner designer-b
    if (Get-Command Set-QvSheetOrder -ErrorAction SilentlyContinue) { Set-QvSheetOrder $doc }
    Write-QvbLog "row3 done $([int]((Get-Date)-$t0).TotalSeconds)s"
} catch {
    Write-QvbLog "ERROR: $_ $($_.ScriptStackTrace)"
    throw
} finally {
    try { Exit-QvParking $doc $SheetId } catch { Write-Warning "parking cleanup: $_" }
    try {
        if (-not $NoShot) {
            (Get-QvApp).WaitForIdle()
            Start-Sleep -Seconds 2
            Save-QvScreenshot -Path "$QvBuildRoot\shots\$SheetId.png" | Out-Null
            "shot: $QvBuildRoot\shots\$SheetId.png"
        }
        if (-not $NoSave) { Save-QvCheckpoint -Doc $doc -Label "B-$SheetId"; 'checkpoint saved' }
    } catch { Write-Warning "shot/save: $_" }
    Exit-QvLock -Owner designer-b
    Write-QvbLog "=== build $SheetId end $([int]((Get-Date)-$t0).TotalSeconds)s"
}
