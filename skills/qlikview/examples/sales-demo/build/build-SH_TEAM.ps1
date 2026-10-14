# build-SH_TEAM.ps1 - "Sales Teams & Budget" (Analysis, story 3: UK & Ireland ~12% below budget). Owner: designer-b.
# Idempotent: clears SH_TEAM and rebuilds all objects with fixed IDs (layout-spec section 5).
# Run: timeout 300 powershell.exe -NoProfile -ExecutionPolicy Bypass -File build-SH_TEAM.ps1 [-NoShot] [-NoSave]
param([string]$SheetId = 'SH_TEAM', [string]$Tag = 'TEAM', [switch]$NoShot, [switch]$NoSave)
. "$PSScriptRoot\..\tools\lib-qv.ps1"; . "$PSScriptRoot\app-settings.ps1"
. "$PSScriptRoot\..\tools\lib-ext.ps1"
$G = $QS.Glyph; $C = $QS.C; $T = $Tag; $E = $G.Eur
$good = Get-QvRgbExpr $C.Good; $bad = Get-QvRgbExpr $C.Bad; $warn = Get-QvRgbExpr $C.Warn; $prim = Get-QvRgbExpr $C.Primary
$cal = 'Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date='
$SetCY = '$(vSetCY)'
$achCol = { param($e) "If(($e)>=1,$good,If(($e)>=0.95,$warn,$bad))" }
$achSeg = @(@('0.8',$C.Bad,'below 95%'),@('0.95',$C.Warn,'95-100%'),@('1',$C.Good,'on target'))
$actCY = "(Sum($SetCY NetSales)-Sum($SetCY CreditAmount))"
$budCY = "Sum($SetCY BudgetNetSales)"

Write-QvbLog "=== build $SheetId start"
Enter-QvLock -Owner designer-b -TimeoutSec 1200
$t0 = Get-Date
try {
    $doc = Get-QvDoc
    Remove-QvbSandbox $doc
    Enter-QvParking $doc
    $sh = Reset-QvSheet $doc $SheetId 'Team & Budget'

    New-QvHeader $doc $sh $T -Active 'TEAM' -Title 'Sales Teams & Budget' `
        -Subtitle ("Budget is per sales rep and month   " + $G.Mid + "   achievement = Net revenue / Budget to date   " + $G.Mid + "   CYTD = Jan" + $G.Dash + "Sep 2026") `
        -Help ("What am I looking at?  Which team misses its budget, and since when? The table shows achievement per team with a status light; drill from team to rep in the ranking chart (click a bar); the heatmap shows achievement by quarter. Budget links only via rep and date, so customer/product/channel selections blank the budget.")

    New-QvbFilterPanel $doc $sh $T -Section5 'Sales team'
    if (Get-Command Repair-QvCurSelWidths -ErrorAction SilentlyContinue) { try { Repair-QvCurSelWidths $doc $sh "${T}_FLT_CS" @(14,118,202,84) | Out-Null } catch { Write-QvbLog "cursel repair: $_" } }
    New-QvbListBox $doc $sh "${T}_FLT_LB_TEAM" @(14,606,202,136) 'SalesTeam' -Size 8.5 | Out-Null
    Write-QvbLog "chrome+panel done $([int]((Get-Date)-$t0).TotalSeconds)s"

    # ---------------- row 1 ----------------
    New-QvbChart @{ Doc=$doc; Sheet=$sh; Id="${T}_TB_TEAMS"; Type='straight'; Rect=@(230,96,720,190)
        Caption=("Budget Achievement by Sales Team " + $G.Dash + " CYTD"); XL=$true
        HelpText='Net revenue vs budget to date (Jan-Sep 2026) per sales team. Status: green >= 100 %, amber 95-100 %, red < 95 %. Trend = monthly achievement Jan-Sep 2026.'
        Dims=@(@{ F='SalesTeam'; L='Sales team'; SortExpr='$(vBudgetAch_CYTD)'; SortDesc=$false; ColWidth=(ConvertTo-QvbCw 116) },
               @{ F='SalesManager'; L='Manager'; ColWidth=(ConvertTo-QvbCw 112) })
        Exprs=@(
            @{ D='$(vNetRevenue_CYTD)'; L=("Net revenue (" + $E + ")"); Fmt='money'; ColWidth=(ConvertTo-QvbCw 104) },
            @{ D='$(vBudget_CYTD)'; L=("Budget to date (" + $E + ")"); Fmt='money'; ColWidth=(ConvertTo-QvbCw 112) },
            @{ D='$(vBudgetAch_CYTD)'; L='Ach. %'; Fmt='pct'; TextColorExpr=(& $achCol '$(vBudgetAch_CYTD)'); ColWidth=(ConvertTo-QvbCw 56) },
            @{ D='$(vBudgetAch_CYTD)'; L=$G.Dot; Repr='traffic'; Gauge=@{ Min='0.8'; Max='1.2'; Seg=$achSeg }; ColWidth=(ConvertTo-QvbCw 30) },
            @{ D='$(vNetRevenue_CYTD)-$(vBudget_CYTD)'; L=("Gap vs budget (" + $E + ")"); Fmt=("+" + $E + " #,##0;-" + $E + " #,##0")
               TextColorExpr="If(`$(vNetRevenue_CYTD)>=`$(vBudget_CYTD),$good,$bad)"; ColWidth=(ConvertTo-QvbCw 108) },
            @{ D='$(vBudgetAch_CYTD)'; L='Trend 2026'; Repr='minichart'; Mini=@{ Dim='YearMonth'; Mode='line' }; NoTotal=$true; ColWidth=(ConvertTo-QvbCw 102) }
        ) } -Extra { param($p) Set-QvbBlankNull $p } | Out-Null

    # ---- story tile: where is the gap? (dynamic, follows selections) ----
    $achT = 'Aggr($(vBudgetAch_CYTD),SalesTeam)'
    $achR = 'Aggr($(vBudgetAch_CYTD),SalesRepName)'
    $gapT = 'Aggr($(vNetRevenue_CYTD)-$(vBudget_CYTD),SalesTeam)'
    $minT = "Min($achT)"
    New-QvKpiTile $doc $sh "${T}_STORY" 230 296 -W 720 -H 118 -Label ("WHERE IS THE GAP?  " + $G.Mid + "  LOWEST BUDGET ACHIEVEMENT  " + $G.Mid + "  CYTD") `
        -Value ("=If(IsNull($minT),'Budget not available for this selection', FirstSortedValue(SalesTeam,$achT) & ':  ' & Num($minT,'0.0%') & ' of budget to date')") `
        -Delta ("=If(IsNull($minT),'', If(FirstSortedValue($gapT,$achT)>=0,Chr(9650),Chr(9660)) & ' ' & Num(FirstSortedValue($gapT,$achT)/1000000,'+" + $E + " #,##0.0;-" + $E + " #,##0.0') & ' M vs budget to date, Jan" + $G.Dash + "Sep 2026')") `
        -Context ("=If(IsNull($minT),'Budget is planned per sales rep and month: clear customer / product / channel selections.', 'Weakest rep: ' & FirstSortedValue(SalesRepName,$achR) & ' ' & Num(Min($achR),'0.0%') & If(GetPossibleCount(SalesTeam)>1, '   " + $G.Mid + "   other teams ' & Num(Min($achT,2),'0.0%') & ' " + $G.Dash + " ' & Num(Max($achT),'0.0%'), '') & '   " + $G.Mid + "   see the heatmap for since when')") `
        -StatusExpr "If($minT>=1,1,If($minT>=0.95,0,-1))" -HelpText 'The sales team with the lowest budget achievement in the current selection, its gap in EUR and the weakest sales rep.'
    Update-QvLock -Owner designer-b

    New-QvbChart @{ Doc=$doc; Sheet=$sh; Id="${T}_CH_ACTBUD"; Type='combo'; Rect=@(960,96,720,320)
        Caption=("Actual vs Budget by Month 2026 (" + $E + " M)"); Legend=$true; LegendPos=0; Maximize=$true
        HelpText='Bars: net revenue per month 2026 (actuals end in September). Amber line: full-year budget 2026 (all 12 months). Dots (right axis): achievement %. Calendar selections are ignored so the whole year stays visible; team selections apply.'
        Dims=@(@{ F='Month'; L='Month' })
        Exprs=@(
            @{ D="$actCY/1000000"; L='Actual 2026'; Fmt='moneyM1'; Mode='bar'; Color=$C.Primary },
            @{ D="$budCY/1000000"; L='Full-year budget 2026'; Fmt='moneyM1'; Mode='linesymbol'; Color=$C.Budget },
            @{ D="If(Sum($SetCY NetSales)>0, $actCY/$budCY)"; L='Achievement %'; Fmt='pct0'; Mode='symbol'; Right=$true; AxisMin='0.8'; AxisMax='1.2'
               ColorExpr=(& $achCol "$actCY/$budCY") }
        ) } | Out-Null
    Update-QvLock -Owner designer-b
    Write-QvbLog "row1 done $([int]((Get-Date)-$t0).TotalSeconds)s"

    # ---------------- row 2 ----------------
    $selName = "If(GetCurrentField(drl_Sales)='SalesRepName','Sales Rep','Sales Team')"
    New-QvbChart @{ Doc=$doc; Sheet=$sh; Id="${T}_CH_REPS"; Type='bar'; Rect=@(230,426,560,320)
        Caption=("='Budget Achievement by ' & $selName & ' " + $G.Dash + " CYTD (%)'"); Horizontal=$true; Maximize=$true
        HelpText='Achievement (net revenue / budget, Jan-Sep 2026), highest first. Click a team bar to drill down to its sales reps; use the drill-up arrow in the caption to go back. Black line = 100 %.'
        Dims=@(@{ F='drl_Sales'; L='Team / rep'; SortExpr='$(vBudgetAch_CYTD)'; SortDesc=$true })
        Exprs=@(@{ D='$(vBudgetAch_CYTD)'; L='Budget achievement'; Fmt='pct'; Values=$true; AxisMin='0.8'; AxisMax='1.1'
                   ColorExpr=(& $achCol '$(vBudgetAch_CYTD)') }) } -Extra {
        param($p)
        Add-QvbRefLine $p '1' $QS.C.Text '100%' 2
        try { $p.SortByYValue = -1 } catch { Write-QvbLog "SortByYValue: $_" }
    } | Out-Null

    New-QvbChart @{ Doc=$doc; Sheet=$sh; Id="${T}_CH_GRID"; Type='grid'; Rect=@(800,426,520,320)
        Caption=("Achievement Heatmap " + $G.Dash + " Team x Quarter 2025" + $G.Dash + "2026 (%)")
        HelpText='Each dot = one team in one quarter (2025 to Sep 2026). Green >= 100 %, amber 95-100 %, red < 95 %. UK & Ireland slides from amber to red during 2025-2026. Hover for the value.'
        Dims=@(@{ F='YearQuarter'; L='Quarter' }, @{ F='SalesTeam'; L='Team' })
        Exprs=@(@{ D='If(Sum(NetSales)>0 and Only(Year)>=2025, $(vBudgetAch))'; L='Budget achievement'; Fmt='pct'
                   ColorExpr=(& $achCol '$(vBudgetAch)') })
        Texts=@(
            @{ T=($G.Dot + ' ' + [char]0x2265 + ' 100%'); R=@(767,8,212,45); Size=8; Bold=$true; Color=$C.Good; Align=0 },
            @{ T=($G.Dot + ' 95' + $G.Dash + '100%'); R=@(979,8,240,45); Size=8; Bold=$true; Color=$C.Warn; Align=0 },
            @{ T=($G.Dot + ' < 95%'); R=@(1220,8,190,45); Size=8; Bold=$true; Color=$C.Bad; Align=0 }) } -Extra {
        param($p)
        $p.ChartProperties.GridChartMode = 0
    } | Out-Null

    New-QvbChart @{ Doc=$doc; Sheet=$sh; Id="${T}_GA_ACH"; Type='gauge'; Rect=@(1330,426,350,320)
        Caption=("Budget Achievement " + $G.Dash + " Current Selection, CYTD (%)")
        HelpText='Net revenue / budget, Jan-Sep 2026, for the selected team(s) or rep(s). Red < 95 %, amber 95-100 %, green >= 100 %. Select UK & Ireland in the left panel to see the miss.'
        Exprs=@(@{ D='$(vBudgetAch_CYTD)'; L='Budget achievement'; Fmt='pct' }); GaugeMode=4
        Gauge=@{ Min='0.8'; Max='1.2'; Seg=$achSeg; Indicator=$C.Text; Ticks=5 }
        Texts=@(@{ T=("=Num(`$(vBudgetAch_CYTD),'0.0%') & Chr(10) & If(GetSelectedCount(SalesTeam)=1, SalesTeam, If(GetSelectedCount(SalesTeam)=0,'All teams', GetSelectedCount(SalesTeam) & ' teams'))"); R=@(0,590,926,150); Size=13; Bold=$true }) } | Out-Null
    Update-QvLock -Owner designer-b
    if (Get-Command Set-QvSheetOrder -ErrorAction SilentlyContinue) { Set-QvSheetOrder $doc }
    Write-QvbLog "row2 done $([int]((Get-Date)-$t0).TotalSeconds)s"
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
